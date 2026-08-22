import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';

/// Planner Budgets tab + budget detail screen (spec 5.1 rework).
///
/// The seed's pinned month is August 2026. Budgeted: Groceries $1,000,
/// Housing $1,200, Entertainment $400, Transportation $500, Shopping $500,
/// Personal $200 → total $3,800. Unbudgeted August spend: Eating out $51,
/// Subscriptions $22 (Health/Garden/Debt have none) → $73.
void main() {
  final aug = DateTime(2026, 8);

  Widget wrap(AppStore store, Widget child) => StoreScope(
        store: store,
        child: MaterialApp(home: child),
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

  test('LEFT THIS MONTH subtracts budgeted + unbudgeted spend', () {
    final store = buildSeedStore();
    final expected = store.totalBudget -
        (store.budgetedSpend(aug) + store.unbudgetedSpend(aug));
    expect(store.leftThisMonth(aug), closeTo(expected, 0.001));
  });

  test('LEFT THIS MONTH goes negative once total spend passes the budget', () {
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

  test('the clamped bar segments never exceed the track', () {
    final store = buildSeedStore();
    final budget = store.totalBudget;
    final solid = (store.budgetedSpend(aug) / budget).clamp(0.0, 1.0);
    final hatch = (store.unbudgetedSpend(aug) / budget).clamp(0.0, 1.0 - solid);
    expect(solid + hatch, lessThanOrEqualTo(1.0 + 1e-9));
    expect(hatch, greaterThanOrEqualTo(0.0));
  });

  test('spentInCategory converts a EUR expense through Fx.toBase', () {
    final store = buildSeedStore();
    // April 2026 Shopping is a single €38 expense (th-cash-eur-8) and nothing
    // else — so the whole month's figure is the conversion. Raw would be 38.00;
    // converted is 38 × 1.10 = 41.80.
    expect(store.spentInCategory('c-shopping', DateTime(2026, 4)),
        closeTo(41.80, 0.001));
  });

  test('over-limit categories sort ahead of the rest', () {
    final store = buildSeedStore();
    final budgets = store.budgetedCategories;
    bool over(Category c) =>
        store.spentInCategory(c.id, aug) > (c.effectiveLimit ?? 0);
    final ordered = [
      ...budgets.where(over),
      ...budgets.where((c) => !over(c)),
    ];
    // Entertainment ($400 limit, ~$468 spent) is the only over-limit budget.
    expect(ordered.first.id, 'c-entertainment');
    expect(over(ordered.first), isTrue);
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
}
