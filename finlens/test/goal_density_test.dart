import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/app_card.dart';

/// Planner goal-card density & verdict (§1/§6). The card tightens to ~56pt and
/// its pace marker thins with the bar, while the Budgets tab is untouched.
void main() {
  Widget wrap(AppStore store, Widget child) => StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openGoals(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
  }

  testWidgets('a goal card is ~56pt tall and grows from intrinsic height',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoals(tester);

    final card = find
        .ancestor(of: find.text('House Deposit'), matching: find.byType(AppCard))
        .first;
    final height = tester.getSize(card).height;
    // The text block plus the tuned padding lands the card near 56 — well down
    // from the old ~68 and never a hardcoded height.
    expect(height, closeTo(56, 6));
    expect(height, lessThan(64));
  });

  testWidgets("the goal track spans the card's inner width — icon left to "
      'amount right', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoals(tester);

    final card = find
        .ancestor(of: find.text('House Deposit'), matching: find.byType(AppCard))
        .first;
    final icon = find.descendant(of: card, matching: find.byType(IconTile));
    final bar = find.descendant(of: card, matching: find.byType(ProgressBar));

    final iconRect = tester.getRect(icon);
    final barRect = tester.getRect(bar);
    // §3 — the track's left edge sits at the icon's left edge (full inner
    // width), not indented past the icon the way a budget row's bar is.
    expect(barRect.left, closeTo(iconRect.left, 0.5));
  });

  testWidgets("the goal card's pace marker is thinner than the summary's",
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    // On the Budgets tab, the 8pt summary bar keeps the default 2pt marker.
    final summary = tester
        .widgetList<ProgressBar>(find.byType(ProgressBar))
        .singleWhere((b) => b.height == 8);
    expect(summary.markerWidth, 2);

    await openGoals(tester);

    // Every goal bar is 3pt with a 1.5pt marker — visibly thinner.
    final goalBar = tester
        .widgetList<ProgressBar>(find.byType(ProgressBar))
        .firstWhere((b) => b.height == 3);
    expect(goalBar.markerWidth, 1.5);
    expect(goalBar.markerWidth, lessThan(summary.markerWidth));
  });

  testWidgets('the Budgets tab row height is unchanged (dense ~47pt)',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    // The InkWell wrapping the Groceries budget row — untouched by this change.
    final row = find
        .ancestor(of: find.text('Groceries'), matching: find.byType(InkWell))
        .first;
    final height = tester.getSize(row).height;
    expect(height, lessThanOrEqualTo(52));
    expect(height, closeTo(47, 6));
  });

  testWidgets('the seed goal cards read their verb-led verdicts', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoals(tester);

    expect(find.text(r'Behind · save $2,543/mo'), findsOneWidget); // House Deposit
    expect(find.text(r'Behind · pay $970/mo'), findsOneWidget); // Main Credit Card
    expect(find.text(r'Behind · earn $2,693/mo'),
        findsOneWidget); // Freelance Side Income
    expect(find.text(r'Refill $569'), findsOneWidget); // Emergency Fund — no .00
  });
}
