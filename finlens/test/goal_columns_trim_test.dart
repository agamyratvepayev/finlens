import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/main.dart';
import 'package:finlens/shared/widgets/app_card.dart';

/// Goal detail — the STARTED · TARGET · AT THIS RATE card, after the height
/// trim (from ~116 to ~90). `flutter test` hangs on the dev machine, so these
/// are written, not run here; verify with `flutter analyze`.
///
/// The card's height is driven by line boxes, not width: with the caps key
/// (12), value (21) and verdict (15) line heights set explicitly, the total is
/// 14 + 36 + 11 + 1 + 6 + 15 + 7 = 90 for a single-line verdict.
void main() {
  Widget wrap(
    AppStore store,
    Widget child, {
    double textScale = 1.0,
    Locale? locale,
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
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

  /// The columns card, located by its `_Col` value style (fontSize 14 with the
  /// explicit 21pt line box) rather than by any localized string — so the same
  /// finder works in every locale.
  Finder columnsCard() {
    final colValue = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontSize == 14 && w.style?.height == 21 / 14,
    );
    return find
        .ancestor(of: colValue.first, matching: find.byType(AppCard))
        .first;
  }

  Future<void> openGoal(WidgetTester tester, String name) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the columns card measures ~90pt on Client Invoice #104 '
      '(393pt, en, scale 1.0)', (tester) async {
    // iPhone-15-class logical size: 393 x 852 at dpr 3.0 — the spec's condition.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoal(tester, 'Client Invoice #104');

    // The state the spec pins: AT THIS RATE is "—", verdict is "Not moving yet".
    expect(find.text('Not moving yet'), findsOneWidget);

    final h = tester.getSize(columnsCard()).height;
    expect(h, closeTo(90, 2));
  });

  testWidgets(
      'a verdict that wraps to two lines grows the card instead of clipping',
      (tester) async {
    // 320pt in Turkish: goalAveraging is a long string that cannot fit one line.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen(),
        locale: const Locale('tr')));
    await openGoal(tester, 'Freelance Side Income');

    // Grew clearly past the single-line 90 — the extra verdict line was added,
    // not clipped away.
    final h = tester.getSize(columnsCard()).height;
    expect(h, greaterThan(96));
    // No overflow stripes: an unbounded, growing card absorbed the second line.
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on the goal detail screen at 320pt in Turkish',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen(),
        locale: const Locale('tr')));
    await openGoal(tester, 'Client Invoice #104');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the Schedule task detail summary card is untouched — NEXT · AMOUNT · '
      'PER YEAR still 10.5/18 in a fromLTRB(6,9,6,10) card', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    // Internet Bill is a recurring task → NEXT · AMOUNT · PER YEAR.
    await tester.tap(find.text('Internet Bill').first);
    await tester.pumpAndSettle();

    // The geometry-defining styles of the summary card, byte-identical to
    // before this change (which touched only the goal detail columns card).
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('PER YEAR'), findsOneWidget);
    expect(tester.widget<Text>(find.text('NEXT')).style!.fontSize, 10.5);

    // Its inner padding literal is intact.
    final innerPad = tester.widgetList<Padding>(find.byType(Padding)).where(
        (p) => p.padding == const EdgeInsets.fromLTRB(6, 9, 6, 10));
    expect(innerPad, isNotEmpty);
  });
}
