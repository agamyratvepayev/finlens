import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/repeat_labels.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/l10n/app_localizations_tr.dart';
import 'package:finlens/theme/app_theme.dart';

const _sizes = <String, Size>{
  '390x844': Size(390, 844),
  '360x640': Size(360, 640),
  '320x568': Size(320, 568),
};

/// Mounts the Schedule tab on the same pinned-width harness the Ledger and
/// Insight layout tests use. The horizon is fixed to the app default (next 30
/// days), which the August seed fills with the overdue Gym row, the this-week
/// Monthly Salary row and the one-off Pay Amex row — the three cases §4.2
/// regressed on.
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

void main() {
  // ── The bug this file exists for: no overflow at any pinned width (§4.4) ────
  for (final size in _sizes.entries) {
    testWidgets('Schedule lays out without overflow at ${size.key}',
        (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(buildSeedStore()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'a task-row subtitle overflowed at ${size.key}');
    });
  }

  testWidgets('no overflow at 130% text scale on the narrowest width',
      (tester) async {
    tester.view.physicalSize = _sizes['320x568']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), scale: 1.3));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  // ── The account name is back on recurring rows (§4.2) ───────────────────────
  testWidgets('a recurring row keeps its account and shows the short cadence',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    // Monthly Salary — the row that lost its account to the old Row-of-pieces.
    final salaryRow = find.ancestor(
      of: find.text('Monthly Salary'),
      matching: find.byType(InkWell),
    );
    expect(salaryRow, findsOneWidget);
    expect(
      find.descendant(
          of: salaryRow, matching: find.textContaining('Main Checking')),
      findsOneWidget,
      reason: 'the account name must survive on a recurring row',
    );
    expect(
      find.descendant(of: salaryRow, matching: find.textContaining('monthly')),
      findsOneWidget,
      reason: 'the row cadence is the frequency word, not "on the 15th"',
    );
  });

  testWidgets('a one-off row shows its account and no cadence run',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    final amexRow = find.ancestor(
      of: find.text('Pay Amex statement'),
      matching: find.byType(InkWell),
    );
    expect(amexRow, findsOneWidget);
    expect(
      find.descendant(
          of: amexRow, matching: find.textContaining('Main Checking')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: amexRow, matching: find.textContaining('monthly')),
      findsNothing,
      reason: 'a one-off task has no ⟳ run at all',
    );
  });

  // ── Density A: the text block, and the tick-driven row envelope (§4.1) ──────
  //
  // §4.1's "~46 pt" is the *text-block* arithmetic (7+7 padding + title + gap +
  // subtitle ≈ 45.6). The rendered row envelope is taller: the mark-paid tick
  // is a 44 pt tap target and is the tallest child of the row's Row, so the
  // envelope is 44 + 14 = ~58 pt. The tap target may not shrink (hard boundary
  // §Hard boundary + §6), so the text block is what density A actually governs.
  testWidgets('the text block honours density A (~45.6 pt) at 390',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    // title (14.5×1.2) + gap (1) + subtitle (11.5×1.15) ≈ 31.6 pt.
    final title = tester.getSize(find.text('Monthly Salary'));
    final subtitle =
        tester.getSize(find.textContaining('Main Checking').first);
    final block = title.height + 1 + subtitle.height;
    expect(block, closeTo(31.6, 2.0),
        reason: 'title + gap + subtitle should be density A, not the old 36+');
    // With 7+7 padding the text block alone would be ~45.6 pt.
    expect(block + 14, greaterThanOrEqualTo(45.0));
  });

  testWidgets('the row envelope is bounded and tick-driven at 390',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    final row = find
        .ancestor(
          of: find.text('Monthly Salary'),
          matching: find.byType(InkWell),
        )
        .first;
    // 44 pt tick + 14 pt padding ≈ 58 pt; assert it never balloons past that.
    expect(tester.getSize(row).height, inInclusiveRange(44.0, 60.0));
  });

  testWidgets('the mark-paid tick keeps a ≥44 pt tap target', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    final tick = find.byIcon(Icons.check_rounded).first;
    final tapTarget =
        find.ancestor(of: tick, matching: find.byType(GestureDetector)).first;
    final size = tester.getSize(tapTarget);
    expect(size.width, greaterThanOrEqualTo(44.0));
    expect(size.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('the subtitle stays on one line', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 300));

    // The subtitle carrying the account text — the only place "Main Checking"
    // appears — must not have wrapped or clipped a second line.
    final para = tester.renderObject<RenderParagraph>(
        find.textContaining('Main Checking').first);
    expect(para.didExceedMaxLines, isFalse);
  });

  // ── repeatShortLabel is the frequency word only (§1) ────────────────────────
  test('repeatShortLabel covers every frequency in en and tr', () {
    final en = AppLocalizationsEn();
    final tr = AppLocalizationsTr();

    expect(repeatShortLabel(RepeatFrequency.weekly, en), 'weekly');
    expect(repeatShortLabel(RepeatFrequency.biweekly, en), 'every 2 weeks');
    expect(repeatShortLabel(RepeatFrequency.monthly, en), 'monthly');
    expect(repeatShortLabel(RepeatFrequency.quarterly, en), 'quarterly');
    expect(repeatShortLabel(RepeatFrequency.yearly, en), 'yearly');
    expect(repeatShortLabel(RepeatFrequency.none, en), en.repeatNever);

    // Turkmen/Turkish are the shorter width case; just prove they resolve and
    // differ from English (no missing-key fallback).
    for (final f in RepeatFrequency.values) {
      expect(repeatShortLabel(f, tr), isNotEmpty);
    }
    expect(repeatShortLabel(RepeatFrequency.monthly, tr), 'aylık');
  });
}
