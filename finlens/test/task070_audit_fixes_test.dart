import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/planner/widgets/amount_override_sheet.dart';
import 'package:finlens/features/planner/widgets/runs_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/undo_bar.dart';

// Task 070 — one regression test per audit fix. flutter test hangs on this
// machine; run these by hand.

DateTime _dec15() => DateTime(2026, 12, 15, 10);
DateTime _d(int y, int m, [int day = 1]) => DateTime(y, m, day);

Widget _host(AppStore store, Widget home) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Category _cat({String id = 'c1', String name = 'Groceries', CategoryType type = CategoryType.expense}) =>
    Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF34C759),
    );

Budget _monthly({
  String id = 'b1',
  String target = 'c1',
  String name = 'Groceries',
  double limit = 1500,
  String currency = '',
}) =>
    Budget(
      id: id,
      name: name,
      scope: BudgetScope.categories,
      targets: {target},
      limit: limit,
      currency: currency,
      anchor: _d(2026, 1, 1),
    );

AppStore _store({List<Budget> budgets = const [], List<Category>? cats, List<Account>? accounts, List<Task> tasks = const []}) =>
    AppStore(
      clock: Clock.fixed(_dec15()),
      baseCurrency: 'TMT',
      accounts: accounts ?? const [],
      categories: cats ?? [_cat()],
      budgets: budgets,
      txns: const [],
      goals: const [],
      tasks: tasks,
    );

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

