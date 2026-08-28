import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// Archive drill-down & the goal detail's archived mode (§1–§2). The seed's
/// Archive holds iPhone 17 (reached), Bali 2026 (abandoned) and Garden (removed
/// budget).
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

  testWidgets('tapping a reached goal opens the archived detail with the '
      'outcome columns and no forecast', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const ArchiveScreen()));

    await tester.tap(find.text('iPhone 17'));
    await tester.pumpAndSettle();

    // Reached outcome block, not the live AT THIS RATE card.
    expect(find.text('REACHED ON'), findsOneWidget);
    expect(find.text('TOOK'), findsOneWidget);
    expect(find.text('AT THIS RATE'), findsNothing);
    expect(find.text('Pace'), findsNothing);
    // Back label is the Archive, not Goals (§4).
    expect(find.widgetWithText(TextButton, 'Archive'), findsOneWidget);
  });

  testWidgets('tapping an abandoned goal opens it with STOPPED ON / GOT TO',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const ArchiveScreen()));

    await tester.tap(find.text('Bali 2026'));
    await tester.pumpAndSettle();

    expect(find.text('STOPPED ON'), findsOneWidget);
    expect(find.text('GOT TO'), findsOneWidget);
    expect(find.text('AT THIS RATE'), findsNothing);
  });

  testWidgets('tapping a removed budget row pushes nothing', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const ArchiveScreen()));

    await tester.tap(find.text('Garden'));
    await tester.pumpAndSettle();

    // No goal detail was pushed, and we are still on the Archive.
    expect(find.text('REACHED ON'), findsNothing);
    expect(find.text('GOT TO'), findsNothing);
    expect(find.text('Clear archive permanently'), findsOneWidget);
  });

  testWidgets('tapping Restore restores the row and does not push a screen',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const ArchiveScreen()));

    // The Restore button inside Bali's row (not the row's own tap).
    final baliRow =
        find.ancestor(of: find.text('Bali 2026'), matching: find.byType(InkWell))
            .first;
    await tester.tap(find.descendant(of: baliRow, matching: find.text('Restore')));
    await tester.pumpAndSettle();

    // No detail screen, and Bali has left the Archive (restored to active).
    expect(find.text('GOT TO'), findsNothing);
    expect(find.text('Bali 2026'), findsNothing);
    expect(find.text('Clear archive permanently'), findsOneWidget);
  });

  testWidgets('a live goal keeps the AT THIS RATE forecast and the Goals '
      'back label', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Deposit'));
    await tester.pumpAndSettle();

    expect(find.text('AT THIS RATE'), findsOneWidget);
    expect(find.text('REACHED ON'), findsNothing);
    expect(find.text('GOT TO'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Goals'), findsOneWidget);
  });
}
