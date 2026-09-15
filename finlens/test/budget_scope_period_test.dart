import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';

/// Task 022 — budget scopes (categories / account / tag), periods (month / week /
/// N-days / once) and the seams they change. Pure store arithmetic; no widgets.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/budget_scope_period_test.dart
void main() {
  // A fixed "today" well inside August so month windows and a 12–22 Aug one-off
  // are all live.
  AppStore store({
    List<Budget> budgets = const [],
    List<Txn> txns = const [],
    List<Tag> tags = const [],
    DateTime? clock,
  }) =>
      AppStore(
        clock: Clock.fixed(clock ?? DateTime(2026, 8, 15, 10, 0)),
        accounts: [
          Account(
              id: 'a-travel',
              name: 'Travel card',
              group: AccountGroup.creditCards,
              currency: 'USD',
              startingBalance: 0),
          Account(
              id: 'a-cash',
              name: 'Cash',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 10000),
        ],
        categories: [
          Category(
              id: 'c-grocery',
              name: 'Grocery',
              type: CategoryType.expense,
              icon: Icons.category_rounded,
              color: Colors.green),
          Category(
              id: 'c-eating',
              name: 'Eating out',
              type: CategoryType.expense,
              icon: Icons.category_rounded,
              color: Colors.orange),
        ],
        tags: tags,
        budgets: budgets,
        txns: txns,
        goals: const [],
        tasks: const [],
      );

  Tag tag(String id) => Tag(
        id: id,
        name: id,
        createdAt: DateTime(2026, 1, 1),
        lastUsedAt: DateTime(2026, 1, 1),
      );

  Txn expense({
    required String id,
    required String account,
    required String category,
    required double amount,
    String currency = 'USD',
    double rateToBase = 1.0,
    double? amountBase,
    List<String> tagIds = const [],
    DateTime? date,
  }) =>
      Txn(
        id: id,
        type: TxnType.expense,
        amount: amount,
        currency: currency,
        fromRef: account,
        toRef: category,
        date: date ?? DateTime(2026, 8, 15),
        rateToBase: rateToBase,
        amountBase: amountBase,
        tagIds: tagIds,
      );

  Budget budget({
    required String id,
    required BudgetScope scope,
    required Set<String> targets,
    double limit = 1000,
    String currency = '',
    BudgetPeriod period = BudgetPeriod.month,
    int? lengthDays,
    DateTime? anchor,
    bool repeats = true,
    DateTime? endedAt,
    DateTime? createdAt,
  }) =>
      Budget(
        id: id,
        name: id,
        scope: scope,
        targets: targets,
        limit: limit,
        currency: currency,
        period: period,
        lengthDays: lengthDays,
        anchor: anchor ?? DateTime(2026, 8, 1),
        repeats: repeats,
        endedAt: endedAt,
        history: [
          BudgetEdit(
              at: createdAt ?? DateTime(2026, 1, 1),
              field: 'created',
              from: 'off',
              to: '')
        ],
      );

  // ── §1d Tag scope ────────────────────────────────────────────────────────────

  test('a tag budget counts a tagged expense, once even with two of its tags',
      () {
    final s = store(
      tags: [tag('t-lisbon'), tag('t-trip')],
      budgets: [
        budget(
            id: 'b-lisbon',
            scope: BudgetScope.tag,
            targets: {'t-lisbon', 't-trip'},
            limit: 800),
      ],
      txns: [
        expense(
            id: 't1',
            account: 'a-cash',
            category: 'c-grocery',
            amount: 38,
            tagIds: ['t-lisbon', 't-trip']),
      ],
    );
    final b = s.budgetById('b-lisbon')!;
    // Counted exactly once despite matching two of the budget's tags.
    expect(s.budgetSpend(b, DateTime(2026, 8, 15)), 38);
  });

  test('a tag budget does not count an untagged expense', () {
    final s = store(
      tags: [tag('t-lisbon')],
      budgets: [
        budget(
            id: 'b-lisbon', scope: BudgetScope.tag, targets: {'t-lisbon'}),
      ],
      txns: [
        expense(
            id: 't1', account: 'a-cash', category: 'c-grocery', amount: 50),
      ],
    );
    expect(s.budgetSpend(s.budgetById('b-lisbon')!, DateTime(2026, 8, 15)), 0);
  });

  // ── Account scope ─────────────────────────────────────────────────────────────

  test('an account budget counts expenses paid from the account', () {
    final s = store(
      budgets: [
        budget(
            id: 'b-travel',
            scope: BudgetScope.account,
            targets: {'a-travel'},
            limit: 1000),
      ],
      txns: [
        expense(
            id: 't1', account: 'a-travel', category: 'c-grocery', amount: 40),
        expense(
            id: 't2', account: 'a-cash', category: 'c-grocery', amount: 99),
      ],
    );
    expect(s.budgetSpend(s.budgetById('b-travel')!, DateTime(2026, 8, 15)), 40);
  });

  // ── §6 The worked example — €38, four budgets ────────────────────────────────

  test('the worked example: a €38 grocery buy counts in all four budgets', () {
    final s = store(
      tags: [tag('t-lisbon')],
      budgets: [
        budget(
            id: 'b-grocery',
            scope: BudgetScope.categories,
            targets: {'c-grocery'},
            limit: 2000),
        budget(
            id: 'b-food',
            scope: BudgetScope.categories,
            targets: {'c-grocery', 'c-eating'},
            limit: 250,
            period: BudgetPeriod.days,
            lengthDays: 7,
            anchor: DateTime(2026, 8, 3)), // Monday
        budget(
            id: 'b-travel',
            scope: BudgetScope.account,
            targets: {'a-travel'},
            limit: 1000),
        budget(
            id: 'b-lisbon',
            scope: BudgetScope.tag,
            targets: {'t-lisbon'},
            limit: 800,
            currency: 'EUR',
            period: BudgetPeriod.days,
            lengthDays: 11,
            anchor: DateTime(2026, 8, 12),
            repeats: false,
            endedAt: DateTime(2026, 8, 22)),
      ],
      txns: [
        expense(
          id: 't1',
          account: 'a-travel',
          category: 'c-grocery',
          amount: 38,
          currency: 'EUR',
          rateToBase: 38 / 41.76,
          amountBase: 41.76,
          tagIds: ['t-lisbon'],
          date: DateTime(2026, 8, 15),
        ),
      ],
    );
    final on = DateTime(2026, 8, 15);
    // The dollar budgets see the frozen base value; the euro one sees €38 native.
    expect(s.budgetSpend(s.budgetById('b-grocery')!, on), closeTo(41.76, 0.001));
    expect(s.budgetSpend(s.budgetById('b-food')!, on), closeTo(41.76, 0.001));
    expect(s.budgetSpend(s.budgetById('b-travel')!, on), closeTo(41.76, 0.001));
    expect(s.budgetSpend(s.budgetById('b-lisbon')!, on), 38);

    final counting =
        s.budgetsCounting(s.txns.firstWhere((t) => t.id == 't1'));
    expect(counting.map((b) => b.id).toSet(),
        {'b-grocery', 'b-food', 'b-travel', 'b-lisbon'});
  });

  test('budgetsCounting returns nothing for a tag budget outside its window', () {
    final s = store(
      tags: [tag('t-lisbon')],
      budgets: [
        budget(
            id: 'b-lisbon',
            scope: BudgetScope.tag,
            targets: {'t-lisbon'},
            period: BudgetPeriod.days,
            lengthDays: 11,
            anchor: DateTime(2026, 8, 12),
            repeats: false,
            endedAt: DateTime(2026, 8, 22)),
      ],
      txns: [
        expense(
            id: 't1',
            account: 'a-cash',
            category: 'c-grocery',
            amount: 10,
            tagIds: ['t-lisbon'],
            date: DateTime(2026, 9, 5)), // after the Lisbon window
      ],
    );
    final counting = s.budgetsCounting(s.txns.firstWhere((t) => t.id == 't1'));
    expect(counting, isEmpty);
  });

  // ── §4a "Unbudgeted" is any-period ───────────────────────────────────────────

  test('a category with only a weekly budget is not unbudgeted', () {
    final s = store(
      budgets: [
        budget(
            id: 'b-week',
            scope: BudgetScope.categories,
            targets: {'c-grocery'},
            period: BudgetPeriod.days,
            lengthDays: 7,
            anchor: DateTime(2026, 8, 3)),
      ],
      txns: [
        expense(
            id: 't1', account: 'a-cash', category: 'c-grocery', amount: 30),
        expense(
            id: 't2', account: 'a-cash', category: 'c-eating', amount: 20),
      ],
    );
    final aug = DateTime(2026, 8, 1);
    // Grocery has a weekly budget → not unbudgeted; only Eating out is.
    expect(s.unbudgetedSpend(aug), 20);
    expect(s.unbudgetedSpendingCategories(aug).map((c) => c.id), ['c-eating']);
    expect(s.budgetsForCategory('c-grocery'), isNotEmpty);
  });

  // ── §4b primaryBudgetForCategory: narrowest lens ─────────────────────────────

  test('primaryBudgetForCategory prefers single-target, then shorter period', () {
    final s = store(budgets: [
      budget(
          id: 'b-month-single',
          scope: BudgetScope.categories,
          targets: {'c-grocery'}),
      budget(
          id: 'b-week-single',
          scope: BudgetScope.categories,
          targets: {'c-grocery'},
          period: BudgetPeriod.days,
          lengthDays: 7,
          anchor: DateTime(2026, 8, 3)),
      budget(
          id: 'b-month-multi',
          scope: BudgetScope.categories,
          targets: {'c-grocery', 'c-eating'}),
    ]);
    // Single-target beats the multi; among singles the shorter (weekly) wins.
    expect(s.primaryBudgetForCategory('c-grocery')!.id, 'b-week-single');
  });

  test('primaryBudgetForCategory breaks a tie by the most recently created', () {
    final s = store(budgets: [
      budget(
          id: 'b-old',
          scope: BudgetScope.categories,
          targets: {'c-grocery'},
          createdAt: DateTime(2026, 1, 1)),
      budget(
          id: 'b-new',
          scope: BudgetScope.categories,
          targets: {'c-grocery'},
          createdAt: DateTime(2026, 5, 1)),
    ]);
    expect(s.primaryBudgetForCategory('c-grocery')!.id, 'b-new');
  });

  // ── §4c The month hero sums monthly, reporting-currency category budgets ──────

  test('totalBudget ignores weekly, one-off and foreign budgets; the off-hero '
      'count equals how many it ignored', () {
    final s = store(budgets: [
      budget(
          id: 'b-monthly',
          scope: BudgetScope.categories,
          targets: {'c-grocery'},
          limit: 2000),
      budget(
          id: 'b-weekly',
          scope: BudgetScope.categories,
          targets: {'c-eating'},
          limit: 250,
          period: BudgetPeriod.days,
          lengthDays: 7,
          anchor: DateTime(2026, 8, 3)),
      budget(
          id: 'b-once',
          scope: BudgetScope.tag,
          targets: {'t-x'},
          limit: 500,
          period: BudgetPeriod.days,
          lengthDays: 11,
          anchor: DateTime(2026, 8, 12),
          repeats: false,
          endedAt: DateTime(2026, 8, 22)),
      budget(
          id: 'b-foreign',
          scope: BudgetScope.categories,
          targets: {'c-grocery'},
          limit: 8000,
          currency: 'EUR'),
    ]);
    expect(s.totalBudget, 2000);
    expect(s.budgetsOffMonthHero, 3);
  });

  // ── Windows: weekly resets on the anchor weekday; once freezes after end ──────

  test('a weekly budget window starts on the anchor weekday', () {
    final s = store();
    final b = budget(
        id: 'b',
        scope: BudgetScope.categories,
        targets: {'c-grocery'},
        period: BudgetPeriod.days,
        lengthDays: 7,
        anchor: DateTime(2026, 8, 3)); // a Monday
    final w = s.budgetWindow(b, DateTime(2026, 8, 6));
    expect(w.start, DateTime(2026, 8, 3));
    expect(w.start.weekday, DateTime.monday);
  });

  test('a finished one-off is running before its end and past after', () {
    final onceBudget = budget(
        id: 'b-once',
        scope: BudgetScope.tag,
        targets: {'t-x'},
        period: BudgetPeriod.days,
        lengthDays: 11,
        anchor: DateTime(2026, 8, 12),
        repeats: false,
        endedAt: DateTime(2026, 8, 22));
    // Before the end (today = 15 Aug): still on the tab and off-hero counted.
    final live = store(budgets: [onceBudget]);
    expect(live.budgetsOffMonthHero, 1);
    // After the end (today = 30 Aug): still on the tab (activeBudgetsByScope
    // filters only archived), so it stays visible, dimmed.
    final past = store(budgets: [onceBudget], clock: DateTime(2026, 8, 30));
    expect(past.activeBudgetsByScope(BudgetScope.tag, DateTime(2026, 8, 1)).length,
        1);
  });
}
