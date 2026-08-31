import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/ledger_filter_sheet_test.dart
//
// The *truthful* unified filter sheet on the MAIN Ledger tab (spec §0–§13).
// Fixture: 24 August-2026 transactions —
//   expenses: Groceries 4, Eating out 5, Housing 0, Transport 3, Shopping 8  (20)
//   income:   Salary 2
//   transfers 2
//   accounts: Main Checking 17, Card 7, Savings 2   (26 incidences; transfers
//             touch two accounts each, so per-account ≤ footer but the sum may
//             exceed it — the real anti-lie invariant is per-item, spec §3)
//   tags:     #fun 2, #coffee 1

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 5000,
    );

Category _cat(String id, String name, CategoryType type) => Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.circle,
      color: const Color(0xFF34C759),
    );

Txn _exp(String id, double amt, String from, String cat, int day,
        {List<String> tags = const []}) =>
    Txn(
      id: id,
      type: TxnType.expense,
      amount: amt,
      currency: 'USD',
      fromRef: from,
      toRef: cat,
      date: DateTime(2026, 8, day, 12),
      tagIds: tags,
    );

AppStore _store() => AppStore(
      accounts: [
        _acc('a1', 'Main Checking'),
        _acc('a2', 'Savings'),
        _acc('a3', 'Card'),
      ],
      categories: [
        _cat('c-food', 'Groceries', CategoryType.expense),
        _cat('c-eat', 'Eating out', CategoryType.expense),
        _cat('c-rent', 'Housing', CategoryType.expense), // 0 this month
        _cat('c-trans', 'Transport', CategoryType.expense),
        _cat('c-shop', 'Shopping', CategoryType.expense),
        _cat('c-pay', 'Salary', CategoryType.income),
      ],
      txns: [
        // Groceries · 4 (t1 tagged #fun)
        _exp('t1', 120, 'a1', 'c-food', 3, tags: ['fun']),
        _exp('t2', 50, 'a1', 'c-food', 4),
        _exp('t3', 30, 'a1', 'c-food', 5),
        _exp('t4', 20, 'a3', 'c-food', 6),
        // Eating out · 5 (t5 #coffee, t6 #fun)
        _exp('t5', 60, 'a1', 'c-eat', 3, tags: ['coffee']),
        _exp('t6', 45, 'a1', 'c-eat', 7, tags: ['fun']),
        _exp('t7', 25, 'a3', 'c-eat', 8),
        _exp('t8', 15, 'a1', 'c-eat', 9),
        _exp('t9', 80, 'a1', 'c-eat', 10),
        // Transport · 3
        _exp('t10', 10, 'a1', 'c-trans', 5),
        _exp('t11', 200, 'a3', 'c-trans', 11),
        _exp('t12', 5, 'a1', 'c-trans', 12),
        // Shopping · 8
        _exp('t13', 35, 'a1', 'c-shop', 2),
        _exp('t14', 40, 'a3', 'c-shop', 3),
        _exp('t15', 22, 'a1', 'c-shop', 4),
        _exp('t16', 18, 'a1', 'c-shop', 6),
        _exp('t17', 60, 'a3', 'c-shop', 8),
        _exp('t18', 75, 'a1', 'c-shop', 13),
        _exp('t19', 12, 'a1', 'c-shop', 14),
        _exp('t20', 90, 'a3', 'c-shop', 19),
        // Salary income · 2
        Txn(
          id: 't21',
          type: TxnType.income,
          amount: 3000,
          currency: 'USD',
          fromRef: 'c-pay',
          toRef: 'a1',
          date: DateTime(2026, 8, 1, 9),
        ),
        Txn(
          id: 't22',
          type: TxnType.income,
          amount: 500,
          currency: 'USD',
          fromRef: 'c-pay',
          toRef: 'a2',
          date: DateTime(2026, 8, 15, 9),
        ),
        // Transfers · 2 (a1→a2, a1→a3)
        Txn(
          id: 't23',
          type: TxnType.transfer,
          amount: 100,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'a2',
          date: DateTime(2026, 8, 16, 9),
        ),
        Txn(
          id: 't24',
          type: TxnType.transfer,
          amount: 250,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'a3',
          date: DateTime(2026, 8, 17, 9),
        ),
      ],
      goals: const [],
      tasks: const [],
    );

/// Seven equal-weight expense categories (Cat A … Cat G) so the EXPENSES section
/// truncates at 5 and the strip reads "2 more categories".
AppStore _manyStore() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [
        for (final n in ['A', 'B', 'C', 'D', 'E', 'F', 'G'])
          _cat('c-$n', 'Cat $n', CategoryType.expense),
      ],
      txns: [
        for (final n in ['A', 'B', 'C', 'D', 'E', 'F', 'G'])
          _exp('t-$n', 10, 'a1', 'c-$n', 5),
      ],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(theme: AppTheme.dark, home: const LedgerScreen()),
  ));
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.filter_alt_outlined));
  await tester.pumpAndSettle();
}

