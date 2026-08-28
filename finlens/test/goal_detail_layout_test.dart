import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// Goal detail screen — spacing, density and sign rules (§1–§10 of the detail
/// refinement pass). The seed's House Deposit is an account-backed SAVING goal:
/// it has a WATCHING row (Main Checking) and a MOVEMENTS card whose first
/// entries are +$900 "Landing page project", $132 and $500.
void main() {
  Widget wrap(AppStore store, Widget child, {double textScale = 1.0}) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Above the Navigator, so a pushed detail route inherits the scale.
          builder: (context, w) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: w!,
          ),
          home: child,
        ),
      );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openHouseDeposit(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Deposit'));
    await tester.pumpAndSettle();
  }

  testWidgets('movement amounts drop the sign and carry a direction '
      'semantics label (§6)', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openHouseDeposit(tester);

    // Unsigned: colour, not a glyph, carries direction on screen.
    expect(find.text(r'$900'), findsWidgets);
    expect(find.text(r'$132'), findsWidgets);
    expect(find.text(r'+$900'), findsNothing);
    expect(find.text('−\$132'), findsNothing); // true minus, not a hyphen

    // The sign is gone, so a screen reader is given the direction in words.
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label ?? '')
        .where((l) => l.startsWith('Money in') || l.startsWith('Money out'))
        .toList();
    expect(labels, isNotEmpty);
    // The amount itself rides along in the label.
    expect(labels.any((l) => l.contains(r'$900')), isTrue);
  });

  testWidgets('the WATCHING title and a movement title resolve to the same '
      'point size (§5)', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openHouseDeposit(tester);

    final watching =
        tester.widget<Text>(find.text('Main Checking')).style!.fontSize;
    final movement =
        tester.widget<Text>(find.text('Landing page project')).style!.fontSize;
    expect(watching, movement);
    expect(watching, 15); // AppText.rowTitle token, no per-call override
  });

  testWidgets('a movement row measures ~46pt, clearing the 44pt tap target '
      '(§7)', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openHouseDeposit(tester);

    // The nearest Padding ancestor of the title is the row's own padding, so
    // its size is the full row height (content + the tuned vertical padding).
    final rowPadding = find
        .ancestor(
            of: find.text('Landing page project'),
            matching: find.byType(Padding))
        .first;
    final h = tester.getSize(rowPadding).height;
    expect(h, closeTo(46, 2.5));
    expect(h, greaterThan(44.5)); // never tightens below the 44pt target
  });

  testWidgets('the hero figure never overlaps the verdict line at 130% text '
      'scale (§2)', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
        wrap(buildSeedStore(), const PlannerScreen(), textScale: 1.3));
    await openHouseDeposit(tester);

    final verdict = tester.getRect(find.text(r'Behind · save $2,543/mo'));
    // The hero is the only 30pt figure on the screen.
    final heroFinder =
        find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 30);
    expect(heroFinder, findsOneWidget);
    final hero = tester.getRect(heroFinder);

    // Its glyphs sit wholly below the verdict — the 16pt clearance survives
    // 1.3x scaling even though AppText.hero's height:1.0 gives no top leading.
    expect(hero.top, greaterThanOrEqualTo(verdict.bottom));
  });
}
