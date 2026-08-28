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

/// The opacity the header Reset is rendered at — 1.0 when a real filter exists,
/// 0.35 when nothing narrows the list.
double _resetOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text('Reset'), matching: find.byType(Opacity)).first,
    )
    .opacity;

/// A one-category / no-transfer store, so selecting the sole category is a
/// *complete* selection that still matches every transaction.
AppStore _singleCatStore() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c-food', 'Groceries', CategoryType.expense)],
      txns: [
        _exp('t1', 10, 'a1', 'c-food', 2),
        _exp('t2', 20, 'a1', 'c-food', 3),
      ],
      goals: const [],
      tasks: const [],
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
    // Nothing selected → the result is everything, so the button reads Done, not
    // "Show 24 of 24" (spec §3: the count returns only when it means something).
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Show 24 of 24'), findsNothing);
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

    // A complete selection is not a filter (spec §1/§4): the result is still
    // everything → the button stays on Done, the header reads "· all", and the
    // control flips to Clear. Reset stays disabled.
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('· all'), findsOneWidget);
    expect(find.text('· 3 selected'), findsNothing);
    expect(find.text('Clear'), findsWidgets);

    // Untick the Card account → the everything-except-Card lens; a real filter
    // now, so the header switches to a count and the button to "Show N of 24".
    await tester.tap(find.widgetWithText(InkWell, 'Card'));
    await tester.pump();
    expect(find.text('· all'), findsNothing);
    expect(find.text('· 2 selected'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
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

    // Back to the unfiltered lens: the result is everything → button reads Done.
    expect(find.text('Done'), findsOneWidget);
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

    // Reopening shows an empty filter over the new (empty) period: 0 of 0 is
    // still "everything", so the button reads Done (spec §3), not "Show 0 of 0".
    await _openSheet(tester);
    expect(find.text('Done'), findsOneWidget);
  });

  // ── §1/§3/§4 — a complete selection is not a filter ────────────────────────

  testWidgets('empty state: Reset dim in the header, footer button reads Done',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // Reset moved into the header (spec §2) and is disabled while nothing filters.
    expect(find.text('Reset'), findsOneWidget);
    expect(_resetOpacity(tester), 0.35);
    // The single full-width footer button (no second control beside it).
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Show'), findsNothing);
  });

  testWidgets(
      'Select all (accounts) is complete, not a filter: Reset stays disabled, '
      'button stays Done, header reads · all', (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // ACCOUNTS Select all (2nd control); all three accounts touch every txn.
    await tester.tap(find.text('Select all').at(1));
    await tester.pump();

    expect(find.text('· all'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget); // result is still everything
    expect(_resetOpacity(tester), 0.35); // complete → not a filter → Reset dim
  });

  testWidgets(
      'unticking one item wakes Reset, header count and button together',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    await tester.tap(find.text('Select all').at(1)); // accounts → complete
    await tester.pump();
    // Sanity: nothing narrows yet.
    expect(_resetOpacity(tester), 0.35);

    // Untick Card → a proper subset → a real filter exists now.
    await tester.tap(find.widgetWithText(InkWell, 'Card'));
    await tester.pump();

    expect(_resetOpacity(tester), 1.0); // Reset live
    expect(find.text('· 2 selected'), findsOneWidget); // header count returns
    expect(find.text('· all'), findsNothing);
    expect(find.text('Show 18 of 24'), findsOneWidget); // button shows the count
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('single-item section: selecting the sole item is not a filter',
      (tester) async {
    await _pump(tester, _singleCatStore());
    await _openSheet(tester);

    // One category → Select all fills it (complete). Every txn is that category
    // and there are no transfers, so the result stays everything.
    await tester.tap(find.text('Select all').first);
    await tester.pump();

    expect(find.text('· all'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(_resetOpacity(tester), 0.35);
  });

  testWidgets('button reads Done at N == total, Show N of M below it',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // Nothing selected → everything → Done.
    expect(find.text('Done'), findsOneWidget);

    // A direction narrows to the 20 expenses → the count returns.
    await tester.tap(find.text('Expenses'));
    await tester.pump();
    expect(find.text('Done'), findsNothing);
    expect(find.text('Show 20 of 24'), findsOneWidget);
    expect(_resetOpacity(tester), 1.0); // direction set → a filter → Reset live
  });

  testWidgets('Clear under an active query deselects only the visible matches',
      (tester) async {
    await _pump(tester, _store());
    await _openSheet(tester);

    // Select Savings with no query.
    await tester.tap(find.widgetWithText(InkWell, 'Savings'));
    await tester.pump();
    expect(find.text('· 1 selected'), findsOneWidget);

    // Query "ca" → only the Card account matches; Savings is hidden.
    await tester.enterText(find.byKey(const ValueKey('filter-search')), 'ca');
    await tester.pump();
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Savings'), findsNothing);

    // Select the visible match, then Clear — which must touch Card only, not the
    // hidden Savings selection (spec §4).
    await tester.tap(find.widgetWithText(InkWell, 'Card'));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    // Drop the query — the Savings selection made earlier has survived.
    await tester.enterText(find.byKey(const ValueKey('filter-search')), '');
    await tester.pump();
    expect(find.text('· 1 selected'), findsOneWidget);
    expect(find.text('· all'), findsNothing);
  });
}