/// The count shown inside a CATEGORIES/ACCOUNTS row (an InkWell holding the
/// row's name and its trailing count Text).
Finder _rowCount(String name, String count) => find.descendant(
      of: find.widgetWithText(InkWell, name),
      matching: find.text(count),
    );

/// The opacity the header Reset is rendered at — 1.0 when a real filter exists,
/// 0.35 when nothing narrows the list.
double _resetOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text('Reset'), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('opens with split categories, no All chip, no Select all (§4/§5/§6)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('DIRECTION'), findsOneWidget);
    // Two category sections replace the single CATEGORIES list (§4).
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('CATEGORIES'), findsNothing);
    expect(find.text('ACCOUNTS'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);

    // The All chip is gone (§5.2); Select all is gone everywhere (§6).
    expect(find.text('All'), findsNothing);
    expect(find.text('Select all'), findsNothing);

    // Nothing selected → the result is everything → Done, not "Show 24 of 24".
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Show 24 of 24'), findsNothing);
  });

  testWidgets('hideEmpty drops zero-count rows; header counts are item counts (§1)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // Housing (0 this month) is not drawn at all — not dimmed, not behind an
    // expander (§1). The four non-zero expense categories show.
    expect(find.text('Housing'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Eating out'), findsOneWidget);

    // "· n" beside the label is the visible item count (§7).
    expect(find.text('· 4'), findsOneWidget); // EXPENSES · 4
    expect(find.text('· 3'), findsOneWidget); // ACCOUNTS · 3 (all non-empty)

    // Account rows carry their period counts (17 / 7 / 2).
    expect(_rowCount('Main Checking', '17'), findsOneWidget);
    expect(_rowCount('Card', '7'), findsOneWidget);
    expect(_rowCount('Savings', '2'), findsOneWidget);
  });

  testWidgets('DIRECTION filters membership + counts; per-item ≤ footer (§2/§3)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Income'));
    await tester.pump();

    // The expense section is *absent* (not dimmed) under Income (§2).
    expect(find.text('EXPENSES'), findsNothing);
    expect(find.text('INCOME'), findsOneWidget);

    // Accounts follow the direction: Main Checking 1, Savings 1, Card hidden.
    expect(_rowCount('Main Checking', '1'), findsOneWidget);
    expect(_rowCount('Savings', '1'), findsOneWidget);
    expect(find.text('Card'), findsNothing);

    // Tags carry no income rows → the whole TAGS section is gone.
    expect(find.text('TAGS'), findsNothing);

    // Footer counts the 2 income rows; both visible account counts (1, 1) are
    // ≤ 2 — the old bug gave 21 vs 2.
    expect(find.text('Show 2 of 24'), findsOneWidget);
    expect(_resetOpacity(tester), 1.0);
  });

  testWidgets('Transfers: category sections gone, one note line, no tags (§5.3)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Transfer'));
    await tester.pump();

    expect(find.text('EXPENSES'), findsNothing);
    expect(find.text('INCOME'), findsNothing);
    expect(find.text('Transfers have no category.'), findsOneWidget);
    expect(find.text('TAGS'), findsNothing);

    // Two transfers touch a1 twice, a2 once, a3 once — each ≤ footer 2.
    expect(_rowCount('Main Checking', '2'), findsOneWidget);
    expect(find.text('Show 2 of 24'), findsOneWidget);
  });

  testWidgets('Revaluation exists as a direction even with no rebalance rows (§5.1)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    expect(find.text('Rebalance'), findsOneWidget); // the fourth chip
    await tester.tap(find.text('Rebalance'));
    await tester.pump();

    expect(find.text('Revaluations move no cash.'), findsOneWidget);
    expect(find.text('EXPENSES'), findsNothing);
  });

  testWidgets('direction chips toggle: re-tapping the selected chip clears it (§5.2)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Expense'));
    await tester.pump();
    expect(find.text('Show 20 of 24'), findsOneWidget);

    // Re-tap clears the direction → back to everything → Done.
    await tester.tap(find.text('Expense'));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('THE §0 REGRESSION: every expense category still filters (§8/§13)',
      (tester) async {
    // On the OLD code, selecting a complete category set left _isActive false —
    // Reset greyed, funnel dark — while the footer dropped below the total.
    // Assert the truthful behaviour: Reset live, footer < 24.
    await _pump(tester, _store());
    await _openSheet(tester);

    for (final c in ['Shopping', 'Eating out', 'Groceries', 'Transport']) {
      await tester.tap(find.text(c));
      await tester.pump();
    }

    // All 20 expenses match; income + transfers drop.
    expect(find.text('Show 20 of 24'), findsOneWidget);
    expect(_resetOpacity(tester), 1.0); // ← the fix: a complete cat set IS a filter
    // Housing is hidden, so 4 of 5 expense categories are selected → not "all".
    expect(find.text('4 selected'), findsOneWidget);
  });

  testWidgets('Select others inverts the visible selection (§6)', (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Select others'), findsOneWidget);

    await tester.tap(find.text('Select others'));
    await tester.pump();

    // Groceries off, the other three on → 3 selected (Eating 5 + Transport 3 +
    // Shopping 8 = 16 rows).
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('Show 16 of 24'), findsOneWidget);
  });

  testWidgets('the badge clears only its own section (§7)', (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Groceries')); // EXPENSES · 1 selected
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Savings')); // ACCOUNTS · 1
    await tester.pump();
    expect(find.text('1 selected'), findsNWidgets(2));

    // Tap the first "1 selected" badge (EXPENSES, above ACCOUNTS in the tree).
    await tester.tap(find.text('1 selected').first);
    await tester.pump();

    // Only the ACCOUNTS selection survives; direction/amount untouched.
    expect(find.text('1 selected'), findsOneWidget);
    // Savings touches t22 (income) + t23 (transfer) = 2 rows.
    expect(find.text('Show 2 of 24'), findsOneWidget);
  });

  testWidgets('complete account selection normalises away (§8)', (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    for (final a in ['Main Checking', 'Savings', 'Card']) {
      await tester.tap(find.widgetWithText(InkWell, a));
      await tester.pump();
    }

    // Every txn touches one of the three accounts, so the result is unchanged →
    // the badge reads "all", the footer stays Done, Reset stays disabled.
    expect(find.text('all'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(_resetOpacity(tester), 0.35);
  });

  testWidgets('search: results count, match headers, sections hide (§11)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.enterText(find.byKey(const ValueKey('filter-search')), 'sa');
    await tester.pump();

    // "Salary" (income) + "Savings" (account) match → 2 results.
    expect(find.text('2 results'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);

    // Each surviving section shows a match count; empty sections + DIRECTION +
    // AMOUNT + TAGS hide while a query is active.
    expect(find.text('· 1 matches'), findsNWidgets(2));
    expect(find.text('EXPENSES'), findsNothing);
    expect(find.text('DIRECTION'), findsNothing);
    expect(find.text('AMOUNT'), findsNothing);
  });

  testWidgets('live count across Expense + Groceries + #fun + min 10 → 1 of 24',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Expense'));
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.ensureVisible(find.text('#fun'));
    await tester.tap(find.text('#fun'));
    await tester.pump();
    await tester.enterText(
      find.descendant(
          of: find.byKey(const ValueKey('filter-min')),
          matching: find.byType(EditableText)),
      '10',
    );
    await tester.pump();

    expect(find.text('Show 1 of 24'), findsOneWidget);
  });

  testWidgets('a selected item that falls to 0 stays visible, dimmed (§1)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    // Switch to Income: Groceries' contextual count is 0, but it is still
    // filtering, so it stays on screen (dimmed) rather than vanishing.
    await tester.tap(find.text('Income'));
    await tester.pump();
    expect(find.text('Groceries'), findsOneWidget);
    final housingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Groceries'), matching: find.byType(Opacity))
          .first,
    );
    expect(housingOpacity.opacity, 0.4);
  });

  testWidgets('masked mode: the amount range reads — (§10)', (tester) async {
    final store = _store();
    await _pump(tester, store);
    // Hide amounts via the Ledger header eye, then open the sheet.
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump();
    await _openSheet(tester);

    // Two em-dashes: the fixed field separator, plus the header range that has
    // fallen back to — rather than leaking a bound (unmasked it would show the
    // money range instead, leaving only the separator).
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('truncation strip shows the remaining count inside the card (§9)',
      (tester) async {
    await _pump(tester, _manyStore());
    await _openSheet(tester);

    // 7 equal categories, 5 shown → "2 more categories".
    expect(find.textContaining('2 more categories'), findsOneWidget);
    expect(find.text('Cat A'), findsOneWidget);
    expect(find.text('Cat G'), findsNothing); // behind the strip

    await tester.tap(find.textContaining('2 more categories'));
    await tester.pump();
    expect(find.text('Cat G'), findsOneWidget); // expanded
  });

  testWidgets('a period change resets the filter (spec §2.2)', (tester) async {
    final store = _store();
    await _pump(tester, store);
    await _openSheet(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded)); // header ✕ closes
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);

    store.shiftPeriod(-1);
    await tester.pump();
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
  });
}
