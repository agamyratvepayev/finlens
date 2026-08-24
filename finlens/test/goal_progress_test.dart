import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

/// Goals, rebuilt on real balances (§1). Progress is derived from the ledger,
/// never stored — these tests pin the derivation, the latch and the history.
void main() {
  // AppStore.today is pinned to 9 Aug 2026.
  final created = DateTime(2026, 6, 1);

  Account account(String id, AccountGroup group, double start) => Account(
        id: id,
        name: id,
        group: group,
        currency: 'USD',
        startingBalance: start,
      );

  Category incomeCat(String id) => Category(
        id: id,
        name: id,
        type: CategoryType.income,
        icon: Icons.attach_money_rounded,
        color: const Color(0xFF30D158),
      );

  AppStore storeWith({
    List<Account> accounts = const [],
    List<Category> categories = const [],
    List<Txn> txns = const [],
    List<Goal> goals = const [],
  }) =>
      AppStore(
        accounts: accounts,
        categories: categories,
        txns: txns,
        goals: goals,
        tasks: const [],
      );

  Txn income(String id, String catId, String accId, double amount,
          {String currency = 'USD', DateTime? date}) =>
      Txn(
        id: id,
        type: TxnType.income,
        amount: amount,
        currency: currency,
        fromRef: catId,
        toRef: accId,
        date: date ?? DateTime(2026, 7, 1),
      );

  // ── Progress, across sources ───────────────────────────────────────────────

  test('SAVING progress derives from the account balance, start-anchored', () {
    final goal = Goal(
      id: 'g1',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      goals: [goal],
    );

    expect(store.goalMetrics(goal).progress, closeTo(0, 1e-9));

    store.addTxn(
      type: TxnType.income,
      amount: 150,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'acc',
      date: DateTime(2026, 7, 1),
    );

    // start 100, current 250, span 900 → 150/900.
    expect(store.goalMetrics(goal).progress, closeTo(150 / 900, 1e-9));
  });

  test('a transfer into the account moves the bar with no write to the Goal',
      () {
    final goal = Goal(
      id: 'g1',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      goals: [goal],
    );

    final targetBefore = goal.targetAmount;
    final historyBefore = goal.history.length;
    final progressBefore = store.goalMetrics(goal).progress;

    store.addTxn(
      type: TxnType.income,
      amount: 150,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'acc',
      date: DateTime(2026, 7, 1),
    );

    expect(store.goalMetrics(goal).progress, greaterThan(progressBefore));
    // The Goal itself was never edited.
    expect(goal.targetAmount, targetBefore);
    expect(goal.history.length, historyBefore);
  });

  test('requiredRate = gap / months remaining', () {
    final goal = Goal(
      id: 'g1',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      txns: [income('t1', 'inc', 'acc', 150)],
      goals: [goal],
    );
    // current 250, gap 750; Aug→Dec = 4 months → 187.5.
    expect(store.goalMetrics(goal).requiredRate, closeTo(187.5, 1e-9));
  });

  test('actualRate and projectedEnd derive from elapsed movement', () {
    final goal = Goal(
      id: 'g1',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      txns: [income('t1', 'inc', 'acc', 150)],
      goals: [goal],
    );
    final m = store.goalMetrics(goal);
    // moved 150 over 2 elapsed months → 75/mo. gap 750 / 75 = 10 months → Jun 2027.
    expect(m.actualRate, closeTo(75, 1e-9));
    expect(m.projectedEnd!.year, 2027);
    expect(m.projectedEnd!.month, 6);
    expect(m.behind, isTrue); // Jun 2027 is after the Dec 2026 target.
  });

  test('a liability source is PAYING OFF and counts debt repaid', () {
    final goal = Goal(
      id: 'g1',
      name: 'Card',
      source: const GoalSource.account('card'),
      targetAmount: 0,
      targetDate: DateTime(2026, 12, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('card', AccountGroup.creditCards, -500)],
      categories: [incomeCat('inc')],
      goals: [goal],
    );
    expect(store.goalSection(goal), GoalSection.payingOff);
    expect(store.goalMetrics(goal).progress, closeTo(0, 1e-9));

    // Pay $200 toward the card (raises its balance toward zero).
    store.addTxn(
      type: TxnType.income,
      amount: 200,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'card',
      date: DateTime(2026, 7, 1),
    );
    // start -500, current -300, span 500 → 200/500.
    expect(store.goalMetrics(goal).progress, closeTo(0.4, 1e-9));
  });

  test('a receivable source is WAITING ON', () {
    final goal = Goal(
      id: 'g1',
      name: 'Invoice',
      source: const GoalSource.account('inv'),
      targetAmount: 0,
      targetDate: DateTime(2026, 10, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('inv', AccountGroup.receivables, 1200)],
      goals: [goal],
    );
    expect(store.goalSection(goal), GoalSection.waitingOn);
  });

  test('an EARNING goal sums earnedInWindow converted to base currency', () {
    final goal = Goal(
      id: 'g1',
      name: 'Freelance',
      source: const GoalSource.category('inc'),
      targetAmount: 12000,
      targetDate: DateTime(2026, 12, 31),
      createdAt: DateTime(2026, 1, 1),
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      txns: [
        income('t1', 'inc', 'acc', 1000, date: DateTime(2026, 3, 1)),
        income('t2', 'inc', 'acc', 1000,
            currency: 'EUR', date: DateTime(2026, 4, 1)),
      ],
      goals: [goal],
    );
    expect(store.goalSection(goal), GoalSection.earning);
    // 1000 USD + 1000 EUR × 1.10 = 2100 base.
    expect(store.goalMetrics(goal).current, closeTo(2100, 1e-6));
  });

  // ── Zero-month spans ───────────────────────────────────────────────────────

  test('a goal created today has no actualRate (AT THIS RATE shows —)', () {
    final goal = Goal(
      id: 'g1',
      name: 'New',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: AppStore.today,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      goals: [goal],
    );
    final m = store.goalMetrics(goal);
    expect(m.monthsElapsed, 0);
    expect(m.actualRate, isNull);
    expect(m.projectedEnd, isNull);
    expect(m.behind, isFalse);
  });

  // ── Latch ─────────────────────────────────────────────────────────────────

  test('target already met at creation latches immediately', () {
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 150)],
    );
    final goal = store.addGoal(
      name: 'Already',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
    );
    expect(goal.completedAt, isNotNull);
    expect(store.goalMetrics(goal).reached, isTrue);
  });

  test('the latch survives the account being emptied', () {
    // createdAt is in the past so later deposits count as movement, not start.
    final goal = Goal(
      id: 'g1',
      name: 'Pot',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      goals: [goal],
    );
    expect(goal.completedAt, isNull);

    // Reach it.
    store.addTxn(
      type: TxnType.income,
      amount: 100,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'acc',
      date: DateTime(2026, 7, 1),
    );
    expect(goal.completedAt, isNotNull);

    // Empty it — the bar falls, but "reached" holds.
    store.addTxn(
      type: TxnType.expense,
      amount: 100,
      currency: 'USD',
      fromRef: 'acc',
      toRef: 'inc',
      date: DateTime(2026, 7, 15),
    );
    final m = store.goalMetrics(goal);
    expect(m.reached, isTrue);
    expect(m.progress, lessThan(1.0));
  });

  test('a refillable goal never latches and reads below target as not funded',
      () {
    final goal = Goal(
      id: 'g1',
      name: 'Emergency',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
      endsWhenReached: false,
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      goals: [goal],
    );
    store.addTxn(
      type: TxnType.income,
      amount: 100,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'acc',
      date: DateTime(2026, 7, 1),
    );
    // At target, but a refillable goal never latches or reads "reached".
    expect(goal.completedAt, isNull);
    expect(store.goalMetrics(goal).reached, isFalse);
    expect(store.goalMetrics(goal).atTarget, isTrue);
  });

  // ── Delete leaves the account and its transactions ─────────────────────────

  test('deleteGoal leaves the account, its balance and its transactions', () {
    final txn = income('t1', 'inc', 'acc', 150);
    final goal = Goal(
      id: 'g1',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      txns: [txn],
      goals: [goal],
    );

    store.deleteGoal(goal);

    expect(store.goals, isEmpty);
    expect(store.accountById('acc'), isNotNull);
    expect(store.balanceOf('acc'), closeTo(250, 1e-9));
    expect(store.txnById('t1'), isNotNull);
  });

  // ── Change history ─────────────────────────────────────────────────────────

  test('GoalEdit records target and date changes but not a name change', () {
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
    );
    final goal = store.addGoal(
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
    );
    // Seeded with a `created` entry.
    expect(goal.history.length, 1);
    expect(goal.history.first.field, 'created');

    store.updateGoal(goal, name: 'Renamed');
    expect(goal.history.length, 1); // name change is not logged.

    store.updateGoal(goal, targetAmount: 2000);
    expect(goal.history.last.field, 'target');

    store.updateGoal(goal, targetDate: DateTime(2027, 6, 1));
    expect(goal.history.last.field, 'targetDate');
    expect(goal.history.last.amber, isTrue); // pushed out → amber.

    expect(goal.history.length, 3);
  });
}
