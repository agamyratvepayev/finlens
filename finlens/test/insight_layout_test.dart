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
            buildSeedStore(),
            CategoryDetailScreen(categoryId: 'c-housing', window: _augustMonth()),
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
            buildSeedStore(),
            SeeAllScreen(income: false, window: _augustMonth()),
            locale: locale,
            scale: scale,
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // ── Density (§4) ────────────────────────────────────────────────────────────
  testWidgets('component heights match the §4 targets', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    double h(Key k) => tester.getSize(find.byKey(k).first).height;
    expect(h(const Key('ins-threeup')), closeTo(46, 1.5));
    expect(h(const Key('ins-debtcells')), closeTo(47, 1.5));
    expect(h(const Key('ins-foot')), closeTo(30, 1.5));
  });

  testWidgets('the category chart is 104 pt', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(),
        CategoryDetailScreen(categoryId: 'c-housing', window: _augustMonth())));
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
