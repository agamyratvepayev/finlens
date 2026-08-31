import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/insight/category_detail_screen.dart';
import 'package:finlens/features/insight/insight_screen.dart';
import 'package:finlens/features/insight/see_all_screen.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/section_header.dart';
import 'package:finlens/theme/app_theme.dart';

const _sizes = <String, Size>{
  '390x844': Size(390, 844),
  '360x640': Size(360, 640),
  '320x568': Size(320, 568),
};

Widget _app(
  AppStore store,
  Widget home, {
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
            child: Scaffold(body: home),
          ),
        ),
      ),
    );

DateRange _augustMonth() => RangePreset.thisMonth.resolve(AppStore.today);

void main() {
  // ── Isolation (§2, §11) ────────────────────────────────────────────────────
  testWidgets('Insight owns its window — stepping it never touches store.period '
      'or the range lens', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    final period0 = store.period;
    final lens0 = store.rangeLens;

    await tester.pumpWidget(_app(store, const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('August 2026'), findsOneWidget);

    // Swipe the header right to step back one period (forward is blocked — a
    // report of the past does not look forward).
    await tester.drag(
        find.byType(HorizontalSectionSwipe).first, const Offset(320, 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('July 2026'), findsOneWidget);
    expect(store.period, period0, reason: 'store.period must not move');
    expect(store.rangeLens, lens0, reason: 'range lens must not move');
  });

  // ── Layout: no exception at every width × scale × locale ────────────────────
  for (final size in _sizes.entries) {
    for (final scale in const [1.0, 1.3]) {
      for (final locale in const [Locale('en'), Locale('ru')]) {
        testWidgets(
            'Insight lays out at ${size.key} · ${scale}x · ${locale.languageCode}',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
              _app(buildSeedStore(), const InsightScreen(),
                  locale: locale, scale: scale));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'Category detail lays out at ${size.key} · ${scale}x · ${locale.languageCode}',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_app(
            buildSeedStore()..setInsightWindow(_augustMonth()),
            const CategoryDetailScreen(categoryId: 'c-housing'),
            locale: locale,
            scale: scale,
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'See-all lays out at ${size.key} · ${scale}x · ${locale.languageCode}',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_app(
            buildSeedStore()..setInsightWindow(_augustMonth()),
            const SeeAllScreen(income: false),
            locale: locale,
            scale: scale,
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // ── Density (§13) ───────────────────────────────────────────────────────────
  testWidgets('component heights match the §13 targets', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    double h(Key k) => tester.getSize(find.byKey(k).first).height;
    expect(h(const Key('ins-waterfall')), closeTo(92, 1));
    expect(h(const Key('ins-gridcell')), closeTo(21, 1));
    expect(h(const Key('ins-debtside')), closeTo(34, 2));
    expect(h(const Key('ins-debtmove')), closeTo(28, 2));
    expect(h(const Key('ins-revalrow')), closeTo(44, 2.5));
    expect(h(const Key('ins-foot')), closeTo(30, 1.5));
  });

  // ── No stacked bar anywhere (§6 / §15) ──────────────────────────────────────
  testWidgets('no 8pt stacked-bar strip is built on Insight or See-all',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A stacked bar was an 8pt-high ClipRRect of coloured segments at the top of
    // every card. It is gone; assert no ClipRRect renders at exactly 8pt.
    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    for (final e in find.byType(ClipRRect).evaluate()) {
      expect((e.renderObject as dynamic).size.height, isNot(closeTo(8, 0.1)));
    }

    await tester.pumpWidget(_app(
        buildSeedStore()..setInsightWindow(_augustMonth()),
        const SeeAllScreen(income: false)));
    await tester.pump(const Duration(milliseconds: 300));
    for (final e in find.byType(ClipRRect).evaluate()) {
      expect((e.renderObject as dynamic).size.height, isNot(closeTo(8, 0.1)));
    }
  });

  // ── The waterfall exposes exactly one semantic sentence (§11) ────────────────
  testWidgets('the waterfall is one semantics node naming the four figures',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // The whole chart reads as one sentence; the bars/axis are ExcludeSemantics.
    expect(find.bySemanticsLabel(RegExp(r'Net worth .* before, .* now\.')),
        findsOneWidget);
    // A group row names its direction in words, never "−\$1,200".
    expect(find.bySemanticsLabel(RegExp(r'(up|down) ')), findsWidgets);
    handle.dispose();
  });

  // ── Masked mode: shape is not a secret (§12) ────────────────────────────────
  testWidgets('masking changes every amount but never the bar geometry',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    await tester.pumpWidget(_app(store, const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    final unmasked = tester.getSize(find.byKey(const Key('ins-waterfall')));

    store.toggleMasked();
    await tester.pump(const Duration(milliseconds: 300));
    final masked = tester.getSize(find.byKey(const Key('ins-waterfall')));

    expect(masked.height, closeTo(unmasked.height, 0.5));
    // The concrete figures are gone once masked.
    expect(find.text('\$189,128'), findsNothing);
  });

  // ── Two-column grid, with a fallback (§5.3) ─────────────────────────────────
  testWidgets('the group grid is two columns at 390 en, one column at 130%',
      (tester) async {
    Future<int> distinctRows(Size size, double scale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
          _app(buildSeedStore(), const InsightScreen(), scale: scale));
      await tester.pump(const Duration(milliseconds: 300));
      final cells = find.byKey(const Key('ins-gridcell'));
      final ys = <double>{};
      for (final e in cells.evaluate()) {
        final box = e.renderObject as RenderBox;
        ys.add(box.localToGlobal(Offset.zero).dy.roundToDouble());
      }
      return ys.length;
    }

    addTearDown(tester.view.reset);
    // August has three movers. Two columns → two rows (2 + 1); the 130% scale
    // reliably breaks the half-width fit → one column → three rows.
    expect(await distinctRows(_sizes['390x844']!, 1.0), 2);
    expect(await distinctRows(_sizes['390x844']!, 1.3), 3);
  });

  // ── Empty window (§12) ──────────────────────────────────────────────────────
  testWidgets('an empty window keeps the hero, drops the waterfall and grid',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Step back to a window with no records (well before the seed's history).
    for (var i = 0; i < 40; i++) {
      await tester.drag(
          find.byType(HorizontalSectionSwipe).first, const Offset(320, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));

    // The empty window keeps the hero but drops the waterfall and grid, and
    // offers a "Go to {period}" link to the nearest window with records.
    expect(find.byKey(const Key('ins-waterfall')), findsNothing);
    expect(find.byKey(const Key('ins-gridcell')), findsNothing);
    expect(find.textContaining('Go to'), findsOneWidget);
  });

  testWidgets('the category chart is 104 pt', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
        buildSeedStore()..setInsightWindow(_augustMonth()),
        const CategoryDetailScreen(categoryId: 'c-housing')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byKey(const Key('ins-chart'))).height,
        closeTo(104, 1.0));
  });

  testWidgets('the archive performance card is 76 pt', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const ArchiveScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byKey(const Key('arc-perfcard'))).height,
        closeTo(76, 2.0));
  });

  // ── Preview length (§3.2) ───────────────────────────────────────────────────
  testWidgets('the expense block shows five rows plus the see-all link (no '
      'warning on August)', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('ins-exprow-4')), findsOneWidget); // 5th row
    expect(find.byKey(const Key('ins-exprow-5')), findsNothing); // no 6th
    expect(find.textContaining('See all'), findsOneWidget);
  });

  // ── Goal performance is gone from Insight (§7) ──────────────────────────────
  testWidgets('the archive shows the goal-performance card', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const ArchiveScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('arc-perfcard')), findsOneWidget);
  });
}
