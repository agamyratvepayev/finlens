import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../persistence/store_mappers.dart';
import '../persistence/sync_store.dart';
import '../store/app_store.dart';
import 'api_client.dart';
import 'sync_controller.dart';
import 'sync_models.dart';
import 'store_diff.dart';

/// Drives sync: watches [AppStore] (its own listener, independent of the
/// persister's), diffs the store against the `sync_shadow` table, pushes and
/// pulls through one API call, queues version conflicts for the user, and
/// applies remote changes back into the store.
///
/// Ordering rule that keeps the loop stable: remote changes update the shadow
/// BEFORE they mutate the store, so the listener this very mutation triggers
/// diffs to nothing and no echo is pushed.
class SyncEngine {
  SyncEngine(this._store, this._syncStore, this._api, this._controller);

  final AppStore _store;
  final SyncStore _syncStore;
  final SyncApiClient _api;
  final SyncController _controller;

  /// Longer than the persister's 500 ms: the local write should land first,
  /// and a burst of edits should collapse into one push.
  static const Duration _debounceDelay = Duration(seconds: 3);

  Timer? _debounce;
  bool _attached = false;
  Future<void>? _inFlight;

  void attach() {
    if (_attached) return;
    _attached = true;
    _store.addListener(_onStoreChanged);
  }

  void dispose() {
    if (_attached) {
      _store.removeListener(_onStoreChanged);
      _attached = false;
    }
    _debounce?.cancel();
    _debounce = null;
  }

  bool get _canSync => _controller.isSignedIn && _controller.isInGroup;

