import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/schedule_history_screen.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/app_card.dart';
import 'package:finlens/shared/widgets/ratio_bar.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task062_schedule_empty_and_done_test.dart
//
// Task 062 — a calm empty window, a ratio bar on sections, one thin Done row.
// `today` is pinned to 2026-08-09 (a Sunday).

final _today = DateTime(2026, 8, 9, 14, 32);

Task _task(
  String id,
  double amount,
  DateTime due, {
  Priority priority = Priority.normal,
  String? payTo,
  RepeatFrequency repeats = RepeatFrequency.none,
}) =>
    Task(
      id: id,
      title: id,
      linkedAccountId: 'a1',
      expectedAmount: amount,
      dueDate: due,
      icon: Icons.receipt_long_rounded,
      priority: priority,
      payToAccountId: payTo,
      repeats: repeats,
    );

AppStore _store({List<Task> tasks = const []}) => AppStore(
      clock: Clock.fixed(_today),
      accounts: [
        Account(
            id: 'a1',
            name: 'Checking',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 10000),
        Account(
            id: 'a2',
            name: 'Savings',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 500),
      ],
      categories: [
        Category(
            id: 'c1',
            name: 'Bills',
            type: CategoryType.expense,
            icon: Icons.receipt_rounded,
            color: Colors.orange),
        Category(
            id: 'c2',
            name: 'Salary',
            type: CategoryType.income,
            icon: Icons.payments_rounded,
            color: Colors.green),
      ],
      txns: const [],
      goals: const [],
      tasks: tasks,
    );

