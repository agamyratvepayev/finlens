import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/ledger/trans_filter.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/scoped_ledger_features_test.dart
//
// Transactions are dated within AppStore.today's month (Aug 2026) so the
// default "This month" period shows them; one July row exercises period-
// confined search.

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

Txn _txn(String id, TxnType type, double amount, String from, String to,
        int day,
        {String note = '', List<String> tags = const [], int month = 8}) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, month, day, 12),
      note: note,
      tags: tags,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Savings')],
      categories: [
        _cat('c-food', 'Groceries', CategoryType.expense),
        _cat('c-rent', 'Housing', CategoryType.expense),
        _cat('c-pay', 'Salary', CategoryType.income),
      ],
      txns: [
        _txn('t1', TxnType.expense, 120, 'a1', 'c-food', 3,
            note: 'Groceries', tags: ['food']),
        _txn('t2', TxnType.expense, 50, 'a1', 'c-food', 3, note: 'Snacks'),
        _txn('t3', TxnType.expense, 900, 'a1', 'c-rent', 5,
            note: 'Ağustos kirası'),
        _txn('t4', TxnType.income, 900, 'c-pay', 'a1', 7, note: 'Salary'),
        // Out of the default (August) period, unique word for the search test.
        _txn('t5', TxnType.expense, 40, 'a1', 'c-rent', 20,
            note: 'Zqxrentonly', month: 7),
      ],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const ScopedLedgerScreen(initialScope: AccountScope('a1')),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('day headers under date sort, one flat card under amount sort',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    // dateNewest (default) → one card per day: Aug 3, 5, 7.
    expect(find.byType(LedgerDayCard), findsNWidgets(3));

    store.setTransSort(account: true, sort: TransSort.amountHigh);
    await tester.pump();
    // amount sort → a single flat card, no day headers.
    expect(find.byType(LedgerDayCard), findsOneWidget);
  });

  testWidgets('filter empty state offers Clear filter', (tester) async {
    final store = _store();
    await _pump(tester, store);
    store.setTransFilter('account:a1', const TransFilter(min: 100000));
    await tester.pump();
    expect(find.text('No transactions match your filter'), findsOneWidget);
    expect(find.text('Clear filter'), findsOneWidget);
  });

  testWidgets('a persisted filter shows the narrowed count on first paint',
      (tester) async {
    final store = _store();
    // Set before the screen ever builds.
    store.setTransFilter('account:a1', const TransFilter(types: {TxnType.income}));
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const ScopedLedgerScreen(initialScope: AccountScope('a1')),
      ),
    ));
    // First frame only.
    await tester.pump(Duration.zero);
    // 4 August rows, 1 income → "1 of 4 transactions" without an unfiltered
    // "4 transactions" frame first.
    expect(find.textContaining('of 4 transactions'), findsOneWidget);
  });

  testWidgets('search results are confined to the selected period',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zqxrentonly');
    // Debounce ~200ms.
    await tester.pump(const Duration(milliseconds: 250));
    // The only match is the July row, outside August → no results.
    expect(find.text('0 results'), findsOneWidget);
  });

  testWidgets('search matches within the period and shows a count',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'groceries');
    await tester.pump(const Duration(milliseconds: 250));
    // t1 (note Groceries) + both c-food rows carry the category "Groceries".
    expect(find.textContaining('results'), findsOneWidget);
    expect(find.text('0 results'), findsNothing);
  });
}
