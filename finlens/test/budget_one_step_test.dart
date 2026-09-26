import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// The limit field is one of several TextFields on the form now (name hero, limit,
// note), so tests target it by key.
final _limitField = find.byKey(const Key('budgetLimitField'));

// One screen, two modes (spec §7) — plus the ••• menu's new Remove budget row
// (spec §5) and the store's budget removal (spec §5). flutter test hangs on this
// machine; these are written to be run by hand.

Widget _host(AppStore store, Widget home,
        {Locale? locale, double textScale = 1.0}) =>
    StoreScope(
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
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: home,
        ),
      ),
    );

Category _unbudgeted(AppStore store, {String name = 'Groceries'}) =>
    store.addCategory(
      name: name,
      type: CategoryType.expense,
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF34C759),
    );

Category _budgeted(AppStore store,
    {String name = 'Groceries', double limit = 500}) {
  final c = _unbudgeted(store, name: name);
  store.updateBudget(c, monthlyBudget: limit);
  return c;
}

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

double _rowHeight(WidgetTester tester, String label) {
  final box = find
      .ancestor(
        of: find.text(label),
        matching: find.byType(ConstrainedBox),
      )
      .first;
  return tester.getSize(box).height;
}

void main() {
  // ── §6/§7 · create mode has no history card; edit mode does ────────────────
  testWidgets('create mode renders no spend-history card; edit mode does',
      (tester) async {
    _size(tester, 390, 844);

    // Create mode: no category chosen.
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), const EditBudgetScreen()));
    await tester.pumpAndSettle();
    // Task 029: the create-mode pill now reads "Budget", not "New budget".
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('WHAT YOU ACTUALLY SPENT'), findsNothing);

    // Edit mode: a budgeted category.
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store);
    await tester
        .pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();
    expect(find.text('Edit budget'), findsOneWidget);
    expect(find.text('WHAT YOU ACTUALLY SPENT'), findsOneWidget);
  });

  // ── §1 · edit mode locks the category; tapping the row opens nothing ───────
  testWidgets('edit mode shows a padlock and the Category row is inert',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store, name: 'Grocery');
    await tester
        .pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    // Task 067.1: Spending on and Period are both locked after creation.
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));

    // Tapping the row opens no picker.
    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsNothing); // the picker's header
    expect(find.byType(EditBudgetScreen), findsOneWidget);
  });

  // ── §6 · the edit screen has no Remove budget row ──────────────────────────
  testWidgets('the edit screen carries no Remove budget row', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store);
    await tester
        .pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();
    expect(find.text('Remove budget'), findsNothing);
  });

  // ── §2.3 · Warn me at reads 80% with no limit, folds in the amount live ────
  testWidgets('Warn me at reads 80% until a limit is typed, then live',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgeted(store);
    // Create mode with a category chosen, so only the limit is missing.
    await tester
        .pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    // No limit yet → bare percentage, never "80% · $0".
    expect(find.text('80%'), findsOneWidget);

    await tester.enterText(_limitField, '2000');
    await tester.pump();

    // 80% of 2000 = 1600, folded onto the one line.
    expect(find.text('80%'), findsNothing);
    expect(find.textContaining('80% · '), findsOneWidget);
  });

  // ── §6 · Save gating across category × limit ───────────────────────────────
  testWidgets('Save needs both a category and a positive limit', (tester) async {
    _size(tester, 390, 844);

    // Create mode draws the FormNavBar (its Save is a GestureDetector, not a
    // TextButton); its canSave flag mirrors the form's gate.
    bool saveEnabled() =>
        tester.widget<FormNavBar>(find.byType(FormNavBar)).canSave;

    // No category, no limit → disabled.
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), const EditBudgetScreen()));
    await tester.pumpAndSettle();
    expect(saveEnabled(), isFalse);

    // No category, a limit → still disabled.
    await tester.enterText(_limitField, '100');
    await tester.pump();
    expect(saveEnabled(), isFalse);

    // A category, no limit → disabled; then a limit → enabled.
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgeted(store);
    await tester
        .pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();
    expect(saveEnabled(), isFalse);
    await tester.enterText(_limitField, '100');
    await tester.pump();
    expect(saveEnabled(), isTrue);
  });

  // ── §2/§8 · the four rows measure equal, at 100% and 130% ──────────────────
  for (final scale in [1.0, 1.3]) {
    testWidgets('the four rows measure equal at ${scale}x text scale',
        (tester) async {
      _size(tester, 390, 844);
      final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
      final cat = _budgeted(store);
      await tester.pumpWidget(
          _host(store, EditBudgetScreen(categoryId: cat.id), textScale: scale));
      await tester.pumpAndSettle();

      final h1 = _rowHeight(tester, 'Spending on');
      final h2 = _rowHeight(tester, 'Monthly limit');
      final h3 = _rowHeight(tester, 'Roll over unspent');
      final h4 = _rowHeight(tester, 'Warn me at');
      expect(h2, closeTo(h1, 0.5));
      expect(h3, closeTo(h1, 0.5));
      expect(h4, closeTo(h1, 0.5));
    });
  }

  // ── §5 · the ••• menu is exactly three rows in order ──────────────────────
  testWidgets('the budget detail ••• menu reads Edit / Remove / Archive',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store);
    await tester.pumpWidget(_host(
      store,
      BudgetDetailScreen(categoryId: cat.id, month: store.period),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    final edit = find.widgetWithText(ListTile, 'Edit budget');
    final remove = find.widgetWithText(ListTile, 'Remove budget');
    final archive = find.widgetWithText(ListTile, 'Archive category');
    expect(edit, findsOneWidget);
    expect(remove, findsOneWidget);
    expect(archive, findsOneWidget);

    final ey = tester.getTopLeft(edit).dy;
    final ry = tester.getTopLeft(remove).dy;
    final ay = tester.getTopLeft(archive).dy;
    expect(ey, lessThan(ry));
    expect(ry, lessThan(ay));
  });

  // ── §5 · removing a budget keeps the category, files it under removed ──────
  test('removeBudget leaves the category and files it under removedBudgets', () {
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store);
    expect(store.monthlyBudgetForCategory(cat.id), isNotNull);

    store.removeBudget(cat);

    // The category survives, unarchived, and its transactions are untouched.
    final still = store.categoryById(cat.id);
    expect(still, isNotNull);
    expect(still!.archived, isFalse);
    expect(store.monthlyBudgetForCategory(cat.id), isNull);
    // It now lives in the Archive's REMOVED BUDGETS.
    expect(store.removedBudgets.any((c) => c.id == cat.id), isTrue);
  });

  // ── §8 · 320pt, Turkish, a seven-figure limit — no overflow ────────────────
  testWidgets('no overflow at 320pt in tr with a 2,000,000 limit',
      (tester) async {
    _size(tester, 320, 568);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _budgeted(store, name: 'Ev', limit: 2000000);
    await tester.pumpWidget(_host(
      store,
      EditBudgetScreen(categoryId: cat.id),
      locale: const Locale('tr'),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
