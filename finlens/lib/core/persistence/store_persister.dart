import 'dart:async';

import 'package:flutter/foundation.dart';

import '../store/app_store.dart';
import 'local_database.dart';
import 'store_mappers.dart';

/// Wires the in-memory [AppStore] to the on-device [LocalDatabase].
///
/// The app never queries the database — it hydrates the whole store at launch
/// ([hydrate]) and writes the whole store back on change ([attach]). Because
/// every mutation on [AppStore] ends in `notifyListeners()`, a single listener
/// captures all ~40 mutation paths without touching any of them. Writes are
/// debounced (a burst of edits collapses into one) and each is a single
/// transaction that clears and rewrites every table, so the file on disk always
/// reflects a whole, consistent store. Data volumes are tiny (personal finance),
/// so a full rewrite is effectively instant.
class StorePersister {
  StorePersister(this._store, this._database);

  final AppStore _store;
  final LocalDatabase _database;

  static const Duration _debounceDelay = Duration(milliseconds: 500);

  Timer? _debounce;
  bool _attached = false;

  /// Builds an [AppStore] from the persisted rows, or returns null when the
  /// database is empty (a fresh install — `main()` then starts blank). The id
  /// counter, tag schema and budget-history epoch ride along in `meta` so the
  /// rebuilt store behaves identically to the one that was saved.
  static Future<AppStore?> hydrate(LocalDatabase database) async {
    final accountRows = await database.readAll(LocalDatabase.accountsTable);
    final categoryRows = await database.readAll(LocalDatabase.categoriesTable);
    final txnRows = await database.readAll(LocalDatabase.txnsTable);
    final tagRows = await database.readAll(LocalDatabase.tagsTable);
    final goalRows = await database.readAll(LocalDatabase.goalsTable);
    final taskRows = await database.readAll(LocalDatabase.tasksTable);

    final isEmpty = accountRows.isEmpty &&
        categoryRows.isEmpty &&
        txnRows.isEmpty &&
        tagRows.isEmpty &&
        goalRows.isEmpty &&
        taskRows.isEmpty;
    if (isEmpty) return null;

    final metaRows = await database.readAll(LocalDatabase.metaTable);
    final meta = <String, String?>{
      for (final r in metaRows) r['key'] as String: r['value'] as String?,
    };
    final since = int.tryParse(meta['budget_history_since'] ?? '');

    return AppStore(
      accounts: accountRows.map(accountFromMap).toList(),
      categories: categoryRows.map(categoryFromMap).toList(),
      txns: txnRows.map(txnFromMap).toList(),
      goals: goalRows.map(goalFromMap).toList(),
      tasks: taskRows.map(taskFromMap).toList(),
      tags: tagRows.map(tagFromMap).toList(),
      idSeq: int.tryParse(meta['id_seq'] ?? ''),
      tagSchema: int.tryParse(meta['tag_schema'] ?? ''),
      budgetHistorySince:
          since == null ? null : DateTime.fromMillisecondsSinceEpoch(since),
    );
  }

  /// Starts persisting: subscribes to the store and writes a debounced snapshot
  /// whenever it changes. Idempotent.
  void attach() {
    if (_attached) return;
    _attached = true;
    _store.addListener(_onChange);
  }

  /// Writes any pending debounced snapshot immediately. Call from the app
  /// lifecycle (paused/detached) so a change made moments before backgrounding
  /// is not lost if the process is killed.
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _debounce = null;
      await _writeSafe();
    }
  }

  /// Stops persisting and drops any pending write.
  void dispose() {
    if (_attached) {
      _store.removeListener(_onChange);
      _attached = false;
    }
    _debounce?.cancel();
    _debounce = null;
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      _debounce = null;
      unawaited(_writeSafe());
    });
  }

  Future<void> _writeSafe() async {
    try {
      await _write();
    } catch (e, st) {
      // A failed save must never crash the app or interrupt the user; the next
      // mutation will trigger another attempt.
      debugPrint('StorePersister: snapshot write failed: $e\n$st');
    }
  }

  Future<void> _write() async {
    // Serialize outside the transaction so the db lock is held as briefly as
    // possible.
    final accounts = _store.snapshotAccounts.map(accountToMap).toList();
    final categories = _store.snapshotCategories.map(categoryToMap).toList();
    final txns = _store.snapshotTxns.map(txnToMap).toList();
    final tags = _store.snapshotTags.map(tagToMap).toList();
    final goals = _store.snapshotGoals.map(goalToMap).toList();
    final tasks = _store.snapshotTasks.map(taskToMap).toList();

    await _database.db.transaction((txn) async {
      final batch = txn.batch();
      for (final table in LocalDatabase.entityTables) {
        batch.delete(table);
      }
      batch.delete(LocalDatabase.metaTable);

      for (final row in accounts) {
        batch.insert(LocalDatabase.accountsTable, row);
      }
      for (final row in categories) {
        batch.insert(LocalDatabase.categoriesTable, row);
      }
      for (final row in txns) {
        batch.insert(LocalDatabase.txnsTable, row);
      }
      for (final row in tags) {
        batch.insert(LocalDatabase.tagsTable, row);
      }
      for (final row in goals) {
        batch.insert(LocalDatabase.goalsTable, row);
      }
      for (final row in tasks) {
        batch.insert(LocalDatabase.tasksTable, row);
      }

      for (final entry in _metaRows().entries) {
        batch.insert(
          LocalDatabase.metaTable,
          {'key': entry.key, 'value': entry.value},
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Map<String, String> _metaRows() => {
        'schema_version': '${LocalDatabase.schemaVersion}',
        'id_seq': '${_store.idSeq}',
        'tag_schema': '${_store.tagSchema}',
        'budget_history_since':
            '${_store.budgetHistorySince.millisecondsSinceEpoch}',
      };
}
