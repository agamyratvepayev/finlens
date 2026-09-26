import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/theme/app_colors.dart';

// Task 067.3 — the Budgets tab's thin cards (ring, spent-of-limit, the
// remainder over {date} · left|over), the note-on-tap, the swipe actions, and
// the reorder / sort index. flutter test hangs on this machine; run by hand.

DateTime _dec15() => DateTime(2026, 12, 15, 10);
DateTime _d(int y, int m, [int day = 1]) => DateTime(y, m, day);

Category _cat({String id = 'c1', String name = 'Groceries'}) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF34C759),
    );

Budget _budget({
  String id = 'b1',
  String target = 'c1',
  String name = 'Groceries',
  double limit = 1500,
  String currency = '',
  bool repeats = true,
  BudgetPeriod period = BudgetPeriod.month,
  int? lengthDays,
  DateTime? anchor,
  DateTime? endedAt,
  String note = '',
  int? sortIndex,
}) =>
    Budget(
      id: id,
      name: name,
      scope: BudgetScope.categories,
      targets: {target},
      limit: limit,
      currency: currency,
      period: period,
      lengthDays: lengthDays,
      anchor: anchor ?? _d(2026, 1, 1),
      repeats: repeats,
      endedAt: endedAt,
      note: note,
      sortIndex: sortIndex,
    );

AppStore _store({
  required List<Budget> budgets,
  List<Category>? cats,
  List<Txn> txns = const [],
}) =>
    AppStore(
      clock: Clock.fixed(_dec15()),
      baseCurrency: 'TMT',
      accounts: const [],
      categories: cats ?? [_cat()],
      budgets: budgets,
      txns: txns,
      goals: const [],
      tasks: const [],
    );

Txn _spend(String cat, double amount,
        {String currency = 'TMT', DateTime? on}) =>
    Txn(
      id: 't-$cat-$amount',
      type: TxnType.expense,
      amount: amount,
      currency: currency,
      fromRef: 'a1',
      toRef: cat,
      date: on ?? _d(2026, 12, 10),
    );

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlannerScreen(),
      ),
    );

void _size(WidgetTester t, [double w = 390, double h = 844]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

/// The live localizations, so expected strings use the same NBSP/·/token spacing
/// the card renders (a literal with a plain space would never match).
AppLocalizations _lc(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(PlannerScreen)));

