import 'dart:convert';

import '../store/app_store.dart';
import 'local_database.dart';
import 'store_mappers.dart';

/// Portable, file-based backup of the whole store — the "dump / restore" that
/// lets a user carry their data to a new phone (Settings › More › DATA).
///
/// The file is plain JSON. It reuses the exact same `*ToMap`/`*FromMap` mappers
/// the on-device SQLite snapshot uses ([store_mappers]), so an export is a
/// byte-faithful copy of what is on disk and an import inherits the mappers'
/// defensive decoding (unknown enum → default, malformed embedded JSON → empty).
/// The store round-trips through its own public seams — the unfiltered
/// `snapshot*` views on the way out (never the filtered public getters, which
/// drop archived rows) and the persistence-seam constructor on the way back in.

/// The `format` marker every FinLens backup carries; a file without it is
/// rejected rather than fed to the mappers.
const String backupFormatMarker = 'finlens-backup';

/// Thrown by [decodeBackup] when the text is not a usable FinLens backup:
/// unparseable JSON, a missing/wrong `format` marker, a `schemaVersion` newer
/// than this build understands, or entity rows too corrupt to rebuild.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);
  final String reason;
  @override
  String toString() => 'BackupFormatException: $reason';
}

/// The result of a successful [decodeBackup]: the rebuilt store plus the few
/// summary figures the restore confirmation shows before it replaces anything.
class BackupDocument {
  const BackupDocument({
    required this.source,
    required this.exportedAt,
    required this.accountCount,
    required this.txnCount,
  });

  /// A fully-constructed store built from the file — pass to
  /// [AppStore.loadFrom] to make it the live data.
  final AppStore source;

  /// When the backup was written, or null if the file omitted it.
  final DateTime? exportedAt;

  final int accountCount;
  final int txnCount;
}

/// Serialises the entire store to a pretty-printed JSON document.
///
/// [exportedAt] is taken from the caller (real wall-clock time — the file's
/// provenance), never [AppStore.today], which is pinned for reproducibility.
String encodeBackup(AppStore store, {required DateTime exportedAt}) {
  final doc = <String, Object?>{
    'format': backupFormatMarker,
    'schemaVersion': LocalDatabase.schemaVersion,
    'exportedAt': exportedAt.millisecondsSinceEpoch,
    // Rides along so the restored store behaves identically to the saved one —
    // mirrors StorePersister's `meta` table.
    'meta': {
      'id_seq': store.idSeq,
      'tag_schema': store.tagSchema,
      'budget_history_since': store.budgetHistorySince.millisecondsSinceEpoch,
    },
    'accounts': store.snapshotAccounts.map(accountToMap).toList(),
    'categories': store.snapshotCategories.map(categoryToMap).toList(),
    'budgets': store.snapshotBudgets.map(budgetToMap).toList(),
    'txns': store.snapshotTxns.map(txnToMap).toList(),
    'tags': store.snapshotTags.map(tagToMap).toList(),
    'goals': store.snapshotGoals.map(goalToMap).toList(),
    'tasks': store.snapshotTasks.map(taskToMap).toList(),
    'currencies':
        store.snapshotCustomCurrencies.map(currencyDefToMap).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}

/// Rebuilds a store from a backup file, or throws [BackupFormatException] if the
/// text is not a valid FinLens backup this build can read.
///
/// The rebuilt [BackupDocument.source] is constructed through the persistence
/// seam of [AppStore] (passing `idSeq`, `tagSchema`, `budgetHistorySince`), so
/// it runs the same normalisation as `StorePersister.hydrate` — tag reification
/// is skipped for an already-migrated file, orphan goals are pruned, goal
/// history/latches are seeded.
BackupDocument decodeBackup(String jsonText) {
  Object? parsed;
  try {
    parsed = jsonDecode(jsonText);
  } on FormatException {
    throw const BackupFormatException('not valid JSON');
  }
  if (parsed is! Map) {
    throw const BackupFormatException('root is not an object');
  }
  if (parsed['format'] != backupFormatMarker) {
    throw const BackupFormatException('not a FinLens backup');
  }
  final schema = parsed['schemaVersion'];
  if (schema is! int || schema > LocalDatabase.schemaVersion) {
    throw const BackupFormatException('unsupported backup version');
  }

  List<Map<String, Object?>> rows(String key) {
    final raw = parsed is Map ? parsed[key] : null;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, Object?>()).toList();
  }

  final meta = parsed['meta'];
  int? metaInt(String key) {
    if (meta is! Map) return null;
    final v = meta[key];
    return v is num ? v.toInt() : null;
  }

  final since = metaInt('budget_history_since');

  // A pre-v5 backup carries no `budgets` array — budgets still lived on the
  // category rows. Run the same migration the on-device upgrade uses so an older
  // backup restores with every budget intact (budgets-as-object spec §A.4).
  final categoryRows = rows('categories');
  final budgetRows = rows('budgets');
  final budgets = budgetRows.isNotEmpty
      ? budgetRows.map(budgetFromMap).toList()
      : legacyBudgetsFromCategoryRows(categoryRows);

  final AppStore source;
  try {
    source = AppStore(
      accounts: rows('accounts').map(accountFromMap).toList(),
      categories: categoryRows.map(categoryFromMap).toList(),
      budgets: budgets,
      txns: rows('txns').map(txnFromMap).toList(),
      tags: rows('tags').map(tagFromMap).toList(),
      goals: rows('goals').map(goalFromMap).toList(),
      tasks: rows('tasks').map(taskFromMap).toList(),
      customCurrencies: rows('currencies').map(currencyDefFromMap).toList(),
      idSeq: metaInt('id_seq'),
      tagSchema: metaInt('tag_schema'),
      budgetHistorySince:
          since == null ? null : DateTime.fromMillisecondsSinceEpoch(since),
    );
  } catch (e) {
    // A structurally-valid file whose rows are missing required fields (e.g. a
    // null id) trips the mappers' hard casts — treat it as corrupt, not a crash.
    throw BackupFormatException('corrupt entity data: $e');
  }

  final exportedRaw = parsed['exportedAt'];
  final exportedAt = exportedRaw is num
      ? DateTime.fromMillisecondsSinceEpoch(exportedRaw.toInt())
      : null;

  return BackupDocument(
    source: source,
    exportedAt: exportedAt,
    accountCount: source.snapshotAccounts.length,
    txnCount: source.snapshotTxns.length,
  );
}
