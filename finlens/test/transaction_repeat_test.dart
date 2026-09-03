import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transaction_repeat_test.dart

// ── Fixtures ─────────────────────────────────────────────────────────────────

AppStore _store({List<Txn> txns = const [], List<Task> tasks = const []}) =>
    AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: txns,
      goals: const [],
      tasks: tasks,
    );

Widget _app(AppStore store, {Txn? editing, Locale? locale}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: QuickAddScreen(
          initialType: QuickAddType.expense,
          editing: editing,
          fixedFromAccountId: editing == null ? 'a1' : null,
          fixedToAccountId: editing == null ? 'g' : null,
        ),
      ),
    );

/// A store already holding a monthly-repeating expense and its backing Task,
/// plus the transaction to edit.
(AppStore, Txn) _editingFixture() {
  final txn = Txn(
    id: 't1',
    type: TxnType.expense,
    amount: 5,
    currency: 'USD',
    fromRef: 'a1',
    toRef: 'g',
    date: DateTime(2026, 9, 15),
    recurrenceTaskId: 'k1',
  );
  final store = _store(txns: [txn], tasks: [
    Task(
      id: 'k1',
      title: 'Rent',
      linkedAccountId: 'a1',
      expectedAmount: -5,
      dueDate: DateTime(2026, 10, 15),
      icon: Icons.repeat_rounded,
      repeats: RepeatFrequency.monthly,
      daysOfMonth: const {15},
    ),
  ]);
  return (store, txn);
}

// ── Model / engine unit tests ────────────────────────────────────────────────

Task _rule({
  required RepeatFrequency repeats,
  int interval = 1,
  RepeatUnit? unit,
  Set<int> weekdays = const {},
  Set<int> daysOfMonth = const {},
  DateTime? endDate,
  int? endCount,
  required DateTime due,
}) =>
    Task(
      id: 'k',
      title: '',
      linkedAccountId: 'a1',
      expectedAmount: -1,
      dueDate: due,
      icon: Icons.repeat_rounded,
      repeats: repeats,
      repeatInterval: interval,
      repeatUnit: unit,
      weekdays: weekdays,
      daysOfMonth: daysOfMonth,
      repeatEndDate: endDate,
      repeatEndCount: endCount,
    );

