import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/task_detail_screen.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 064 §A — the detail screen. `flutter test` hangs on the author's
// machine, so these are written, not run here; verify with `flutter analyze`
// and run the file yourself:
//   flutter test test/task064_detail_screen_test.dart
//
// today is pinned to 2026-08-09.

final _today = DateTime(2026, 8, 9, 14, 32);
DateTime _d(int y, int m, int day) => DateTime(y, m, day);

void _size(WidgetTester tester, [double w = 390, double h = 900]) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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
        Account(
            id: 'rhk',
            name: 'Rowshen HK',
            group: AccountGroup.receivables,
            currency: 'TMT',
            startingBalance: 0),
        Account(
            id: 'card',
            name: 'Visa Card',
            group: AccountGroup.creditCards,
            currency: 'TMT',
            startingBalance: -5000),
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

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            StoreScope.of(context); // subscribe so a write rebuilds the tree
            return const TaskDetailScreen(taskId: 't1');
          },
        ),
      ),
    );

Task _monthly({
  double amount = 20000,
  String account = 'a1',
  String? categoryId = 'sal',
  String? payTo,
  int? endCount,
  DateTime? endDate,
  Map<DateTime, double> overrides = const {},
}) =>
    Task(
      id: 't1',
      title: 'Salary',
      linkedAccountId: account,
      expectedAmount: amount,
      dueDate: _d(2026, 9, 15),
      icon: Icons.payments_rounded,
      categoryId: categoryId,
      payToAccountId: payTo,
      repeats: RepeatFrequency.monthly,
      daysOfMonth: const {15},
      repeatEndCount: endCount,
      repeatEndDate: endDate,
      amountOverrides: overrides,
    );

