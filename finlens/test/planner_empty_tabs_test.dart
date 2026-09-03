import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart' show EmptyState;
import 'package:finlens/features/ledger/ledger_screen.dart'
    show buildFirstRunHint;
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
  Widget wrap(AppStore store, Widget child,
          {Locale? locale, double textScale = 1.0}) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, home) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: home!,
          ),
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

  // One budgeted category → totalBudget > 0, so the Budgets tab is populated and
  // its summary renders (August 2026 is the current month, so the Pace legend
  // shows).
  AppStore budgetedStore() => AppStore(
        accounts: [account('a1')],
        categories: [
          Category(
            id: 'c1',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.local_grocery_store_rounded,
            color: Colors.green,
          ),
        ],
        budgets: [
          Budget(
            id: 'b1',
            name: 'Groceries',
            scope: BudgetScope.categories,
            targets: {'c1'},
            limit: 500,
            anchor: DateTime(2026, 1, 1),
          ),
        ],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  // A store whose only goal is abandoned: `goals` (active) is empty so the Goals
  // tab shows its empty state, but `archivedCount` is 1 — the ••• must stay, or
  // the archived goal is unreachable.
  AppStore archivedGoalStore() => AppStore(
        accounts: [account('a1')],
        categories: const [],
        txns: const [],
        goals: [
          Goal(
            id: 'g1',
            name: 'Old goal',
            source: GoalSource.account('a1'),
            targetAmount: 5000,
            createdAt: DateTime(2026, 1, 1),
            status: GoalStatus.abandoned,
          ),
        ],
        tasks: const [],
      );

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  // The month control is the Budgets tab's only down-chevron; the NO BUDGET SET
  // header uses a right-chevron, the summary none.
  Finder monthControl() => find.byIcon(Icons.keyboard_arrow_down_rounded);

  // The privacy eye (either state) and the ••• Archive button in the header.
  Finder eye() => find.byIcon(Icons.visibility_rounded);
  Finder archiveButton() => find.byIcon(Icons.more_horiz_rounded);

  // The first-run hint names the header +; it is a Text.rich around the glyph.
  Finder hint() => find.textContaining('Start with');

  // ── §1/§2/§5 Budgets ────────────────────────────────────────────────────────

  testWidgets('empty Budgets: no month control, empty state, hint, no pill',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));

    // The month control is gone from the tree — stepping it would only walk from
    // one empty month to another.
    expect(monthControl(), findsNothing);
    // The tab shows its empty state with the new copy.
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Yes, you can afford it'), findsOneWidget);
    // The pill is gone; the header + is the only action, named by the hint.
    expect(find.text('New budget'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'New budget'), findsNothing);
    expect(hint(), findsOneWidget);
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
    // The summary is absent: `$0 left of $0` over real spending is a claim about
    // nothing, so the hero and its Pace legend do not draw (§3.1).
    expect(find.text('Pace'), findsNothing);
    expect(find.textContaining('left of'), findsNothing);
  });

  testWidgets('_BudgetSummary is absent at zero total budget, present with a '
      'budget', (tester) async {
    bigScreen(tester);

    // Zero total budget (only unbudgeted spending) → no summary.
    await tester.pumpWidget(wrap(unbudgetedSpendingStore(), const PlannerScreen()));
    expect(find.text('Pace'), findsNothing);

    // A budgeted category → totalBudget > 0 → the summary renders. August 2026 is
    // current, so its Pace legend shows.
    await tester.pumpWidget(wrap(budgetedStore(), const PlannerScreen()));
    expect(find.text('Pace'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  // ── §1/§3 Schedule ──────────────────────────────────────────────────────────

  testWidgets('no tasks at all: no horizon control, the empty state renders',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));
    await tapTab(tester, 'Schedule');

    expect(find.byType(ScheduleControl), findsNothing);
    expect(find.text('Nothing catches you out'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(hint(), findsOneWidget);
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

  // ── §2 the untouched-Planner header ──────────────────────────────────────────

  testWidgets('fresh store: header has no eye and no •••', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));

    // Nothing money-shaped to mask, nothing archived → both leave the header,
    // and only the + remains.
    expect(eye(), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    expect(archiveButton(), findsNothing);
    // The + is untouched.
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('only archived goals: the ••• stays so Archive is reachable',
      (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(wrap(archivedGoalStore(), const PlannerScreen()));

    // The active goal list is empty, so the Goals tab shows its empty state…
    await tapTab(tester, 'Goals');
    expect(find.byType(EmptyState), findsOneWidget);
    // …but archivedCount is 1, so the header is not "untouched": the ••• stays,
    // and the eye returns too.
    expect(archiveButton(), findsOneWidget);
    expect(eye(), findsOneWidget);
  });

  // ── §4.4 the hint ────────────────────────────────────────────────────────────

  testWidgets('the hint shows on every empty tab and is gone once a tab has '
      'content', (tester) async {
    bigScreen(tester);
    // Empty on all three tabs.
    await tester.pumpWidget(wrap(emptyStore(), const PlannerScreen()));
    expect(hint(), findsOneWidget); // Budgets
    await tapTab(tester, 'Goals');
    expect(hint(), findsOneWidget);
    await tapTab(tester, 'Schedule');
    expect(hint(), findsOneWidget);

    // A budget → the Budgets tab is populated → its hint is gone.
    await tester.pumpWidget(wrap(budgetedStore(), const PlannerScreen()));
    expect(hint(), findsNothing);
  });

  testWidgets('the hint falls back to plain text when the localized string has '
      'no placeholder', (tester) async {
    // A broken localization that lost {plus}: buildFirstRunHint must degrade to a
    // plain readable line with the glyph omitted, never throw (§4.4).
    final sentinel = String.fromCharCode(0);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: buildFirstRunHint('Start with above', sentinel)),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Start with above'), findsOneWidget);
    // No inline add glyph, because there was no placeholder to host it.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  // ── §4.3 the icon does not move between tabs ─────────────────────────────────

  Future<void> expectIconStaysPut(WidgetTester tester,
      {double scale = 1.0}) async {
    await tester.pumpWidget(
        wrap(emptyStore(), const PlannerScreen(), textScale: scale));

    // The 54pt backdrop is centred, so each glyph's centre y is the block's, even
    // though the three glyphs differ in size. Equal centres ⇒ the icon never
    // shifts as the user swipes tabs.
    final budgetsY =
        tester.getCenter(find.byIcon(Icons.pie_chart_outline_rounded)).dy;
    await tapTab(tester, 'Goals');
    final goalsY = tester.getCenter(find.byIcon(Icons.outlined_flag_rounded)).dy;
    await tapTab(tester, 'Schedule');
    final scheduleY =
        tester.getCenter(find.byIcon(Icons.event_available_rounded)).dy;

    expect(goalsY, moreOrLessEquals(budgetsY, epsilon: 0.01));
    expect(scheduleY, moreOrLessEquals(budgetsY, epsilon: 0.01));
  }

  testWidgets('empty tabs: the icon lands on the same y on all three (default '
      'scale)', (tester) async {
    bigScreen(tester);
    await expectIconStaysPut(tester);
  });

  testWidgets('empty tabs: the icon lands on the same y on all three (130% '
      'text)', (tester) async {
    bigScreen(tester);
    await expectIconStaysPut(tester, scale: 1.3);
  });

  // ── §1 the В· regression guard ────────────────────────────────────────────────

  test('no user-visible string in lib contains U+0412 followed by U+00B7', () {
    // The cp1251→UTF-8 round-trip that produced `В·` (U+0412 U+00B7). Scan every
    // .dart under lib/ with line comments stripped (the mojibake that remains in
    // comments is cosmetic, not user-visible) plus every .arb, which is all
    // user-visible text.
    const bug = 'В·';
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.endsWith('.arb')) {
        if (entity.readAsStringSync().contains(bug)) offenders.add(path);
        continue;
      }
      if (!path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        final code = line.contains('//') ? line.substring(0, line.indexOf('//')) : line;
        if (code.contains(bug)) {
          offenders.add(path);
          break;
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'user-visible `В·` mojibake found in: $offenders');
  });
}
