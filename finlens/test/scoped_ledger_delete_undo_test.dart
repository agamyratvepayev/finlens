import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/scoped_ledger_delete_undo_test.dart
//
// The regression these guard: since Flutter 3.37 an actionable SnackBar does
// not auto-dismiss, so _deleteWithUndo's `.closed` future never fired on its
// own — the row was hidden but the transaction stayed in the store, and every
// balance still counted it. The fix is showUndoBar's persist: false.

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 5000,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

Txn _txn(String id, double amount, int day, {String note = ''}) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c-food',
      date: DateTime(2026, 8, day, 12),
      note: note,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c-food', 'Groceries')],
      txns: [
        _txn('t1', 120, 3, note: 'Groceries'),
        _txn('t2', 50, 4, note: 'Snacks'),
      ],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ScopedLedgerScreen(initialScope: AccountScope('a1')),
    ),
  ));
  await tester.pump();
}

/// Swipes the given row open and taps its Delete action.
Future<void> _swipeDelete(WidgetTester tester, Finder row) async {
  await tester.drag(row, const Offset(-260, 0));
  await tester.pumpAndSettle(); // open the action strip
  await tester.tap(find.text('Delete'));
  await tester.pump(); // show the undo bar
}

bool _hasTxn(AppStore store, String id) => store.txns.any((t) => t.id == id);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('left alone, the delete commits after the window — the real bug',
      (tester) async {
    final store = _store();
    await _pump(tester, store);

    // Balance counts both expenses up front: 5000 − 120 − 50 = 4830.
    expect(store.balanceOf('a1'), 4830);

    await _swipeDelete(tester, find.byType(LedgerTxnRow).first);

    // While the bar is up the row is hidden but the store is unchanged — the
    // balance still counts the "deleted" transaction.
    expect(find.text('Transaction deleted'), findsOneWidget);
    expect(_hasTxn(store, 't1'), isTrue);
    expect(store.balanceOf('a1'), 4830);

    // Let the window expire and the exit animation run.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Now the deletion is committed: the txn is gone and the balance moved.
    expect(_hasTxn(store, 't1'), isFalse);
    expect(store.balanceOf('a1'), 4950); // 5000 − 50 (t2 only)
  });

  testWidgets('tapping Undo restores the row and leaves balances untouched',
      (tester) async {
    final store = _store();
    await _pump(tester, store);

    await _swipeDelete(tester, find.byType(LedgerTxnRow).first);
    expect(find.text('Transaction deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // The transaction is still present and the row is back.
    expect(_hasTxn(store, 't1'), isTrue);
    expect(store.balanceOf('a1'), 4830);
    expect(find.byType(LedgerTxnRow), findsNWidgets(2));

    // And it does not commit later — the undo cancelled the pending delete.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_hasTxn(store, 't1'), isTrue);
  });

  testWidgets('a second delete commits the first', (tester) async {
    final store = _store();
    await _pump(tester, store);

    // Delete t1 (the Aug-3 row is last under newest-first date sort).
    await _swipeDelete(tester, find.byType(LedgerTxnRow).last);
    expect(_hasTxn(store, 't1'), isTrue);

    // A second delete replaces the first bar via hideCurrentSnackBar(), which
    // closes it with `hide` and commits the first delete once the hide
    // animation completes.
    await _swipeDelete(tester, find.byType(LedgerTxnRow).first);
    await tester.pumpAndSettle();

    expect(_hasTxn(store, 't1'), isFalse); // first committed
    expect(find.text('Transaction deleted'), findsOneWidget); // fresh bar
  });
}
