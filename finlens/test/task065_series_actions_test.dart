import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/features/planner/task_detail_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 065 — Pause · Archive · Delete, one meaning each. `flutter test` hangs
// on the author's machine, so these are written, not run here; verify with
// `flutter analyze` and run the file yourself:
//   flutter test test/task065_series_actions_test.dart
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
            currency: 'TMT',
            startingBalance: 100000),
      ],
      categories: [
        Category(
            id: 'sal',
            name: 'Salary',
            type: CategoryType.income,
            icon: Icons.payments_rounded,
            color: Colors.green),
      ],
      txns: txns,
      goals: const [],
      tasks: tasks,
    );

Task _monthly({int? endCount, DateTime? due}) => Task(
      id: 't1',
      title: 'Salary',
      linkedAccountId: 'a1',
      expectedAmount: 20000,
      dueDate: due ?? _d(2026, 9, 15),
      icon: Icons.payments_rounded,
      categoryId: 'sal',
      repeats: RepeatFrequency.monthly,
      daysOfMonth: const {15},
      repeatEndCount: endCount,
    );

/// Records [n] payments against t1, advancing the series each time (as
/// mark-paid does), so the task ends with [n] linked Ledger entries.
void _recordPayments(AppStore store, int n) {
  for (var i = 0; i < n; i++) {
    final t = store.taskById('t1')!;
    store.markTaskPaid(t,
        amount: 20000,
        date: t.dueDate,
        fromAccountId: 'a1',
        toRef: 'sal');
  }
}

Widget _host(AppStore store, {Widget? home}) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            StoreScope.of(context);
            return home ?? const TaskDetailScreen(taskId: 't1');
          },
        ),
      ),
    );

