import 'dart:convert';

import '../persistence/store_mappers.dart';
import '../persistence/sync_store.dart';
import '../store/app_store.dart';
import 'sync_models.dart';

/// Entity-type names on the wire (and in `sync_shadow`). The `currency` type
/// is keyed by `code`; everything else by `id`. `meta` carries the two pieces
/// of store meta that must be shared for the dataset to behave identically on
/// every member's device (`id_seq` stays local — obsolete under UUID ids).
class EntityTypes {
  static const account = 'account';
  static const category = 'category';
  static const budget = 'budget';
  static const txn = 'txn';
  static const tag = 'tag';
  static const goal = 'goal';
  static const task = 'task';
  static const currency = 'currency';
  static const meta = 'meta';
}

/// A (type, id) key — Dart records give == for free.
typedef RecordKey = (String entityType, String recordId);

/// Serializes the live store into per-record payloads using the same mappers
/// the persister writes to SQLite — the wire format IS the local row format.
Map<RecordKey, Map<String, Object?>> snapshotAsRecords(AppStore store) {
  final out = <RecordKey, Map<String, Object?>>{};
  for (final a in store.snapshotAccounts) {
    out[(EntityTypes.account, a.id)] = accountToMap(a);
  }
  for (final c in store.snapshotCategories) {
    out[(EntityTypes.category, c.id)] = categoryToMap(c);
  }
  for (final b in store.snapshotBudgets) {
    out[(EntityTypes.budget, b.id)] = budgetToMap(b);
  }
  for (final t in store.snapshotTxns) {
    out[(EntityTypes.txn, t.id)] = txnToMap(t);
  }
  for (final t in store.snapshotTags) {
    out[(EntityTypes.tag, t.id)] = tagToMap(t);
  }
  for (final g in store.snapshotGoals) {
    out[(EntityTypes.goal, g.id)] = goalToMap(g);
  }
  for (final t in store.snapshotTasks) {
    out[(EntityTypes.task, t.id)] = taskToMap(t);
  }
  for (final c in store.snapshotCustomCurrencies) {
    out[(EntityTypes.currency, c.code)] = currencyDefToMap(c);
  }
  out[(EntityTypes.meta, 'tag_schema')] = {'value': '${store.tagSchema}'};
  out[(EntityTypes.meta, 'budget_history_since')] = {
    'value': '${store.budgetHistorySince.millisecondsSinceEpoch}',
  };
  return out;
}

/// Canonical JSON (sorted keys) so payload equality is content equality.
String canonicalJson(Map<String, Object?> payload) {
  final sorted = Map.fromEntries(
    payload.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  return jsonEncode(sorted);
}

/// Compares the live snapshot against the last server-acknowledged shadow:
/// new records push with baseVersion 0, changed records with the shadow's
/// version, and records present in the shadow but gone from the store become
/// tombstones. Hard `List.remove` deletes are caught here without any model
/// or mutation-path changes.
List<RecordChange> diffAgainstShadow(
  Map<RecordKey, Map<String, Object?>> current,
  List<ShadowRow> shadow,
) {
  final shadowByKey = <RecordKey, ShadowRow>{
    for (final row in shadow) (row.entityType, row.recordId): row,
  };
  final changes = <RecordChange>[];

  current.forEach((key, payload) {
    final existing = shadowByKey[key];
    if (existing == null) {
      changes.add(RecordChange(
        entityType: key.$1,
        recordId: key.$2,
        baseVersion: 0,
        deleted: false,
        payload: payload,
      ));
    } else if (canonicalJson(existing.payload) != canonicalJson(payload)) {
      changes.add(RecordChange(
        entityType: key.$1,
        recordId: key.$2,
        baseVersion: existing.version,
        deleted: false,
        payload: payload,
      ));
    }
  });

  for (final entry in shadowByKey.entries) {
    if (!current.containsKey(entry.key)) {
      changes.add(RecordChange(
        entityType: entry.key.$1,
        recordId: entry.key.$2,
        baseVersion: entry.value.version,
        deleted: true,
      ));
    }
  }

  return changes;
}