void main() {
  // ── A3 · archived series count toward the Archive ─────────────────────────
  test('A3: archiving a series raises archivedCount', () {
    final task = Task(
      id: 't1',
      title: 'Rent',
      linkedAccountId: '',
      expectedAmount: 100,
      dueDate: _d(2026, 12, 1),
      icon: Icons.home_rounded,
    );
    final store = _store(tasks: [task]);
    final before = store.archivedCount;
    store.archiveTask(task);
    expect(store.archivedTasks, hasLength(1));
    expect(store.archivedCount, before + 1);
  });

  // ── A6 · the hero caption counts the month's off-hero budgets ─────────────
  test('A6: budgetsOffMonthHeroFor counts this month only', () {
    final weekly = Budget(
      id: 'w',
      name: 'Coffee',
      scope: BudgetScope.categories,
      targets: {'c1'},
      limit: 150,
      period: BudgetPeriod.days,
      lengthDays: 7,
      anchor: _d(2026, 1, 5),
    );
    // A monthly budget that starts next month (January 2027): not this month.
    final startsNext = _monthly(id: 'n', target: 'c2', name: 'Gifts')
      ..anchor = _d(2027, 1, 1);
    // A one-off that ended last month.
    final endedLast = Budget(
      id: 'e',
      name: 'Trip',
      scope: BudgetScope.categories,
      targets: {'c3'},
      limit: 500,
      period: BudgetPeriod.days,
      lengthDays: 10,
      anchor: _d(2026, 11, 1),
      repeats: false,
      endedAt: _d(2026, 11, 10),
    );
    final store = _store(budgets: [weekly, startsNext, endedLast], cats: [
      _cat(id: 'c1', name: 'Coffee'),
      _cat(id: 'c2', name: 'Gifts'),
      _cat(id: 'c3', name: 'Trip'),
    ]);
    // Only the weekly runs on its own clock this month.
    expect(store.budgetsOffMonthHeroFor(_dec15()), 1);
  });

  // ── B7 · per-period history, reset amber, currency-agnostic totals ────────
  test('B7: "and after" logs a Limit-from row when the usual limit changes', () {
    final b = _monthly();
    final store = _store(budgets: [b]);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    // Now save the same 2,500 as "and after": D already carried 2,500, but the
    // usual limit moves 1,500 → 2,500, so a row must appear (task 070 B7).
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: true);
    final row = b.history.lastWhere((e) => e.field == 'limit');
    expect(row.period, _d(2026, 12));
    expect(row.from, contains('1,500'));
    expect(row.to, contains('2,500'));
    expect(row.amber, isTrue);
  });

  test('B7: a reset that raises the limit is amber', () {
    final b = _monthly();
    final store = _store(budgets: [b]);
    // December's own limit is lower than usual; resetting it raises to 1,500.
    store.setBudgetPeriodLimit(b, _d(2026, 12), 1000, andAfter: false);
    store.resetBudgetPeriodLimit(b, _d(2026, 12));
    final row = b.history.lastWhere((e) => e.field == 'periodLimit');
    expect(row.amber, isTrue);
  });

  test('B7: a USD monthly budget changes neither the total nor left', () {
    final tmt = _monthly(id: 'b1', target: 'c1', limit: 1000);
    final usd = _monthly(id: 'b2', target: 'c2', name: 'Subs', limit: 60, currency: 'USD');
    final store = _store(budgets: [tmt, usd], cats: [
      _cat(id: 'c1'),
      _cat(id: 'c2', name: 'Subs'),
    ]);
    // The USD budget sits outside the reporting-currency total, and its spend is
    // excluded from left (task 070 B7): total and left rest on the TMT budget.
    expect(store.totalBudgetFor(_dec15()), 1000);
    expect(store.leftThisMonth(_dec15()), 1000);
  });

  // ── A2 · editing a multi-category budget does not throw ───────────────────
  testWidgets('A2: a two-category budget opens empty (auto), no exception',
      (tester) async {
    _size(tester);
    final b = Budget(
      id: 'b1',
      name: 'Groceries + 1', // equals the derived name → reads as auto
      scope: BudgetScope.categories,
      targets: {'c1', 'c2'},
      limit: 1500,
      anchor: _d(2026, 1, 1),
    );
    final store = _store(budgets: [b], cats: [
      _cat(id: 'c1', name: 'Groceries'),
      _cat(id: 'c2', name: 'Dining'),
    ]);
    await tester.pumpWidget(_host(store, EditBudgetScreen(budgetId: 'b1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The name field is empty (auto): the `auto` pill and the derived-name hint
    // both show, and the custom name never appears typed.
    expect(find.text('auto'), findsOneWidget);
    expect(find.text('Groceries + 1'), findsOneWidget); // the hint
  });

  testWidgets('A2: a custom-named budget opens prefilled', (tester) async {
    _size(tester);
    final b = Budget(
      id: 'b1',
      name: 'Holiday food',
      scope: BudgetScope.categories,
      targets: {'c1', 'c2'},
      limit: 1500,
      anchor: _d(2026, 1, 1),
    );
    final store = _store(budgets: [b], cats: [
      _cat(id: 'c1', name: 'Groceries'),
      _cat(id: 'c2', name: 'Dining'),
    ]);
    await tester.pumpWidget(_host(store, EditBudgetScreen(budgetId: 'b1')));
    await tester.pumpAndSettle();
    expect(find.text('Holiday food'), findsOneWidget);
  });

  // ── A5 · the amount sheet masks the "usually" line ────────────────────────
  testWidgets('A5: the amount sheet reads "usually ••••" when masked',
      (tester) async {
    _size(tester);
    await tester.pumpWidget(_host(
      _store(budgets: [_monthly()]),
      Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAmountOverrideSheet(
                context,
                title: 'December 2026',
                initialMagnitude: 1500,
                usualMagnitude: 1500,
                currencyCode: 'TMT',
                hasOverride: false,
                masked: true,
                onlyLabel: 'Only December 2026',
                andAfterLabel: 'December 2026 and after',
                onSave: (_, _) {},
                onReset: () {},
              ),
              child: const Text('open'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('••••'), findsWidgets);
  });

  // ── A7 · Runs: with No end on, a tap sets FROM ────────────────────────────
  testWidgets('A7: with No end on, tapping a month sets FROM not UNTIL',
      (tester) async {
    _size(tester);
    RunsResult? result;
    await tester.pumpWidget(_host(
      _store(budgets: [_monthly()]),
      Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showRunsSheet(
                  context,
                  mode: RunsMode.months,
                  once: false,
                  strideDays: 30,
                  today: _dec15(),
                  initialFrom: _d(2026, 1, 1),
                  initialUntil: null, // No end on
                  fromLocked: false,
                  subtitle: 'Every month',
                );
              },
              child: const Text('open'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No end is on: tapping June moves FROM, not UNTIL.
    await tester.tap(find.text('Jun'));
    await tester.pumpAndSettle();
    expect(find.text('Jun 2026'), findsOneWidget); // FROM pill
    expect(find.text('No end'), findsOneWidget); // UNTIL still No end

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.from, _d(2026, 6, 1));
    expect(result!.until, isNull);
  });

  // ── B2 · receivable mode clears an expense category ───────────────────────
  testWidgets('B2: entering receivable mode clears an expense category',
      (tester) async {
    _size(tester);
    final task = Task(
      id: 't1',
      title: 'Loan back',
      linkedAccountId: 'r1',
      categoryId: 'c1', // an expense category
      expectedAmount: 500,
      dueDate: _d(2026, 12, 20),
      icon: Icons.home_rounded,
    );
    final store = _store(
      accounts: [
        Account(
          id: 'r1',
          name: 'Owed by Sam',
          group: AccountGroup.receivables,
          currency: 'TMT',
          startingBalance: 0,
        ),
      ],
      cats: [_cat(id: 'c1', name: 'Groceries')],
      tasks: [task],
    );
    await tester.pumpWidget(_host(store, const EditTaskScreen(taskId: 't1')));
    await tester.pumpAndSettle();
    // The linked account is a receivable, so on entry the expense category is
    // cleared — "Groceries" no longer shows as the chosen category.
    expect(find.text('Groceries'), findsNothing);
  });

  // ── A4 · the undo bar undoes and is transient ─────────────────────────────
  testWidgets('A4: showUndoBarOn shows a dismissable bar and undoes',
      (tester) async {
    var undone = false;
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(_host(
      _store(budgets: const []),
      Builder(builder: (context) {
        return Scaffold(
          body: Builder(builder: (inner) {
            messenger = ScaffoldMessenger.of(inner);
            return Center(
              child: ElevatedButton(
                onPressed: () => showUndoBarOn(
                  messenger,
                  message: 'Deleted',
                  onUndo: () => undone = true,
                  actionLabel: 'Undo',
                ),
                child: const Text('go'),
              ),
            );
          }),
        );
      }),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, isTrue);
  });
}
