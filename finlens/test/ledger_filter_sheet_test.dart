import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/ledger_filter_sheet_test.dart
//
// The unified filter sheet on the MAIN Ledger tab. Fixture: 24 August-2026
// transactions — Groceries 4, Eating out 5, Housing 0, tags #fun · 2,
// #coffee · 1 — so the acceptance numbers (spec §6) are exact.

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
      tags: tags,
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
        // Transfers · 2
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

void main() {
  testWidgets('funnel opens the unified sheet in spec order (§6)',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('DIRECTION'), findsOneWidget);
    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('ACCOUNTS'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    // Sticky footer live count, nothing selected → everything passes.
    expect(find.text('Show 24 of 24'), findsOneWidget);
  });

  testWidgets('per-item counts: Groceries 4, Eating out 5, Housing 0 dimmed',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    expect(_rowCount('Groceries', '4'), findsOneWidget);
    expect(_rowCount('Eating out', '5'), findsOneWidget);

    // 6 categories → the first 5 (by count) show; Housing (0) sits behind the
    // per-section expander. Expand to reveal it.
    await tester.tap(find.text('Show all 6'));
    await tester.pump();
    expect(_rowCount('Housing', '0'), findsOneWidget);

    // Housing (0) is wrapped in a 40%-opacity layer but stays a live row.
    final housingOpacity = tester.widget<Opacity>(
      find.ancestor(
          of: find.text('Housing'), matching: find.byType(Opacity)).first,
    );
    expect(housingOpacity.opacity, 0.4);

    // Tag chips carry counts too.
    expect(find.text('#fun'), findsOneWidget);
    expect(find.text('#coffee'), findsOneWidget);
  });

  testWidgets('live count across Expenses + Groceries + #fun + min 10 → 1 of 24',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Expenses'));
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

  testWidgets('Select all on ACCOUNTS, then untick one → everything-except',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // ACCOUNTS' Select all (CATEGORIES also has one — take the 2nd control).
    final selectAll = find.text('Select all');
    await tester.tap(selectAll.at(1));
    await tester.pump();

    // All three accounts touch every txn → still 24; header flips to Clear.
    expect(find.text('Show 24 of 24'), findsOneWidget);
    expect(find.text('· 3 selected'), findsOneWidget);
    expect(find.text('Clear'), findsWidgets);

    // Untick the Card account → the everything-except-Card lens; count drops.
    await tester.tap(find.widgetWithText(InkWell, 'Card'));
    await tester.pump();
    expect(find.text('Show 24 of 24'), findsNothing);
    expect(find.textContaining('of 24'), findsOneWidget);
  });

  testWidgets('in-sheet search narrows to matches; empty sections hide',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey('filter-search')),
      'ca',
    );
    await tester.pump();

    // Only "Card" matches — CATEGORIES and TAGS hide entirely.
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('CATEGORIES'), findsNothing);
    expect(find.text('Main Checking'), findsNothing);

    // Select all with the query active selects only the visible match.
    await tester.tap(find.text('Select all'));
    await tester.pump();
    // Clear the query (field ✕) — the single selection persists.
    await tester.enterText(
      find.byKey(const ValueKey('filter-search')),
      '',
    );
    await tester.pump();
    expect(find.text('· 1 selected'), findsOneWidget);
  });

  testWidgets('direction switch dims categories without clearing selections',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Groceries'));
    await tester.pump();
    // A selection is now present in CATEGORIES.
    expect(find.text('· 1 selected'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pump();

    // Groceries (an expense category) now reads 0 in the income context and
    // dims — but the selection is preserved (still · 1 selected).
    expect(_rowCount('Groceries', '0'), findsOneWidget);
    expect(find.text('· 1 selected'), findsOneWidget);
  });

  testWidgets('Reset clears every dimension and disables when empty',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Expenses'));
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.enterText(
      find.descendant(
          of: find.byKey(const ValueKey('filter-max')),
          matching: find.byType(EditableText)),
      '100',
    );
    await tester.pump();

    await tester.tap(find.text('Reset'));
    await tester.pump();

    // Back to the unfiltered lens.
    expect(find.text('Show 24 of 24'), findsOneWidget);
    expect(find.text('· 1 selected'), findsNothing);
  });

  testWidgets('a period change resets the filter (tags + amount too)',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    await _openSheet(tester);

    await tester.ensureVisible(find.text('#fun'));
    await tester.tap(find.text('#fun'));
    await tester.pump();
    await tester.enterText(
      find.descendant(
          of: find.byKey(const ValueKey('filter-min')),
          matching: find.byType(EditableText)),
      '5',
    );
    await tester.pump();
    // Close via the header ✕ (the only close_rounded while the query is empty).
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // The funnel is now active.
    expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);

    // Move to the previous month — the lens (incl. tags + amount) resets.
    store.shiftPeriod(-1);
    await tester.pump();
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

    // Reopening shows an empty filter over the new (empty) period.
    await _openSheet(tester);
    expect(find.text('Show 0 of 0'), findsOneWidget);
  });
}