  void _onStoreChanged() {
    if (!_canSync) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      _debounce = null;
      unawaited(_enqueue(() => _sync(skipWhenClean: true)));
    });
  }

  /// Manual "Sync now" and launch/resume pulls — always goes to the network.
  Future<void> syncNow() => _enqueue(() => _sync(skipWhenClean: false));

  /// Serializes syncs so two never overlap (same pattern as StorePersister).
  Future<void> _enqueue(Future<void> Function() job) {
    final next = (_inFlight ?? Future<void>.value()).then((_) => job());
    _inFlight = next;
    next.whenComplete(() {
      if (identical(_inFlight, next)) _inFlight = null;
    });
    return next;
  }

  Future<void> _sync({required bool skipWhenClean}) async {
    if (!_canSync) return;
    final token = _controller.token!;
    final group = _controller.group!;

    final current = snapshotAsRecords(_store);
    final shadow = await _syncStore.readShadow();
    final changes = diffAgainstShadow(current, shadow);
    // A store notification that produced no content change (view prefs, the
    // echo of an applied pull) should not hit the network at all.
    if (skipWhenClean && changes.isEmpty) return;

    final cursor =
        int.tryParse(await _syncStore.getMeta(SyncStore.kSyncCursor) ?? '') ?? 0;

    _controller.reportStatus(SyncStatus.syncing);
    final SyncResponse response;
    try {
      response = await _api.sync(token, group.id, cursor, changes);
    } on SyncApiException catch (e) {
      switch (e.kind) {
        case SyncApiErrorKind.network:
          _controller.reportStatus(SyncStatus.offline);
        case SyncApiErrorKind.unauthorized:
          await _controller.handleUnauthorized();
        case SyncApiErrorKind.forbidden:
          await _controller.handleRemovedFromGroup();
        default:
          _controller.reportStatus(SyncStatus.error);
      }
      return;
    } catch (e) {
      debugPrint('SyncEngine: sync failed: $e');
      _controller.reportStatus(SyncStatus.error);
      return;
    }

    // 1. Acknowledged pushes → shadow reflects what the server now holds.
    final pushedByKey = <RecordKey, RecordChange>{
      for (final c in changes) (c.entityType, c.recordId): c,
    };
    for (final applied in response.applied) {
      final key = (applied.entityType, applied.recordId);
      final pushed = pushedByKey[key];
      if (pushed == null) continue;
      if (pushed.deleted) {
        await _syncStore.removeShadow(applied.entityType, applied.recordId);
      } else {
        await _syncStore.upsertShadow(
          applied.entityType,
          applied.recordId,
          applied.version,
          pushed.payload!,
        );
      }
    }

    // 2. Version conflicts → queue for the user; nothing is applied for these
    //    keys until they decide (their pulled rows are excluded below too).
    for (final conflict in response.conflicts) {
      final pushed = pushedByKey[(conflict.entityType, conflict.recordId)];
      await _syncStore.putConflict(ConflictRow(
        entityType: conflict.entityType,
        recordId: conflict.recordId,
        localPayload: pushed?.payload,
        localDeleted: pushed?.deleted ?? false,
        remotePayload: conflict.serverPayload,
        remoteDeleted: conflict.serverDeleted,
        remoteVersion: conflict.serverVersion,
        remoteUpdatedBy: conflict.updatedByEmail,
        remoteUpdatedAt: conflict.updatedAt,
      ));
    }

    // 3. Pulled changes → shadow first, then one batched store apply.
    final conflictKeys = <RecordKey>{
      for (final row in await _syncStore.readConflicts())
        (row.entityType, row.recordId),
    };
    final shadowVersions = <RecordKey, int>{
      for (final row in await _syncStore.readShadow())
        (row.entityType, row.recordId): row.version,
    };
    final toApply = <RemoteChange>[];
    for (final change in response.changes) {
      final key = (change.entityType, change.recordId);
      // Skip our own echoes (shadow already at this version) and every record
      // awaiting the user's conflict decision.
      if (conflictKeys.contains(key)) continue;
      if ((shadowVersions[key] ?? -1) >= change.version) continue;
      if (change.deleted) {
        await _syncStore.removeShadow(change.entityType, change.recordId);
      } else {
        await _syncStore.upsertShadow(
          change.entityType,
          change.recordId,
          change.version,
          change.payload!,
        );
      }
      toApply.add(change);
    }
    if (toApply.isNotEmpty) _applyRemoteChanges(toApply);

    await _syncStore.setMeta(SyncStore.kSyncCursor, '${response.cursor}');
    await _controller.reportSynced();
    if (response.conflicts.isNotEmpty || conflictKeys.isNotEmpty) {
      await _controller.refreshConflictCount();
    }
  }

  /// One batched, typed apply — the store notifies once.
  void _applyRemoteChanges(List<RemoteChange> remote) {
    final accounts = <Account>[];
    final categories = <Category>[];
    final budgets = <Budget>[];
    final txns = <Txn>[];
    final tags = <Tag>[];
    final goals = <Goal>[];
    final tasks = <Task>[];
    final currencies = <CurrencyDef>[];
    final deleted = <String, Set<String>>{};
    int? tagSchema;

    for (final change in remote) {
      if (change.deleted) {
        (deleted[change.entityType] ??= {}).add(change.recordId);
        continue;
      }
      final payload = change.payload!;
      switch (change.entityType) {
        case EntityTypes.account:
          accounts.add(accountFromMap(payload));
        case EntityTypes.category:
          categories.add(categoryFromMap(payload));
        case EntityTypes.budget:
          budgets.add(budgetFromMap(payload));
        case EntityTypes.txn:
          txns.add(txnFromMap(payload));
        case EntityTypes.tag:
          tags.add(tagFromMap(payload));
        case EntityTypes.goal:
          goals.add(goalFromMap(payload));
        case EntityTypes.task:
          tasks.add(taskFromMap(payload));
        case EntityTypes.currency:
          currencies.add(currencyDefFromMap(payload));
        case EntityTypes.meta:
          if (change.recordId == 'tag_schema') {
            tagSchema = int.tryParse('${payload['value']}');
          }
          // budget_history_since only matters at construction; the initial
          // full pull handles it, incremental changes to it are ignored.
      }
    }

    _store.applySyncedRecords(
      accounts: accounts,
      categories: categories,
      budgets: budgets,
      txns: txns,
      tags: tags,
      goals: goals,
      tasks: tasks,
      currencies: currencies,
      deletedAccountIds: deleted[EntityTypes.account] ?? const {},
      deletedCategoryIds: deleted[EntityTypes.category] ?? const {},
      deletedBudgetIds: deleted[EntityTypes.budget] ?? const {},
      deletedTxnIds: deleted[EntityTypes.txn] ?? const {},
      deletedTagIds: deleted[EntityTypes.tag] ?? const {},
      deletedGoalIds: deleted[EntityTypes.goal] ?? const {},
      deletedTaskIds: deleted[EntityTypes.task] ?? const {},
      deletedCurrencyCodes: deleted[EntityTypes.currency] ?? const {},
      tagSchema: tagSchema,
    );
  }

  /// The user's mine/theirs decision for one queued conflict.
  Future<void> resolveConflict(ConflictRow conflict, {required bool keepMine}) =>
      _enqueue(() => _resolve(conflict, keepMine: keepMine));

  Future<void> _resolve(ConflictRow conflict, {required bool keepMine}) async {
    if (!_canSync) return;
    final token = _controller.token!;
    final group = _controller.group!;

    if (keepMine) {
      // Deliberate overwrite: re-push based on the server's current version.
      // For "mine" the local store already holds the desired state — the
      // freshest payload comes from the store, not the stale conflict row.
      final current = snapshotAsRecords(_store);
      final payload = current[(conflict.entityType, conflict.recordId)];
      final change = RecordChange(
        entityType: conflict.entityType,
        recordId: conflict.recordId,
        baseVersion: conflict.remoteVersion,
        deleted: payload == null,
        payload: payload,
      );
      try {
        final response = await _api.sync(token, group.id, 0, [change]);
        AppliedRecord? applied;
        for (final a in response.applied) {
          if (a.entityType == conflict.entityType &&
              a.recordId == conflict.recordId) {
            applied = a;
            break;
          }
        }
        if (applied == null) {
          // Lost another race — the refreshed server side replaces the queued
          // conflict and the user decides again.
          RemoteConflict? again;
          for (final c in response.conflicts) {
            if (c.entityType == conflict.entityType &&
                c.recordId == conflict.recordId) {
              again = c;
              break;
            }
          }
          if (again != null) {
            await _syncStore.putConflict(ConflictRow(
              entityType: conflict.entityType,
              recordId: conflict.recordId,
              localPayload: payload,
              localDeleted: payload == null,
              remotePayload: again.serverPayload,
              remoteDeleted: again.serverDeleted,
              remoteVersion: again.serverVersion,
              remoteUpdatedBy: again.updatedByEmail,
              remoteUpdatedAt: again.updatedAt,
            ));
          }
          await _controller.refreshConflictCount();
          return;
        }
        if (payload == null) {
          await _syncStore.removeShadow(conflict.entityType, conflict.recordId);
        } else {
          await _syncStore.upsertShadow(
            conflict.entityType,
            conflict.recordId,
            applied.version,
            payload,
          );
        }
      } on SyncApiException catch (e) {
        _controller.reportStatus(e.kind == SyncApiErrorKind.network
            ? SyncStatus.offline
            : SyncStatus.error);
        return;
      }
    } else {
      // Theirs: shadow first, then the store — same no-echo ordering as pulls.
      if (conflict.remoteDeleted) {
        await _syncStore.removeShadow(conflict.entityType, conflict.recordId);
      } else {
        await _syncStore.upsertShadow(
          conflict.entityType,
          conflict.recordId,
          conflict.remoteVersion,
          conflict.remotePayload!,
        );
      }
      _applyRemoteChanges([
        RemoteChange(
          entityType: conflict.entityType,
          recordId: conflict.recordId,
          version: conflict.remoteVersion,
          deleted: conflict.remoteDeleted,
          payload: conflict.remotePayload,
        ),
      ]);
    }

    await _syncStore.removeConflict(conflict.entityType, conflict.recordId);
    await _controller.refreshConflictCount();
  }

  /// Owner activating group mode: with an empty shadow every record diffs as
  /// new, so the first sync IS the initial upload.
  Future<void> initialPush() async {
    await _syncStore.clearShadow();
    await _syncStore.setMeta(SyncStore.kSyncCursor, null);
    await syncNow();
  }

  /// Invitee joining: full pull from cursor 0, wholesale replace of the local
  /// store (the caller has already backed the old data up), shadow seeded to
  /// match. Throws [SyncApiException] so the caller can surface failures.
  Future<void> initialPullReplace() =>
      _enqueue(_initialPullReplace);

  Future<void> _initialPullReplace() async {
    final token = _controller.token!;
    final group = _controller.group!;

    _controller.reportStatus(SyncStatus.syncing);
    final response = await _api.sync(token, group.id, 0, const []);

    final accounts = <Account>[];
    final categories = <Category>[];
    final budgets = <Budget>[];
    final txns = <Txn>[];
    final tags = <Tag>[];
    final goals = <Goal>[];
    final tasks = <Task>[];
    final currencies = <CurrencyDef>[];
    int? tagSchema;
    DateTime? budgetHistorySince;

    for (final change in response.changes) {
      if (change.deleted) continue;
      final payload = change.payload!;
      switch (change.entityType) {
        case EntityTypes.account:
          accounts.add(accountFromMap(payload));
        case EntityTypes.category:
          categories.add(categoryFromMap(payload));
        case EntityTypes.budget:
          budgets.add(budgetFromMap(payload));
        case EntityTypes.txn:
          txns.add(txnFromMap(payload));
        case EntityTypes.tag:
          tags.add(tagFromMap(payload));
        case EntityTypes.goal:
          goals.add(goalFromMap(payload));
        case EntityTypes.task:
          tasks.add(taskFromMap(payload));
        case EntityTypes.currency:
          currencies.add(currencyDefFromMap(payload));
        case EntityTypes.meta:
          if (change.recordId == 'tag_schema') {
            tagSchema = int.tryParse('${payload['value']}');
          } else if (change.recordId == 'budget_history_since') {
            final ms = int.tryParse('${payload['value']}');
            if (ms != null) {
              budgetHistorySince = DateTime.fromMillisecondsSinceEpoch(ms);
            }
          }
      }
    }

    final incoming = AppStore(
      accounts: accounts,
      categories: categories,
      budgets: budgets,
      txns: txns,
      goals: goals,
      tasks: tasks,
      tags: tags,
      customCurrencies: currencies,
      tagSchema: tagSchema,
      budgetHistorySince: budgetHistorySince,
    );

    // Shadow first (whole dataset), then the wholesale replace — the listener
    // fires on loadFrom's notify and diffs to nothing.
    await _syncStore.clearShadow();
    await _syncStore.clearConflicts();
    for (final change in response.changes) {
      if (change.deleted) continue;
      await _syncStore.upsertShadow(
        change.entityType,
        change.recordId,
        change.version,
        change.payload!,
      );
    }
    _store.loadFrom(incoming);

    await _syncStore.setMeta(SyncStore.kSyncCursor, '${response.cursor}');
    await _controller.reportSynced();
  }
}
