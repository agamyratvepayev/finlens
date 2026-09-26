import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/auto_pill.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 067.1 — the reworked budget form (name hero + auto, Spending on, the
// limit named after its period, a Runs row for every period, a note), and the
// month-readers that honour a start-later / has-an-end budget. flutter test
// hangs on this machine; run these by hand.

DateTime _sep26() => DateTime(2026, 9, 26, 10);

Widget _host(AppStore store, Widget home, {Locale? locale}) => StoreScope(
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
        home: home,
      ),
    );

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Category _cat(AppStore store, {String name = 'Groceries'}) => store.addCategory(
      name: name,
      type: CategoryType.expense,
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF34C759),
    );

DateRange _month(DateTime m) =>
    DateRange(DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 0));

void main() {
  // ── §3 · the name hero, derived, marked auto ──────────────────────────────
  testWidgets('create opens with a name hero: donut glyph, derived hint, auto pill',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);

    await tester.pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    expect(find.byType(NameField), findsOneWidget);
    expect(find.byIcon(Icons.donut_large_rounded), findsOneWidget);
    // Empty field with one target → derived name as hint + the auto pill.
    expect(find.text('Groceries'), findsWidgets); // hint + Spending-on value
    expect(find.byType(AutoPill), findsOneWidget);
  });

  testWidgets('typing a name replaces the auto pill with the clear button',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);

    await tester.pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    final nameField =
        find.descendant(of: find.byType(NameField), matching: find.byType(TextField));
    await tester.enterText(nameField, 'Weekly food');
    await tester.pump();

    expect(find.byType(AutoPill), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget); // the clear button
  });

  // ── §4/§5/§6/§7 · the form's rows, monthly ────────────────────────────────
  testWidgets('monthly budget reads Spending on / Monthly limit / Period / Runs',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);

    await tester.pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    expect(find.text('Spending on'), findsOneWidget);
    expect(find.text('Monthly limit'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Every month'), findsOneWidget);
    expect(find.text('Runs'), findsOneWidget);
    expect(find.text('From this month · no end'), findsOneWidget);
    expect(find.text('Roll over unspent'), findsOneWidget);
    expect(find.text('Warn me at'), findsOneWidget);
    // The note card.
    expect(find.byType(NoteRow), findsOneWidget);
    expect(find.text('Add a note'), findsOneWidget);
  });

  // ── §5 · Once hides Roll over and reads "Limit" ───────────────────────────
  testWidgets('once budget reads Limit and hides Roll over unspent',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);

    await tester.pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    // Switch the period to Once via the Period sheet.
    await tester.tap(find.text('Every month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Once'));
    await tester.pumpAndSettle();

    expect(find.text('Limit'), findsOneWidget);
    expect(find.text('Monthly limit'), findsNothing);
    expect(find.text('Roll over unspent'), findsNothing);
  });

  // ── §6d · a months run window saves anchor + runsUntil ────────────────────
  test('addBudget with a Jan–Jun 2027 window stores anchor 1 Jan, end 30 Jun', () {
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);
    final b = store.addBudget(
      scope: BudgetScope.categories,
      targets: {cat.id},
      name: 'Groceries',
      limit: 1500,
      period: BudgetPeriod.month,
      anchor: DateTime(2027, 1, 1),
      repeats: true,
      runsUntil: DateTime(2027, 6, 30),
    );

    expect(b.anchor, DateTime(2027, 1, 1));
    expect(b.runsUntil, DateTime(2027, 6, 30));

    // Starts later: created in September 2026, first period is January 2027.
    expect(store.budgetStartsLater(b), DateTime(2027, 1, 1));

    // Measured in March 2027, not in July 2027, not in August 2026.
    expect(store.budgetRunsIn(b, _month(DateTime(2027, 3))), isTrue);
    expect(store.budgetRunsIn(b, _month(DateTime(2027, 7))), isFalse);
    expect(store.budgetRunsIn(b, _month(DateTime(2026, 8))), isFalse);

    // budgetWindow never advances past the end.
    final w = store.budgetWindow(b, DateTime(2027, 12, 1));
    expect(w.end.isAfter(DateTime(2027, 6, 30, 23, 59, 59, 999)), isFalse);
  });

  test('a start-later budget lists (dimmed) in Sep–Dec 2026, hides in past/after',
      () {
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);
    final b = store.addBudget(
      scope: BudgetScope.categories,
      targets: {cat.id},
      name: 'Groceries',
      limit: 1500,
      period: BudgetPeriod.month,
      anchor: DateTime(2027, 1, 1),
      repeats: true,
      runsUntil: DateTime(2027, 6, 30),
    );

    List<String> ids(DateTime m) => store
        .activeBudgetsByScope(BudgetScope.categories, m)
        .map((x) => x.id)
        .toList();

    // Current + later-before-start months list it (to edit/remove), dimmed.
    expect(ids(DateTime(2026, 9)), contains(b.id));
    expect(ids(DateTime(2026, 12)), contains(b.id));
    // A month it actually runs in lists it.
    expect(ids(DateTime(2027, 3)), contains(b.id));
    // A past month does not.
    expect(ids(DateTime(2026, 8)), isNot(contains(b.id)));
    // A month after the end does not.
    expect(ids(DateTime(2027, 7)), isNot(contains(b.id)));

    // The hero total excludes it until it starts, includes it once it runs.
    expect(store.totalBudgetFor(DateTime(2026, 9)), 0);
    expect(store.totalBudgetFor(DateTime(2027, 3)), 1500);
  });

  test('a one-off with dates ahead is a start-later budget', () {
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);
    final b = store.addBudget(
      scope: BudgetScope.categories,
      targets: {cat.id},
      name: 'Istanbul trip',
      limit: 8000,
      period: BudgetPeriod.days,
      lengthDays: 15,
      anchor: DateTime(2026, 10, 1),
      repeats: false,
      endedAt: DateTime(2026, 10, 15),
    );
    expect(store.budgetStartsLater(b), DateTime(2026, 10, 1));
    // Listed dimmed in September (before it starts), measured in October.
    final sep = store
        .activeBudgetsByScope(BudgetScope.categories, DateTime(2026, 9))
        .map((x) => x.id);
    expect(sep, contains(b.id));
    expect(store.budgetRunsIn(b, _month(DateTime(2026, 10))), isTrue);
  });

  // ── §1 · note & runsUntil round-trip the mapper; old rows default ─────────
  test('note and runsUntil round-trip budgetToMap / budgetFromMap', () {
    final b = Budget(
      id: 'b1',
      name: 'Groceries',
      scope: BudgetScope.categories,
      targets: {'c1'},
      limit: 1500,
      period: BudgetPeriod.month,
      anchor: DateTime(2027, 1, 1),
      repeats: true,
      runsUntil: DateTime(2027, 6, 30),
      note: 'Flights already paid',
    );
    final back = budgetFromMap(budgetToMap(b));
    expect(back.note, 'Flights already paid');
    expect(back.runsUntil, DateTime(2027, 6, 30));

    // A pre-067.1 row carries neither column → '' / null, never a crash.
    final old = budgetToMap(b)
      ..remove('note')
      ..remove('runs_until');
    final loaded = budgetFromMap(old);
    expect(loaded.note, '');
    expect(loaded.runsUntil, isNull);
  });

  // ── §8 · the Task 005 path saves a typed name and never forks a second budget
  test('editing a monthly category budget keeps one budget and takes a name', () {
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);
    store.updateBudget(cat, monthlyBudget: 500);
    final before = store.budgetsForCategory(cat.id).length;

    final b = store.monthlyBudgetForCategory(cat.id)!;
    store.setBudgetName(b, 'Food money');
    store.setBudgetNote(b, 'watch weekends');

    expect(store.budgetsForCategory(cat.id).length, before);
    expect(store.monthlyBudgetForCategory(cat.id)!.name, 'Food money');
    expect(store.monthlyBudgetForCategory(cat.id)!.note, 'watch weekends');
  });

  // ── §6e · setting an end on a repeating budget logs an 'until' edit ───────
  test('setBudgetRunsUntil logs an until edit; a one-off is a no-op', () {
    final store = AppStore.empty(clock: Clock.fixed(_sep26()));
    final cat = _cat(store);
    final rep = store.addBudget(
      scope: BudgetScope.categories,
      targets: {cat.id},
      name: 'Groceries',
      limit: 1000,
      period: BudgetPeriod.month,
      anchor: DateTime(2026, 9, 1),
      repeats: true,
    );
    store.setBudgetRunsUntil(rep, DateTime(2026, 12, 31));
    expect(rep.runsUntil, DateTime(2026, 12, 31));
    expect(rep.history.where((e) => e.field == 'until'), isNotEmpty);

    final once = store.addBudget(
      scope: BudgetScope.categories,
      targets: {cat.id},
      name: 'Trip',
      limit: 500,
      period: BudgetPeriod.days,
      lengthDays: 10,
      anchor: DateTime(2026, 10, 1),
      repeats: false,
      endedAt: DateTime(2026, 10, 10),
    );
    store.setBudgetRunsUntil(once, DateTime(2026, 11, 1));
    expect(once.runsUntil, isNull); // no-op on a one-off
  });
}
