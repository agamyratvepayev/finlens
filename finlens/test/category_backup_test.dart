import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/persistence/local_database.dart';
import 'package:finlens/core/store/app_store.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/category_backup_test.dart
//
// Category colour, icon and emoji must survive an export/restore, and a backup
// written before this change (schemaVersion 2, no icon_emoji/created_at on
// categories) must still decode — yielding null emoji/createdAt with the
// colour and icon unchanged (category-picker spec §5 / §10).

AppStore _storeWith(Category c) => AppStore(
      accounts: const <Account>[],
      categories: [c],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

void main() {
  test('schemaVersion is 3 (was 2)', () {
    expect(LocalDatabase.schemaVersion, 3);
  });

  test('a custom icon + colour + emoji category round-trips', () {
    final cat = Category(
      id: 'c-custom',
      name: 'Coffee',
      type: CategoryType.expense,
      icon: Icons.local_cafe_rounded,
      color: const Color(0xFF8B5CF6),
      emoji: '☕',
      createdAt: DateTime(2026, 8, 20),
    );
    final json = encodeBackup(_storeWith(cat), exportedAt: DateTime(2026, 9, 1));
    final restored = decodeBackup(json).source.snapshotCategories.single;

    expect(restored.color, const Color(0xFF8B5CF6));
    expect(restored.icon.codePoint, Icons.local_cafe_rounded.codePoint);
    expect(restored.emoji, '☕');
    expect(restored.createdAt, DateTime(2026, 8, 20));
  });

  test('an emoji-only category keeps its emoji and colour', () {
    final cat = Category(
      id: 'c-emoji',
      name: 'Gifts',
      type: CategoryType.expense,
      icon: Icons.redeem_rounded,
      color: const Color(0xFFFF9F0A),
      emoji: '🎁',
    );
    final json = encodeBackup(_storeWith(cat), exportedAt: DateTime(2026, 9, 1));
    final restored = decodeBackup(json).source.snapshotCategories.single;
    expect(restored.emoji, '🎁');
    expect(restored.hasEmoji, isTrue);
    expect(restored.color, const Color(0xFFFF9F0A));
  });

  test('a pre-change (schemaVersion 2) backup decodes with null emoji/createdAt',
      () {
    final cat = Category(
      id: 'c-old',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
      emoji: '🥦',
      createdAt: DateTime(2026, 8, 20),
    );
    // Start from a real current-version backup, then downgrade it to look like a
    // file written before this feature: drop the schemaVersion to 2 and strip the
    // new category columns from every category row.
    final map = jsonDecode(
            encodeBackup(_storeWith(cat), exportedAt: DateTime(2026, 9, 1)))
        as Map<String, dynamic>;
    map['schemaVersion'] = 2;
    for (final row in (map['categories'] as List)) {
      (row as Map)
        ..remove('icon_emoji')
        ..remove('created_at');
    }

    final restored = decodeBackup(jsonEncode(map)).source.snapshotCategories.single;
    // Unknown new fields read back as null → "behave exactly as before".
    expect(restored.emoji, isNull);
    expect(restored.createdAt, isNull);
    // The fields that existed at v2 are preserved.
    expect(restored.color, const Color(0xFF34C759));
    expect(restored.icon.codePoint, Icons.shopping_basket_rounded.codePoint);
  });
}
