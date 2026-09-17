import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/insight/insight_screen.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/screen_header.dart' show HeaderCircleButton;
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 039 — the flow identity, the debt block, the corner button.
void main() {
  final today = DateTime(2026, 8, 9);
  final august = RangePreset.thisMonth.resolve(today);

  Widget app(
    AppStore store,
    Widget home, {
    Locale locale = const Locale('en'),
    double scale = 1.0,
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(body: home),
            ),
          ),
        ),
      );

  // ── Fixture builders ───────────────────────────────────────────────────────
  AppStore store({
    required List<Account> accounts,
    List<Category> categories = const [],
    List<Txn> txns = const [],
  }) =>
      AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 12)),
        accounts: accounts,
        categories: categories,
        txns: txns,
        goals: const [],
        tasks: const [],
      );

  Account acc(String id, AccountGroup group, double bal) => Account(
        id: id,
        name: id,
        group: group,
        currency: 'USD',
        startingBalance: bal,
        icon: Icons.circle,
      );

  Category expenseCat(String id) => Category(
        id: id,
        name: id,
        type: CategoryType.expense,
        icon: Icons.circle,
        color: const Color(0xFF888888),
      );

  Category incomeCat(String id) => Category(
        id: id,
        name: id,
        type: CategoryType.income,
        icon: Icons.circle,
        color: const Color(0xFF888888),
      );

  Txn expense(String id, String from, String cat, double amt) => Txn(
        id: id,
        type: TxnType.expense,
        amount: amt,
        currency: 'USD',
        fromRef: from,
        toRef: cat,
        date: DateTime(2026, 8, 5, 10),
      );

  Txn income(String id, String cat, String to, double amt) => Txn(
        id: id,
        type: TxnType.income,
        amount: amt,
        currency: 'USD',
        fromRef: cat,
        toRef: to,
        date: DateTime(2026, 8, 5, 10),
      );

  Txn transfer(String id, String from, String to, double amt) => Txn(
        id: id,
        type: TxnType.transfer,
        amount: amt,
        currency: 'USD',
        fromRef: from,
        toRef: to,
        date: DateTime(2026, 8, 5, 10),
      );

  Future<void> pump(WidgetTester tester, AppStore s,
      {Locale locale = const Locale('en'), double scale = 1.0}) async {
    await tester.pumpWidget(app(s, const InsightScreen(), locale: locale, scale: scale));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ── §1 · the flow identity closes exactly by the transfer leak ──────────────
  group('§1 flow identity', () {
    // Documents the defect: the strip's arithmetic is short by exactly the
    // transfer leak, which no column shows. Expected to pass while the bug lives.
    test('the waterfall gap equals −transferLeak over the seed August', () {
      final s = buildSeedStore();
      final before = s.netWorthOn(DateTime(2026, 7, 31));
      final now = s.netWorthOn(today);
      final cumulative = before +
          s.inflowInWindow(august) -
          s.outflowInWindow(august) +
          s.revaluedInWindow(august);
      final gap = now - cumulative;
      final leak = s.transferLeakInWindow(august);

      expect(leak, closeTo(3.30, 0.01)); // the seed's €→$ transfer fee
      expect(leak.abs(), greaterThan(0.005)); // non-zero: the strip cannot close
      expect(gap, closeTo(-leak, 0.01)); // the gap IS the leak, negated
    });

    test('a window with no transfer has no gap', () {
      final s = store(
        accounts: [acc('a', AccountGroup.spendable, 1000)],
        categories: [expenseCat('c')],
        txns: [expense('t', 'a', 'c', 100)],
      );
      final before = s.netWorthOn(DateTime(2026, 7, 31));
      final now = s.netWorthOn(today);
      final gap = now -
          (before +
              s.inflowInWindow(august) -
              s.outflowInWindow(august) +
              s.revaluedInWindow(august));
      expect(s.transferLeakInWindow(august), closeTo(0, 0.001));
      expect(gap, closeTo(0, 0.001));
    });

    testWidgets('the transfer footnote names the leak when non-zero',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester, buildSeedStore());
      // Seed August leaks $3.30; the footnote states the cost.
      expect(find.textContaining('\$3.30'), findsWidgets);
    });
  });

  // ── §2.1 · insightSidePresent (pure) ────────────────────────────────────────
  group('§2.1 insightSidePresent', () {
    test('all zero → absent', () {
      expect(
          insightSidePresent(balanceNow: 0, delta: 0, moved: 0), isFalse);
    });
    test('balance now only → present', () {
      expect(insightSidePresent(balanceNow: 800, delta: 0, moved: 0), isTrue);
    });
    test('balance before only (now 0, delta ≠ 0) → present', () {
      expect(insightSidePresent(balanceNow: 0, delta: -500, moved: 0), isTrue);
    });
    test('movement only (ends at zero) → present', () {
      expect(insightSidePresent(balanceNow: 0, delta: 0, moved: 300), isTrue);
    });
    test('sub-epsilon everywhere → absent', () {
      expect(insightSidePresent(balanceNow: 0.004, delta: 0.004, moved: 0.004),
          isFalse);
    });
  });

  // ── §2 · the debt block layout ──────────────────────────────────────────────
  group('§2 debt block', () {
    testWidgets('both sides → two cells, a 1pt divider, header DEBT & CREDIT',
        (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, -800),
          acc('inv', AccountGroup.receivables, 500),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)], // keep the window non-empty
      );
      await pump(tester, s);

      expect(find.byKey(const Key('ins-debtside')), findsNWidgets(2));
      expect(find.text('DEBT & CREDIT'), findsOneWidget);
      // A 1pt-wide divider between the cells.
      final dividers = find.byWidgetPredicate((w) =>
          w is SizedBox && w.width == 1 && w.child is ColoredBox);
      expect(dividers, findsOneWidget);
    });

    testWidgets('debt only → one full-width cell, header DEBT', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, -800),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s);

      expect(find.byKey(const Key('ins-debtside')), findsOneWidget);
      expect(find.text('DEBT'), findsOneWidget);
      expect(find.text('DEBT & CREDIT'), findsNothing);
    });

    testWidgets('credit only → one cell, header CREDIT', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [
          acc('inv', AccountGroup.receivables, 500),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s);

      expect(find.byKey(const Key('ins-debtside')), findsOneWidget);
      expect(find.text('CREDIT'), findsOneWidget);
    });

    testWidgets('neither side → no block at all', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [acc('cash', AccountGroup.spendable, 1000)],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s);
      expect(find.byKey(const Key('ins-debtlist')), findsNothing);
    });

    testWidgets('a card that ends at zero after movement still renders',
        (tester) async {
      addTearDown(tester.view.reset);
      // Card opens the window at 0; charged 200, then paid 200 → ends at 0, but
      // it moved, so the debt cell (and both movement rows) still render.
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, 0),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [
          expense('charge', 'card', 'c', 200),
          transfer('pay', 'cash', 'card', 200),
        ],
      );
      await pump(tester, s);
      expect(find.byKey(const Key('ins-debtside')), findsOneWidget);
      expect(find.byKey(const Key('ins-debtmove')), findsNWidgets(2));
    });

    testWidgets('the label sits above the value in the cell', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, -800),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s);

      final cell = find.byKey(const Key('ins-debtside')).first;
      final labelY = tester.getCenter(find.descendant(
          of: cell, matching: find.text('YOUR DEBT'))).dy;
      final valueY = tester
          .getCenter(find
              .descendant(of: cell, matching: find.byType(AmountText))
              .first)
          .dy;
      expect(labelY, lessThan(valueY));
    });

    testWidgets('a zero change renders the word "unchanged", not ▲\$0',
        (tester) async {
      addTearDown(tester.view.reset);
      // The card has a balance but no movement in the window; a separate cash
      // expense keeps the window non-empty.
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, -800),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s);
      final cell = find.byKey(const Key('ins-debtside')).first;
      expect(find.descendant(of: cell, matching: find.text('unchanged')),
          findsOneWidget);
      expect(find.descendant(of: cell, matching: find.text('▲')), findsNothing);
      expect(find.descendant(of: cell, matching: find.text('▼')), findsNothing);
    });
  });

  // ── §2.4 · the delta's arrow & colour (Yön ≠ renk) ──────────────────────────
  group('§2.4 delta arrow & colour', () {
    Future<Color?> arrowColour(WidgetTester tester, AppStore s, String glyph) async {
      await pump(tester, s);
      final cell = find.byKey(const Key('ins-debtside')).first;
      final t = tester.widget<Text>(
          find.descendant(of: cell, matching: find.text(glyph)).first);
      return t.style?.color;
    }

    testWidgets('debt rose → ▲ in the negative colour', (tester) async {
      addTearDown(tester.view.reset);
      // Expense from a bank loan raises debt without a credit-card movement row.
      final s = store(
        accounts: [acc('loan', AccountGroup.bankLoans, -100)],
        categories: [expenseCat('c')],
        txns: [expense('t', 'loan', 'c', 50)],
      );
      expect(await arrowColour(tester, s, '▲'), AppColors.negative);
    });

    testWidgets('debt fell → ▼ in the positive colour', (tester) async {
      addTearDown(tester.view.reset);
      // Income into a bank loan shrinks debt without a "paid" movement row.
      final s = store(
        accounts: [acc('loan', AccountGroup.bankLoans, -100)],
        categories: [incomeCat('c')],
        txns: [income('t', 'c', 'loan', 50)],
      );
      expect(await arrowColour(tester, s, '▼'), AppColors.positive);
    });

    testWidgets('receivable rose → ▲ in the positive colour', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [acc('inv', AccountGroup.receivables, 100)],
        categories: [incomeCat('c')],
        txns: [income('t', 'c', 'inv', 50)],
      );
      expect(await arrowColour(tester, s, '▲'), AppColors.positive);
    });

    testWidgets('receivable fell → ▼ in the negative colour', (tester) async {
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [acc('inv', AccountGroup.receivables, 100)],
        categories: [expenseCat('c')],
        txns: [expense('t', 'inv', 'c', 50)],
      );
      expect(await arrowColour(tester, s, '▼'), AppColors.negative);
    });
  });

  // ── §4 · scaling & a11y ─────────────────────────────────────────────────────
  group('§4 scaling & a11y', () {
    testWidgets('320pt · 130% · ru · seven-figure debt: no overflow, scaled',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = store(
        accounts: [
          acc('card', AccountGroup.creditCards, -1234567),
          acc('inv', AccountGroup.receivables, 987654),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [expenseCat('c')],
        txns: [expense('t', 'cash', 'c', 10)],
      );
      await pump(tester, s, locale: const Locale('ru'), scale: 1.3);
      expect(tester.takeException(), isNull);
      // The value shrinks via FittedBox, never a smaller font constant.
      final cell = find.byKey(const Key('ins-debtside')).first;
      expect(find.descendant(of: cell, matching: find.byType(FittedBox)),
          findsWidgets);
    });

    testWidgets('each cell exposes a semantics label with a direction word',
        (tester) async {
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      final s = store(
        accounts: [
          acc('loan', AccountGroup.bankLoans, -100),
          acc('cash', AccountGroup.spendable, 1000),
        ],
        categories: [incomeCat('c')],
        txns: [income('t', 'c', 'loan', 50)], // debt fell → "down"
      );
      await pump(tester, s);
      expect(find.bySemanticsLabel(RegExp(r'(up|down|unchanged)')),
          findsWidgets);
      handle.dispose();
    });
  });

  // ── §3 · the corner button is the shared widget ─────────────────────────────
  group('§3 corner button', () {
    testWidgets('Insight ••• is a 36×36 HeaderCircleButton, same as Planner',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester, buildSeedStore());
      final insBtn = find.descendant(
        of: find.byType(HeaderCircleButton),
        matching: find.byIcon(Icons.more_horiz_rounded),
      );
      expect(insBtn, findsOneWidget);
      final host = find.ancestor(
          of: find.byIcon(Icons.more_horiz_rounded),
          matching: find.byType(HeaderCircleButton));
      expect(tester.getSize(host.first), const Size(36, 36));
      expect(HeaderCircleButton.diameter, 36);
      // The glyph is the shared 19pt (non-accent), not a 15pt bare clone.
      expect(tester.widget<Icon>(find.byIcon(Icons.more_horiz_rounded)).size, 19);
    });

    testWidgets('Planner ••• is the same HeaderCircleButton widget & size',
        (tester) async {
      addTearDown(tester.view.reset);
      // The seed store already has budgets and goals, so the Planner is
      // "touched" and its ••• menu renders.
      final s = buildSeedStore();
      await tester.pumpWidget(app(s, const PlannerScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      final host = find.ancestor(
          of: find.byIcon(Icons.more_horiz_rounded),
          matching: find.byType(HeaderCircleButton));
      expect(host, findsWidgets);
      expect(tester.getSize(host.first), const Size(36, 36));
    });
  });
}
