import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';

/// Planner Budgets tab + budget detail screen (spec 5.1 rework).
///
/// The seed's pinned month is August 2026. Budgeted: Groceries $1,000,
/// Housing $1,200, Entertainment $400, Transportation $500, Shopping $500,
/// Personal $200 → total $3,800. Unbudgeted August spend: Eating out $51,
/// Subscriptions $22 (Health/Garden/Debt have none) → $73.
void main() {
  final aug = DateTime(2026, 8);

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

  // ── Store math ─────────────────────────────────────────────────────────────

  test('totalBudget sums effectiveLimit across budgeted categories', () {
    final store = buildSeedStore();
    expect(store.totalBudget, 3800);
  });

  test('unbudgetedSpend folds only unbudgeted expense categories', () {
    final store = buildSeedStore();
    // Eating out (18 + 15.50 + 17.50) + Subscriptions (22) = 73.
    expect(store.unbudgetedSpend(aug), closeTo(73.0, 0.001));
  });

  test('the hero figure is budget − budgeted spend and ignores unbudgeted', () {
    final store = buildSeedStore();
    // The hero describes the budget alone: 3,800 − 2,899 = 901. The $73 of
    // unbudgeted spend sits outside the budget and must not move it (spec §2).
    expect(store.unbudgetedSpend(aug), greaterThan(0));
    expect(
      store.leftThisMonth(aug),
      closeTo(store.totalBudget - store.budgetedSpend(aug), 0.001),
    );
    expect(store.leftThisMonth(aug), closeTo(901, 0.001));
    // The old definition (also subtracting unbudgeted) would have read $828 —
    // the hero now agrees with the tab's `budgeted of total` line instead.
    expect(store.leftThisMonth(aug), isNot(closeTo(828, 0.001)));
  });

  test('the caption percentage uses budgeted spend only', () {
    final store = buildSeedStore();
    // 2,899 / 3,800 = 76% — budgeted spend over budget, not (budgeted +
    // unbudgeted) / budget, which would read 78% (spec §2).
    final captionRatio = store.budgetedSpend(aug) / store.totalBudget;
    expect(percent(captionRatio, decimals: 0), '76%');
    final withUnbudgeted =
        (store.budgetedSpend(aug) + store.unbudgetedSpend(aug)) /
            store.totalBudget;
    expect(percent(withUnbudgeted, decimals: 0), isNot('76%'));
  });

  test('LEFT THIS MONTH goes negative once budgeted spend passes the budget',
      () {
    final store = buildSeedStore();
    expect(store.leftThisMonth(aug), greaterThan(0));

    store.addTxn(
      type: TxnType.expense,
      amount: 5000,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-groceries',
      date: DateTime(2026, 8, 9),
    );

    expect(store.leftThisMonth(aug), lessThan(0));
  });

  test('spentInCategory converts a EUR expense through Fx.toBase', () {
    final store = buildSeedStore();
    // April 2026 Shopping is a single €38 expense (th-cash-eur-8) and nothing
    // else — so the whole month's figure is the conversion. Raw would be 38.00;
    // converted is 38 × 1.10 = 41.80.
    expect(store.spentInCategory('c-shopping', DateTime(2026, 4)),
        closeTo(41.80, 0.001));
  });

  test('the tab order is creation order, not over-limit-first (task 067.3 §5b)',
      () {
    final store = buildSeedStore();
    // The over-limit-first rule is gone: an unindexed budget list is oldest-
    // created-first, so Entertainment (over budget) no longer jumps the queue.
    final order =
        store.activeBudgetsByScope(BudgetScope.categories, aug);
    expect(order.first.targets.first, isNot('c-entertainment'));
    // A move renumbers the scope and the new order is honoured.
    final ent = order.firstWhere((b) => b.targets.first == 'c-entertainment');
    store.moveBudget(ent, before: order.first);
    final moved = store.activeBudgetsByScope(BudgetScope.categories, aug);
    expect(moved.first.targets.first, 'c-entertainment');
  });

  int monthsWithSpending(AppStore store, String categoryId, DateTime end) {
    var n = 0;
    for (var i = 0; i < 6; i++) {
      if (store.spentInCategory(
              categoryId, DateTime(end.year, end.month - i)) >
          0) {
        n++;
      }
    }
    return n;
  }

  // ── Widget behaviour ─────────────────────────────────────────────────────────

  testWidgets('tapping a budget card opens the budget screen, never the editor',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    // The budget detail screen — not EditBudgetScreen.
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(find.text('AGAINST THE LIMIT'), findsWidgets);
    expect(find.text('Monthly limit'), findsNothing);
  });

  testWidgets('the pace marker is hidden for a non-current month',
      (tester) async {
    bigScreen(tester);

    // Current month → the summary caption carries the Pace legend.
    await tester.pumpWidget(wrap(
      buildSeedStore(),
      BudgetDetailScreen(categoryId: 'c-groceries', month: aug),
    ));
    expect(find.text('Pace'), findsOneWidget);

    // A closed month has no pace to keep.
    await tester.pumpWidget(wrap(
      buildSeedStore(),
      BudgetDetailScreen(categoryId: 'c-groceries', month: DateTime(2026, 6)),
    ));
    await tester.pump();
    expect(find.text('Pace'), findsNothing);
  });

  testWidgets('AGAINST THE LIMIT hides below two months of data', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    // A far-future month: the six months ending there hold no spending.
    final future = DateTime(2031, 1);
    expect(monthsWithSpending(store, 'c-groceries', future), lessThan(2));

    await tester.pumpWidget(wrap(
      store,
      BudgetDetailScreen(categoryId: 'c-groceries', month: future),
    ));
    await tester.pump();
    expect(find.text('AGAINST THE LIMIT'), findsNothing);
  });

  testWidgets('AGAINST THE LIMIT shows its footer only with three months',
      (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    // Groceries has spending in most of the six months ending August 2026.
    expect(monthsWithSpending(store, 'c-groceries', aug),
        greaterThanOrEqualTo(3));

    await tester.pumpWidget(wrap(
      store,
      BudgetDetailScreen(categoryId: 'c-groceries', month: aug),
    ));
    await tester.pump();
    expect(find.text('AGAINST THE LIMIT'), findsOneWidget);
    expect(find.textContaining('Averaging'), findsOneWidget);
  });

  // The dense-row structure (bar, triangle, shared right edges, AppCard, the
  // "/" connector, the 56.5pt height) belonged to the pre-067.3 card and is
  // gone; its coverage moved to task067_3_budget_cards_test.dart, which pins the
  // ring, the two lines, the right column and the swipe/reorder gestures.

  testWidgets('the NO BUDGET SET section is collapsed by default and expands '
      'on tap', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    final cats = store.unbudgetedSpendingCategories(aug);
    expect(cats.length, greaterThanOrEqualTo(2));
    final firstName = cats.first.name; // highest spend — Eating out
    final countLabel =
        cats.length == 1 ? '1 category' : '${cats.length} categories';

    // Collapsed: the header shows the count · total, but the member rows and
    // their Set buttons are hidden.
    expect(find.text('NO BUDGET SET'), findsOneWidget);
    expect(find.text(countLabel), findsOneWidget);
    expect(find.text('Set'), findsNothing);
    expect(find.text(firstName), findsNothing);

    await tester.tap(find.text('NO BUDGET SET'));
    await tester.pumpAndSettle();

    expect(find.text(firstName), findsOneWidget);
    expect(find.text('Set'), findsWidgets);
  });

  // ── The summary card (spec §1–§4) ────────────────────────────────────────────

  testWidgets('the caption renders in full beside the Pace legend at 320pt',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    // Both clauses on one line — "76% spent" (budgeted only) · "day 9 of 31"
    // (today is 2026-08-09) — with the Pace legend still on the same row.
    const caption = '76% spent · day 9 of 31';
    expect(find.text(caption), findsOneWidget);
    expect(find.text('Pace'), findsOneWidget);

    // The caption is not ellipsised: the paragraph fits inside its one line.
    final paragraph = tester.renderObject<RenderParagraph>(find.text(caption));
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets(
      'the summary bar is one solid budgeted fill — no hatch — when unbudgeted '
      'spend is non-zero', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    // The precondition the old hatch existed for.
    expect(store.unbudgetedSpend(aug), greaterThan(0));
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // The hero summary bar is now 3pt (task 067.3 §6), and it is the only
    // ProgressBar on the tab — the cards draw a ring, not a bar.
    final summary = tester
        .widgetList<ProgressBar>(find.byType(ProgressBar))
        .singleWhere((b) => b.height == 3);
    // Solid fill = budgeted / budget only; there is no hatched segment plotting
    // the unbudgeted share (spec §2/§3).
    expect(
      summary.value,
      closeTo(store.budgetedSpend(aug) / store.totalBudget, 1e-6),
    );
    expect(summary.paceMarker, closeTo(store.monthProgressFor(aug), 1e-6));
  });
}
