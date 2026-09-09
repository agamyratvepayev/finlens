import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'local_database.dart';

/// One shadow row: the last server-acknowledged state of a record. The diff in
/// `store_diff.dart` compares the live store against these to find what to push.
class ShadowRow {
  const ShadowRow({
    required this.entityType,
    required this.recordId,
    required this.version,
    required this.payload,
  });

  final String entityType;
  final String recordId;
  final int version;
  final Map<String, Object?> payload;
}

/// A record waiting for the user's mine/theirs decision.
class ConflictRow {
  const ConflictRow({
    required this.entityType,
    required this.recordId,
    required this.localPayload,
    required this.localDeleted,
    required this.remotePayload,
    required this.remoteDeleted,
    required this.remoteVersion,
    this.remoteUpdatedBy,
    this.remoteUpdatedAt,
  });

  final String entityType;
  final String recordId;
  final Map<String, Object?>? localPayload;
  final bool localDeleted;
  final Map<String, Object?>? remotePayload;
  final bool remoteDeleted;
  final int remoteVersion;
  final String? remoteUpdatedBy;
  final DateTime? remoteUpdatedAt;
}

/// DAO over the three sync tables. Deliberately separate from the entity
/// tables and [LocalDatabase.metaTable]: `StorePersister._write` clears and
/// rewrites those on every store change, and sync state must survive that.
class SyncStore {
  SyncStore(this._db);

  final LocalDatabase _db;

  // sync_meta keys.
  static const String kAuthToken = 'auth_token';
  static const String kUserEmail = 'user_email';
  static const String kUserName = 'user_name';
  static const String kGroupId = 'group_id';
  static const String kGroupRole = 'group_role';
  static const String kSyncCursor = 'sync_cursor';
  static const String kLastSyncedAt = 'last_synced_at';

  // ── sync_meta ─────────────────────────────────────────────────────────────

  Future<String?> getMeta(String key) async {
    final rows = await _db.db.query(
      LocalDatabase.syncMetaTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await _db.db.delete(
        LocalDatabase.syncMetaTable,
        where: 'key = ?',
        whereArgs: [key],
      );
      return;
    }
    await _db.db.insert(
      LocalDatabase.syncMetaTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── sync_shadow ───────────────────────────────────────────────────────────

  Future<List<ShadowRow>> readShadow() async {
    final rows = await _db.db.query(LocalDatabase.syncShadowTable);
    return rows
        .map((r) => ShadowRow(
              entityType: r['entity_type'] as String,
              recordId: r['record_id'] as String,
              version: r['version'] as int,
              payload:
                  (jsonDecode(r['payload'] as String) as Map).cast<String, Object?>(),
            ))
        .toList();
  }

  Future<void> upsertShadow(
    String entityType,
    String recordId,
    int version,
    Map<String, Object?> payload,
  ) async {
    await _db.db.insert(
      LocalDatabase.syncShadowTable,
      {
        'entity_type': entityType,
        'record_id': recordId,
        'version': version,
        'payload': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeShadow(String entityType, String recordId) async {
    await _db.db.delete(
      LocalDatabase.syncShadowTable,
      where: 'entity_type = ? AND record_id = ?',
      whereArgs: [entityType, recordId],
    );
  }

  Future<void> clearShadow() async {
    await _db.db.delete(LocalDatabase.syncShadowTable);
  }

  // ── sync_conflicts ────────────────────────────────────────────────────────

  Future<List<ConflictRow>> readConflicts() async {
    final rows = await _db.db.query(LocalDatabase.syncConflictsTable);
    Map<String, Object?>? decode(Object? v) => v == null
        ? null
        : (jsonDecode(v as String) as Map).cast<String, Object?>();
    return rows
        .map((r) => ConflictRow(
              entityType: r['entity_type'] as String,
              recordId: r['record_id'] as String,
              localPayload: decode(r['local_payload']),
              localDeleted: (r['local_deleted'] as int) != 0,
              remotePayload: decode(r['remote_payload']),
              remoteDeleted: (r['remote_deleted'] as int) != 0,
              remoteVersion: r['remote_version'] as int,
              remoteUpdatedBy: r['remote_updated_by'] as String?,
              remoteUpdatedAt: r['remote_updated_at'] == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      r['remote_updated_at'] as int),
            ))
        .toList();
  }

  Future<void> putConflict(ConflictRow conflict) async {
    await _db.db.insert(
      LocalDatabase.syncConflictsTable,
      {
        'entity_type': conflict.entityType,
        'record_id': conflict.recordId,
        'local_payload': conflict.localPayload == null
            ? null
            : jsonEncode(conflict.localPayload),
        'local_deleted': conflict.localDeleted ? 1 : 0,
        'remote_payload': conflict.remotePayload == null
            ? null
            : jsonEncode(conflict.remotePayload),
        'remote_deleted': conflict.remoteDeleted ? 1 : 0,
        'remote_version': conflict.remoteVersion,
        'remote_updated_by': conflict.remoteUpdatedBy,
        'remote_updated_at': conflict.remoteUpdatedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeConflict(String entityType, String recordId) async {
    await _db.db.delete(
      LocalDatabase.syncConflictsTable,
      where: 'entity_type = ? AND record_id = ?',
      whereArgs: [entityType, recordId],
    );
  }

  Future<void> clearConflicts() async {
    await _db.db.delete(LocalDatabase.syncConflictsTable);
  }

  /// Wipes everything group-scoped (leaving auth alone): shadow, conflicts,
  /// cursor and group identity. Used on leave-group / removed-from-group.
  Future<void> clearGroupState() async {
    await clearShadow();
    await clearConflicts();
    await setMeta(kGroupId, null);
    await setMeta(kGroupRole, null);
    await setMeta(kSyncCursor, null);
    await setMeta(kLastSyncedAt, null);
  }
}