void main() {
  // ── §1/§2 · persistence and store ──────────────────────────────────────────
  group('archived status', () {
    test('round-trips through the mapper by name', () {
      final t = _monthly();
      t
        ..status = TaskStatus.archived
        ..statusChangedAt = _d(2026, 9, 26);
      final map = taskToMap(t);
      expect(map['status_name'], 'archived');
      expect(taskFromMap(map).status, TaskStatus.archived);
    });

    test('an unknown status name falls back to open, never crashes', () {
      final map = taskToMap(_monthly())..['status_name'] = 'no_such_status';
      expect(taskFromMap(map).status, TaskStatus.open);
    });

    test('archiveTask ends the series and keeps it off the Schedule', () {
      final store = _store(tasks: [_monthly()]);
      store.archiveTask(store.taskById('t1')!);
      expect(store.taskById('t1')!.status, TaskStatus.archived);
      // Off the Schedule and the forecast: every reader filters to `open`.
      expect(store.openTasks, isEmpty);
      expect(store.overdueTasks, isEmpty);
      expect(store.archivedTasks.map((t) => t.id), ['t1']);
    });

    test('restoreTask returns it to open at the first occurrence ≥ today', () {
      // Due in the past; archive then restore should advance to ≥ today.
      final store = _store(tasks: [_monthly(due: _d(2026, 6, 15))]);
      store.archiveTask(store.taskById('t1')!);
      store.restoreTask(store.taskById('t1')!);
      final t = store.taskById('t1')!;
      expect(t.status, TaskStatus.open);
      expect(t.dueDate.isBefore(_d(2026, 8, 9)), isFalse);
    });
  });

  // ── §3 · delete for good + undo, and no Ledger effect ──────────────────────
  group('delete for good', () {
    test('purges the task, unlinks its Ledger rows, leaves balances', () {
      final store = _store(tasks: [_monthly()]);
      _recordPayments(store, 2);
      final txnCountBefore = store.txns.length;
      final balBefore = store.balanceOf('a1');

      final snapshot = store.deleteTaskForGood(store.taskById('t1')!);
      expect(store.taskById('t1'), isNull);
      // The Ledger keeps every row; only the recurrence link is nulled.
      expect(store.txns.length, txnCountBefore);
      expect(store.txns.where((t) => t.recurrenceTaskId == 't1'), isEmpty);
      expect(store.balanceOf('a1'), balBefore);

      // Undo re-inserts the task identically and re-links its rows.
      store.undoDeleteForGood(snapshot);
      expect(store.taskById('t1'), isNotNull);
      expect(store.txns.where((t) => t.recurrenceTaskId == 't1').length, 2);
    });
  });

  // ── §4c · clearing FINISHED purges archived series ─────────────────────────
  test('clearFinished purges archived series', () {
    final store = _store(tasks: [_monthly()]);
    store.archiveTask(store.taskById('t1')!);
    store.clearFinished();
    expect(store.taskById('t1'), isNull);
  });

  // ── §6 · skip is undoable ──────────────────────────────────────────────────
  group('skip undo', () {
    test('recurring: undo restores the due date and drops the skipped date', () {
      final store = _store(tasks: [_monthly()]);
      final t = store.taskById('t1')!;
      final due = t.dueDate;
      final skip = store.skipTask(t);
      expect(t.dueDate.isAfter(due), isTrue);
      expect(t.skippedDates, contains(due));

      store.undoSkipTask(skip);
      expect(t.dueDate, due);
      expect(t.skippedDates, isEmpty);
    });

    test('one-off: undo restores the open status', () {
      final store = _store(tasks: [
        Task(
          id: 't1',
          title: 'Gift',
          linkedAccountId: 'a1',
          expectedAmount: 50,
          dueDate: _d(2026, 9, 1),
          icon: Icons.card_giftcard_rounded,
        ),
      ]);
      final t = store.taskById('t1')!;
      final skip = store.skipTask(t);
      expect(t.status, TaskStatus.skipped);
      store.undoSkipTask(skip);
      expect(t.status, TaskStatus.open);
    });
  });

  // ── no action touches the Ledger ───────────────────────────────────────────
  test('archive/restore/skip never create, edit or delete a transaction', () {
    final store = _store(tasks: [_monthly()]);
    _recordPayments(store, 1);
    final before = store.txns.length;
    final t = store.taskById('t1')!;
    store.archiveTask(t);
    store.restoreTask(t);
    final skip = store.skipTask(t);
    store.undoSkipTask(skip);
    expect(store.txns.length, before);
  });

  // ── §2 · the menu ──────────────────────────────────────────────────────────
  group('the ••• menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('reads Edit, Pause, Archive, Delete — and no Skip',
        (tester) async {
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Skip this one'), findsNothing);
    });

    testWidgets('a series with no history: Delete is enabled and red',
        (tester) async {
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('Removes this scheduled item.'), findsOneWidget);
      // Tapping it opens the confirm sheet.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Salary?'), findsOneWidget);
    });

    testWidgets('a series with history: Delete is dim, inert and explains why',
        (tester) async {
      final store = _store(tasks: [_monthly()]);
      _recordPayments(store, 5);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(
          find.text(
              'It has 5 done. Archive it first, then delete it from the Archive.'),
          findsOneWidget);
      // It is drawn dim (§2b) — the whole row at 40% opacity — and inert.
      final dim = find.ancestor(
          of: find.text('Delete'), matching: find.byType(Opacity));
      expect(dim, findsOneWidget);
      expect(tester.widget<Opacity>(dim).opacity, 0.4);

      // Tapping does nothing: no confirm sheet, the menu stays.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Salary?'), findsNothing);
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('a paused item shows Resume in Pause\'s place', (tester) async {
      final store = _store(tasks: [_monthly()]);
      store.pauseTask(store.taskById('t1')!);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('Resume'), findsWidgets);
      expect(find.text('Pause'), findsNothing);
    });
  });

  // ── §5 · the archived detail ───────────────────────────────────────────────
  group('archived detail', () {
    testWidgets('banner, no Upcoming, no •••, Restore + Delete for good',
        (tester) async {
      final store = _store(tasks: [_monthly()]);
      _recordPayments(store, 5);
      store.archiveTask(store.taskById('t1')!);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('Archived on'), findsOneWidget);
      expect(find.text('UPCOMING'), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete for good'), findsOneWidget);
      expect(find.textContaining('Continues from'), findsOneWidget);
    });

    testWidgets('Restore returns it to the Schedule at the first occurrence',
        (tester) async {
      final store = _store(tasks: [_monthly(due: _d(2026, 6, 15))]);
      store.archiveTask(store.taskById('t1')!);
      await tester.pumpWidget(_host(store,
          home: const _Nav(child: TaskDetailScreen(taskId: 't1'))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      final t = store.taskById('t1')!;
      expect(t.status, TaskStatus.open);
      expect(t.dueDate.isBefore(_d(2026, 8, 9)), isFalse);
    });
  });

  // ── the Archive lists an archived series under FINISHED ─────────────────────
  testWidgets('an archived series appears under FINISHED with its line',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = _store(tasks: [_monthly()]);
    _recordPayments(store, 5);
    store.archiveTask(store.taskById('t1')!);

    await tester.pumpWidget(_host(store, home: const ArchiveScreen()));
    await tester.pumpAndSettle();

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.arGroupFinished.toUpperCase()), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.textContaining('archived'), findsWidgets);
  });
}

/// A minimal route host so Restore's `Navigator.pop` has somewhere to go.
class _Nav extends StatelessWidget {
  const _Nav({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
      );
}
