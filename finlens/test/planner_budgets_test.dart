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
import 'package:finlens/shared/widgets/app_card.dart';
import 'package:finlens/theme/app_colors.dart';

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

  testWidgets('each budgeted category is its own card, 8pt apart, with no '
      'dividers anywhere in the list', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // Every budgeted category sits in its own AppCard (spec §1) — the ancestor
    // AppCard of each name is that budget's card, not one shared container.
    for (final c in store.budgetedCategories) {
      final card = find.ancestor(
          of: find.text(c.name), matching: find.byType(AppCard));
      expect(card, findsOneWidget, reason: c.name);
    }
    // No hairline anywhere in the budget list: a gap and a rule would say the
    // same thing twice (§1). The NO BUDGET SET section is collapsed by default,
    // so its dividers are absent too.
    expect(find.byType(RowDivider), findsNothing);

    // 8pt between consecutive cards: the gap is one card's top minus the card
    // above it (each card owns an 8pt bottom margin).
    final first = tester.getRect(find
        .ancestor(of: find.text('Entertainment'), matching: find.byType(AppCard))
        .first);
    final second = tester.getRect(find
        .ancestor(of: find.text('Groceries'), matching: find.byType(AppCard))
        .first);
    expect(second.top - first.bottom, closeTo(8, 0.5));
  });

  testWidgets('a budget card measures 56.5pt — the same as a goal card',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    final budgetCard = find
        .ancestor(of: find.text('Groceries'), matching: find.byType(AppCard))
        .first;
    final budgetHeight = tester.getSize(budgetCard).height;
    expect(budgetHeight, closeTo(56.5, 1));

    // Switch to Goals and measure a goal card: the two tabs are one segmented
    // control apart and must be the same card (§3).
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    final goalCard = find
        .ancestor(of: find.text('House Deposit'), matching: find.byType(AppCard))
        .first;
    final goalHeight = tester.getSize(goalCard).height;
    expect(budgetHeight, closeTo(goalHeight, 1));
  });

  testWidgets("the 4pt bar starts at the text column and the spent figure is "
      'white', (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    final row = find
        .ancestor(of: find.text('Groceries'), matching: find.byType(InkWell))
        .first;
    final icon = find.descendant(of: row, matching: find.byType(IconTile));
    final bar = find.descendant(of: row, matching: find.byType(ProgressBar));

    final iconRect = tester.getRect(icon);
    final barRect = tester.getRect(bar);

    // The bar is still 4pt and spans the text column: its left edge sits at the
    // icon's right edge plus the 12pt gap, not under the icon (§2).
    expect(barRect.height, closeTo(4, 0.6));
    expect(barRect.left, greaterThanOrEqualTo(iconRect.right - 0.5));
    expect(barRect.left, lessThanOrEqualTo(iconRect.right + 14));

    // The spent figure carries no colour override → textPrimary (§4): green
    // here would read as money in, and the bar already carries the state.
    final spent = tester.widget<AmountText>(
        find.descendant(of: row, matching: find.byType(AmountText)));
    expect(spent.color, isNull);
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

  testWidgets('an over-budget row: triangle, red bar, and a textPrimary amount',
      (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // Entertainment is the seed's only over-limit budget.
    final row = find
        .ancestor(of: find.text('Entertainment'), matching: find.byType(InkWell))
        .first;
    expect(find.descendant(of: row, matching: find.byIcon(Icons.warning_amber_rounded)),
        findsOneWidget);
    final bar = tester.widget<ProgressBar>(
        find.descendant(of: row, matching: find.byType(ProgressBar)));
    expect(bar.color, AppColors.negative);
    // The figure stays white even over budget — the red is on the bar, not the
    // amount (§4).
    final spent = tester.widget<AmountText>(
        find.descendant(of: row, matching: find.byType(AmountText)));
    expect(spent.color, isNull);
  });

  testWidgets('a near-limit row renders no glyph and an amber bar',
      (tester) async {
    bigScreen(tester);
    final store = buildSeedStore();
    // Push Groceries into the warn band (0.8 ≤ ratio < 1) by pinning its limit
    // to spent / 0.9 — near, but not over.
    final groceries =
        store.budgetedCategories.firstWhere((c) => c.id == 'c-groceries');
    final spent = store.spentInCategory('c-groceries', aug);
    expect(spent, greaterThan(0));
    groceries.monthlyBudget = spent / 0.9;

    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    final row = find
        .ancestor(of: find.text('Groceries'), matching: find.byType(InkWell))
        .first;
    // Near-limit's only signal is the bar's colour and length — no glyph (§4).
    expect(find.descendant(of: row, matching: find.byIcon(Icons.warning_amber_rounded)),
        findsNothing);
    final bar = tester.widget<ProgressBar>(
        find.descendant(of: row, matching: find.byType(ProgressBar)));
    expect(bar.color, AppColors.warning);
  });

  testWidgets('320pt in tr: long name + seven-figure limit, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3.0, 900 * 3.0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    // The tightest case (spec §7): a long name, the over-budget triangle, and
    // seven-figure spent + limit, in Turkmen. Entertainment is already over;
    // pin the limit to $1,000,000 and push spend to ~$1,240,000 so both figures
    // render whole while the triangle and red bar still show.
    final ent =
        store.budgetedCategories.firstWhere((c) => c.id == 'c-entertainment');
    ent.name = 'Güýmenje we dynç alyş hyzmatlary üçin aýlyk býudžet';
    ent.monthlyBudget = 1000000;
    final spent = store.spentInCategory('c-entertainment', aug);
    store.addTxn(
      type: TxnType.expense,
      amount: 1240000 - spent,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'c-entertainment',
      date: DateTime(2026, 8, 9),
    );
    expect(store.spentInCategory('c-entertainment', aug),
        greaterThan(ent.effectiveLimit ?? 0));

    await tester.pumpWidget(
        wrap(store, const PlannerScreen(), locale: const Locale('tk')));
    await tester.pumpAndSettle();

    // No RenderFlex overflow was thrown while laying the row out.
    expect(tester.takeException(), isNull);
    // The name ellipsised rather than forcing the row wider.
    final name = tester.renderObject<RenderParagraph>(find.text(ent.name));
    expect(name.didExceedMaxLines, isTrue);
  });

  // A 402pt-wide viewport — the width the row layout is specified against
  // (spec §1/§4). Tall enough that the Budgets list lays out unclipped.
  void narrowScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(402 * 3.0, 1400 * 3.0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Finder rowOf(String categoryName) => find
      .ancestor(of: find.text(categoryName), matching: find.byType(InkWell))
      .first;

  // The spent figure is the row's only AmountText (the limit is a plain Text
  // now that the "/" connector is gone, spec §2).
  Finder spentOf(String categoryName) =>
      find.descendant(of: rowOf(categoryName), matching: find.byType(AmountText));

  // The limit Text, matched by its rendered value inside the row.
  Finder limitOf(AppStore store, String categoryName) {
    final c = store.budgetedCategories.firstWhere((c) => c.name == categoryName);
    return find.descendant(
        of: rowOf(categoryName),
        matching: find.text(money(c.effectiveLimit ?? 0)));
  }

  testWidgets('Entertainment renders in full — no ellipsis — at 402pt',
      (tester) async {
    narrowScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    // With the name on Expanded (not Flexible beside a Spacer), the full room
    // the amount doesn't need is the name's: "Entertainment" fits whole.
    final name = tester.renderObject<RenderParagraph>(find.text('Entertainment'));
    expect(name.didExceedMaxLines, isFalse);
    // Transportation is the other name that used to truncate.
    final trans =
        tester.renderObject<RenderParagraph>(find.text('Transportation'));
    expect(trans.didExceedMaxLines, isFalse);
  });

  testWidgets('down a list, spent figures share a right edge and limits share a '
      'right edge', (tester) async {
    narrowScreen(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // Housing ($1,200 limit, four-figure spend) is the widest; Personal ($200)
    // the narrowest. Each row's spent figure is right-aligned in the same text
    // column, so despite different widths the two terminate at one x (spec §2).
    final wideSpent = tester.getRect(spentOf('Housing').first);
    final narrowSpent = tester.getRect(spentOf('Personal').first);
    expect(wideSpent.width, isNot(closeTo(narrowSpent.width, 1)));
    expect(wideSpent.right, closeTo(narrowSpent.right, 0.5));

    // The limits form their own right-aligned column directly beneath.
    final wideLimit = tester.getRect(limitOf(store, 'Housing'));
    final narrowLimit = tester.getRect(limitOf(store, 'Personal'));
    expect(wideLimit.right, closeTo(narrowLimit.right, 0.5));
    // And the limit sits under its own spent figure, sharing that right edge.
    expect(wideLimit.right, closeTo(wideSpent.right, 0.5));
  });

  testWidgets('no "/", "of" or connector appears between spent and limit',
      (tester) async {
    narrowScreen(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const PlannerScreen()));

    // The stacking and shared right edge carry the relation; the old
    // " / $limit" Text is gone (spec §2).
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('an over-budget row with a very long name keeps the triangle',
      (tester) async {
    narrowScreen(tester);
    final store = buildSeedStore();
    // Entertainment is the seed's only over-limit budget; give it a name too
    // long to fit so the ellipsis has to bite.
    store.budgetedCategories.firstWhere((c) => c.id == 'c-entertainment').name =
        'Entertainment and Recreation and Streaming Subscriptions Budget Line';
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // The name shortens; the triangle is not inside the Expanded, so it stays.
    final name = tester.renderObject<RenderParagraph>(
        find.textContaining('Entertainment and Recreation'));
    expect(name.didExceedMaxLines, isTrue);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
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

    // The hero summary bar is the only 8pt-tall ProgressBar (rows are 4pt).
    final summary = tester
        .widgetList<ProgressBar>(find.byType(ProgressBar))
        .singleWhere((b) => b.height == 8);
    // Solid fill = budgeted / budget only; there is no hatched segment plotting
    // the unbudgeted share (spec §2/§3).
    expect(
      summary.value,
      closeTo(store.budgetedSpend(aug) / store.totalBudget, 1e-6),
    );
    expect(summary.paceMarker, closeTo(store.monthProgressFor(aug), 1e-6));
  });
}
