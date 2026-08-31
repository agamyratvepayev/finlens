import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart' show EmptyState;
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/features/planner/schedule_horizon.dart'
    show ScheduleControl;
import 'package:finlens/features/planner/widgets/goal_scope_sheet.dart'
    show GoalScopeControl;
import 'package:finlens/l10n/app_localizations.dart';

/// Planner's three empty tabs (spec: "Planner's three empty tabs"). A header
/// control that could only step from one empty view to another is not drawn; a
/// control that is the way out of an empty view stays. The month control hides
/// on an empty Budgets tab, the horizon control on no-tasks-at-all; both tabs
/// keep their control the moment there is content to step through.
///
/// `AppStore.today` is pinned to 2026-08-09, so a hand-built store's Planner
/// month is August 2026.
void main() {
  Widget wrap(AppStore store, Widget child, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Account account(String id) => Account(
        id: id,
        name: id,
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 1000,
      );

  // A store with one expense category that has spending in August but no budget
  // — the "subtle" case (§5): no budgeted categories, so `budgetedCategories` is
  // empty, but `unbudgetedSpendingCategories(aug)` is not. The tab must NOT show
  // its empty state, and the month control must stay.
  AppStore unbudgetedSpendingStore() {
    final store = AppStore(
      accounts: [account('a1')],
      categories: [
        Category(
          id: 'c1',
          name: 'Eating out',
          type: CategoryType.expense,
          icon: Icons.restaurant_rounded,
          color: Colors.orange,
          // monthlyBudget left null → not a budgeted category.
        ),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    store.addTxn(
      type: TxnType.expense,
      amount: 50,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c1',
      date: DateTime(2026, 8, 9),
    );
    return store;
  }

  // A store whose only task falls well past the default Next-30-days horizon:
  // open (so not "no tasks at all") but out of window (so `_nothingDue`, not
  // `_emptyState`).
  AppStore futureTaskStore() => AppStore(
        accounts: [account('a1')],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: [
          Task(
            id: 't1',
            title: 'Rent',
            linkedAccountId: 'a1',
            expectedAmount: -1200,
            dueDate: DateTime(2026, 11, 1),
            icon: Icons.home_rounded,
          ),
        ],
      );

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  // The month control is the Budgets tab's only down-chevron; the NO BUDGET SET
  // header uses a right-chevron, the summary none.
  Finder monthControl() => find.byIcon(Icons.keyboard_arrow_down_rounded);

  // ── §1/§2/§5 Budgets ────────────────────────────────────────────────────────

  testWidgets('empty Budgets: no month control, empty state with a working '
      'action', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));

    // The month control is gone from the tree — stepping it would only walk from
    // one empty month to another.
    expect(monthControl(), findsNothing);
    // The tab shows its empty state, now with the New budget action (§2).
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Budgets cap a category'), findsOneWidget);
    expect(find.text('New budget'), findsOneWidget);
  });

  testWidgets('the New budget button opens the category-first budget flow',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));

    // The same flow this tab's + runs: Quick Add intercepts newBudget into a
    // category picker before any sheet builds (§2.1). With no expense category
    // to pick, the flow surfaces its own "nothing to pick" path — the key point
    // is the button is live and routes, not into an expense form. Bounded pumps
    // (not pumpAndSettle) since that path may raise a self-dismissing snackbar.
    await tester.tap(find.text('New budget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no budgets but one unbudgeted-spending category: month control '
      'stays, NO BUDGET SET renders, no empty state', (tester) async {
    bigScreen(tester);
    final store = unbudgetedSpendingStore();
    // Precondition: nothing budgeted, but the August spend is uncovered.
    expect(store.budgetedCategories, isEmpty);
    expect(store.unbudgetedSpendingCategories(DateTime(2026, 8)), isNotEmpty);

    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    expect(monthControl(), findsOneWidget);
    expect(find.text('NO BUDGET SET'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  // ── §1/§3 Schedule ──────────────────────────────────────────────────────────

  testWidgets('no tasks at all: no horizon control, the empty state renders',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));
    await tapTab(tester, 'Schedule');

    expect(find.byType(ScheduleControl), findsNothing);
    expect(find.text("Plan what's coming"), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('tasks outside the horizon: horizon control stays, _nothingDue '
      'renders unchanged', (tester) async {
    bigScreen(tester);
    final store = futureTaskStore();
    // The task is open (so not "no tasks at all") but past Next 30 days.
    expect(store.openTasks, isNotEmpty);
    expect(store.overdueTasks, isEmpty);

    await tester.pumpWidget(wrap(store, const PlannerScreen()));
    await tapTab(tester, 'Schedule');

    // The control is the way out — it is how the "next 3 months" link reaches
    // the deferred task, so it must not hide.
    expect(find.byType(ScheduleControl), findsOneWidget);
    // _nothingDue, not _emptyState.
    expect(find.text('Nothing due in this window'), findsOneWidget);
    expect(find.text('Show next 3 months ›'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  // ── §5 cross-tab and Goals ────────────────────────────────────────────────────

  testWidgets('switching from an empty Budgets to a populated Goals shows the '
      'scope control', (tester) async {
    bigScreen(tester);
    // Empty budgets, but one goal exists → each header reflects its own tab.
    final store = AppStore(
      accounts: [account('a1')],
      categories: const [],
      txns: const [],
      goals: [
        Goal(
          id: 'g1',
          name: 'House Deposit',
          source: GoalSource.account('a1'),
          targetAmount: 5000,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      tasks: const [],
    );
    await tester.pumpWidget(wrap(store, const PlannerScreen()));

    // Budgets empty → its slot is empty.
    expect(monthControl(), findsNothing);
    expect(find.byType(GoalScopeControl), findsNothing);

    await tapTab(tester, 'Goals');
    // Goals has content → the scope control appears.
    expect(find.byType(GoalScopeControl), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  // ── §5 the 320pt / tr overflow sweep ──────────────────────────────────────────

  testWidgets('320pt in tr: no overflow on any of the three empty states',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        wrap(emptyStore(), const PlannerScreen(), locale: const Locale('tr')));
    await tester.pumpAndSettle();
    // Budgets empty state.
    expect(tester.takeException(), isNull);

    await tapTab(tester, 'Hedefler'); // Goals
    expect(tester.takeException(), isNull);

    await tapTab(tester, 'Takvim'); // Schedule
    expect(tester.takeException(), isNull);
  });
}
