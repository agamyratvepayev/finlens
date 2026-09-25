import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/main.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 058.1 — the occurrence-based Schedule list and its tab-card summary.
/// `flutter test` hangs on the dev machine; these are written, not run there —
/// verify with `flutter analyze` and run the suite elsewhere.
void main() {
  final today = DateTime(2026, 8, 9);

  Widget app(
    AppStore store, {
    ScheduleHorizon horizon =
        const ScheduleHorizon.preset(SchedulePreset.next30),
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: ScheduleTab(
                store: StoreScope.of(context),
                horizon: horizon,
                onHorizonChange: (_) {},
              ),
            ),
          ),
        ),
      );

  // ── One row per occurrence (§1) ─────────────────────────────────────────────
  group('Task.occurrencesIn drives the list', () {
    test('a monthly series inside a 3-month window yields 3 dates, one == due',
        () {
      final task = Task(
        id: 't',
        title: 'X',
        linkedAccountId: 'a-checking',
        expectedAmount: -10,
        dueDate: DateTime(2026, 8, 22, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
        repeats: RepeatFrequency.monthly,
      );
      final occ = task.occurrencesIn(today, DateTime(2026, 11, 9));
      expect(occ.length, 3); // 22 Aug, 22 Sep, 22 Oct
      final due = DateTime(2026, 8, 22);
      expect(occ.where((d) => d == due).length, 1); // exactly one isNext
    });

    test('a one-off yields exactly one', () {
      final task = Task(
        id: 't',
        title: 'X',
        linkedAccountId: 'a-checking',
        expectedAmount: -10,
        dueDate: DateTime(2026, 8, 22, 9),
        icon: Icons.bolt_rounded,
        categoryId: 'c-housing',
      );
      expect(task.occurrencesIn(today, DateTime(2026, 11, 9)).length, 1);
    });
  });

  // ── The seed row counts per preset (§1e) ─────────────────────────────────────
  group('scheduleOccurrenceCount on the seed', () {
    int count(SchedulePreset p) => buildSeedStore()
        .scheduleOccurrenceCount(ScheduleHorizon.preset(p).range(today));
    test('this week = 3 rows', () => expect(count(SchedulePreset.thisWeek), 3));
    test('next 30 days = 7 rows', () => expect(count(SchedulePreset.next30), 7));
    test('this month = 4 rows',
        () => expect(count(SchedulePreset.thisMonth), 4));
    test('next 3 months = 17 rows',
        () => expect(count(SchedulePreset.next3Months), 17));
  });

  // ── A recurring series shows up once per occurrence in the list (§1) ─────────
  testWidgets('a monthly series renders one row per occurrence at 3 months',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(buildSeedStore(),
        horizon:
            const ScheduleHorizon.preset(SchedulePreset.next3Months)));
    await tester.pump(const Duration(milliseconds: 300));

    // Internet Bill is monthly, due 22 Aug — 22 Aug/Sep/Oct all fall in the
    // 3-month window, so it renders three times (§1).
    expect(find.text('Internet Bill'), findsNWidgets(3));
    // The check tick is gone — an empty ring only (§2b).
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  // ── The tab card's payment count equals the rows the list shows (§4a) ────────
  testWidgets('the tab card reads "7 payments" on the seed at Next 30 days',
      (tester) async {
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('7 payments'), findsOneWidget);
  });
}
