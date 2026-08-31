import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/features/planner/widgets/goal_scope_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';

/// The Goals-tab scope control and its STATUS sheet (Planner §1–§3). Seed
/// fixture: 5 active goals, 3 needing attention (House Deposit, Main Credit
/// Card, Freelance Side Income) across three sections.
void main() {
  Widget wrap(AppStore store, Widget child, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
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

  testWidgets('the control names the active scope: 5 goals · 3 need attention',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoalsTab(tester);

    expect(find.text('5 goals · 3 need attention'), findsOneWidget);
  });

  testWidgets('archiving a source keeps its goal in the needs-attention set',
      (tester) async {
    // Not pumped — a store assertion on the acceptance fixture.
    final store = buildSeedStore();
    final before = store.goalFilterCounts();
    expect(before.needsAttention, 3);

    store.removeAccount(store.accountById('a-checking')!); // House Deposit source
    final m = store.goalMetrics(store.goalById('g-house')!);
    expect(m.sourceAvailable, isFalse);
    expect(m.needsAttention, isTrue);
    // Still 3 — House Deposit was already behind; it is now broken, not fixed.
    expect(store.goalFilterCounts().needsAttention, 3);
  });

  testWidgets('selecting Needs attention filters to three cards in three '
      'sections and recomputes SAVING', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));
    await openGoalsTab(tester);

    // The unfiltered SAVING total covers both goals.
    expect(find.text(r'$17,628 of $36,000'), findsOneWidget);

    await tester.tap(find.text('5 goals · 3 need attention'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();

    // Exactly the three behind goals, each still under its own section.
    expect(find.text('House Deposit'), findsOneWidget);
    expect(find.text('Main Credit Card'), findsOneWidget);
    expect(find.text('Freelance Side Income'), findsOneWidget);
    // WAITING ON drops from the tree entirely.
    expect(find.text('Client Invoice #104'), findsNothing);
    expect(find.text('WAITING ON'), findsNothing);
    expect(find.text('Emergency Fund'), findsNothing);

    // SAVING's total recomputes to House Deposit alone — no unfiltered carryover.
    expect(find.text(r'$12,198 of $30,000'), findsOneWidget);
    expect(find.text(r'$17,628 of $36,000'), findsNothing);

    // The control now names the filtered scope.
    expect(find.text('Needs attention · 3 of 5'), findsOneWidget);
  });

  testWidgets('a zero-count sheet row is not selectable', (tester) async {
    bigScreen(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      wrap(buildSeedStore(), Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })),
    );

    // On track = 0 → its row is dimmed and inert.
    final future = showGoalScopeSheet(
      ctx,
      current: GoalFilter.all,
      counts: (all: 3, needsAttention: 3, onTrack: 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsOneWidget);

    // Tapping the 0-count row does nothing — the sheet stays open.
    await tester.tap(find.text('On track'));
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsOneWidget);

    // A live row still closes it, proving the sheet is otherwise responsive.
    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsNothing);
    expect(await future, GoalFilter.needsAttention);
  });

  testWidgets('emptying the filtered set shows Show all, never the EmptyState',
      (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));
    await openGoalsTab(tester);

    await tester.tap(find.text('5 goals · 3 need attention'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();
    expect(find.text('House Deposit'), findsOneWidget);

    // Resolve every behind goal while the filter is on Needs attention.
    for (final id in ['g-house', 'g-amex', 'g-freelance']) {
      store.markGoalReached(store.goalById(id)!);
    }
    await tester.pumpAndSettle();

    expect(find.text('No goals need attention'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    // Not the tab's real EmptyState (the user still has goals).
    expect(find.text('Goals answer “when”'), findsNothing);
  });

  testWidgets('no goals → the header slot is empty and EmptyState is unchanged',
      (tester) async {
    bigScreen(tester);
    final store = AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    await tester.pumpWidget(wrap(store, const PlannerScreen()));
    await openGoalsTab(tester);

    expect(find.byType(GoalScopeControl), findsNothing);
    expect(find.text('Goals answer “when”'), findsOneWidget);
  });

  // The Goals tab label per locale — the three header buttons keep their size
  // and the scope label scales down in its FittedBox (§5). tk carries the
  // longest scope label ("Üns talap edýär · 5 maksatdan 3").
  const goalsLabel = {'en': 'Goals', 'tr': 'Hedefler', 'tk': 'Maksatlar'};
  for (final code in goalsLabel.keys) {
    testWidgets('no overflow on the Goals tab + sheet at 320pt in $code',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(buildSeedStore(), const PlannerScreen(), locale: Locale(code)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(goalsLabel[code]!));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The sheet must fit the width too.
      await tester.tap(find.byType(GoalScopeControl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
