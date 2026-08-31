import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// New Budget — the seventh Quick Add type. It never renders in the numeric-hero
// sheet: choosing it opens a category picker (expense categories with no budget,
// including ones with no spend) and pushes EditBudgetScreen for the pick.

const _defaultSize = Size(390, 844);

Widget _host(AppStore store, {Widget? home, Locale? locale}) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home ??
            const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );

/// A bare Scaffold whose one button starts the New Budget flow — the two entry
/// points funnel into [startNewBudgetFlow], so driving it directly exercises the
/// real filter, sort, picker and push without depending on any one caller.
Widget _flowHost(AppStore store, {Locale? locale}) => _host(
      store,
      locale: locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => startNewBudgetFlow(context),
              child: const Text('start'),
            ),
          ),
        ),
      ),
    );

/// Give every expense category a budget, so the "all budgeted" branch is
/// reachable from the seed fixture.
void _budgetEveryExpenseCategory(AppStore store) {
  for (final c in store.categories.where((c) => c.type == CategoryType.expense)) {
    c.monthlyBudget ??= 100;
  }
}

void main() {
  // ── §1 · the type sheet lists seven rows, New Budget fifth ────────────────
  testWidgets('type sheet lists seven rows in order, New Budget fifth',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(buildSeedStore()));
    await tester.pump(const Duration(milliseconds: 350));

    // Open the type menu via the chip's dropdown arrow.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    // Every one of these labels is unique to the sheet (the nav bar shows only
    // the current type name, "Expense", and the save button "Save expense").
    double dy(String label) {
      final f = find.text(label);
      expect(f, findsOneWidget, reason: '"$label" should be a single sheet row');
      return tester.getTopLeft(f).dy;
    }

    final income = dy('Income');
    final transfer = dy('Transfer');
    final rebalance = dy('Rebalance');
    final newBudget = dy('New Budget');
    final newGoal = dy('New Goal');
    final newTask = dy('New Task');

    // Strictly top-to-bottom in the requested order; New Budget sits between
    // Rebalance and New Goal — the fifth row overall (Expense is first).
    expect(income, lessThan(transfer));
    expect(transfer, lessThan(rebalance));
    expect(rebalance, lessThan(newBudget));
    expect(newBudget, lessThan(newGoal));
    expect(newGoal, lessThan(newTask));
  });

  // ── §3 · choosing New Budget opens the picker; a pick pushes EditBudget ────
  testWidgets('New Budget opens the picker and a pick pushes EditBudgetScreen',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    // A zero-spend, unbudgeted expense category — the trip you haven't taken.
    final trip = store.addCategory(
      name: 'TripFundZZ',
      type: CategoryType.expense,
      icon: Icons.flight_rounded,
      color: Colors.teal,
    );

    await tester.pumpWidget(_flowHost(store));
    await tester.tap(find.text('start'));
    await tester.pump(const Duration(milliseconds: 350));

    // The picker opened with its own title (not "Expense category").
    expect(find.text('Budget which category?'), findsOneWidget);
    // The zero-spend category is listed, with its context subtitle.
    expect(find.text('TripFundZZ'), findsOneWidget);
    expect(find.text('Nothing yet'), findsWidgets);

    await tester.tap(find.text('TripFundZZ'));
    await tester.pumpAndSettle();

    final editor = find.byType(EditBudgetScreen);
    expect(editor, findsOneWidget);
    expect(
      tester.widget<EditBudgetScreen>(editor).categoryId,
      trip.id,
    );
  });

  // ── §3/§6 · New Budget from inside an open Quick Add closes it first ───────
  testWidgets('New Budget from an open Quick Add closes it, then opens picker',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    store.addCategory(
      name: 'TripFundZZ',
      type: CategoryType.expense,
      icon: Icons.flight_rounded,
      color: Colors.teal,
    );

    // A home over which Quick Add is pushed, so popping it lands somewhere.
    await tester.pumpWidget(_host(
      store,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showQuickAdd(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddScreen), findsOneWidget);

    // Open the type menu and choose New Budget.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('New Budget'));
    await tester.pumpAndSettle();

    // Quick Add closed; no stacked modals — the picker is what's on screen.
    expect(find.byType(QuickAddScreen), findsNothing);
    expect(find.text('Budget which category?'), findsOneWidget);
  });

  // ── §3 · the candidate list: zero-spend unbudgeted in, others out ─────────
  testWidgets('picker includes zero-spend unbudgeted, excludes budgeted, '
      'income and removed', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    final included = store.addCategory(
      name: 'IncludeMeZZ',
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: Colors.orange,
    );
    store.addCategory(
      name: 'BudgetedZZ',
      type: CategoryType.expense,
      icon: Icons.home_rounded,
      color: Colors.blue,
      monthlyBudget: 200,
    );
    store.addCategory(
      name: 'IncomeZZ',
      type: CategoryType.income,
      icon: Icons.payments_rounded,
      color: Colors.green,
    );
    final removed = store.addCategory(
      name: 'RemovedZZ',
      type: CategoryType.expense,
      icon: Icons.delete_rounded,
      color: Colors.red,
    );
    removed.removedOn = DateTime(2026, 1, 1);

    await tester.pumpWidget(_flowHost(store));
    await tester.tap(find.text('start'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('IncludeMeZZ'), findsOneWidget);
    expect(find.text('BudgetedZZ'), findsNothing); // has a budget
    expect(find.text('IncomeZZ'), findsNothing); // income category
    expect(find.text('RemovedZZ'), findsNothing); // removed
    // The included one still exists as a real category.
    expect(store.categoryById(included.id), isNotNull);
  });

  // ── §6 · every expense category budgeted → a notice, no sheet ─────────────
  testWidgets('all budgeted shows a notice and opens no picker', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    _budgetEveryExpenseCategory(store);

    await tester.pumpWidget(_flowHost(store));
    await tester.tap(find.text('start'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Budget which category?'), findsNothing);
    expect(find.byType(EditBudgetScreen), findsNothing);
    expect(find.text('Every category already has a budget'), findsOneWidget);
  });

  // ── §5 · the Planner + per tab ────────────────────────────────────────────
  testWidgets('Planner + on Budgets tab starts the budget flow', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    store.addCategory(
      name: 'TripFundZZ',
      type: CategoryType.expense,
      icon: Icons.flight_rounded,
      color: Colors.teal,
    );

    await tester.pumpWidget(_host(store, home: const PlannerScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    // Budgets is the default tab; its + opens the category-first budget flow.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Budget which category?'), findsOneWidget);
    // Not an expense form — no numeric hero screen was pushed.
    expect(find.byType(QuickAddScreen), findsNothing);
  });

  testWidgets('Planner + on Schedule tab still opens a new task', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(buildSeedStore(), home: const PlannerScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    // Move to the Schedule tab, then add.
    await tester.tap(find.text('Schedule'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddScreen), findsOneWidget);
    // New Task is the type name shown in the nav bar.
    expect(find.text('New Task'), findsWidgets);
  });

  // ── §6 · 320pt, Turkish — the type sheet must not overflow ────────────────
  testWidgets('type sheet has no overflow at 320pt in tr', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(buildSeedStore(), locale: const Locale('tr')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump(const Duration(milliseconds: 350));

    // The long tr rows ("Yeni bütçe") are present and nothing overflowed.
    expect(find.text('Yeni bütçe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
