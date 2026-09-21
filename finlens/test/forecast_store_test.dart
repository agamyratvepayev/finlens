import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/forecast.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';

/// Task 057 — the Planner forecast engine (`AppStore.forecastTo`) and the pure
/// `Task.occurrencesIn` enumerator. Pure store/model arithmetic, no widgets.
///
/// `flutter test` hangs on the author's machine — run these yourself:
///   flutter test test/forecast_store_test.dart
void main() {
  final today = DateTime(2026, 8, 9); // 9 Aug 2026

  Account acc(String id, AccountGroup group, double bal,
          {String currency = 'USD', bool countAsSpendable = true}) =>
      Account(
        id: id,
        name: id,
        group: group,
        currency: currency,
        startingBalance: bal,
        countAsSpendable: countAsSpendable,
      );

  Category cat(String id, {CategoryType type = CategoryType.expense}) =>
      Category(id: id, name: id, type: type, icon: Icons.category_rounded, color: Colors.green);

  AppStore store({
    List<Account>? accounts,
    List<Task> tasks = const [],
    List<Budget> budgets = const [],
    List<Goal> goals = const [],
    DateTime? clockDay,
    Map<String, double>? rates,
  }) =>
      AppStore(
        clock: Clock.fixed(clockDay ?? DateTime(2026, 8, 9, 14, 0)),
        baseCurrency: 'USD',
        accounts: accounts ?? [acc('a-cash', AccountGroup.spendable, 1000)],
        categories: [cat('c-food'), cat('c-rent'), cat('c-inc', type: CategoryType.income)],
        txns: const [],
        goals: goals,
        tasks: tasks,
        budgets: budgets,
        rates: rates,
      );

  Task task({
    required double amount,
    required DateTime due,
    String account = 'a-cash',
    String? category = 'c-food',
    String? payTo,
    RepeatFrequency repeats = RepeatFrequency.none,
    Set<int> daysOfMonth = const {},
    List<DateTime> skipped = const [],
  }) =>
      Task(
        id: 't-${due.millisecondsSinceEpoch}-${amount.toInt()}',
        title: 'T',
        linkedAccountId: account,
        expectedAmount: amount,
        dueDate: due,
        icon: Icons.bolt_rounded,
        categoryId: payTo == null ? category : null,
        payToAccountId: payTo,
        repeats: repeats,
        daysOfMonth: daysOfMonth,
        skippedDates: skipped,
      );

  DateTime plus(int d) => today.add(Duration(days: d));

  // ── forecastTo ──────────────────────────────────────────────────────────────

  group('forecastTo — the empty case', () {
    test('both lenses equal today with nothing planned; days is right', () {
      final s = store();
      final f = s.forecastTo(plus(30));
      expect(f.spendableToday, 1000);
      expect(f.netWorthToday, 1000);
      expect(f.spendable, 1000);
      expect(f.netWorth, 1000);
      expect(f.days, 30);
      expect(f.spendableByDay.length, 31); // start..end inclusive
      expect(f.spendableBelowZero, isNull);
      expect(f.lines, isEmpty);
    });

    test('end before today yields today figures, no lines', () {
      final s = store();
      final f = s.forecastTo(plus(-5));
      expect(f.spendable, 1000);
      expect(f.netWorth, 1000);
      expect(f.lines, isEmpty);
    });
  });

  group('forecastTo — where the money lands (§1c)', () {
    test('scheduled pay-out from a spendable account drops both lenses', () {
      final s = store(tasks: [task(amount: -200, due: plus(6))]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 800);
      expect(f.netWorth, 800);
    });

    test('pay-in into receivables raises net worth only', () {
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-recv', AccountGroup.receivables, 0),
      ], tasks: [
        task(amount: 500, due: plus(6), account: 'a-recv', category: 'c-inc'),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 1000); // unchanged
      expect(f.netWorth, 1500);
    });

    test('pay-out booked to a credit card drops net worth only', () {
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-card', AccountGroup.creditCards, 0),
      ], tasks: [
        task(amount: -300, due: plus(6), account: 'a-card'),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 1000); // card is not spendable
      expect(f.netWorth, 700); // debt grows
    });

    test('a transfer spendable → card drops spendable, leaves net worth', () {
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-card', AccountGroup.creditCards, 0),
      ], tasks: [
        task(amount: -400, due: plus(6), payTo: 'a-card'),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 600);
      expect(f.netWorth, 1000); // net-worth-neutral
    });
  });

  group('forecastTo — every occurrence (§1f)', () {
    test('a monthly task over 90 days is counted three times, one line', () {
      final s = store(tasks: [
        task(
            amount: -100,
            due: DateTime(2026, 8, 15),
            repeats: RepeatFrequency.monthly,
            daysOfMonth: {15}),
      ]);
      final f = s.forecastTo(plus(90)); // Aug 9 → Nov 7
      expect(f.spendable, 700); // 1000 − 3×100
      final line = f.lines.firstWhere((l) => l.kind == ForecastKind.scheduled);
      expect(line.count, 3);
      expect(line.amount, -300);
    });

    test('a skipped occurrence inside the window is not counted', () {
      final s = store(tasks: [
        task(
            amount: -100,
            due: DateTime(2026, 8, 15),
            repeats: RepeatFrequency.monthly,
            daysOfMonth: {15},
            skipped: [DateTime(2026, 9, 15)]),
      ]);
      final f = s.forecastTo(plus(90));
      expect(f.spendable, 800); // Aug 15 + Oct 15 only
    });
  });

  group('forecastTo — budgets at planned pace (§1d)', () {
    Budget monthly({required Set<String> targets, double limit = 900}) => Budget(
          id: 'b',
          name: 'B',
          scope: BudgetScope.categories,
          targets: targets,
          limit: limit,
          period: BudgetPeriod.month,
          anchor: DateTime(2026, 1, 1),
          repeats: true,
        );

    test('900/month over 10 days of September ≈ 300 out of both lenses', () {
      final s = store(
          clockDay: DateTime(2026, 9, 1, 12),
          budgets: [monthly(targets: {'c-food'})]);
      final f = s.forecastTo(DateTime(2026, 9, 11)); // tomorrow..Sep11 = 10 days
      expect(f.spendable, closeTo(700, 0.001)); // 1000 − 300
      expect(f.netWorth, closeTo(700, 0.001));
    });

    test('a window crossing into October uses ÷30 then ÷31', () {
      final s = store(
          clockDay: DateTime(2026, 9, 25, 12),
          budgets: [monthly(targets: {'c-food'})]);
      final f = s.forecastTo(DateTime(2026, 10, 5));
      // Sep 26..30 = 5 × 900/30; Oct 1..5 = 5 × 900/31.
      final expected = 5 * (900 / 30) + 5 * (900 / 31);
      expect(1000 - f.spendable!, closeTo(expected, 0.01));
    });

    test('a bill in a budgeted category is not double-counted', () {
      final s = store(
          clockDay: DateTime(2026, 9, 1, 12),
          tasks: [task(amount: -30, due: DateTime(2026, 9, 2))],
          budgets: [monthly(targets: {'c-food'})]);
      final f = s.forecastTo(DateTime(2026, 9, 2)); // only Sep 2 in the window
      // Pace 30 − claimed 30 = 0, so only the task's 30 leaves.
      expect(f.spendable, closeTo(970, 0.001));
    });

    test('a budget scoped to a credit-card account is not counted', () {
      final cardBudget = Budget(
        id: 'b-card',
        name: 'Card',
        scope: BudgetScope.account,
        targets: {'a-card'},
        limit: 900,
        period: BudgetPeriod.month,
        anchor: DateTime(2026, 1, 1),
        repeats: true,
      );
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-card', AccountGroup.creditCards, 0),
      ], clockDay: DateTime(2026, 9, 1, 12), budgets: [cardBudget]);
      final f = s.forecastTo(DateTime(2026, 9, 30));
      expect(f.spendable, 1000); // untouched
    });

    test('a non-repeating budget stops at its window end', () {
      final oneOff = Budget(
        id: 'b1',
        name: 'One',
        scope: BudgetScope.categories,
        targets: {'c-food'},
        limit: 300,
        period: BudgetPeriod.days,
        lengthDays: 30,
        anchor: today,
        repeats: false,
        endedAt: plus(3),
      );
      final s = store(budgets: [oneOff]);
      final f = s.forecastTo(plus(10));
      // Tomorrow..+3 = 3 days × (300/30 = 10) = 30; nothing past +3.
      final line = f.lines.firstWhere((l) => l.kind == ForecastKind.budget);
      expect(line.count, 3);
      expect(f.spendable, closeTo(970, 0.001));
    });
  });

  group('forecastTo — goals by target date (§1e)', () {
    Goal goal({
      required GoalSource source,
      required double target,
      DateTime? targetDate,
      String currency = 'USD',
    }) =>
        Goal(
          id: 'g',
          name: 'G',
          source: source,
          targetAmount: target,
          createdAt: DateTime(2026, 1, 1),
          currency: currency,
          targetDate: targetDate,
        );

    List<Account> withSave() => [
          acc('a-cash', AccountGroup.spendable, 1000),
          acc('a-save', AccountGroup.setAside, 500),
        ];

    test('a saving goal due in the window leaves spendable, not net worth', () {
      final s = store(accounts: withSave(), goals: [
        goal(
            source: const GoalSource.account('a-save'),
            target: 2000,
            targetDate: plus(30)),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, closeTo(1000 - 1500, 0.001)); // remaining 1500 leaves
      expect(f.netWorth, closeTo(1500, 0.001)); // 1000 + 500, unchanged
    });

    test('a goal one day past the window contributes nothing', () {
      final s = store(accounts: withSave(), goals: [
        goal(
            source: const GoalSource.account('a-save'),
            target: 2000,
            targetDate: plus(31)),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 1000);
    });

    test('reached, no-date, earning and waiting-on goals contribute nothing', () {
      final accounts = [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-save', AccountGroup.setAside, 2000), // already at target
        acc('a-recv', AccountGroup.receivables, 100),
      ];
      final s = store(accounts: accounts, goals: [
        goal(source: const GoalSource.account('a-save'), target: 2000, targetDate: plus(10)), // reached
        goal(source: const GoalSource.account('a-cash'), target: 5000), // no date
        goal(source: const GoalSource.category('c-inc'), target: 500, targetDate: plus(10)), // earning
        goal(source: const GoalSource.account('a-recv'), target: 0, targetDate: plus(10)), // waiting on
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.lines.where((l) => l.kind == ForecastKind.goal), isEmpty);
    });
  });

  group('forecastTo — overdue (§1c)', () {
    test('an overdue pay-out applies on day 0; an overdue pay-in is ignored', () {
      final s = store(tasks: [
        task(amount: -200, due: plus(-8)), // overdue pay-out
        task(amount: 300, due: plus(-8), category: 'c-inc'), // overdue pay-in
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 800); // only the −200
      expect(f.netWorth, 800);
      expect(f.spendableByDay[0], 800); // applied at day 0
    });
  });

  group('forecastTo — missing rates (§1h)', () {
    test('a missing rate silences its lens and lists the code; the other computes',
        () {
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1000),
        acc('a-recv', AccountGroup.receivables, 500, currency: 'EUR'),
      ], rates: {
        'GBP': 2.0 // non-empty so seeding is skipped; EUR left unrated
      });
      final f = s.forecastTo(plus(30));
      expect(f.spendable, 1000); // spendable lens has no EUR account
      expect(f.netWorth, isNull); // net worth includes the unrated receivable
      expect(f.missingRateCodes, contains('EUR'));
    });
  });

  group('forecastTo — spendableBelowZero (§1b)', () {
    test('reports the first day the run goes negative', () {
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 100)
      ], tasks: [
        task(amount: -60, due: plus(1)),
        task(amount: -60, due: plus(3)),
      ]);
      final f = s.forecastTo(plus(30));
      expect(f.spendableBelowZero, plus(3));
    });

    test('is null when the run never goes negative', () {
      final s = store(tasks: [task(amount: -60, due: plus(1))]);
      final f = s.forecastTo(plus(30));
      expect(f.spendableBelowZero, isNull);
    });
  });

  // ── Task.occurrencesIn ────────────────────────────────────────────────────

  group('Task.occurrencesIn', () {
    test('a non-repeating task yields its due date only when in range', () {
      final t = task(amount: -1, due: DateTime(2026, 8, 15));
      expect(t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 9, 8)).length, 1);
      expect(t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 8, 14)), isEmpty);
    });

    test('weekly walks every seven days', () {
      final t = task(amount: -1, due: DateTime(2026, 8, 10), repeats: RepeatFrequency.weekly);
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 9, 8));
      expect(occ.length, 5); // 10, 17, 24, 31, Sep 7
    });

    test('monthly honours the chosen day', () {
      final t = task(
          amount: -1,
          due: DateTime(2026, 8, 15),
          repeats: RepeatFrequency.monthly,
          daysOfMonth: {15});
      expect(t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 11, 7)).length, 3);
    });

    test('custom Every-3-days steps by three', () {
      final t = Task(
        id: 'c',
        title: 'C',
        linkedAccountId: 'a-cash',
        expectedAmount: -1,
        dueDate: DateTime(2026, 8, 9),
        icon: Icons.bolt_rounded,
        repeats: RepeatFrequency.custom,
        repeatUnit: RepeatUnit.day,
        repeatInterval: 3,
      );
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 8, 20));
      expect(occ, [
        DateTime(2026, 8, 9),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 18),
      ]);
    });

    test('repeatEndCount counts from the first occurrence', () {
      final t = task(amount: -1, due: DateTime(2026, 8, 10), repeats: RepeatFrequency.weekly)
        ..repeatEndCount = 3;
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 12, 31));
      expect(occ, [DateTime(2026, 8, 10), DateTime(2026, 8, 17), DateTime(2026, 8, 24)]);
    });

    test('repeatEndDate stops the series on or before the date', () {
      final t = task(amount: -1, due: DateTime(2026, 8, 10), repeats: RepeatFrequency.weekly)
        ..repeatEndDate = DateTime(2026, 8, 24);
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 12, 31));
      expect(occ.length, 3); // 10, 17, 24
    });

    test('a monthly on the 31st clamps in short months', () {
      final t = task(
          amount: -1,
          due: DateTime(2026, 1, 31),
          repeats: RepeatFrequency.monthly,
          daysOfMonth: {31});
      final occ = t.occurrencesIn(DateTime(2026, 1, 1), DateTime(2026, 4, 30));
      expect(occ, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('skipped dates drop out', () {
      final t = task(
          amount: -1,
          due: DateTime(2026, 8, 15),
          repeats: RepeatFrequency.monthly,
          daysOfMonth: {15},
          skipped: [DateTime(2026, 9, 15)]);
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 10, 31));
      expect(occ, [DateTime(2026, 8, 15), DateTime(2026, 10, 15)]);
    });

    test('cap bounds the in-range collection', () {
      final t = task(amount: -1, due: DateTime(2026, 8, 9), repeats: RepeatFrequency.daily);
      final occ = t.occurrencesIn(DateTime(2026, 8, 9), DateTime(2026, 8, 9).add(const Duration(days: 200)), cap: 10);
      expect(occ.length, 10);
    });
  });
}
