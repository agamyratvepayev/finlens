import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 067.2 — a limit per period (limitOverrides / limitBefore), the readers
// that honour it, and the budget detail's UPCOMING / NOTE / 3pt bars. flutter
// test hangs on this machine; run these by hand.

DateTime _sep26() => DateTime(2026, 9, 26, 10);
DateTime _d(int y, int m, [int day = 1]) => DateTime(y, m, day);

Budget _budget({double limit = 1500, bool rollover = false}) => Budget(
      id: 'b1',
      name: 'Groceries',
      scope: BudgetScope.categories,
      targets: {'c1'},
      limit: limit,
      anchor: _d(2026, 1, 1), // retroactive: runs every month back to Jan 2026
      rollover: rollover,
    );

Category _cat() => Category(
      id: 'c1',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store(Budget b) => AppStore(
      clock: Clock.fixed(_sep26()),
      accounts: const [],
      categories: [_cat()],
      budgets: [b],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

Widget _host(AppStore store, DateTime month) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BudgetDetailScreen(categoryId: 'c1', month: month),
      ),
    );

void main() {
  // ── §1 · budgetLimitFor / budgetEffectiveLimit ────────────────────────────
  test('budgetLimitFor returns the override for its period, usual elsewhere', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);

    expect(store.budgetLimitFor(b, _d(2026, 12, 15)), 2500);
    expect(store.budgetLimitFor(b, _d(2026, 11, 15)), 1500);
    expect(store.budgetLimitFor(b, _d(2027, 1, 15)), 1500);
    expect(store.budgetLimitIsOwn(b, _d(2026, 12, 15)), isTrue);
    expect(store.budgetLimitIsOwn(b, _d(2026, 11, 15)), isFalse);
  });

  test('budgetEffectiveLimit adds the carry, using the overridden prev limit', () {
    final b = _budget(rollover: true);
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);

    // No December spend → the whole 2,500 carries into January, on top of its
    // usual 1,500.
    expect(store.budgetRolloverCarry(b, _d(2027, 1, 15)), 2500);
    expect(store.budgetEffectiveLimit(b, _d(2027, 1, 15)), 4000);
  });

  // ── §2 · Only, back-to-usual, Reset ───────────────────────────────────────
  test('Only December changes December; back to usual removes the entry', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    expect(b.limitOverrides.length, 1);

    store.setBudgetPeriodLimit(b, _d(2026, 12), 1500, andAfter: false);
    expect(b.limitOverrides, isEmpty);

    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    store.resetBudgetPeriodLimit(b, _d(2026, 12));
    expect(b.limitOverrides, isEmpty);
  });

  // ── §2 · And after ────────────────────────────────────────────────────────
  test('And after on December keeps earlier periods, changes December onward', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: true);

    expect(b.limit, 2500);
    expect(b.limitBefore[_d(2026, 12)], 1500);
    // Every period before December — past ones included — still reads 1,500.
    expect(store.budgetLimitFor(b, _d(2026, 6, 15)), 1500);
    expect(store.budgetLimitFor(b, _d(2026, 11, 15)), 1500);
    // December and later read 2,500.
    expect(store.budgetLimitFor(b, _d(2026, 12, 15)), 2500);
    expect(store.budgetLimitFor(b, _d(2027, 3, 15)), 2500);
  });

  test('And after on September keeps August and earlier', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 9), 1800, andAfter: true);
    expect(store.budgetLimitFor(b, _d(2026, 8, 15)), 1500);
    expect(store.budgetLimitFor(b, _d(2026, 9, 15)), 1800);
  });

  test('a run of And-after edits gives the right limit for every month', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 11), 2000, andAfter: true);
    store.setBudgetPeriodLimit(b, _d(2027, 2), 3000, andAfter: true);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: true);

    double lim(int y, int m) => store.budgetLimitFor(b, _d(y, m, 15));
    // Jun–Oct 2026: the original 1,500.
    for (final m in [6, 7, 8, 9, 10]) {
      expect(lim(2026, m), 1500, reason: '2026-$m');
    }
    // November 2026: 2,000.
    expect(lim(2026, 11), 2000);
    // December 2026 onward (Dec's And-after superseded February's): 2,500.
    expect(lim(2026, 12), 2500);
    expect(lim(2027, 1), 2500);
    expect(lim(2027, 2), 2500);
    expect(lim(2027, 6), 2500);
  });

  // ── §2 · the form's whole-budget edit ─────────────────────────────────────
  test('editing the usual limit with limitBefore empty changes every period', () {
    final b = _budget();
    final store = _store(b);
    final cat = store.categoryById('c1')!;
    store.updateBudgetGeneral(b, limit: 2000);
    expect(store.budgetLimitFor(b, _d(2026, 6, 15)), 2000);
    expect(store.budgetLimitFor(b, _d(2027, 1, 15)), 2000);

    // An override equal to the new usual limit is dropped.
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    store.updateBudgetGeneral(b, limit: 2500);
    expect(b.limitOverrides, isEmpty);
    // (cat is unused-friendly; touch it so the analyzer sees intent)
    expect(cat.id, 'c1');
  });

  // ── §5f / hero · the month total honours a period's own limit ─────────────
  test('the month total for December includes the 2,500 override', () {
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    expect(store.totalBudgetFor(_d(2026, 12)), 2500);
    expect(store.totalBudgetFor(_d(2026, 11)), 1500);
  });

  // ── §1 · persistence round-trip ───────────────────────────────────────────
  test('limitOverrides, limitBefore and BudgetEdit.period round-trip', () {
    final b = _budget();
    b.limitOverrides[_d(2026, 12)] = 2500;
    b.limitBefore[_d(2026, 12)] = 1500;
    b.history.add(BudgetEdit(
      at: _d(2026, 9, 26),
      field: 'periodLimit',
      period: _d(2026, 12),
      from: '1,500',
      to: '2,500',
    ));

    final back = budgetFromMap(budgetToMap(b));
    expect(back.limitOverrides[_d(2026, 12)], 2500);
    expect(back.limitBefore[_d(2026, 12)], 1500);
    expect(back.history.single.period, _d(2026, 12));

    // A pre-067.2 row carries neither map, and old history has no period.
    final old = budgetToMap(b)
      ..remove('limit_overrides')
      ..remove('limit_before');
    final loaded = budgetFromMap(old);
    expect(loaded.limitOverrides, isEmpty);
    expect(loaded.limitBefore, isEmpty);
  });

  // ── §5d · UPCOMING lists the next three periods ────────────────────────────
  testWidgets('UPCOMING lists Oct–Dec, December in accentLight', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);

    await tester.pumpWidget(_host(store, _d(2026, 9)));
    await tester.pumpAndSettle();

    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('December 2026'), findsOneWidget);

    // December's own limit is drawn in accentLight.
    final decLimit = find.textContaining('2,500');
    expect(decLimit, findsWidgets);
    expect(tester.widget<Text>(decLimit.first).style!.color,
        AppColors.accentLight);
  });

  testWidgets('UPCOMING is hidden on a past month', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _store(_budget());
    await tester.pumpWidget(_host(store, _d(2026, 8)));
    await tester.pumpAndSettle();
    expect(find.text('UPCOMING'), findsNothing);
  });

  // ── §5e · NOTE shows only with a note ─────────────────────────────────────
  testWidgets('the NOTE card shows only when the budget has a note',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final b = _budget();
    final store = _store(b);

    await tester.pumpWidget(_host(store, _d(2026, 9)));
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsNothing);

    store.setBudgetNote(b, 'Weekly bazaar and the supermarket.');
    await tester.pumpAndSettle();
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('Weekly bazaar and the supermarket.'), findsOneWidget);
  });

  // ── §5c · tapping THIS MONTH opens the sheet ──────────────────────────────
  testWidgets('tapping THIS MONTH opens the period sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = _store(_budget());
    await tester.pumpWidget(_host(store, _d(2026, 9)));
    await tester.pumpAndSettle();

    // Tap inside the THIS MONTH card (its caption), which is the tappable region.
    await tester.tap(find.textContaining('left').first);
    await tester.pumpAndSettle();
    // The sheet's title is the period name — present only in the sheet.
    expect(find.text('September 2026'), findsOneWidget);
  });

  // ── §3 · history rendering ────────────────────────────────────────────────
  testWidgets('history renders Limit for / Limit from / Ends', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final b = _budget();
    final store = _store(b);
    store.setBudgetPeriodLimit(b, _d(2026, 12), 2500, andAfter: false);
    store.setBudgetRunsUntil(b, _d(2027, 6, 30));
    store.setBudgetPeriodLimit(b, _d(2027, 2), 3000, andAfter: true);

    await tester.pumpWidget(_host(store, _d(2026, 9)));
    await tester.pumpAndSettle();

    expect(find.text('Limit for December 2026'), findsOneWidget);
    expect(find.text('Limit from February 2027'), findsOneWidget);
    expect(find.text('Ends'), findsOneWidget);
  });
}