void main() {
  // ── §2 · the strip ─────────────────────────────────────────────────────────
  group('the strip', () {
    testWidgets('ending series: bar present, done/left, Σ remaining',
        (tester) async {
      _size(tester);
      // 14 occurrences, none done → left 14; sum = 14 × 20,000 = 280,000.
      final store = _store(tasks: [_monthly(endCount: 14)]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('14 left'), findsOneWidget);
      expect(find.textContaining('280,000'), findsOneWidget);
      expect(find.textContaining('a year'), findsNothing);
    });

    testWidgets('ending series: a raised month lifts the remaining sum',
        (tester) async {
      _size(tester);
      final store = _store(tasks: [
        _monthly(endCount: 14, overrides: {_d(2026, 12, 15): 25000}),
      ]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      // One of the 14 remaining is 25,000 → 13×20,000 + 25,000 = 285,000.
      expect(find.textContaining('285,000'), findsOneWidget);
    });

    testWidgets('never-ending series: dashed bar, done-so-far, a-year sum',
        (tester) async {
      _size(tester);
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      // Next 12 × 20,000 = 240,000 a year.
      expect(find.textContaining('a year'), findsOneWidget);
      expect(find.textContaining('240,000'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
    });

    testWidgets('one-off: a due line, no bar, no right side', (tester) async {
      _size(tester);
      final store = _store(tasks: [
        Task(
          id: 't1',
          title: 'Gift',
          linkedAccountId: 'a1',
          expectedAmount: -50,
          dueDate: _d(2026, 9, 1),
          icon: Icons.card_giftcard_rounded,
          categoryId: 'rent',
        ),
      ]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('Due · '), findsOneWidget);
      expect(find.textContaining('a year'), findsNothing);
      expect(find.textContaining('left'), findsNothing);
    });
  });

  // ── §3 · Upcoming ──────────────────────────────────────────────────────────
  group('Upcoming', () {
    testWidgets('rows carry the year, the amount and a chevron', (tester) async {
      _size(tester);
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('15 Oct 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    });

    testWidgets('a changed row is accentLight with no dot, and says no "edited"',
        (tester) async {
      _size(tester);
      final store =
          _store(tasks: [_monthly(overrides: {_d(2026, 11, 15): 25000})]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final changed = find.textContaining('25,000');
      expect(changed, findsWidgets);
      // Task 067.2 §6 — a changed amount is said in colour alone: accentLight,
      // no leading dot.
      expect(tester.widget<Text>(changed.first).style!.color,
          AppColors.accentLight);
      expect(find.textContaining('edited'), findsNothing);
    });

    testWidgets('the rule and end chips: count', (tester) async {
      _size(tester);
      final store = _store(tasks: [_monthly(endCount: 14)]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.text('Monthly · 15th'), findsOneWidget);
      expect(find.text('14 times'), findsOneWidget);
    });

    testWidgets('the rule and end chips: date', (tester) async {
      _size(tester);
      final store =
          _store(tasks: [_monthly(endDate: _d(2027, 8, 31))]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.text('Ends 31 Aug 2027'), findsOneWidget);
    });

    testWidgets('the rule and end chips: never (no end pill)', (tester) async {
      _size(tester);
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.text('Monthly · 15th'), findsOneWidget);
      expect(find.textContaining('times'), findsNothing);
      expect(find.textContaining('Ends'), findsNothing);
    });
  });

  // ── §7 · the occurrence amount sheet ───────────────────────────────────────
  group('per-occurrence amount sheet', () {
    Future<void> openRow(WidgetTester tester, String date) async {
      await tester.tap(find.text(date));
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String label) => tester.tap(
        find.descendant(
            of: find.byType(NumericKeypad), matching: find.text(label)));

    testWidgets('opens prefilled; 20000+5000 resolves to 25,000; Only changes '
        'that row alone', (tester) async {
      _size(tester, 390, 900);
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      await openRow(tester, '15 Nov 2026');
      // Prefilled with the usual 20,000.
      expect(find.textContaining('20,000'), findsWidgets);

      // 20,000 + 5,000 =
      await tapKey(tester, '+');
      await tester.pump();
      for (final k in ['5', '0', '0', '0']) {
        await tapKey(tester, k);
        await tester.pump();
      }
      expect(find.textContaining('= 25,000'), findsOneWidget);

      // Save (Only is the default).
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final t = store.taskById('t1')!;
      expect(t.amountOn(_d(2026, 11, 15)), 25000);
      expect(t.amountOn(_d(2026, 12, 15)), 20000, reason: 'only that row');
      expect(t.expectedAmount, 20000);
    });

    testWidgets('And after changes that row and the ones after it',
        (tester) async {
      _size(tester, 390, 900);
      final store = _store(tasks: [_monthly()]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      await openRow(tester, '15 Dec 2026');
      await tapKey(tester, '+');
      await tester.pump();
      for (final k in ['5', '0', '0', '0']) {
        await tapKey(tester, k);
        await tester.pump();
      }
      await tester.tap(find.textContaining('and after'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final t = store.taskById('t1')!;
      expect(t.expectedAmount, 25000);
      expect(t.amountOn(_d(2026, 12, 15)), 25000);
      expect(t.amountOn(_d(2027, 1, 15)), 25000);
      // Earlier open occurrences kept the old amount.
      expect(t.amountOn(_d(2026, 10, 15)), 20000);
    });
  });

  // ── §6 · the button and its result line ────────────────────────────────────
  group('Mark as done and the result line', () {
    Future<String> lineFor(WidgetTester tester, Task task) async {
      _size(tester);
      final store = _store(tasks: [task]);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.text('Mark as done'), findsOneWidget);
      return '';
    }

    testWidgets('pay-out from an asset: will go down by', (tester) async {
      await lineFor(
          tester,
          _monthly(amount: -20000, categoryId: 'rent'));
      expect(find.textContaining('Checking will go down by'), findsOneWidget);
    });

    testWidgets('pay-in to an asset: will go up by', (tester) async {
      await lineFor(tester, _monthly(amount: 20000, categoryId: 'sal'));
      expect(find.textContaining('Checking will go up by'), findsOneWidget);
    });

    testWidgets('receivable: will owe you … more', (tester) async {
      await lineFor(
          tester, _monthly(amount: 20000, account: 'rhk', categoryId: 'sal'));
      expect(find.textContaining('Rowshen HK will owe you'), findsOneWidget);
    });

    testWidgets('bill on a liability account: you\'ll owe … more',
        (tester) async {
      await lineFor(
          tester, _monthly(amount: -3000, account: 'card', categoryId: 'rent'));
      expect(find.textContaining("You'll owe Visa Card"), findsOneWidget);
    });

    testWidgets('pay-off transfer: debt goes down by', (tester) async {
      await lineFor(tester,
          _monthly(amount: -3000, categoryId: null, payTo: 'card'));
      expect(find.textContaining("Visa Card's debt goes down by"),
          findsOneWidget);
    });

    testWidgets('paused reads Resume, no result line', (tester) async {
      _size(tester);
      final store = _store(tasks: [_monthly()]);
      store.pauseTask(store.taskById('t1')!);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Mark as done'), findsNothing);
    });
  });

  // ── §4 · neutral history copy ──────────────────────────────────────────────
  testWidgets('empty history reads the neutral copy', (tester) async {
    _size(tester);
    final store = _store(tasks: [_monthly()]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    expect(find.text('Past ones show up here once you mark one as done.'),
        findsOneWidget);
    expect(find.textContaining('mark one as paid'), findsNothing);
  });
}
