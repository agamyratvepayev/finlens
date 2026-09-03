import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/persistence/local_database.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';

/// budgets-as-object spec §A.4 — the legacy per-category budget columns migrate
/// into [Budget] objects, and a backup written before this change (no `budgets`
/// array, budgets still on the category rows) still restores with every budget
/// intact.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/budget_object_migration_test.dart
void main() {
  test('schemaVersion is 5 (budgets table added)', () {
    expect(LocalDatabase.schemaVersion, 5);
  });

  // ── the migration helper, in isolation ──────────────────────────────────────

  test('legacyBudgetsFromCategoryRows synthesizes an active + a removed budget',
      () {
    final rows = <Map<String, Object?>>[
      {
        'id': 'c-groceries',
        'name': 'Groceries',
        'type_name': 'expense',
        'created_at': DateTime(2026, 3, 1).millisecondsSinceEpoch,
        'monthly_budget': 500.0,
        'budget_rollover': 1,
        'warn_threshold': 0.9,
        'removed_on': null,
        'budget_history': jsonEncode([
          {
            'at': DateTime(2026, 3, 1).millisecondsSinceEpoch,
            'field': 'created',
            'from': 'off',
            'to': r'$500',
            'amber': false,
          }
        ]),
      },
      {
        'id': 'c-garden',
        'name': 'Garden',
        'type_name': 'expense',
        'monthly_budget': null,
        'budget_rollover': 0,
        'warn_threshold': 0.8,
        'removed_on': DateTime(2026, 6, 12).millisecondsSinceEpoch,
        'budget_history': '[]',
      },
      // A plain unbudgeted category yields no budget.
      {
        'id': 'c-eatingout',
        'name': 'Eating out',
        'type_name': 'expense',
        'monthly_budget': null,
        'budget_rollover': 0,
        'warn_threshold': 0.8,
        'removed_on': null,
        'budget_history': '[]',
      },
    ];

    final budgets = legacyBudgetsFromCategoryRows(rows);
    expect(budgets, hasLength(2));

    final groceries = budgets.firstWhere((b) => b.targets.contains('c-groceries'));
    expect(groceries.scope, BudgetScope.categories);
    expect(groceries.period, BudgetPeriod.month);
    expect(groceries.limit, 500);
    expect(groceries.rollover, isTrue);
    expect(groceries.warnThreshold, 0.9);
    expect(groceries.repeats, isTrue);
    expect(groceries.isArchived, isFalse);
    expect(groceries.history, hasLength(1));
    expect(groceries.history.single.field, 'created');

    final garden = budgets.firstWhere((b) => b.targets.contains('c-garden'));
    expect(garden.isArchived, isTrue);
    expect(garden.archivedAt, DateTime(2026, 6, 12));
  });

  // ── a pre-v5 backup restores intact (the spec's v1→v2 requirement) ───────────

  test('a pre-v5 backup (budgets still on categories) restores every budget', () {
    final store = AppStore(
      accounts: const <Account>[],
      categories: [
        Category(
            id: 'c-a',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.shopping_basket_rounded,
            color: const Color(0xFF34C759)),
        Category(
            id: 'c-b',
            name: 'Garden',
            type: CategoryType.expense,
            icon: Icons.local_florist_rounded,
            color: const Color(0xFF34C759)),
      ],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    // Encode a current backup, then downgrade it to look like a file written
    // before budgets-as-object: schemaVersion 4, no `budgets` array, and the
    // budget fields living back on the category rows.
    final map = jsonDecode(
            encodeBackup(store, exportedAt: DateTime(2026, 9, 1)))
        as Map<String, dynamic>;
    map['schemaVersion'] = 4;
    map.remove('budgets');
    for (final row in (map['categories'] as List).cast<Map>()) {
      if (row['id'] == 'c-a') {
        row['monthly_budget'] = 500.0;
        row['budget_rollover'] = 1;
        row['warn_threshold'] = 0.9;
        row['budget_history'] = jsonEncode([
          {
            'at': DateTime(2026, 3, 1).millisecondsSinceEpoch,
            'field': 'created',
            'from': 'on',
            'to': r'$500',
            'amber': false,
          }
        ]);
      } else if (row['id'] == 'c-b') {
        row['removed_on'] = DateTime(2026, 6, 12).millisecondsSinceEpoch;
      }
    }

    final restored = decodeBackup(jsonEncode(map)).source;

    // The active budget came back with its limit, rollover, warn and history.
    final catA = restored.categoryById('c-a')!;
    expect(restored.monthlyLimitOf(catA), 500);
    expect(restored.rolloverOf(catA), isTrue);
    expect(restored.warnThresholdOf(catA), 0.9);
    expect(restored.budgetHistoryOf(catA), hasLength(1));
    expect(restored.budgetedCategories.map((c) => c.id), contains('c-a'));

    // The removed budget landed in the Archive's REMOVED BUDGETS.
    expect(restored.removedBudgets.map((c) => c.id), contains('c-b'));
    expect(restored.removedOnOf(restored.categoryById('c-b')!),
        DateTime(2026, 6, 12));
  });

  // ── a v5 backup round-trips budgets faithfully ───────────────────────────────

  test('a v5 backup round-trips a Budget through the budgets array', () {
    final store = AppStore(
      accounts: const <Account>[],
      categories: [
        Category(
            id: 'c-a',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.shopping_basket_rounded,
            color: const Color(0xFF34C759)),
      ],
      budgets: [
        Budget(
          id: 'b-a',
          name: 'Groceries',
          scope: BudgetScope.categories,
          targets: {'c-a'},
          limit: 750,
          period: BudgetPeriod.days,
          lengthDays: 40,
          anchor: DateTime(2026, 8, 13),
          repeats: false,
          rollover: false,
          warnThreshold: 0.75,
        ),
      ],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    final json = encodeBackup(store, exportedAt: DateTime(2026, 9, 1));
    final b = decodeBackup(json).source.snapshotBudgets.single;
    expect(b.id, 'b-a');
    expect(b.limit, 750);
    expect(b.period, BudgetPeriod.days);
    expect(b.lengthDays, 40);
    expect(b.anchor, DateTime(2026, 8, 13));
    expect(b.repeats, isFalse);
    expect(b.warnThreshold, 0.75);
    expect(b.targets, {'c-a'});
  });
}
