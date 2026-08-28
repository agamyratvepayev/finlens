import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

/// Frozen figures (§3). An archived goal's record is a photograph: `goalMetrics`
/// takes an `asOf` date that freezes every figure at the day the goal ended, and
/// a transaction dated after `asOf` must not move any of them.
void main() {
  final created = DateTime(2026, 1, 1);

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
          {DateTime? date}) =>
      Txn(
        id: id,
        type: TxnType.income,
        amount: amount,
        currency: 'USD',
        fromRef: catId,
        toRef: accId,
        date: date ?? DateTime(2026, 2, 1),
      );

  // ── endedAt ────────────────────────────────────────────────────────────────

  test('endedAt prefers completedAt over stoppedAt and is null when active', () {
    final active = Goal(
      id: 'a',
      name: 'a',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
      createdAt: created,
    );
    expect(active.endedAt, isNull);

    final reached = Goal(
      id: 'r',
      name: 'r',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
      createdAt: created,
      status: GoalStatus.reached,
      completedAt: DateTime(2026, 5, 14),
      stoppedAt: DateTime(2026, 6, 1),
    );
    expect(reached.endedAt, DateTime(2026, 5, 14));

    final abandoned = Goal(
      id: 's',
      name: 's',
      source: const GoalSource.account('acc'),
      targetAmount: 100,
      createdAt: created,
      status: GoalStatus.abandoned,
      stoppedAt: DateTime(2026, 4, 3),
    );
    expect(abandoned.endedAt, DateTime(2026, 4, 3));
  });

  // ── Account source: frozen balance ──────────────────────────────────────────

  test('asOf freezes an account goal at the balance on that date', () {
    final goal = Goal(
      id: 'g',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      txns: [
        income('t1', 'inc', 'acc', 100, date: DateTime(2026, 2, 1)),
        income('t2', 'inc', 'acc', 100, date: DateTime(2026, 3, 1)),
        income('t3', 'inc', 'acc', 500, date: DateTime(2026, 6, 1)),
      ],
      goals: [goal],
    );

    // On 1 Apr only the Feb and Mar deposits count: 0 + 100 + 100.
    expect(store.goalMetrics(goal, asOf: DateTime(2026, 4, 1)).current,
        closeTo(200, 1e-9));
    // Today (no asOf) sees all three: 700.
    expect(store.goalMetrics(goal).current, closeTo(700, 1e-9));
  });

  test('a transaction dated after asOf moves no frozen field', () {
    final goal = Goal(
      id: 'g',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      txns: [
        income('t1', 'inc', 'acc', 100, date: DateTime(2026, 2, 1)),
        income('t2', 'inc', 'acc', 100, date: DateTime(2026, 3, 1)),
      ],
      goals: [goal],
    );

    final asOf = DateTime(2026, 4, 1);
    final before = store.goalMetrics(goal, asOf: asOf);

    // A later deposit — well after the frozen date.
    store.addTxn(
      type: TxnType.income,
      amount: 5000,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'acc',
      date: DateTime(2026, 7, 1),
    );

    final after = store.goalMetrics(goal, asOf: asOf);
    expect(after.current, before.current);
    expect(after.progress, before.progress);
    expect(after.monthsElapsed, before.monthsElapsed);
    expect(after.projectedEnd, before.projectedEnd);
  });

  // ── Category source: window ends at asOf ────────────────────────────────────

  test('asOf ends a category goal window on that date, ignoring targetDate', () {
    final goal = Goal(
      id: 'g',
      name: 'Freelance',
      source: const GoalSource.category('inc'),
      targetAmount: 12000,
      targetDate: DateTime(2026, 12, 31),
      createdAt: created,
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 0)],
      categories: [incomeCat('inc')],
      txns: [
        income('t1', 'inc', 'acc', 1000, date: DateTime(2026, 2, 1)),
        income('t2', 'inc', 'acc', 1000, date: DateTime(2026, 5, 1)),
      ],
      goals: [goal],
    );

    // The window ends 1 Apr even though targetDate is December: only Feb counts.
    expect(store.goalMetrics(goal, asOf: DateTime(2026, 4, 1)).current,
        closeTo(1000, 1e-9));
    // Live: the window runs to targetDate, so both count.
    expect(store.goalMetrics(goal).current, closeTo(2000, 1e-9));
  });

  // ── No asOf is byte-identical to the live path ──────────────────────────────

  test('goalMetrics with no asOf is unchanged for a live goal', () {
    final goal = Goal(
      id: 'g',
      name: 'Save',
      source: const GoalSource.account('acc'),
      targetAmount: 1000,
      targetDate: DateTime(2026, 12, 1),
      createdAt: DateTime(2026, 6, 1),
    );
    final store = storeWith(
      accounts: [account('acc', AccountGroup.spendable, 100)],
      categories: [incomeCat('inc')],
      txns: [income('t1', 'inc', 'acc', 150, date: DateTime(2026, 7, 1))],
      goals: [goal],
    );
    final m = store.goalMetrics(goal);
    // Pins the pre-change derivation (see goal_progress_test): current 250,
    // moved 150 over 2 months → 75/mo; gap 750 / 75 = 10 → Jun 2027.
    expect(m.current, closeTo(250, 1e-9));
    expect(m.progress, closeTo(150 / 900, 1e-9));
    expect(m.requiredRate, closeTo(187.5, 1e-9));
    expect(m.projectedEnd!.year, 2027);
    expect(m.projectedEnd!.month, 6);
  });

  // ── A source archived after the goal ended still reports its outcome ─────────

  test('a source archived after the goal ended keeps its frozen outcome', () {
    final acc = account('acc', AccountGroup.spendable, 0);
    final goal = Goal(
      id: 'g',
      name: 'Phone',
      source: const GoalSource.account('acc'),
      targetAmount: 200,
      createdAt: created,
      status: GoalStatus.reached,
      completedAt: DateTime(2026, 5, 14),
    );
    final store = storeWith(
      accounts: [acc],
      categories: [incomeCat('inc')],
      txns: [income('t1', 'inc', 'acc', 300, date: DateTime(2026, 3, 1))],
      goals: [goal],
    );

    // Archive the source after the goal has already ended (it has a txn, so
    // removeAccount archives rather than hard-deletes).
    store.removeAccount(acc);

    final m = store.goalMetrics(goal, asOf: goal.endedAt);
    // The frozen balance on 14 May is unaffected by the archive flag…
    expect(m.current, closeTo(300, 1e-9));
    // …and the outcome (latched by completedAt) still reads reached, even though
    // the live sourceAvailable flag is now false.
    expect(m.reached, isTrue);
    expect(m.sourceAvailable, isFalse);
  });
}
