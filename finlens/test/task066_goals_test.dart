import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/planner/goal_presentation.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show CurrencyChip;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/shared/widgets/typed_date_field.dart';

// Task 066 — no forecast row, "Progress from", and a saving pace per period.
// `flutter test` hangs on the author's machine; verify with `flutter analyze`
// and run the file yourself:
//   flutter test test/task066_goals_test.dart
//
// today is pinned to 2026-08-09.

final _today = DateTime(2026, 8, 9, 14, 32);

AppStore _store() => AppStore.empty(clock: Clock.fixed(_today));

Goal _goal({GoalPace pace = GoalPace.month, DateTime? targetDate}) => Goal(
      id: 'g',
      name: 'G',
      source: const GoalSource.account('a'),
      targetAmount: 1000,
      createdAt: DateTime(2026, 1, 1),
      pace: pace,
      targetDate: targetDate,
    );

void main() {
  // ── §5a · the pace model persists ──────────────────────────────────────────
  group('pace persistence', () {
    test('round-trips through the mapper by name', () {
      final map = goalToMap(_goal(pace: GoalPace.week));
      expect(map['pace_name'], 'week');
      expect(goalFromMap(map).pace, GoalPace.week);
    });

    test('a row without the column loads as month (old goal)', () {
      final map = goalToMap(_goal())..remove('pace_name');
      expect(goalFromMap(map).pace, GoalPace.month);
    });

    test('addGoal stores the pace', () {
      final store = _store();
      final acc = store.addAccount(
          name: 'Vault',
          group: AccountGroup.setAside,
          currency: 'USD',
          startingBalance: 0);
      final g = store.addGoal(
        name: 'Trip',
        source: GoalSource.account(acc.id),
        targetAmount: 5000,
        pace: GoalPace.year,
      );
      expect(g.pace, GoalPace.year);
    });
  });

  // ── §5c · the verdict reads in the goal's period ───────────────────────────
  group('pace surfaces convert from the monthly rate', () {
    test('goalPaceRate converts a monthly figure to each period', () {
      expect(goalPaceRate(300, GoalPace.month), 300);
      expect(goalPaceRate(300, GoalPace.quarter), 900);
      expect(goalPaceRate(300, GoalPace.year), 3600);
      expect(goalPaceRate(300, GoalPace.week), closeTo(300 * 12 / 52, 0.01));
      expect(goalPaceRate(300, GoalPace.day), closeTo(300 * 12 / 365, 0.01));
    });

    test('an old (month) goal reads /mo; a weekly goal reads /wk', () {
      final l = AppLocalizationsEn();
      GoalMetrics behind(double requiredMonthly) => GoalMetrics(
            section: GoalSection.saving,
            start: 0,
            current: 100,
            target: 1000,
            targetDate: DateTime(2026, 12, 1),
            progress: 0.1,
            reached: false,
            atTarget: false,
            sourceAvailable: true,
            monthsElapsed: 0,
            monthsRemaining: 4,
            requiredRate: requiredMonthly,
            actualRate: null,
            projectedEnd: DateTime(2026, 11, 1),
            daysElapsed: 0,
            daysTotal: 120,
          );
      final month = goalVerdict(l, _goal(), behind(300), _today).text;
      expect(month, contains('/mo'));
      final week =
          goalVerdict(l, _goal(pace: GoalPace.week), behind(300), _today).text;
      expect(week, contains('/wk'));
    });
  });

  // ── §2/§3/§4/§5 · the form's rows ──────────────────────────────────────────
  Widget host(AppStore store) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditGoalScreen(),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Finder rowByLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
  Finder fieldInRow(String label) =>
      find.descendant(of: rowByLabel(label), matching: find.byType(TextField));

  testWidgets('the form reads Progress from, Choose account, Pick a date, '
      'Monthly; no caption', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(_store()));
    await tester.pumpAndSettle();

    expect(find.text('Progress from'), findsOneWidget);
    expect(find.text('Choose account'), findsOneWidget);
    expect(find.text('Pick a date'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Set either one — the other follows.'), findsNothing);
    expect(find.byType(CurrencyChip), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  // ── §5d · the period sheet changes the pace and recomputes ─────────────────
  testWidgets('choosing Weekly re-labels the pace row', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(_store()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldInRow('Target amount'), '18000');
    await tester.pump();

    // Open the pace sheet from the row's label, choose Weekly.
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week'));
    await tester.pumpAndSettle();

    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsNothing);
  });

  testWidgets('a typed date computes the weekly figure and marks it auto',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host(_store()));
    await tester.pumpAndSettle();

    await tester.enterText(fieldInRow('Target amount'), '18000');
    await tester.pump();
    // Switch to weekly first.
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week'));
    await tester.pumpAndSettle();

    // 26 weeks out: 2026-08-09 + 182 days = 2027-02-07.
    await tester.tap(find.text('Target date'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
          of: find.byType(TypedDateField), matching: find.byType(TextField)),
      '07022027',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 18,000 / 26 ≈ 692.
    expect(fieldInRow('Weekly'), findsOneWidget);
    final weekly = tester.widget<TextField>(fieldInRow('Weekly'));
    expect(weekly.controller!.text, '692');
    expect(find.text('auto'), findsOneWidget);
  });

  // ── §6 · Save always answers in creation ───────────────────────────────────
  Widget navHost(AppStore store) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const EditGoalScreen()),
          ),
        ),
      );

  testWidgets('Save with no name flashes the name blocker, creates nothing',
      (tester) async {
    phone(tester);
    final store = _store();
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Name your goal'), findsOneWidget);
    expect(store.goals, isEmpty);
  });

  testWidgets('Save names each missing field in order', (tester) async {
    phone(tester);
    final store = _store();
    store.addAccount(
        name: 'Vault',
        group: AccountGroup.setAside,
        currency: 'USD',
        startingBalance: 0);
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.descendant(
            of: find.byType(NameField), matching: find.byType(TextField)),
        'Trip');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    // Name is filled → the next missing is the source.
    expect(find.text('Choose an account'), findsOneWidget);
  });

  testWidgets('a complete goal saves and stores the date to the day',
      (tester) async {
    phone(tester);
    final store = _store();
    await tester.pumpWidget(navHost(store));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.descendant(
            of: find.byType(NameField), matching: find.byType(TextField)),
        'New Phone');
    await tester.pump();
    // New savings account source.
    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New savings account').last);
    await tester.pumpAndSettle();
    await tester.enterText(fieldInRow('Target amount'), '30000');
    await tester.pump();
    // A day-precise target date.
    await tester.tap(find.text('Target date'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
          of: find.byType(TypedDateField), matching: find.byType(TextField)),
      '17032027',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.goals, hasLength(1));
    final g = store.goals.single;
    expect(g.name, 'New Phone');
    expect(g.targetDate, isNotNull);
    expect(g.targetDate!.day, 17);
    expect(g.targetDate!.month, 3);
  });
}