void main() {
  // ── §1 · the card's two lines and right column ────────────────────────────
  testWidgets('an own-limit card reads 1,120 of 2,500 TMT / 1,380 TMT · left',
      (tester) async {
    _size(tester);
    final b = _budget();
    final store = _store(budgets: [b], txns: [_spend('c1', 1120)]);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final l = _lc(tester);

    // Line two: spent of the period's own limit, and the limit run is accentLight.
    final lineTwo = find.text(l.bgSpentOfLimit(
        money(1120, currency: 'TMT', withSymbol: false),
        money(2500, currency: 'TMT', withSymbol: true)));
    expect(lineTwo, findsOneWidget);
    final rich = tester.widget<Text>(lineTwo).textSpan as TextSpan;
    var accent = false;
    rich.visitChildren((s) {
      if (s is TextSpan && s.style?.color == AppColors.accentLight) accent = true;
      return true;
    });
    expect(accent, isTrue, reason: 'the own limit is drawn in accentLight');

    // Right column: what is left, over the period's end.
    expect(find.text('${money(1380, currency: 'TMT', withSymbol: false)} TMT'),
        findsOneWidget);
    final end = dayMonth(store.budgetWindow(b, _dec15()).end, l);
    expect(find.text(l.bgCardUntil(end, l.bgCardLeft)), findsOneWidget);

    // No third line, and no bar in the card — the ring carries the fill.
    expect(find.byType(ProgressBar), findsOneWidget); // only the hero
  });

  testWidgets('an over card reads its remainder and over, in negative',
      (tester) async {
    _size(tester);
    final b = _budget(limit: 150);
    final store = _store(budgets: [b], txns: [_spend('c1', 210)]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final l = _lc(tester);

    // Remainder = |150 − 210| = 60, and the state word is "over".
    final figText = '${money(60, currency: 'TMT', withSymbol: false)} TMT';
    expect(find.text(figText), findsOneWidget);
    final end = dayMonth(store.budgetWindow(b, _dec15()).end, l);
    expect(find.text(l.bgCardUntil(end, l.bgCardOver)), findsOneWidget);
    // The figure's number run is negative.
    final fig = tester.widget<Text>(find.text(figText)).textSpan as TextSpan;
    expect((fig.children!.first as TextSpan).style?.color, AppColors.negative);
  });

  testWidgets(r'a USD budget reads $42 of $60 / $18', (tester) async {
    _size(tester);
    final b = _budget(limit: 60, currency: 'USD');
    final store = _store(
        budgets: [b], txns: [_spend('c1', 42, currency: 'USD')]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final l = _lc(tester);

    expect(
        find.text(l.bgSpentOfLimit(money(42, currency: 'USD', withSymbol: true),
            money(60, currency: 'USD', withSymbol: true))),
        findsOneWidget);
    expect(find.text(money(18, currency: 'USD', withSymbol: true)),
        findsOneWidget);
  });

  testWidgets('a one-off card shows its own end date', (tester) async {
    _size(tester);
    final b = _budget(
      repeats: false,
      period: BudgetPeriod.days,
      lengthDays: 14,
      anchor: _d(2026, 12, 20),
      endedAt: _d(2027, 1, 2),
      limit: 1800,
    );
    final store = _store(budgets: [b]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final l = _lc(tester);

    // The window on screen (December) ends at the one-off's own end, 2 Jan.
    final end = dayMonth(store.budgetWindow(b, _dec15()).end, l);
    expect(find.textContaining(end), findsWidgets);
  });

  // ── §3 · the note opens in one line ───────────────────────────────────────
  testWidgets('tapping a card with a note opens one line; another closes it',
      (tester) async {
    _size(tester);
    final a = _budget(id: 'b1', target: 'c1', name: 'Groceries', note: 'Weekly bazaar.');
    final b2 = _budget(id: 'b2', target: 'c2', name: 'Dining', note: 'Team dinners.');
    final store = _store(
      budgets: [a, b2],
      cats: [_cat(id: 'c1', name: 'Groceries'), _cat(id: 'c2', name: 'Dining')],
    );
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    expect(find.text('Weekly bazaar.'), findsNothing);
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly bazaar.'), findsOneWidget);

    // Opening the second card's note closes the first.
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly bazaar.'), findsNothing);
    expect(find.text('Team dinners.'), findsOneWidget);
  });

  testWidgets('a card without a note opens the budget on tap', (tester) async {
    _size(tester);
    final store = _store(budgets: [_budget()]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    // A monthly single-category budget opens its detail.
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
  });

  // ── §4 · swipe for Edit / Remove ──────────────────────────────────────────
  testWidgets('a left swipe reveals Edit and Remove; Edit opens the editor',
      (tester) async {
    _size(tester);
    final store = _store(budgets: [_budget()]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Groceries'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(EditBudgetScreen), findsOneWidget);
  });

  testWidgets('Remove confirms and leaves the Planner on a decline',
      (tester) async {
    _size(tester);
    final store = _store(budgets: [_budget()]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Groceries'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // The monthly-category confirmation sheet appears; declining keeps the tab.
    expect(find.text('Cancel'), findsWidgets);
    expect(store.monthlyBudgetForCategory('c1'), isNotNull);
    expect(find.byType(PlannerScreen), findsOneWidget);
  });

  // ── §1e · a not-started budget is dimmed and reads "starts" ───────────────
  testWidgets('a January budget in December reads dimmed 1,500 TMT / … starts',
      (tester) async {
    _size(tester);
    // Anchored January 2027, created now (December 2026): it starts later.
    final b = _budget(anchor: _d(2027, 1, 1));
    final store = _store(budgets: [b]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final l = _lc(tester);

    // The figure is the limit; the sub-line reads "{start} · starts".
    expect(find.text('${money(1500, currency: 'TMT', withSymbol: false)} TMT'),
        findsOneWidget);
    expect(find.text(l.bgCardUntil('1 Jan', l.bgCardStarts)), findsOneWidget);
    // Line two reads "of {limit}" — nothing spent yet.
    expect(find.text(l.bgOfLimit(money(1500, currency: 'TMT', withSymbol: true))),
        findsOneWidget);
  });

  // ── §6 · the hero bar is 3pt ──────────────────────────────────────────────
  testWidgets('the hero summary bar is 3pt', (tester) async {
    _size(tester);
    final store = _store(budgets: [_budget()], txns: [_spend('c1', 500)]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(bar.height, 3);
  });

  // ── §5 · reorder / sort index (store) ─────────────────────────────────────
  test('moveBudget renumbers the whole scope and persists', () {
    final a = _budget(id: 'b1', target: 'c1');
    final b = _budget(id: 'b2', target: 'c2');
    final c = _budget(id: 'b3', target: 'c3');
    final store = _store(
      budgets: [a, b, c],
      cats: [
        _cat(id: 'c1', name: 'A'),
        _cat(id: 'c2', name: 'B'),
        _cat(id: 'c3', name: 'C'),
      ],
    );
    // Unindexed → creation (anchor) order, tie broken by id: b1, b2, b3.
    var order = store.activeBudgetsByScope(BudgetScope.categories, _dec15());
    expect(order.map((x) => x.id), ['b1', 'b2', 'b3']);

    // Move c to the front.
    store.moveBudget(c, before: a);
    order = store.activeBudgetsByScope(BudgetScope.categories, _dec15());
    expect(order.map((x) => x.id), ['b3', 'b1', 'b2']);
    // The whole scope was renumbered, no collisions.
    final indices = [a.sortIndex, b.sortIndex, c.sortIndex]..sort();
    expect(indices, [0, 1, 2]);
  });

  test('a new budget lands last; a running one-off can be moved', () {
    final a = _budget(id: 'b1', target: 'c1', sortIndex: 0);
    final oneOff = _budget(
      id: 'b2',
      target: 'c2',
      repeats: false,
      period: BudgetPeriod.days,
      lengthDays: 20,
      anchor: _d(2026, 12, 10),
      endedAt: _d(2026, 12, 30),
      sortIndex: 1,
    );
    final fresh = _budget(id: 'b3', target: 'c3'); // no index → lands last
    final store = _store(
      budgets: [a, oneOff, fresh],
      cats: [
        _cat(id: 'c1', name: 'A'),
        _cat(id: 'c2', name: 'B'),
        _cat(id: 'c3', name: 'C'),
      ],
    );
    var order = store.activeBudgetsByScope(BudgetScope.categories, _dec15());
    expect(order.last.id, 'b3'); // unindexed new one is last among running

    // The one-off (still running on 15 Dec) can be moved to the front.
    store.moveBudget(oneOff, before: a);
    order = store.activeBudgetsByScope(BudgetScope.categories, _dec15());
    expect(order.first.id, 'b2');
  });

  test('a past-end one-off sorts below the running budgets', () {
    final running = _budget(id: 'b1', target: 'c1', sortIndex: 5);
    final past = _budget(
      id: 'b2',
      target: 'c2',
      repeats: false,
      period: BudgetPeriod.days,
      lengthDays: 10,
      anchor: _d(2026, 11, 1),
      endedAt: _d(2026, 11, 10), // ended before 15 Dec
      sortIndex: 0,
    );
    final store = _store(
      budgets: [running, past],
      cats: [_cat(id: 'c1', name: 'A'), _cat(id: 'c2', name: 'B')],
    );
    final order = store.activeBudgetsByScope(BudgetScope.categories, _dec15());
    expect(order.map((x) => x.id), ['b1', 'b2']); // past-end last despite index 0
    expect(store.budgetPastEnd(past), isTrue);
  });

  // ── §5 · sortIndex round-trips ────────────────────────────────────────────
  test('sortIndex round-trips the mapper; an old row loads null', () {
    final b = _budget(sortIndex: 7);
    final back = budgetFromMap(budgetToMap(b));
    expect(back.sortIndex, 7);
    final old = budgetToMap(b)..remove('sort_index');
    expect(budgetFromMap(old).sortIndex, isNull);
  });
}
