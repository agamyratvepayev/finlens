import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';

// Task 064 §7 — per-occurrence amounts on the store. `flutter test` hangs on
// the author's machine, so these are written, not run here; verify with
// `flutter analyze` and run the file yourself:
//   flutter test test/task064_occurrence_amounts_test.dart
//
// today is pinned to 2026-08-09.

final _today = DateTime(2026, 8, 9, 14, 32);
DateTime _d(int y, int m, int day) => DateTime(y, m, day);

AppStore _store({List<Task> tasks = const [], List<Txn> txns = const []}) =>
    AppStore(
      clock: Clock.fixed(_today),
      accounts: [
        Account(
            id: 'a1',
            name: 'Checking',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100000),
      ],
      categories: [
        Category(
            id: 'sal',
            name: 'Salary',
            type: CategoryType.income,
            icon: Icons.payments_rounded,
            color: Colors.green),
        Category(
            id: 'rent',
            name: 'Rent',
            type: CategoryType.expense,
            icon: Icons.home_rounded,
            color: Colors.red),
      ],
      txns: txns,
      goals: const [],
      tasks: tasks,
    );

/// A monthly pay-in of [amount] on the 15th, first due 2026-09-15.
Task _monthly({double amount = 20000, String id = 't1'}) => Task(
      id: id,
      title: 'Salary',
      linkedAccountId: 'a1',
      expectedAmount: amount,
      dueDate: _d(2026, 9, 15),
      icon: Icons.payments_rounded,
      categoryId: 'sal',
      repeats: RepeatFrequency.monthly,
      daysOfMonth: const {15},
    );

