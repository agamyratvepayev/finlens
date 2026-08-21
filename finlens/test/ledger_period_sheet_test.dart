import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/theme/app_theme.dart';

/// Widget tests for the Ledger tab's Period sheet and range-lens header,
/// driven through the real [LedgerScreen] against the shipped seed (which spans
/// Sep 2025 – Aug 2026, today pinned 9 Aug 2026).

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: LedgerScreen()),
      ),
    );

/// The strip's horizontal scroll view (the only [ShaderMask] on the page).
Finder get _strip => find.descendant(
      of: find.byType(ShaderMask),
      matching: find.byType(Scrollable),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpLedger(WidgetTester tester, AppStore store) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
  }

  testWidgets('title tap opens the PERIOD sheet on the current year', (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);

    expect(find.text('August 2026'), findsOneWidget); // the title
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    expect(find.text('PERIOD'), findsOneWidget);
    expect(find.text('Custom range…'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget); // year stepper
    expect(find.text('Aug'), findsOneWidget); // the selected month chip
  });

  testWidgets('year stepper bounds: › off at the current year, ‹ off at 2025',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    // At 2026 (the current year) forward is absent; back is available.
    expect(find.bySemanticsLabel('Next year'), findsNothing);
    expect(find.bySemanticsLabel('Previous year'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Previous year'));
    await t.pumpAndSettle();

    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    // 2025 is the earliest year with data → back is now absent, forward present.
    expect(find.bySemanticsLabel('Previous year'), findsNothing);
    expect(find.bySemanticsLabel('Next year'), findsOneWidget);
  });

  testWidgets('tapping an empty 2025 month navigates there and shows empty',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    await t.tap(find.bySemanticsLabel('Previous year')); // → 2025
    await t.pumpAndSettle();

    // Stepping back lands near December; scroll to the start to reach Feb.
    await t.drag(_strip, const Offset(700, 0));
    await t.pumpAndSettle();

    await t.tap(find.text('Feb')); // Feb 2025 has no data but is selectable
    await t.pumpAndSettle();

    expect(find.text('February 2025'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(store.isRangeLensActive, isFalse);
  });

  testWidgets('a future month chip is inert', (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    // Reveal Sep–Dec 2026 (future) and tap October.
    await t.drag(_strip, const Offset(-300, 0));
    await t.pumpAndSettle();

    await t.tap(find.text('Oct'), warnIfMissed: false);
    await t.pumpAndSettle();

    // Nothing happened: still on the sheet, still August, no lens.
    expect(find.text('PERIOD'), findsOneWidget);
    expect(store.period, DateTime(2026, 8));
    expect(store.isRangeLensActive, isFalse);
  });

  testWidgets('custom range applies as a lens with a purple title + subtitle',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    await t.tap(find.text('Custom range…'));
    await t.pumpAndSettle();

    expect(find.text('CUSTOM RANGE'), findsOneWidget);
    // Seeded today−3 … today = 6–9 Aug.
    expect(find.text('6 Aug'), findsOneWidget);
    expect(find.text('9 Aug'), findsOneWidget);

    await t.tap(find.textContaining('Apply · '));
    await t.pumpAndSettle();

    // The lens is active; the header reads the range in purple with a subtitle.
    expect(store.isRangeLensActive, isTrue);
    expect(find.text('6–9 Aug'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
  });

  testWidgets('reopening during a lens shows the calendar pre-filled', (t) async {
    final store = buildSeedStore();
    store.applyRangeLens(
        DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59, 999)));
    await pumpLedger(t, store);

    expect(find.text('6–9 Aug'), findsOneWidget);
    await t.tap(find.text('6–9 Aug')); // the lens title
    await t.pumpAndSettle();

    // Opens straight onto the calendar page, pre-filled with the active range.
    expect(find.text('CUSTOM RANGE'), findsOneWidget);
    expect(find.text('6 Aug'), findsOneWidget);
    expect(find.text('9 Aug'), findsOneWidget);
  });

  testWidgets('an active filter resets when a range applies (same path)',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);

    // Turn on a direction filter through the filter sheet.
    await t.tap(find.byIcon(Icons.filter_alt_outlined));
    await t.pumpAndSettle();
    await t.tap(find.text('Expenses'));
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget); // active

    // Applying a lens changes the window → the filter resets, same as a month
    // change would.
    store.applyRangeLens(
        DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59, 999)));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget); // reset
    expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);
  });

  testWidgets('a swipe during a lens clears it, leaving period at August 2026',
      (t) async {
    final store = buildSeedStore();
    store.applyRangeLens(
        DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59, 999)));
    await pumpLedger(t, store);
    expect(find.text('6–9 Aug'), findsOneWidget);

    // The header swipe funnels through shiftPeriod; a lens exit leaves `period`
    // untouched (here already August 2026) rather than jumping to today.
    store.shiftPeriod(-1);
    await t.pumpAndSettle();

    expect(store.isRangeLensActive, isFalse);
    expect(store.period, DateTime(2026, 8));
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('the × renders only while a lens is active and clears it (§1)',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);

    // Month mode: no clear affordance, white month title.
    expect(find.bySemanticsLabel('Clear custom range'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('August 2026'), findsOneWidget);

    store.applyRangeLens(
        DateRange(DateTime(2026, 8, 2), DateTime(2026, 8, 6, 23, 59, 59, 999)));
    await t.pumpAndSettle();

    // Lens mode: the range title + subtitle, and a × beside the eye.
    expect(find.text('2–6 Aug'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Clear custom range'));
    await t.pumpAndSettle();

    // Back to August 2026: title white, subtitle and × gone.
    expect(store.isRangeLensActive, isFalse);
    expect(store.period, DateTime(2026, 8));
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('5 days'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('the Period sheet custom row reflects the applied lens (§2)',
      (t) async {
    final store = buildSeedStore();
    store.applyRangeLens(
        DateRange(DateTime(2026, 8, 2), DateTime(2026, 8, 6, 23, 59, 59, 999)));
    await pumpLedger(t, store);

    // Tapping the purple title opens on the calendar; step back to the period
    // page and the custom row states what is applied, with a checkmark.
    await t.tap(find.text('2–6 Aug').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Period')); // ‹ Period
    await t.pumpAndSettle();

    expect(find.text('Custom range…'), findsNothing);
    // Scope to the custom row (the one Row holding the calendar-today glyph):
    // the header title behind the sheet also reads '2–6 Aug'.
    final customRow = find.ancestor(
      of: find.byIcon(Icons.calendar_today_rounded),
      matching: find.byType(Row),
    );
    expect(find.descendant(of: customRow, matching: find.text('2–6 Aug')),
        findsOneWidget);
    expect(
        find.descendant(
            of: customRow, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);
  });

  testWidgets('with no lens the custom row reads "Custom range…" (§2)',
      (t) async {
    final store = buildSeedStore();
    await pumpLedger(t, store);
    await t.tap(find.text('August 2026'));
    await t.pumpAndSettle();

    expect(find.text('Custom range…'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('lens header (3 buttons + long label) fits 320pt at 130% (§6)',
      (t) async {
    final store = buildSeedStore();
    // The longest realistic lens label — a multi-month, prior-year span.
    store.applyRangeLens(
        DateRange(DateTime(2025, 6, 1), DateTime(2025, 8, 15, 23, 59, 59, 999)));
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const Scaffold(body: LedgerScreen()),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    // Three circle buttons plus an ellipsised title, no RenderFlex overflow.
    expect(t.takeException(), isNull);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
