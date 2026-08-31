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
  final today = AppStore.today; // 9 Aug 2026

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

  // ── Zero items: empty lines, no chevron, link opens the sheet (§B5) ─────────
  testWidgets('zero items shows the two empty lines and no toggle',
      (tester) async {
    // The seed has no completed events, so `This month` is empty.
    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing completed in this period.'), findsOneWidget);
    expect(find.text('Choose a longer period'), findsOneWidget);
    expect(find.byType(AnimatedRotation), findsNothing,
        reason: 'no chevron when there is nothing to open');

    // The link opens the same range sheet as the header.
    await tester.tap(find.text('Choose a longer period'));
    await tester.pumpAndSettle();
    expect(find.text('Last 3 months'), findsOneWidget,
        reason: 'the shared range-picker sheet should be open');
  });

  // ── The count toggles the card open and closed (§B4) ────────────────────────
  testWidgets('the count expands and collapses the completed card',
      (tester) async {
    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 8, 8)); // inside `This month`
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.byType(ScheduleEventRow), findsNothing);

    await tester.tap(find.text('1 item'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEventRow), findsWidgets);

    await tester.tap(find.text('1 item'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleEventRow), findsNothing);
  });

  // ── Picking a preset changes both the header label and the query (§B1/B7) ───
  testWidgets('picking Last 3 months re-labels the header and re-queries',
      (tester) async {
    final store = buildSeedStore();
    _payInternetOn(store, DateTime(2026, 6, 15)); // in last-3-months, not in-month
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // `This month` sees nothing — the June payment is out of window.
    expect(find.text('THIS MONTH COMPLETED'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);

    await tester.tap(find.text('THIS MONTH COMPLETED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 3 months'));
    await tester.pumpAndSettle();

    expect(find.text('LAST 3 MONTHS COMPLETED'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget,
        reason: 'the section re-queried against the new range');
  });

  // ── The forward horizon and the completed section are independent (§B2) ─────
  testWidgets('changing the forward horizon leaves the completed section alone',
      (tester) async {
    final store = buildSeedStore();
    await tester.pumpWidget(_app(store,
        horizon: const ScheduleHorizon.preset(SchedulePreset.next30)));
    await tester.pumpAndSettle();
    expect(find.text('THIS MONTH COMPLETED'), findsOneWidget);

    // A different forward horizon — the completed header must not move.
    await tester.pumpWidget(_app(store,
        horizon: const ScheduleHorizon.preset(SchedulePreset.next3Months)));
    await tester.pumpAndSettle();
    expect(find.text('THIS MONTH COMPLETED'), findsOneWidget);
  });

  // ── 320 pt, tr, the longest label — no overflow (§B6) ───────────────────────
  testWidgets('no overflow on the header row at 320 pt in tr', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore()
      ..setCompletedRange(RangePreset.last3Months.resolve(today));
    await tester.pumpWidget(_app(store, locale: const Locale('tr')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
