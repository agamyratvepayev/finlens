import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/persistence/local_database.dart';
import 'package:finlens/core/persistence/sync_store.dart';

/// The three v6 sync tables behind [SyncStore]: shadow rows, queued conflicts
/// and the sync_meta key/value store all round-trip through SQLite, and
/// clearing group state leaves auth alone. Runs against an in-memory database
/// so no real finlens.db is ever touched.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/sync_shadow_roundtrip_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late SyncStore sync;

  setUp(() async {
    db = await LocalDatabase.openInMemory();
    sync = SyncStore(db);
  });

  tearDown(() => db.close());

  test('shadow rows round-trip and replace on conflict', () async {
    await sync.upsertShadow('tag', 'tg_a', 1, {'id': 'tg_a', 'name': 'food'});
    await sync.upsertShadow('tag', 'tg_a', 2, {'id': 'tg_a', 'name': 'fuel'});
    await sync.upsertShadow('txn', 't_1', 1, {'id': 't_1', 'amount': 5.5});

    final rows = await sync.readShadow();
    expect(rows, hasLength(2));
    final tag = rows.singleWhere((r) => r.entityType == 'tag');
    expect(tag.version, 2);
    expect(tag.payload['name'], 'fuel');
    final txn = rows.singleWhere((r) => r.entityType == 'txn');
    expect(txn.payload['amount'], 5.5);

    await sync.removeShadow('tag', 'tg_a');
    expect(await sync.readShadow(), hasLength(1));
  });

  test('conflicts round-trip with nullable payloads', () async {
    await sync.putConflict(ConflictRow(
      entityType: 'txn',
      recordId: 't_1',
      localPayload: const {'id': 't_1', 'amount': 5.0},
      localDeleted: false,
      remotePayload: null,
      remoteDeleted: true,
      remoteVersion: 4,
      remoteUpdatedBy: 'wife@test.tm',
      remoteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    ));

    final rows = await sync.readConflicts();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.localPayload!['amount'], 5.0);
    expect(row.remotePayload, isNull);
    expect(row.remoteDeleted, isTrue);
    expect(row.remoteVersion, 4);
    expect(row.remoteUpdatedBy, 'wife@test.tm');
    expect(row.remoteUpdatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000));

    await sync.removeConflict('txn', 't_1');
    expect(await sync.readConflicts(), isEmpty);
  });

  test('sync_meta round-trips, null deletes, clearGroupState spares auth',
      () async {
    await sync.setMeta(SyncStore.kAuthToken, 'jwt');
    await sync.setMeta(SyncStore.kGroupId, '7');
    await sync.setMeta(SyncStore.kGroupRole, 'owner');
    await sync.setMeta(SyncStore.kSyncCursor, '42');
    await sync.upsertShadow('tag', 'tg_a', 1, {'id': 'tg_a'});
    await sync.putConflict(const ConflictRow(
      entityType: 'tag',
      recordId: 'tg_a',
      localPayload: {'id': 'tg_a'},
      localDeleted: false,
      remotePayload: {'id': 'tg_a'},
      remoteDeleted: false,
      remoteVersion: 2,
    ));

    expect(await sync.getMeta(SyncStore.kSyncCursor), '42');
    await sync.setMeta(SyncStore.kSyncCursor, null);
    expect(await sync.getMeta(SyncStore.kSyncCursor), isNull);
    await sync.setMeta(SyncStore.kSyncCursor, '42');

    await sync.clearGroupState();
    expect(await sync.getMeta(SyncStore.kAuthToken), 'jwt');
    expect(await sync.getMeta(SyncStore.kGroupId), isNull);
    expect(await sync.getMeta(SyncStore.kGroupRole), isNull);
    expect(await sync.getMeta(SyncStore.kSyncCursor), isNull);
    expect(await sync.readShadow(), isEmpty);
    expect(await sync.readConflicts(), isEmpty);
  });

  test('the persister tables and sync tables are disjoint', () {
    // The whole design hinges on the persister's clear+rewrite never touching
    // sync state — if someone adds a sync table to entityTables this fails.
    expect(
      LocalDatabase.entityTables,
      isNot(anyOf(
        contains(LocalDatabase.syncShadowTable),
        contains(LocalDatabase.syncConflictsTable),
        contains(LocalDatabase.syncMetaTable),
      )),
    );
  });
}