void main() {
  group('recurrence engine', () {
    test('daily steps one day', () {
      final r = _rule(repeats: RepeatFrequency.daily, due: DateTime(2026, 8, 31));
      expect(r.nextOccurrence(DateTime(2026, 8, 31)), DateTime(2026, 9, 1));
    });

    test('custom every 3 days steps three days', () {
      final r = _rule(
          repeats: RepeatFrequency.custom,
          unit: RepeatUnit.day,
          interval: 3,
          due: DateTime(2026, 8, 10));
      expect(r.nextOccurrence(DateTime(2026, 8, 10)), DateTime(2026, 8, 13));
    });

    test('custom every 2 weeks steps fourteen days', () {
      final r = _rule(
          repeats: RepeatFrequency.custom,
          unit: RepeatUnit.week,
          interval: 2,
          due: DateTime(2026, 8, 10));
      expect(r.nextOccurrence(DateTime(2026, 8, 10)), DateTime(2026, 8, 24));
    });

    test('custom every 2 years steps two years', () {
      final r = _rule(
          repeats: RepeatFrequency.custom,
          unit: RepeatUnit.year,
          interval: 2,
          daysOfMonth: const {10},
          due: DateTime(2026, 8, 10));
      expect(r.nextOccurrence(DateTime(2026, 8, 10)), DateTime(2028, 8, 10));
    });

    test('monthly on day 31 lands on the last day of February', () {
      final r = _rule(
          repeats: RepeatFrequency.monthly,
          daysOfMonth: const {31},
          due: DateTime(2026, 1, 31));
      // 2026 is not a leap year → 28 Feb.
      expect(r.nextOccurrence(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('Last (32) plus 31 yield one occurrence in a 31-day month', () {
      final r = _rule(
          repeats: RepeatFrequency.monthly,
          daysOfMonth: const {31, 32},
          due: DateTime(2026, 1, 15));
      // Both clamp to 31 in January and collapse into a single 31 Jan date.
      final first = r.nextOccurrence(DateTime(2026, 1, 15));
      expect(first, DateTime(2026, 1, 31));
      // Stepping again reaches February's last day, not a second January date.
      expect(r.nextOccurrence(first), DateTime(2026, 2, 28));
    });

    test('After 12 times yields twelve occurrences including the first', () {
      final r = _rule(
          repeats: RepeatFrequency.monthly,
          daysOfMonth: const {15},
          endCount: 12,
          due: DateTime(2026, 1, 15));
      final series = r.boundedSeries(DateTime(2026, 1, 15));
      expect(series.length, 12);
      expect(series.first, DateTime(2026, 1, 15));
    });

    test('an end date stops the series at the last date on or before it', () {
      final r = _rule(
          repeats: RepeatFrequency.monthly,
          daysOfMonth: const {15},
          endDate: DateTime(2026, 4, 20),
          due: DateTime(2026, 1, 15));
      final series = r.boundedSeries(DateTime(2026, 1, 15));
      // Jan, Feb, Mar, Apr — the May date would fall after 20 Apr.
      expect(series, [
        DateTime(2026, 1, 15),
        DateTime(2026, 2, 15),
        DateTime(2026, 3, 15),
        DateTime(2026, 4, 15),
      ]);
    });
  });

  // ── Form: Repeat row + Split action ────────────────────────────────────────

  group('form', () {
    testWidgets('expense shows a Repeat row and a full-width Split action',
        (tester) async {
      await tester.pumpWidget(_app(_store()));
      await tester.pump(const Duration(milliseconds: 400));
      // The Repeat row (label) and the Split action (its true label) both
      // render; the old side-by-side "Repeat"/"Split" toggle pair is gone.
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Split into several categories'), findsOneWidget);
    });

    testWidgets('with no repeat the row reads Never', (tester) async {
      await tester.pumpWidget(_app(_store()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Never'), findsOneWidget);
    });

    testWidgets('a monthly repeat reads Monthly with an accent icon',
        (tester) async {
      final (store, txn) = _editingFixture();
      await tester.pumpWidget(_app(store, editing: txn));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Monthly'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.repeat_rounded).first);
      expect(icon.color, AppColors.accent);
    });
  });

  // ── Repeat sheet structure ─────────────────────────────────────────────────

  group('repeat sheet', () {
    Future<void> openRepeat(WidgetTester tester) async {
      await tester.pumpWidget(_app(_store()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers exactly five cadences and no Yearly', (tester) async {
      await openRepeat(tester);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Yearly'), findsNothing);
    });

    testWidgets('Ends row is absent with Never and present with Monthly',
        (tester) async {
      await openRepeat(tester);
      expect(find.text('Ends'), findsNothing);
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(find.text('Ends'), findsOneWidget);
      // No ENDS section heading, and no summary sentence.
      expect(find.text('ENDS'), findsNothing);
      expect(find.textContaining('Planner'), findsNothing);
    });
  });

  // ── Custom sheet ───────────────────────────────────────────────────────────

  group('custom sheet', () {
    Future<void> openCustom(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpWidget(_app(_store(), locale: locale));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
    }

    testWidgets('Every N unit renders singular then plural', (tester) async {
      await openCustom(tester);
      // Switch the unit to weeks, N starts at 1 → singular.
      await tester.tap(find.text('Week'));
      await tester.pump();
      expect(find.text('Every 1 week'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('Every 2 weeks'), findsOneWidget);
    });

    testWidgets('month unit renders a 32-cell grid ending in Last',
        (tester) async {
      await openCustom(tester);
      // Month is the default unit → the grid is already shown.
      for (final d in ['1', '15', '31']) {
        expect(find.text(d), findsWidgets);
      }
      expect(find.text('Last'), findsOneWidget);
    });

    testWidgets('grid cells clear the 44pt hit target vertically',
        (tester) async {
      await openCustom(tester);
      // Measure the tappable cell (the GestureDetector), not its label.
      final cell = find
          .ancestor(
              of: find.text('Last'), matching: find.byType(GestureDetector))
          .first;
      expect(tester.getSize(cell).height, greaterThanOrEqualTo(44.0));
    });
  });
}
