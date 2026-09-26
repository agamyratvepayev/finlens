import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// Part B — the completed section gets its own period control, independent of
/// the forward horizon. `flutter test` hangs on the dev machine — written, not
/// run there; verify with `flutter analyze`.
///
/// The harness subscribes to the store (StoreScope.of) exactly as PlannerScreen
/// does, so setCompletedRange's notifyListeners rebuilds the tab — without that
/// subscription only AmountText would rebuild and the header would stay stale.
Widget _app(
  AppStore store, {
  Locale locale = const Locale('en'),
  ScheduleHorizon horizon = const ScheduleHorizon.preset(SchedulePreset.next30),
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            final s = StoreScope.of(context); // subscribe → rebuild on notify
            return Scaffold(
              body: ScheduleTab(
                store: s,
                horizon: horizon,
                onHorizonChange: (_) {},
              ),
            );
          },
        ),
      ),
    );

/// Pays `k-internet` on [date], creating one completed event on that day.
void _payInternetOn(AppStore store, DateTime date) {
  store.markTaskPaid(
    store.taskById('k-internet')!,
    amount: 40,
    date: date,
    fromAccountId: 'a-checking',
    toRef: 'c-housing',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 8, 9); // 9 Aug 2026

  // ── Persistence: round-trip + preset re-resolves (§B3) ──────────────────────
  test('a preset range re-resolves against a later today; a custom range keeps '
      'its dates', () async {
    SharedPreferences.setMockInitialValues({});
    await saveScheduleCompletedRange('k', RangePreset.thisMonth.resolve(today));

    // Reopened in September: `This month` must be September, not a frozen August.
    final later = DateTime(2026, 9, 20);
    final reloaded = await loadScheduleCompletedRange('k', later);
    expect(reloaded, isNotNull);
    expect(reloaded!.preset, RangePreset.thisMonth);
    expect(reloaded.start, RangePreset.thisMonth.resolve(later).start);
    expect(reloaded.start.month, 9, reason: 'the window must not freeze');

    // A custom range persists as its two dates, no preset.
    SharedPreferences.setMockInitialValues({});
    final custom =
        DateRange(DateTime(2026, 6, 1), DateTime(2026, 6, 30, 23, 59, 59, 999));
    await saveScheduleCompletedRange('k', custom);
    final back = await loadScheduleCompletedRange('k', later);
    expect(back, isNotNull);
    expect(back!.preset, isNull);
    expect(back.start, custom.start);
    expect(back.end, custom.end);
  });

  test('nothing stored → null, so the caller keeps its default', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadScheduleCompletedRange('k', today), isNull);
  });

  // ── The default is a preset that is in the sheet (§B3) ──────────────────────
  test('the completed range defaults to This month', () {
    final store = buildSeedStore();
    expect(store.completedRange.preset, RangePreset.thisMonth);
  });

  // ── Task 062 §4: the completed header/expansion is one thin Done row ────────
  testWidgets('zero events: the Done row reads its empty line and opens History',
      (tester) async {
    // The seed has no completed events, so this month is empty.
    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pumpAndSettle();

    // The old header UI is gone.
    expect(find.text('THIS MONTH COMPLETED'), findsNothing);
    expect(find.text('Nothing completed in this period.'), findsNothing);
    expect(find.text('History ›'), findsNothing);

    expect(find.text('DONE THIS MONTH'), findsOneWidget);
    expect(find.text('Nothing done this month'), findsOneWidget);

    // The row is the tab's only way into History — never a period sheet.
    await tester.tap(find.text('Nothing done this month'));
    await tester.pumpAndSettle();
    expect(find.text("DIDN'T HAPPEN"), findsOneWidget,
        reason: 'the History screen (its summary columns) should be open');
  });

  testWidgets('one paid event: the row reads 1 done, never expands inline',
      (tester) async {
    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 8, 8)); // inside this month
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('1 done'), findsOneWidget);
    expect(find.byType(ScheduleEventRow), findsNothing,
        reason: 'the inline expansion is gone (task 062 §4)');

    // A tap opens History, where the rows now live.
    await tester.tap(find.text('1 done'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEventRow), findsWidgets);
  });

  // ── The Done row is always this month, whatever completedRange holds ────────
  testWidgets('the Done row ignores store.completedRange', (tester) async {
    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 6, 15)); // June — not this month
    store.setCompletedRange(RangePreset.last3Months.resolve(today));
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Last 3 months would see the June payment; the row must not (§4b).
    expect(find.text('Nothing done this month'), findsOneWidget);
    expect(find.text('1 done'), findsNothing);
  });

  // ── The forward horizon and the Done row are independent ────────────────────
  testWidgets('changing the forward horizon leaves the Done row alone',
      (tester) async {
    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 8, 8));
    await tester.pumpWidget(_app(store,
        horizon: const ScheduleHorizon.preset(SchedulePreset.next30)));
    await tester.pumpAndSettle();
    expect(find.text('1 done'), findsOneWidget);

    await tester.pumpWidget(_app(store,
        horizon: const ScheduleHorizon.preset(SchedulePreset.next3Months)));
    await tester.pumpAndSettle();
    expect(find.text('1 done'), findsOneWidget);
  });

  // ── 320 pt, tr — no overflow (§7) ───────────────────────────────────────────
  testWidgets('no overflow on the Done section at 320 pt in tr', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 8, 8));
    await tester.pumpWidget(_app(store, locale: const Locale('tr')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
