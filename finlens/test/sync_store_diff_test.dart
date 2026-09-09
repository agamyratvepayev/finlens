import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/persistence/sync_store.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/sync/store_diff.dart';

/// The sync engine's shadow diff: the live store serialized through the same
/// mappers the persister uses, compared against the last server-acknowledged
/// state. New records push as baseVersion 0, edits as the shadow's version,
/// records missing from the store become tombstones, and an untouched store
/// diffs to nothing (the no-echo guarantee after a pull is applied).
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/sync_store_diff_test.dart
void main() {
  Tag tag(String id, String name) => Tag(
        id: id,
        name: name,
        createdAt: DateTime(2026, 1, 1),
        lastUsedAt: DateTime(2026, 1, 2),
      );

  AppStore storeWith(List<Tag> tags) => AppStore(
        accounts: [],
        categories: [],
        budgets: [],
        txns: [],
        goals: [],
        tasks: [],
        tags: tags,
        customCurrencies: [],
      );

  ShadowRow shadowOf(String entityType, String recordId, int version,
          Map<String, Object?> payload) =>
      ShadowRow(
        entityType: entityType,
        recordId: recordId,
        version: version,
        payload: payload,
      );

  test('empty store, empty shadow → only the two meta rows push', () {
    final changes = diffAgainstShadow(
      snapshotAsRecords(AppStore.empty()),
      const [],
    );
    expect(changes, hasLength(2));
    expect(changes.every((c) => c.entityType == EntityTypes.meta), isTrue);
    expect(changes.every((c) => c.baseVersion == 0 && !c.deleted), isTrue);
  });

  test('a record unknown to the shadow pushes as new (baseVersion 0)', () {
    final store = storeWith([tag('tg_a', 'food')]);
    final changes = diffAgainstShadow(snapshotAsRecords(store), const []);
    final tagChange =
        changes.singleWhere((c) => c.entityType == EntityTypes.tag);
    expect(tagChange.recordId, 'tg_a');
    expect(tagChange.baseVersion, 0);
    expect(tagChange.deleted, isFalse);
    expect(tagChange.payload, isNotNull);
  });

  test('a shadow-matching snapshot diffs to nothing', () {
    final store = storeWith([tag('tg_a', 'food')]);
    final snapshot = snapshotAsRecords(store);
    final shadow = [
      for (final entry in snapshot.entries)
        shadowOf(entry.key.$1, entry.key.$2, 3, entry.value),
    ];
    expect(diffAgainstShadow(snapshotAsRecords(store), shadow), isEmpty);
  });

  test('an edited record pushes with the shadow version as base', () {
    final store = storeWith([tag('tg_a', 'food')]);
    final snapshot = snapshotAsRecords(store);
    final shadow = [
      for (final entry in snapshot.entries)
        shadowOf(entry.key.$1, entry.key.$2, 7, entry.value),
    ];
    expect(diffAgainstShadow(snapshotAsRecords(store), shadow), isEmpty);

    // Same store with the tag renamed (fresh instance — Tag payload differs).
    final edited = storeWith([tag('tg_a', 'groceries')]);
    final changes = diffAgainstShadow(snapshotAsRecords(edited), shadow);
    final tagChange =
        changes.singleWhere((c) => c.entityType == EntityTypes.tag);
    expect(tagChange.baseVersion, 7);
    expect(tagChange.deleted, isFalse);
    expect(tagChange.payload!['name'], 'groceries');
  });

  test('a record in the shadow but gone from the store becomes a tombstone',
      () {
    final full = storeWith([tag('tg_a', 'food'), tag('tg_b', 'fuel')]);
    final shadow = [
      for (final entry in snapshotAsRecords(full).entries)
        shadowOf(entry.key.$1, entry.key.$2, 2, entry.value),
    ];
    final afterDelete = storeWith([tag('tg_a', 'food')]);
    final changes = diffAgainstShadow(snapshotAsRecords(afterDelete), shadow);
    final tombstone = changes.singleWhere((c) => c.deleted);
    expect((tombstone.entityType, tombstone.recordId),
        (EntityTypes.tag, 'tg_b'));
    expect(tombstone.baseVersion, 2);
    expect(tombstone.payload, isNull);
  });

  test('payload equality is canonical — key order does not matter', () {
    final store = storeWith([tag('tg_a', 'food')]);
    final payload = tagToMap(store.snapshotTags.first);
    final reversed = Map.fromEntries(payload.entries.toList().reversed);
    final shadow = [
      for (final entry in snapshotAsRecords(store).entries)
        shadowOf(
          entry.key.$1,
          entry.key.$2,
          1,
          entry.key.$1 == EntityTypes.tag ? reversed : entry.value,
        ),
    ];
    expect(diffAgainstShadow(snapshotAsRecords(store), shadow), isEmpty);
  });
}
