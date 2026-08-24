import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// Goals tab + card behaviour (§2). The seed exercises all four sections:
/// SAVING (House Deposit, Emergency Fund), PAYING OFF (Main Credit Card),
/// WAITING ON (Client Invoice #104), EARNING (Freelance Side Income).
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

  Future<void> openGoalsTab(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
  }

  testWidgets('section headers are derived from the source group', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoalsTab(tester);

    // Every populated section renders, uppercased by SectionLabel.
    expect(find.text('SAVING'), findsOneWidget);
    expect(find.text('PAYING OFF'), findsOneWidget);
    expect(find.text('WAITING ON'), findsOneWidget);
    expect(find.text('EARNING'), findsOneWidget);

    // A credit-card goal lands under PAYING OFF.
    expect(find.text('Main Credit Card'), findsOneWidget);
  });

  testWidgets('a WAITING ON goal reads a "Due" verdict (structurally no rate)',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoalsTab(tester);

    // The receivable card takes the Due branch, which can never contain a rate.
    expect(find.textContaining('Due '), findsWidgets);
  });

  testWidgets('tapping a card opens the detail screen, never the editor',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoalsTab(tester);

    expect(find.text('House Deposit'), findsOneWidget);
    await tester.tap(find.text('House Deposit'));
    await tester.pumpAndSettle();

    // The detail screen — its STARTED / TARGET / AT THIS RATE columns.
    expect(find.text('STARTED'), findsOneWidget);
    expect(find.text('AT THIS RATE'), findsOneWidget);
    // Not the editor: its "Done once reached" switch is absent.
    expect(find.text('Done once reached'), findsNothing);
  });
}
