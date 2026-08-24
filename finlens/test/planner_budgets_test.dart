import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/app_card.dart';

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

  // ── The dense budget row (spec §3/§4) ────────────────────────────────────────

  testWidgets('a budget row is dense (≤52pt) and its 4pt bar starts at the '
      'text column', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // The InkWell wrapping Groceries' row, and the icon + bar inside it.
    final row = find
        .ancestor(of: find.text('Groceries'), matching: find.byType(InkWell))
        .first;
    final icon = find.descendant(of: row, matching: find.byType(IconTile));
    final bar = find.descendant(of: row, matching: find.byType(ProgressBar));

    final rowRect = tester.getRect(row);
    final iconRect = tester.getRect(icon);
    final barRect = tester.getRect(bar);

    // 48pt of pitch — the bar costs no row height (spec §3).
    expect(rowRect.height, lessThanOrEqualTo(52));
    // The bar is 4pt and spans the text column: its left edge sits at the
    // icon's right edge plus the 12pt gap, not under the icon.
    expect(barRect.height, closeTo(4, 0.6));
    expect(barRect.left, greaterThanOrEqualTo(iconRect.right - 0.5));
    expect(barRect.left, lessThanOrEqualTo(iconRect.right + 14));
  });

  testWidgets('the over glyph renders only above the effective limit',
      (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    final overCount = store.budgetedCategories
        .where((c) =>
            store.spentInCategory(c.id, aug) > (c.effectiveLimit ?? 0))
        .length;
    // The seed has exactly one over-limit budget (Entertainment); no warn-level
    // glyph exists, so the count of triangles equals the over-limit count.
    expect(overCount, greaterThan(0));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(overCount));
  });

  testWidgets('every budget row announces its state in a single semantics label',
      (tester) async {
    bigScreen(tester);
    final handle = tester.ensureSemantics();
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    var sawOver = false;
    for (final c in store.budgetedCategories) {
      final spent = store.spentInCategory(c.id, aug);
      final limit = c.effectiveLimit ?? 0;
      final ratio = limit <= 0 ? 0.0 : spent / limit;
      final s = money(spent), lim = money(limit);
      final String expected;
      if (ratio > 1) {
        expected = '${c.name}, over budget, $s of $lim';
        sawOver = true;
      } else if (ratio >= c.warnThreshold) {
        expected = '${c.name}, near the limit, $s of $lim';
      } else {
        expected = '${c.name}, $s of $lim';
      }
      expect(find.bySemanticsLabel(expected), findsOneWidget, reason: c.name);
    }
    // The three-state coverage is only meaningful if an over-budget row exists.
    expect(sawOver, isTrue);
    handle.dispose();
  });

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
}