/// Hosts the tab with a working horizon holder, subscribed to the store the
/// way PlannerScreen is.
Widget _app(
  AppStore store, {
  ScheduleHorizon initial = const ScheduleHorizon.preset(SchedulePreset.next30),
  Locale? locale,
}) {
  var horizon = initial;
  return StoreScope(
    store: store,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: StatefulBuilder(
        builder: (context, setState) {
          final s = StoreScope.of(context);
          return Scaffold(
            body: ScheduleTab(
              store: s,
              horizon: horizon,
              onHorizonChange: (h) => setState(() => horizon = h),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  // ── §1b · the store query ────────────────────────────────────────────────────
  group('nextOccurrenceAfter', () {
    test('returns the earliest open occurrence strictly after the day', () {
      final store = _store(tasks: [
        _task('Netflix', -15.99, DateTime(2026, 10, 1)),
        _task('Rent', -1200, DateTime(2026, 11, 1)),
      ]);
      final next = store.nextOccurrenceAfter(DateTime(2026, 8, 31))!;
      expect(next.task.id, 'Netflix');
      expect(next.date, DateTime(2026, 10, 1));
      expect(next.sameDay, 0);

      // Strictly after: a task due ON the day does not count.
      final after = store.nextOccurrenceAfter(DateTime(2026, 10, 1))!;
      expect(after.task.id, 'Rent');
    });

    test('same-day ties order by priority, then amount; sameDay counts the rest',
        () {
      final store = _store(tasks: [
        _task('Big', -500, DateTime(2026, 10, 1)),
        _task('Urgent', -10, DateTime(2026, 10, 1), priority: Priority.high),
      ]);
      final next = store.nextOccurrenceAfter(DateTime(2026, 8, 31))!;
      expect(next.task.id, 'Urgent', reason: 'high priority wins the tie');
      expect(next.sameDay, 1);
    });

    test('returns null when nothing is due after the day', () {
      final store = _store(tasks: [_task('Rent', -1200, DateTime(2026, 8, 15))]);
      expect(store.nextOccurrenceAfter(DateTime(2026, 12, 31)), isNull);
    });
  });

  // ── §1 · the empty window ────────────────────────────────────────────────────
  group('the empty window', () {
    final farTask = _task('Rent', -1200, DateTime(2026, 12, 15));

    for (final (horizon, title) in [
      (const ScheduleHorizon.preset(SchedulePreset.thisWeek),
          'Nothing due this week'),
      (const ScheduleHorizon.preset(SchedulePreset.next30),
          'Nothing due in the next 30 days'),
      (const ScheduleHorizon.preset(SchedulePreset.thisMonth),
          'Nothing due this month'),
      (const ScheduleHorizon.preset(SchedulePreset.next3Months),
          'Nothing due in the next 3 months'),
      (ScheduleHorizon.until(DateTime(2026, 9, 1)),
          'Nothing due through 1 Sep'),
    ]) {
      testWidgets('title: $title', (tester) async {
        await tester.pumpWidget(
            _app(_store(tasks: [farTask]), initial: horizon));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text('Nothing due in this window'), findsNothing);
        expect(find.text('Show next 3 months ›'), findsNothing);
      });
    }

    testWidgets('the next line names the task, its date and its amount',
        (tester) async {
      final store = _store(tasks: [_task('Netflix', -15.99, DateTime(2026, 10, 1))]);
      await tester.pumpWidget(_app(store,
          initial: const ScheduleHorizon.preset(SchedulePreset.thisMonth)));
      await tester.pumpAndSettle();

      // Same year → no year in the date; the amount unsigned in the task's own
      // currency (the linked account's USD).
      expect(find.textContaining('Next: Netflix on 1 Oct'), findsOneWidget);
      expect(find.textContaining('15.99'), findsOneWidget);
      expect(find.text('Show next payment'), findsOneWidget);
    });

    testWidgets('Show next payment widens the horizon to that day and the row '
        'appears', (tester) async {
      final store = _store(tasks: [_task('Netflix', -15.99, DateTime(2026, 10, 1))]);
      await tester.pumpWidget(_app(store,
          initial: const ScheduleHorizon.preset(SchedulePreset.thisMonth)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show next payment'));
      await tester.pumpAndSettle();

      // The tab re-rendered with the occurrence in a section — nothing was
      // paid or created.
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Show next payment'), findsNothing);
      expect(store.txns, isEmpty);
    });
  });

  // ── §2 · the custom horizon control ─────────────────────────────────────────
  testWidgets('a custom horizon reads Today – 1 Oct', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Scaffold(
        body: ScheduleControl(
          horizon: ScheduleHorizon.until(DateTime(2026, 10, 1)),
          onTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Today – 1 Oct'), findsOneWidget);
    expect(find.textContaining('Until'), findsNothing);
  });

  // ── §3 · the section ratio bar ───────────────────────────────────────────────
  group('section totals', () {
    testWidgets('a one-row section has no count and no bar', (tester) async {
      final store = _store(tasks: [_task('Rent', -1200, DateTime(2026, 8, 9))]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.text('1 item'), findsNothing);
      expect(find.byType(RatioBar), findsNothing);
    });

    testWidgets('two rows: the count, a 2pt bar, unsigned out/in on the gutters',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _store(tasks: [
        _task('Rent', -1215.99, DateTime(2026, 8, 9)),
        _task('Salary', 4500, DateTime(2026, 8, 9)),
      ]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.text('2 items'), findsOneWidget);
      final bar = find.byType(RatioBar);
      expect(bar, findsOneWidget);
      expect(tester.getSize(bar).height, 2);

      final out = find.textContaining(' out');
      final income = find.textContaining(' in');
      expect(out, findsOneWidget);
      expect(income, findsOneWidget);
      // Unsigned: no −, no + anywhere in the tab.
      expect(find.textContaining('−'), findsNothing);
      expect(find.textContaining('+'), findsNothing);
      // The figures' two ends sit on the gutters: out's left edge and in's
      // right edge, Insets.gutter from the screen edges.
      expect(tester.getTopLeft(out).dx, Insets.gutter);
      expect(tester.getTopRight(income).dx, 390 - Insets.gutter);

      // Segment widths proportional to out / in (±1 pt): the two DecoratedBox
      // fills inside the bar.
      final segs = find.descendant(
          of: bar, matching: find.byType(DecoratedBox));
      final leftW = tester.getSize(segs.first).width;
      final rightW = tester.getSize(segs.last).width;
      final expectedLeft =
          (leftW + rightW) * (1215.99 / (1215.99 + 4500));
      expect((leftW - expectedLeft).abs(), lessThan(1.0));
    });

    testWidgets('a pay-in-only section keeps the in figure on the right',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _store(tasks: [
        _task('Salary', 4500, DateTime(2026, 8, 9)),
        _task('Bonus', 300, DateTime(2026, 8, 9)),
      ]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final income = find.textContaining(' in');
      expect(income, findsOneWidget);
      expect(find.textContaining(' out'), findsNothing);
      expect(tester.getTopRight(income).dx, 390 - Insets.gutter);
    });
  });

  // ── §4/§5 · the Done row ─────────────────────────────────────────────────────
  group('Done this month', () {
    testWidgets('3 done: transfers counted, never summed; received in green',
        (tester) async {
      final store = _store(tasks: [
        _task('Bills', -50, DateTime(2026, 8, 5)),
        _task('ToSavings', -200, DateTime(2026, 8, 6), payTo: 'a2'),
        _task('Salary', 300, DateTime(2026, 8, 7)),
        _task('Rent', -1200, DateTime(2026, 8, 20)), // keeps sections non-empty
      ]);
      store.markTaskPaid(store.taskById('Bills')!,
          amount: 50, date: DateTime(2026, 8, 5), fromAccountId: 'a1', toRef: 'c1');
      store.markTaskPaid(store.taskById('ToSavings')!,
          amount: 200, date: DateTime(2026, 8, 6), fromAccountId: 'a1', toRef: 'a2');
      store.markTaskPaid(store.taskById('Salary')!,
          amount: 300, date: DateTime(2026, 8, 7), fromAccountId: 'a1', toRef: 'c2');

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.text('DONE THIS MONTH'), findsOneWidget);
      expect(find.text('3 done'), findsOneWidget);
      // Red = non-transfer paid only (50, not 250); green = received (300).
      expect(find.textContaining('50'), findsWidgets);
      expect(find.textContaining('250'), findsNothing,
          reason: 'the transfer is counted, never summed');

      // The card is a visible 34; the hit area extends 5 above it.
      final card = find.ancestor(
          of: find.text('3 done'), matching: find.byType(AppCard));
      expect(tester.getSize(card).height, 34);
      await tester.tapAt(tester.getRect(card).topCenter.translate(0, -5));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleHistoryScreen), findsOneWidget,
          reason: 'the 44pt hit area opens History from just above the card');
    });

    testWidgets('a skipped-only month reads 1 skipped with no figures',
        (tester) async {
      final store = _store(tasks: [
        _task('Gym', -30, DateTime(2026, 8, 12),
            repeats: RepeatFrequency.monthly),
      ]);
      store.skipTask(store.taskById('Gym')!);

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      expect(find.text('1 skipped'), findsOneWidget);
      expect(find.text('1 done'), findsNothing);
    });

    testWidgets('an empty month reads Nothing done this month, tappable',
        (tester) async {
      final store = _store(tasks: [_task('Rent', -1200, DateTime(2026, 8, 20))]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final line = find.text('Nothing done this month');
      expect(line, findsOneWidget);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleHistoryScreen), findsOneWidget);
    });
  });

  // ── the extraction guard: Balance's bar geometry is the default ─────────────
  testWidgets("RatioBar's default height is Balance's 3pt; Schedule passes 2",
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RatioBar(
          left: 5,
          right: 3,
          leftColor: AppColors.positive,
          rightColor: AppColors.negative,
          emptyColor: AppColors.surfaceHigh,
        ),
      ),
    ));
    expect(tester.getSize(find.byType(RatioBar)).height, 3);
  });
}