void main() {
  group('amountOn', () {
    test('returns the override, else expectedAmount', () {
      final t = _monthly();
      expect(t.amountOn(_d(2026, 10, 15)), 20000);
      t.amountOverrides[_d(2026, 10, 15)] = 25000;
      expect(t.amountOn(_d(2026, 10, 15)), 25000);
      expect(t.amountOn(_d(2026, 11, 15)), 20000);
    });
  });

  group('setOccurrenceAmount — Only', () {
    test('sets one date', () {
      final store = _store(tasks: [_monthly()]);
      store.setOccurrenceAmount(store.taskById('t1')!, _d(2026, 10, 15), 25000,
          andAfter: false);
      final t = store.taskById('t1')!;
      expect(t.amountOn(_d(2026, 10, 15)), 25000);
      expect(t.amountOn(_d(2026, 9, 15)), 20000);
      expect(t.amountOn(_d(2026, 11, 15)), 20000);
      expect(t.expectedAmount, 20000, reason: 'the usual amount is untouched');
    });

    test('an override equal to the usual amount is not stored', () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      t.amountOverrides[_d(2026, 10, 15)] = 25000;
      store.setOccurrenceAmount(t, _d(2026, 10, 15), 20000, andAfter: false);
      expect(t.hasOverrideOn(_d(2026, 10, 15)), isFalse);
    });
  });

  group('setOccurrenceAmount — And after', () {
    test('earlier occurrences keep the old amount, later become the new usual',
        () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      // From December on, 25,000.
      store.setOccurrenceAmount(t, _d(2026, 12, 15), 25000, andAfter: true);

      // Sep, Oct, Nov (before December, still open) keep 20,000 via overrides.
      expect(t.amountOn(_d(2026, 9, 15)), 20000);
      expect(t.amountOn(_d(2026, 11, 15)), 20000);
      expect(t.hasOverrideOn(_d(2026, 9, 15)), isTrue);
      // December and after read the new usual, with no stored override.
      expect(t.expectedAmount, 25000);
      expect(t.amountOn(_d(2026, 12, 15)), 25000);
      expect(t.amountOn(_d(2027, 1, 15)), 25000);
      expect(t.hasOverrideOn(_d(2026, 12, 15)), isFalse);
      expect(t.hasOverrideOn(_d(2027, 1, 15)), isFalse);
    });

    test('a later override is removed when the usual is raised from before it',
        () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      t.amountOverrides[_d(2027, 2, 15)] = 30000; // a future one-off change
      store.setOccurrenceAmount(t, _d(2026, 12, 15), 25000, andAfter: true);
      expect(t.hasOverrideOn(_d(2027, 2, 15)), isFalse,
          reason: 'overrides at or after the anchor are cleared');
    });
  });

  group('advancing and undo', () {
    test('advancing drops overrides before the new due date', () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      t.amountOverrides[_d(2026, 9, 15)] = 25000; // the current occurrence
      t.amountOverrides[_d(2026, 10, 15)] = 26000;
      store.markTaskPaid(t,
          amount: 25000,
          date: _d(2026, 9, 15),
          fromAccountId: 'a1',
          toRef: 'sal');
      // Advanced to Oct 15; Sep's override is spent, Oct's survives.
      expect(t.dueDate, _d(2026, 10, 15));
      expect(t.hasOverrideOn(_d(2026, 9, 15)), isFalse);
      expect(t.hasOverrideOn(_d(2026, 10, 15)), isTrue);
    });

    test('undo restores the consumed override with the due date', () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      t.amountOverrides[_d(2026, 9, 15)] = 25000;
      final r = store.markTaskPaid(t,
          amount: 25000,
          date: _d(2026, 9, 15),
          fromAccountId: 'a1',
          toRef: 'sal');
      expect(t.hasOverrideOn(_d(2026, 9, 15)), isFalse);

      store.undoMarkTaskPaid(r);
      expect(t.dueDate, _d(2026, 9, 15));
      expect(t.amountOn(_d(2026, 9, 15)), 25000,
          reason: 'the override comes back with the occurrence');
    });
  });

  group('persistence', () {
    test('amountOverrides round-trips through the mapper', () {
      final t = _monthly();
      t.amountOverrides[_d(2026, 12, 15)] = 25000;
      final back = taskFromMap(taskToMap(t));
      expect(back.amountOn(_d(2026, 12, 15)), 25000);
      expect(back.amountOverrides.length, 1);
    });

    test('a row without the column loads as an empty map', () {
      final map = taskToMap(_monthly())..remove('amount_overrides');
      expect(taskFromMap(map).amountOverrides, isEmpty);
    });
  });

  group('aggregates read the override for its month', () {
    // September's occurrence raised to 25,000; the usual is 20,000.
    AppStore withDecemberOverride() {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      // Raise December specifically (a month inside a 4-month horizon).
      t.amountOverrides[_d(2026, 12, 15)] = 25000;
      return store;
    }

    DateRange horizon() =>
        const ScheduleHorizon.preset(SchedulePreset.next3Months)
            .range(_d(2026, 12, 1)); // a window that contains 15 Dec

    test('comingIn counts the December override', () {
      final store = withDecemberOverride();
      // A 3-month window from 1 Dec holds 15 Dec, 15 Jan, 15 Feb: 25k + 20k + 20k.
      expect(store.comingIn(horizon()), 65000);
    });

    test('firstShortfall uses the override', () {
      // A pay-out series that only breaches once its raised month lands.
      final store = _store(tasks: [
        Task(
          id: 'bill',
          title: 'Rent',
          linkedAccountId: 'a1',
          expectedAmount: -50000,
          dueDate: _d(2026, 9, 15),
          icon: Icons.home_rounded,
          categoryId: 'rent',
          repeats: RepeatFrequency.monthly,
          daysOfMonth: const {15},
        ),
      ]);
      final t = store.taskById('bill')!;
      // Balance 100,000; 50k in Sep leaves 50k, 50k in Oct leaves 0 — no
      // breach. Raise October to 60,000 → Oct goes negative.
      t.amountOverrides[_d(2026, 10, 15)] = -60000;
      final breach = store.firstShortfall(
          const ScheduleHorizon.preset(SchedulePreset.next3Months)
              .range(_today));
      expect(breach, isNotNull);
      expect(breach!.day.month, 10);
    });

    test('the forecast counts the override for its month', () {
      final store = withDecemberOverride();
      final base = _store(tasks: [_monthly()]); // no override
      final withOverride = store.forecastTo(_d(2027, 1, 1));
      final without = base.forecastTo(_d(2027, 1, 1));
      // The overridden run ends 5,000 higher (25,000 vs 20,000 in December).
      expect(withOverride.spendable! - without.spendable!,
          moreOrLessEquals(5000, epsilon: 0.01));
    });
  });
}
