import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// Part A — the amount rises onto the title's line and the subtitle runs the
/// full column width. `flutter test` hangs on the dev machine — written, not run
/// there; verify with `flutter analyze`.
///
/// Seed facts these tests lean on (today = 9 Aug 2026):
///   • Gym Subscription — overdue by 2 days (due 7 Aug), monthly, Main Checking.
///   • Monthly Salary   — this week, monthly, Main Checking (not overdue).
Widget _app(
  AppStore store, {
  Locale locale = const Locale('en'),
  double scale = 1.0,
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: ScheduleTab(
                store: store,
                horizon: const ScheduleHorizon.preset(SchedulePreset.next30),
                onHorizonChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget app, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _rowOf(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

void main() {
  const w393 = Size(393, 852);
  const w320 = Size(320, 568);

  // ── The row does not get taller (§A · acceptance) ───────────────────────────
  // The tick's 44 pt tap target still governs; with 7+7 padding the envelope is
  // ~58 pt. Moving the amount into the column changes no height — this asserts
  // the concrete number so a regression that grows the row fails here.
  testWidgets('the row envelope stays tick-driven at ~58 pt', (tester) async {
    await _pump(tester, _app(buildSeedStore()), w393);
    expect(tester.getSize(_rowOf('Monthly Salary')).height,
        inInclusiveRange(56.0, 60.0));
  });

  // ── The subtitle now spans further than the title (§A · acceptance) ─────────
  // The title is Expanded, so it measures the column minus the amount and its
  // gap; the subtitle measures the whole column. The subtitle must be wider —
  // that gap is exactly the width the amount used to steal from line two.
  testWidgets('the subtitle spans wider than the title line', (tester) async {
    await _pump(tester, _app(buildSeedStore()), w393);
    final row = _rowOf('Gym Subscription');
    final titleW = tester.getSize(find.text('Gym Subscription')).width;
    final subtitleW = tester
        .getSize(find.descendant(
            of: row, matching: find.textContaining('Main Checking')))
        .width;
    expect(subtitleW, greaterThan(titleW),
        reason: 'the subtitle should run past the title into the amount\'s '
            'old width');
  });

  // ── A long account name + monthly cadence render whole at 393 (§A2) ─────────
  testWidgets('account + monthly cadence render whole at 393', (tester) async {
    await _pump(tester, _app(buildSeedStore()), w393);
    final row = _rowOf('Monthly Salary');
    final subtitle = find.descendant(
        of: row, matching: find.textContaining('Main Checking'));
    expect(subtitle, findsOneWidget);
    expect(
        find.descendant(of: row, matching: find.textContaining('monthly')),
        findsOneWidget);
    final para = tester.renderObject<RenderParagraph>(subtitle);
    expect(para.didExceedMaxLines, isFalse,
        reason: 'both the account and the cadence must fit on one line');
  });

  // ── A masked amount renders whole; the title yields (§A5) ───────────────────
  testWidgets('a masked amount renders whole', (tester) async {
    final store = buildSeedStore()..toggleMasked();
    await _pump(tester, _app(store), w393);
    // money(masked) → "$••••"; the masked figure must render, not ellipsise.
    expect(find.textContaining('••••').first, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── "2 days late" becomes "2 days" (§A3), en and tr ─────────────────────────
  testWidgets('an overdue subtitle carries the count but not "late" (en)',
      (tester) async {
    await _pump(tester, _app(buildSeedStore()), w393);
    final subtitle = find.descendant(
        of: _rowOf('Gym Subscription'),
        matching: find.textContaining('Main Checking'));
    final text = tester.widget<Text>(subtitle);
    final rendered = text.textSpan!.toPlainText();
    expect(rendered, contains('2 days'));
    expect(rendered, isNot(contains('late')));
  });

  testWidgets('an overdue subtitle carries the count but not "gecikmiş" (tr)',
      (tester) async {
    await _pump(
        tester, _app(buildSeedStore(), locale: const Locale('tr')), w393);
    final subtitle = find.descendant(
        of: _rowOf('Gym Subscription'),
        matching: find.textContaining('Main Checking'));
    final rendered = tester.widget<Text>(subtitle).textSpan!.toPlainText();
    expect(rendered, contains('2 gün'));
    expect(rendered, isNot(contains('gecikmiş')));
  });

  // ── The screen reader keeps the full "late" wording (§A4) ───────────────────
  testWidgets('an overdue task announces the full "late" phrase; a non-overdue '
      'one does not', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await _pump(tester, _app(buildSeedStore()), w393);

    // Overdue Gym — its container semantics must carry "2 days late".
    expect(find.bySemanticsLabel(RegExp(r'Gym Subscription.*2 days late')),
        findsOneWidget);
    // Non-overdue Salary — no "late" anywhere in its label.
    expect(find.bySemanticsLabel(RegExp(r'Monthly Salary.*late')),
        findsNothing);
  });

  // ── The tightest case: 320 pt, tr, overdue row — no overflow (§A5) ──────────
  testWidgets('no overflow on the overdue row at 320 pt in tr', (tester) async {
    await _pump(
        tester, _app(buildSeedStore(), locale: const Locale('tr')), w320);
    expect(tester.takeException(), isNull);
  });
}
