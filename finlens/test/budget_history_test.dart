import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';

/// Budget-detail CHANGES — the store write paths (spec §3/§4). A budget edited
/// over three months: each field value is written once, by the right method,
/// with the right `from`/`to`, and only when something actually changed.
void main() {
  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Category addUnbudgeted(AppStore store) => store.addCategory(
        name: 'Groceries',
        type: CategoryType.expense,
        icon: Icons.shopping_cart_rounded,
        color: Colors.green,
      );

  Category addBudgeted(AppStore store, double limit) => store.addCategory(
        name: 'Groceries',
        type: CategoryType.expense,
        icon: Icons.shopping_cart_rounded,
        color: Colors.green,
        monthlyBudget: limit,
      );

  // ── created ────────────────────────────────────────────────────────────────

  test('addCategory with a budget writes one created entry, rollover off', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    expect(cat.budgetHistory, hasLength(1));
    final e = cat.budgetHistory.single;
    expect(e.field, 'created');
    expect(e.to, money(3000)); // $3,000
    expect(e.from, 'off'); // rollover token, not displayed as-is
    expect(e.amber, isFalse);
  });

  test('addCategory without a budget writes nothing', () {
    final store = emptyStore();
    final cat = addUnbudgeted(store);
    expect(cat.budgetHistory, isEmpty);
  });

  test('updateBudget on an unbudgeted category writes created, not limit', () {
    final store = emptyStore();
    final cat = addUnbudgeted(store);
    store.updateBudget(cat, monthlyBudget: 3000);
    expect(cat.budgetHistory, hasLength(1));
    expect(cat.budgetHistory.single.field, 'created');
    expect(cat.budgetHistory.single.to, money(3000));
  });

  // ── limit + amber ────────────────────────────────────────────────────────

  test('raising the limit writes a limit entry flagged amber', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    store.updateBudget(cat, monthlyBudget: 4000);
    final e = cat.budgetHistory.last;
    expect(e.field, 'limit');
    expect(e.from, money(3000));
    expect(e.to, money(4000));
    expect(e.amber, isTrue);
  });

  test('lowering the limit writes a limit entry that is not amber', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 4000);
    store.updateBudget(cat, monthlyBudget: 3500);
    final e = cat.budgetHistory.last;
    expect(e.field, 'limit');
    expect(e.from, money(4000));
    expect(e.to, money(3500));
    expect(e.amber, isFalse);
  });

  // ── rollover + warn ──────────────────────────────────────────────────────

  test('flipping rollover writes an unflagged rollover entry (off → on)', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    store.updateBudget(cat, rollover: true);
    final e = cat.budgetHistory.last;
    expect(e.field, 'rollover');
    expect(e.from, 'off');
    expect(e.to, 'on');
    expect(e.amber, isFalse); // rollover is never amber, even loosening
  });

  test('changing the threshold writes a warn entry (80% → 90%)', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000); // default warn 0.8
    store.updateBudget(cat, warnThreshold: 0.9);
    final e = cat.budgetHistory.last;
    expect(e.field, 'warn');
    expect(e.from, percent(0.8, decimals: 0));
    expect(e.to, percent(0.9, decimals: 0));
    expect(e.amber, isFalse);
  });

  // ── the no-op guard ──────────────────────────────────────────────────────

  test('updateBudget with unchanged values appends nothing', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    final before = cat.budgetHistory.length;
    store.updateBudget(
      cat,
      monthlyBudget: 3000,
      rollover: false,
      warnThreshold: 0.8,
    );
    expect(cat.budgetHistory.length, before);
  });

  test('one save that moves limit, rollover and threshold writes three rows, '
      'all dated today', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    final before = cat.budgetHistory.length;
    store.updateBudget(
      cat,
      monthlyBudget: 4000,
      rollover: true,
      warnThreshold: 0.9,
    );
    final added = cat.budgetHistory.skip(before).toList();
    expect(added, hasLength(3));
    expect(added.map((e) => e.field),
        containsAll(<String>['limit', 'rollover', 'warn']));
    expect(added.every((e) => e.at == AppStore.today), isTrue);
  });

  // ── removed / restored survive ─────────────────────────────────────────────

  test('removeBudget writes removed with the last limit; restoreBudget writes '
      'restored; earlier rows survive both', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3500);
    store.removeBudget(cat);
    expect(cat.budgetHistory.last.field, 'removed');
    expect(cat.budgetHistory.last.to, money(3500));

    store.restoreBudget(cat, 3500);
    expect(cat.budgetHistory.last.field, 'restored');
    expect(cat.budgetHistory.last.to, money(3500));

    // The created row written first is still there under both later rows.
    expect(cat.budgetHistory.first.field, 'created');
    expect(cat.budgetHistory.map((e) => e.field).toList(),
        <String>['created', 'removed', 'restored']);
  });

  // ── archive logs once ──────────────────────────────────────────────────────

  test('archiveCategory on a budgeted category writes one categoryArchived '
      'row and no removed row', () {
    final store = emptyStore();
    final cat = addBudgeted(store, 3000);
    final before = cat.budgetHistory.length;
    store.archiveCategory(cat);
    final added = cat.budgetHistory.skip(before).toList();
    expect(added, hasLength(1));
    expect(added.single.field, 'categoryArchived');
    expect(cat.budgetHistory.any((e) => e.field == 'removed'), isFalse);
    // The budget was still cleared as a side effect.
    expect(cat.monthlyBudget, isNull);
    expect(cat.archived, isTrue);
  });

  test('archiveCategory on an unbudgeted category logs nothing', () {
    final store = emptyStore();
    final cat = addUnbudgeted(store);
    store.archiveCategory(cat);
    expect(cat.budgetHistory, isEmpty);
  });

  // ── no backfill ────────────────────────────────────────────────────────────

  test('a budget that predates the feature starts with an empty history', () {
    // A category loaded with a budget already set (not created through
    // addCategory) gets no invented `created` entry.
    final preExisting = Category(
      id: 'c-old',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_cart_rounded,
      color: Colors.green,
      monthlyBudget: 3000,
    );
    final store = AppStore(
      accounts: const [],
      categories: [preExisting],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    expect(store.categoryById('c-old')!.budgetHistory, isEmpty);
  });

  test('the seed’s budgeted categories start with empty history (no backfill)',
      () {
    final store = buildSeedStore();
    final groceries = store.categoryById('c-groceries')!;
    expect(groceries.monthlyBudget, isNotNull);
    expect(groceries.budgetHistory, isEmpty);
  });

  // ── budgetHistorySince ─────────────────────────────────────────────────────

  test('budgetHistorySince defaults to today when a store is built fresh', () {
    expect(emptyStore().budgetHistorySince, AppStore.today);
    expect(buildSeedStore().budgetHistorySince, AppStore.today);
  });
}
