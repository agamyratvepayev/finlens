import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/balance_screen.dart' show BalanceScreen;
import 'package:finlens/features/insight/category_detail_screen.dart'
    show CategoryDetailScreen;
import 'package:finlens/features/insight/insight_screen.dart' show InsightScreen;
import 'package:finlens/features/insight/see_all_screen.dart' show SeeAllScreen;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/features/more/more_screen.dart' show MoreScreen;
import 'package:finlens/features/planner/planner_screen.dart' show PlannerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 028 — masking is a single global preference, set only in
/// More › Preferences. No header (Balance, Ledger, Insight, Planner, See-all,
/// Category-detail) carries an eye, and no ••• menu carries a mask row; but the
/// preference still hides every figure app-wide.
///
/// The "no eye anywhere" finder is scoped by *pumping each screen on its own* —
/// More (whose `_MaskRow` legitimately uses `visibility_off_rounded`) is never in
/// the tree — so an app-wide `find.byIcon` cannot false-positive on More's icon.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// One account, one budgeted category, one expense: enough to populate every
  /// header (Balance's hero, the Ledger's strip, the Planner's •••).
  AppStore touchedStore() {
    final store = emptyStore();
    final wallet = store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    final food = store.addCategory(
      name: 'Food',
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: AppColors.accent,
      monthlyBudget: 50,
    );
    store.addTxn(
      type: TxnType.expense,
      amount: 12,
      currency: 'USD',
      fromRef: wallet.id,
      toRef: food.id,
      date: DateTime.now(),
    );
    return store;
  }

  Widget host(AppStore store, Widget screen) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: screen),
        ),
      );

  void expectNoEye() {
    expect(find.byIcon(Icons.visibility_rounded), findsNothing,
        reason: 'no unmasked eye');
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing,
        reason: 'no masked eye');
  }

  // ── No eye on any of the six screens, masked or not ──────────────────────────

  for (final masked in const [false, true]) {
    final tag = masked ? 'masked' : 'unmasked';

    testWidgets('Balance: no eye ($tag)', (tester) async {
      final store = touchedStore();
      if (masked) store.toggleMasked();
      await tester.pumpWidget(host(store, const BalanceScreen()));
      await tester.pumpAndSettle();
      expectNoEye();
    });

    testWidgets('Ledger: no eye ($tag)', (tester) async {
      final store = touchedStore();
      if (masked) store.toggleMasked();
      await tester.pumpWidget(host(store, const LedgerScreen()));
      await tester.pumpAndSettle();
      expectNoEye();
    });

    testWidgets('Insight: no eye ($tag)', (tester) async {
      final store = buildSeedStore();
      if (masked) store.toggleMasked();
      await tester.pumpWidget(host(store, const InsightScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expectNoEye();
    });

    testWidgets('Planner: no eye ($tag)', (tester) async {
      final store = touchedStore();
      if (masked) store.toggleMasked();
      await tester.pumpWidget(host(store, const PlannerScreen()));
      await tester.pumpAndSettle();
      expectNoEye();
    });

    testWidgets('See-all: no eye ($tag)', (tester) async {
      final store = buildSeedStore();
      if (masked) store.toggleMasked();
      await tester.pumpWidget(host(store, const SeeAllScreen(income: false)));
      await tester.pumpAndSettle();
      expectNoEye();
    });

    testWidgets('Category-detail: no eye ($tag)', (tester) async {
      final store = buildSeedStore();
      if (masked) store.toggleMasked();
      final cat =
          store.categories.firstWhere((c) => c.type == CategoryType.expense);
      await tester.pumpWidget(
          host(store, CategoryDetailScreen(categoryId: cat.id)));
      await tester.pumpAndSettle();
      expectNoEye();
    });
  }

  // Also: first-run (empty) screens carry no eye either.
  testWidgets('Balance and Ledger first run: no eye', (tester) async {
    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    expectNoEye();

    await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
    await tester.pumpAndSettle();
    expectNoEye();
  });

  // ── Masking still works end to end, driven from More ─────────────────────────

  testWidgets('toggling Mask in More hides figures on Balance and Insight',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    expect(store.masked, isFalse);

    // Toggle the one control, in More › Preferences.
    await tester.pumpWidget(host(store, const MoreScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mask all amounts'));
    await tester.tap(find.text('Mask all amounts'));
    await tester.pumpAndSettle();
    expect(store.masked, isTrue);

    // Every figure now reads ••••, on screens that never had an eye of their own.
    await tester.pumpWidget(host(store, const BalanceScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('••••'), findsWidgets,
        reason: 'Balance figures are masked');

    await tester.pumpWidget(host(store, const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('••••'), findsWidgets,
        reason: 'Insight figures are masked');
  });

  // ── The gaps the eye's removal must not have doubled ──────────────────────────

  double gapRightToLeft(WidgetTester tester, Finder left, Finder right) {
    return tester.getRect(right).left - tester.getRect(left).right;
  }

  /// The header +'s rect — the topmost `add_rounded` (the first-run hint draws
  /// its own inline + lower in the tree).
  Finder headerPlus(WidgetTester tester) {
    final f = find.byIcon(Icons.add_rounded);
    final n = f.evaluate().length;
    var top = 0;
    var bestTop = double.infinity;
    for (var i = 0; i < n; i++) {
      final t = tester.getRect(f.at(i)).top;
      if (t < bestTop) {
        bestTop = t;
        top = i;
      }
    }
    return f.at(top);
  }

  testWidgets('Balance: the date pill sits Insets.sm from the +', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // The date pill's visual box is the Container wrapping its "Today" label.
    final pill = find
        .ancestor(of: find.text('Today'), matching: find.byType(Container))
        .first;
    final gap = gapRightToLeft(tester, pill, headerPlus(tester));
    expect(gap, moreOrLessEquals(Insets.sm, epsilon: 0.5));
  });

  testWidgets('Planner: the ••• sits Insets.sm from the +', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const PlannerScreen()));
    await tester.pumpAndSettle();

    final gap = gapRightToLeft(
      tester,
      find.byIcon(Icons.more_horiz_rounded),
      headerPlus(tester),
    );
    expect(gap, moreOrLessEquals(Insets.sm, epsilon: 0.5));
  });
}
