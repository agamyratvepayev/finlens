import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// New Budget — the one-step flow. Choosing it (from the type sheet, the Budgets
// tab +, or Quick Add) opens EditBudgetScreen in *create* mode with no category
// chosen. The category is picked on that screen, from its Category row — there is
// no "Budget which category?" step any more.

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

/// A bare Scaffold whose one button starts the New Budget flow — the entry
/// points funnel into [startNewBudgetFlow], so driving it directly exercises the
/// real push without depending on any one caller.
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

/// Open the create screen and then its category picker by tapping the Category
/// row (its value reads "Choose categories" until one is chosen).
Future<void> _openPicker(WidgetTester tester, AppStore store,
    {Locale? locale}) async {
  await tester.pumpWidget(_flowHost(store, locale: locale));
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose categories'));
  await tester.pumpAndSettle();
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

    await tester.tap(find.descendant(
        of: find.byType(FormNavBar),
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded)));
    await tester.pump(const Duration(milliseconds: 350));

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

    expect(income, lessThan(transfer));
    expect(transfer, lessThan(rebalance));
    expect(rebalance, lessThan(newBudget));
    expect(newBudget, lessThan(newGoal));
    expect(newGoal, lessThan(newTask));
  });

  // ── §4 · New Budget opens the create screen directly, NOT a picker ────────
  testWidgets('startNewBudgetFlow opens EditBudgetScreen; no picker in the tree',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_flowHost(buildSeedStore()));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    // The create screen is up, category unset.
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget); // Task 029: the type pill, now "Budget"
    expect(find.text('Choose categories'), findsOneWidget); // the Category value
    // The old step is gone — no picker on screen at this moment.
    expect(find.text('Budget which category?'), findsNothing);
    // Nothing was created yet.
    expect(find.text('Edit budget'), findsNothing);
  });

  // ── §3 · the Category row opens the picker; a pick fills the row ──────────
  testWidgets('tapping the Category row opens the picker and a pick fills it',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    store.addCategory(
      name: 'TripFundZZ',
      type: CategoryType.expense,
      icon: Icons.flight_rounded,
      color: Colors.teal,
    );

    await _openPicker(tester, store);

    // The picker is up (its create action names it) and lists the candidate.
    expect(find.text('New category'), findsOneWidget);
    expect(find.text('TripFundZZ'), findsOneWidget);

    await tester.tap(find.text('TripFundZZ'));
    await tester.pumpAndSettle();

    // Back on the create screen, the Category row now reads the chosen name and
    // "Choose categories" is gone.
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('TripFundZZ'), findsOneWidget);
    expect(find.text('Choose categories'), findsNothing);
  });

  // ── §4 · New Budget from an open Quick Add closes it, opens create screen ──
  testWidgets('New Budget from an open Quick Add closes it, opens the screen',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();

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

    await tester.tap(find.descendant(
        of: find.byType(FormNavBar),
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('New Budget'));
    await tester.pumpAndSettle();

    // Quick Add closed; the create screen — not a picker — is what's on screen.
    expect(find.byType(QuickAddScreen), findsNothing);
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('Budget which category?'), findsNothing);
  });

  // ── §3c · the picker: unbudgeted selectable, budgeted dimmed, others out ──
  testWidgets('picker shows budgeted dimmed, excludes income and removed',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    store.addCategory(
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
      monthlyBudget: 150,
    );
    store.removeBudget(removed);

    await _openPicker(tester, store);

    // Selectable candidate present.
    expect(find.text('IncludeMeZZ'), findsOneWidget);
    // Budgeted category is present but dimmed (shown with its reason), NOT hidden.
    expect(find.text('BudgetedZZ'), findsOneWidget);
    expect(find.text('Already budgeted'), findsWidgets);
    // Income and removed-budget categories are not listed.
    expect(find.text('IncomeZZ'), findsNothing);
    expect(find.text('RemovedZZ'), findsNothing);
  });

  // ── §3c · tapping a dimmed (budgeted) row does not select it ──────────────
  testWidgets('tapping a budgeted row does not select it', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    store.addCategory(
      name: 'BudgetedZZ',
      type: CategoryType.expense,
      icon: Icons.home_rounded,
      color: Colors.blue,
      monthlyBudget: 200,
    );

    await _openPicker(tester, store);
    expect(find.text('BudgetedZZ'), findsOneWidget);

    await tester.tap(find.text('BudgetedZZ'));
    await tester.pumpAndSettle();

    // Still on the picker (the row is inert); the create screen behind it still
    // reads "Choose categories".
    expect(find.text('New category'), findsOneWidget);
  });

  // ── §3d · creating a category from the picker selects it and returns ──────
  testWidgets('creating a category from the picker selects it', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));

    await _openPicker(tester, store);

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FreshCatZZ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create & select'));
    await tester.pumpAndSettle();

    // The sheet closed and the create screen's Category row shows the new name.
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('FreshCatZZ'), findsOneWidget);
    expect(store.categories.any((c) => c.name == 'FreshCatZZ'), isTrue);
  });

  // ── §4 · Planner + on the Budgets tab opens the create screen ─────────────
  testWidgets('Planner + on Budgets tab opens New budget create screen',
      (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(buildSeedStore(), home: const PlannerScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(EditBudgetScreen), findsOneWidget);
    // Task 029: the type pill now reads "Budget".
    expect(find.text('Budget'), findsOneWidget);
    // Not an expense form, and not the removed picker step.
    expect(find.byType(QuickAddScreen), findsNothing);
    expect(find.text('Budget which category?'), findsNothing);
  });

  testWidgets('Planner + on Schedule tab still opens a new task', (tester) async {
    tester.view.physicalSize = _defaultSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(buildSeedStore(), home: const PlannerScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Schedule'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddScreen), findsOneWidget);
    // Task 029: the schedule form's type pill now reads "Schedule".
    expect(find.text('Schedule'), findsWidgets);
  });

  // ── §8 · 320pt, Turkish — the type sheet must not overflow ────────────────
  testWidgets('type sheet has no overflow at 320pt in tr', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(buildSeedStore(), locale: const Locale('tr')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.descendant(
        of: find.byType(FormNavBar),
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded)));
    await tester.pump(const Duration(milliseconds: 350));

    // Task 029: the Turkish Budget row dropped its "Yeni" prefix → "Bütçe".
    expect(find.text('Bütçe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
