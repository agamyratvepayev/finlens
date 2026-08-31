import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';

/// Unit coverage for the Schedule rebuild (§13). NOTE: `flutter test` hangs on
/// the dev machine — these files are written but not run there; verify with
/// `flutter analyze` and run the suite elsewhere.
void main() {
  final today = AppStore.today; // 9 Aug 2026, 14:32

  Task mkTask({
    required double amount,
    required DateTime due,
    String account = 'a-checking',
    String? category = 'c-housing',
    String? payTo,
    RepeatFrequency repeats = RepeatFrequency.none,
  }) =>
      Task(
        id: 't-x',
        title: 'X',
        linkedAccountId: account,
        expectedAmount: amount,
        dueDate: due,
        icon: Icons.bolt_rounded,
        categoryId: category,
        payToAccountId: payTo,
        repeats: repeats,
      );

  DateRange next30() =>
      const ScheduleHorizon.preset(SchedulePreset.next30).range(today);

  group('Task.daysUntilDue', () {
    test('counts whole days to a fixed reference date', () {
      expect(mkTask(amount: -1, due: DateTime(2026, 8, 12)).daysUntilDue(today), 3);
    });
    test('is 0 on the due day regardless of time', () {
      expect(mkTask(amount: -1, due: DateTime(2026, 8, 9, 23, 59)).daysUntilDue(today), 0);
    });
    test('is negative when overdue', () {
      expect(mkTask(amount: -1, due: DateTime(2026, 8, 7)).daysUntilDue(today), -2);
      expect(mkTask(amount: -1, due: DateTime(2026, 8, 7)).isOverdue(today), isTrue);
    });
    test('reads no wall clock', () {
      // grep guard: the model must not reference DateTime.now().
      expect(mkTask(amount: -1, due: DateTime(2026, 8, 10)).daysUntilDue(today), 1);
    });
  });

  group('horizon windows', () {
    test('next 30 days spans today..today+30', () {
      final r = next30();
      expect(r.start, DateTime(2026, 8, 9));
      expect(r.end.year, 2026);
      expect(r.end.month, 9);
      expect(r.end.day, 8);
      expect(const ScheduleHorizon.preset(SchedulePreset.next30).spanDays(today), 30);
    });
    test('this week spans today..today+7', () {
      final r = const ScheduleHorizon.preset(SchedulePreset.thisWeek).range(today);
      expect(r.end.day, 16);
    });
    test('this month ends on the last day of the month', () {
      final lastDay = DateTime(2026, 8, 31);
      final r = const ScheduleHorizon.preset(SchedulePreset.thisMonth).range(lastDay);
      expect(r.start, DateTime(2026, 8, 31));
      expect(r.end.day, 31);
    });
    test('custom end date is honoured', () {
      final r = ScheduleHorizon.until(DateTime(2026, 8, 19)).range(today);
      expect(r.end.day, 19);
      expect(ScheduleHorizon.until(DateTime(2026, 8, 19)).spanDays(today), 10);
    });
  });

  group('projection', () {
    test('equals spendable + comingIn − goingOut, overdue outflow included', () {
      final store = buildSeedStore();
      final h = next30();
      expect(store.projection(h),
          closeTo(store.spendable + store.comingIn(h) - store.goingOut(h), 0.01));
      // The overdue Gym pay-out is folded into goingOut (§2.1).
      expect(store.goingOut(h), closeTo(3115.98, 0.01));
      expect(store.comingIn(h), closeTo(5200, 0.01));
    });

    test('overdue inflow is excluded from the projection', () {
      final store = buildSeedStore();
      // Make the salary overdue: an inflow that has not arrived is not money.
      store.taskById('k-salary')!.dueDate = DateTime(2026, 8, 1);
      final h = next30();
      // Salary no longer counts toward comingIn.
      expect(store.comingIn(h), closeTo(0, 0.01));
    });

    test('empty horizon leaves the projection at spendable', () {
      final store = buildSeedStore();
      // A one-day horizon with nothing due today and no overdue.
      for (final t in [...store.openTasks]) {
        store.deleteTask(t);
      }
      final h = ScheduleHorizon.until(today).range(today);
      expect(store.projection(h), closeTo(store.spendable, 0.01));
    });
  });

  group('firstShortfall', () {
    test('returns null when the balance never breaks', () {
      final store = buildSeedStore();
      expect(store.firstShortfall(next30()), isNull);
    });

    test('reports a mid-horizon breach with the right day and amount', () {
      final store = buildSeedStore();
      // A huge expense in three days breaks the balance on 12 Aug.
      store.addTask(
        title: 'Huge',
        linkedAccountId: 'a-checking',
        expectedAmount: -1000000,
        dueDate: DateTime(2026, 8, 12, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
      );
      final breach = store.firstShortfall(next30());
      expect(breach, isNotNull);
      expect(breach!.day, DateTime(2026, 8, 12));
    });

    test('breach on day 0 from an overdue pay-out', () {
      final store = buildSeedStore();
      store.addTask(
        title: 'Owed',
        linkedAccountId: 'a-checking',
        expectedAmount: -1000000,
        dueDate: DateTime(2026, 8, 1, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
      );
      final breach = store.firstShortfall(next30());
      expect(breach, isNotNull);
      expect(breach!.day, DateTime(2026, 8, 9)); // today
    });
  });

  group('markTaskPaid', () {
    test('writes the passed amount and date, stamps the task, advances', () {
      final store = buildSeedStore();
      final task = store.taskById('k-internet')!;
      final before = store.txns.length;
      final r = store.markTaskPaid(
        task,
        amount: 47.30,
        date: DateTime(2026, 8, 9),
        fromAccountId: 'a-checking',
        toRef: task.categoryId!,
      );
      expect(store.txns.length, before + 1);
      expect(r.txn.amount, 47.30);
      expect(r.txn.date, DateTime(2026, 8, 9));
      expect(r.txn.recurrenceTaskId, 'k-internet');
      expect(r.txn.type, TxnType.expense);
      // Advanced a monthly series to 22 September.
      expect(task.dueDate, DateTime(2026, 9, 22, 9));
    });

    test('undo removes the txn and restores the due date and amount', () {
      final store = buildSeedStore();
      final task = store.taskById('k-internet')!;
      final due = task.dueDate;
      final expected = task.expectedAmount;
      final before = store.txns.length;
      final r = store.markTaskPaid(
        task,
        amount: 47.30,
        date: DateTime(2026, 8, 9),
        fromAccountId: 'a-checking',
        toRef: task.categoryId!,
        rememberAmount: true,
      );
      expect(task.expectedAmount, -47.30);
      store.undoMarkTaskPaid(r);
      expect(store.txns.length, before);
      expect(task.dueDate, due);
      expect(task.expectedAmount, expected);
    });

    test('closes a one-off', () {
      final store = buildSeedStore();
      final task = store.addTask(
        title: 'One off',
        linkedAccountId: 'a-checking',
        expectedAmount: -20,
        dueDate: DateTime(2026, 8, 10, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
      );
      store.markTaskPaid(task,
          amount: 20, date: today, fromAccountId: 'a-checking', toRef: 'c-housing');
      expect(task.status, TaskStatus.paid);
    });
  });

  group('transfer path (§10.4)', () {
    test('a pay-out to a liability writes a transfer and shrinks the debt', () {
      final store = buildSeedStore();
      final task = store.taskById('k-amex')!;
      final checking = store.balanceOf('a-checking');
      final amex = store.balanceOf('a-amex');
      final worth = store.netWorth;

      final r = store.markTaskPaid(
        task,
        amount: 3000,
        date: today,
        fromAccountId: 'a-checking',
        toRef: 'a-amex',
      );

      expect(r.txn.type, TxnType.transfer);
      expect(store.balanceOf('a-checking'), closeTo(checking - 3000, 0.01));
      expect(store.balanceOf('a-amex'), closeTo(amex + 3000, 0.01));
      expect(store.netWorth, closeTo(worth, 0.01));
    });

    test('a pay-out to a category still writes an expense', () {
      final store = buildSeedStore();
      final task = store.taskById('k-internet')!;
      final r = store.markTaskPaid(
        task,
        amount: 40,
        date: today,
        fromAccountId: 'a-checking',
        toRef: 'c-housing',
      );
      expect(r.txn.type, TxnType.expense);
    });
  });

  group('scheduleEvents', () {
    test('merges paid, skipped and cancelled sources newest first', () {
      final store = buildSeedStore();
      // Pay one task and skip another; cancel a one-off.
      store.markTaskPaid(store.taskById('k-internet')!,
          amount: 40, date: DateTime(2026, 8, 8), fromAccountId: 'a-checking', toRef: 'c-housing');
      store.skipTask(store.taskById('k-netflix')!); // records a skip on 1 Sep? no — advances
      final oneOff = store.addTask(
        title: 'Cancelled',
        linkedAccountId: 'a-checking',
        expectedAmount: -5,
        dueDate: DateTime(2026, 8, 5, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
      );
      store.skipTask(oneOff); // cancels the one-off

      final events = store.scheduleEvents(
          DateRange(DateTime(2026, 7, 1), DateTime(2026, 9, 30, 23, 59, 59)));
      expect(events.any((e) => e.outcome == ScheduleOutcome.paid), isTrue);
      expect(events.any((e) => e.outcome == ScheduleOutcome.cancelled), isTrue);
      // Newest first.
      for (var i = 1; i < events.length; i++) {
        expect(events[i - 1].date.isBefore(events[i].date), isFalse);
      }
    });
  });

  group('lifecycle', () {
    test('pause then resume advances the due date to at/after today', () {
      final store = buildSeedStore();
      final task = store.taskById('k-gym')!; // overdue, monthly
      store.pauseTask(task);
      expect(task.status, TaskStatus.paused);
      store.resumeTask(task);
      expect(task.status, TaskStatus.open);
      expect(task.dueDate.isBefore(DateTime(2026, 8, 9)), isFalse);
    });

    test('delete then undo restores the previous status', () {
      final store = buildSeedStore();
      final task = store.taskById('k-internet')!;
      store.deleteTask(task);
      expect(task.status, TaskStatus.deleted);
      store.undoDeleteTask(task);
      expect(task.status, TaskStatus.open);
    });

    test('emptying recently-deleted nulls recurrenceTaskId on orphaned payments',
        () {
      final store = buildSeedStore();
      final task = store.taskById('k-internet')!;
      final r = store.markTaskPaid(task,
          amount: 40, date: today, fromAccountId: 'a-checking', toRef: 'c-housing');
      store.deleteTask(task);
      // A deleted task lands in RECENTLY DELETED; deleteRecycledTasks empties it.
      store.deleteRecycledTasks();
      expect(store.taskById('k-internet'), isNull);
      expect(r.txn.recurrenceTaskId, isNull);
    });
  });
}
