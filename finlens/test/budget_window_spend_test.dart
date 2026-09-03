import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

/// budgets-as-object spec §A.2 / §A.3 — the window, the spend and the rollover
/// carry. Pure store arithmetic; no widgets.
///
/// flutter test hangs on the author's machine — run these yourself:
///   flutter test test/budget_window_spend_test.dart
void main() {
  AppStore store() => AppStore(
        accounts: [
          Account(
              id: 'a-family',
              name: 'Family',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 10000),
          Account(
              id: 'a-other',
              name: 'Other',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 10000),
          Account(
              id: 'a-card',
              name: 'Card',
              group: AccountGroup.creditCards,
              currency: 'USD',
              startingBalance: 0),
        ],
        categories: [
          for (final id in ['c1', 'c2', 'c3', 'c4', 'c-inc'])
            Category(
                id: id,
                name: id,
                type: id == 'c-inc'
                    ? CategoryType.income
                    : CategoryType.expense,
                icon: Icons.category_rounded,
                color: Colors.green),
        ],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Budget monthly({int anchorDay = 1, bool rollover = false, double limit = 1000}) =>
      Budget(
        id: 'b',
        name: 'B',
        scope: BudgetScope.categories,
        targets: {'c1'},
        limit: limit,
        period: BudgetPeriod.month,
        anchor: DateTime(2026, 1, anchorDay),
        repeats: true,
        rollover: rollover,
      );

  // ── budgetWindow: month ────────────────────────────────────────────────────

  test('month/1st spans the whole calendar month', () {
    final w = store().budgetWindow(monthly(), DateTime(2026, 8, 15));
    expect(w.start, DateTime(2026, 8, 1));
    expect(w.end.year, 2026);
    expect(w.end.month, 8);
    expect(w.end.day, 31);
  });

  test('month/1st across a 28-day February', () {
    final w = store().budgetWindow(monthly(), DateTime(2026, 2, 10));
    expect(w.start, DateTime(2026, 2, 1));
    expect(w.end.month, 2);
    expect(w.end.day, 28); // 2026 is not a leap year
  });

  test('month/13th yields 13 Aug – 12 Sep for a date on/after the 13th', () {
    final w = store().budgetWindow(monthly(anchorDay: 13), DateTime(2026, 8, 20));
    expect(w.start, DateTime(2026, 8, 13));
    expect(w.end.month, 9);
    expect(w.end.day, 12);
  });

  test('month/13th yields 13 Jul – 12 Aug for a date before the 13th', () {
    final w = store().budgetWindow(monthly(anchorDay: 13), DateTime(2026, 8, 5));
    expect(w.start, DateTime(2026, 7, 13));
    expect(w.end.month, 8);
    expect(w.end.day, 12);
  });

  // ── budgetWindow: days ──────────────────────────────────────────────────────

  Budget days(int len, {DateTime? anchor, bool repeats = true, DateTime? endedAt}) =>
      Budget(
        id: 'b',
        name: 'B',
        scope: BudgetScope.categories,
        targets: {'c1'},
        limit: 1000,
        period: BudgetPeriod.days,
        lengthDays: len,
        anchor: anchor ?? DateTime(2026, 8, 1),
        repeats: repeats,
        endedAt: endedAt,
      );

  test('14-day stride from 1 Aug lands 20 Aug in 15–28 Aug', () {
    final w = store().budgetWindow(days(14), DateTime(2026, 8, 20));
    expect(w.start, DateTime(2026, 8, 15));
    expect(w.end.day, 28);
    expect(w.end.month, 8);
  });

  test('40 days from 13 Aug runs to 21 Sep', () {
    final w = store()
        .budgetWindow(days(40, anchor: DateTime(2026, 8, 13)), DateTime(2026, 8, 20));
    expect(w.start, DateTime(2026, 8, 13));
    expect(w.end.month, 9);
    expect(w.end.day, 21);
  });

  test('a date after a non-repeating budget ended clamps to the last window', () {
    final b = days(40,
        anchor: DateTime(2026, 8, 13),
        repeats: false,
        endedAt: DateTime(2026, 9, 21, 23, 59, 59));
    final w = store().budgetWindow(b, DateTime(2026, 10, 15));
    expect(w.start, DateTime(2026, 8, 13));
    expect(w.end.day, 21);
    expect(w.end.month, 9);
  });

  // ── spend ───────────────────────────────────────────────────────────────────

  test('categories spend over 4 targets = sum of the four windowed sums', () {
    final s = store();
    void exp(String cat, double amt) => s.addTxn(
        type: TxnType.expense,
        amount: amt,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: cat,
        date: DateTime(2026, 8, 10));
    exp('c1', 100);
    exp('c2', 200);
    exp('c3', 50);
    exp('c4', 25);
    final b = Budget(
      id: 'b',
      name: 'B',
      scope: BudgetScope.categories,
      targets: {'c1', 'c2', 'c3', 'c4'},
      limit: 1000,
      anchor: DateTime(2026, 1, 1),
    );
    final w = s.budgetWindow(b, DateTime(2026, 8, 15));
    final byHand = ['c1', 'c2', 'c3', 'c4']
        .fold(0.0, (sum, id) => sum + s.spentInCategoryWindow(id, w));
    expect(s.budgetSpend(b, DateTime(2026, 8, 15)), closeTo(375, 0.001));
    expect(s.budgetSpend(b, DateTime(2026, 8, 15)), closeTo(byHand, 0.001));
  });

  test('account spend counts only expense paid from the account — not a '
      'transfer, a card payment, or income', () {
    final s = store();
    // A genuine spend from the family account.
    s.addTxn(
        type: TxnType.expense,
        amount: 100,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'c1',
        date: DateTime(2026, 8, 10));
    // A transfer to another own account — never counted.
    s.addTxn(
        type: TxnType.transfer,
        amount: 50,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'a-other',
        date: DateTime(2026, 8, 11));
    // A card payment (transfer to the credit card) — never counted.
    s.addTxn(
        type: TxnType.transfer,
        amount: 40,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'a-card',
        date: DateTime(2026, 8, 12));
    // A charge on the card belongs to the card, not to the family account.
    s.addTxn(
        type: TxnType.expense,
        amount: 30,
        currency: 'USD',
        fromRef: 'a-card',
        toRef: 'c2',
        date: DateTime(2026, 8, 12));
    // Income into the family account — never counted.
    s.addTxn(
        type: TxnType.income,
        amount: 200,
        currency: 'USD',
        fromRef: 'c-inc',
        toRef: 'a-family',
        date: DateTime(2026, 8, 13));
    final b = Budget(
      id: 'b',
      name: 'B',
      scope: BudgetScope.account,
      targets: {'a-family'},
      limit: 1000,
      anchor: DateTime(2026, 1, 1),
    );
    final w = s.budgetWindow(b, DateTime(2026, 8, 15));
    expect(s.budgetSpend(b, DateTime(2026, 8, 15)), closeTo(100, 0.001));
    expect(s.budgetSpend(b, DateTime(2026, 8, 15)),
        closeTo(s.expenseInWindow(w, visible: {'a-family'}), 0.001));
  });

  // ── rollover (spec §A.3) ─────────────────────────────────────────────────────

  test('rollover carries a positive remainder from the previous period only', () {
    final s = store();
    s.addTxn(
        type: TxnType.expense,
        amount: 600,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'c1',
        date: DateTime(2026, 7, 10)); // July spend 600, limit 1000 → carry 400
    final b = monthly(rollover: true, limit: 1000);
    expect(s.budgetRolloverCarry(b, DateTime(2026, 8, 15)), closeTo(400, 0.001));
    expect(s.budgetEffectiveLimit(b, DateTime(2026, 8, 15)), closeTo(1400, 0.001));
  });

  test('rollover clamps a negative carry (overspend) to zero', () {
    final s = store();
    s.addTxn(
        type: TxnType.expense,
        amount: 1200,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'c1',
        date: DateTime(2026, 7, 10)); // July overspent by 200
    final b = monthly(rollover: true, limit: 1000);
    expect(s.budgetRolloverCarry(b, DateTime(2026, 8, 15)), 0);
    expect(s.budgetEffectiveLimit(b, DateTime(2026, 8, 15)), closeTo(1000, 0.001));
  });

  test('rollover is ignored when the budget does not repeat', () {
    final s = store();
    s.addTxn(
        type: TxnType.expense,
        amount: 600,
        currency: 'USD',
        fromRef: 'a-family',
        toRef: 'c1',
        date: DateTime(2026, 7, 10));
    final b = Budget(
      id: 'b',
      name: 'B',
      scope: BudgetScope.categories,
      targets: {'c1'},
      limit: 1000,
      anchor: DateTime(2026, 1, 1),
      repeats: false,
      rollover: true,
    );
    expect(s.budgetRolloverCarry(b, DateTime(2026, 8, 15)), 0);
  });
}
