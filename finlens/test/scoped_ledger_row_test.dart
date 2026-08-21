import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/search_fold.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Widget tests for the scoped-ledger row (LedgerTxnRow) once the balance became
// conditional and descriptions gained a toggle (balance spec §1/§3):
//   • the running balance renders only when the list is told it is a legible
//     tape (showBalance), and never announces a figure it does not draw;
//   • the description follows the toggle, but a search-matched note reveals
//     regardless;
//   • the account name still drops under an account scope.

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

void main() {
  late AppStore store;
  setUp(() {
    store = AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Cash Wallet')],
      categories: [_cat('c-cat', 'Groceries')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
  });

  // An Aug-5 expense of 120 from a1 (start 1000) → running balance 880.
  ScopedTxn rowFor(LedgerScope scope, {String note = ''}) {
    final added = store.addTxn(
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c-cat',
      date: DateTime(2026, 8, 5),
      note: note,
    );
    final q = LedgerQuery(
        store: store, scope: scope, start: DateTime(2020), end: DateTime(2030));
    return q.rows().firstWhere((r) => r.txn.id == added.id);
  }

  Future<void> pumpRow(
    WidgetTester tester,
    ScopedTxn row,
    LedgerScope scope, {
    required bool showBalance,
    bool showDescription = true,
    String? highlight,
    double width = 360,
  }) async {
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LedgerTxnRow(
                row: row,
                scope: scope,
                showBalance: showBalance,
                showDescription: showDescription,
                highlight: highlight,
                onOpen: () {},
                onEdit: () {},
                onCopy: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('running balance', () {
    testWidgets('an account-scope tape shows the balance and drops the account',
        (tester) async {
      const scope = AccountScope('a1');
      await pumpRow(tester, rowFor(scope), scope, showBalance: true);
      expect(find.text(r'$880'), findsOneWidget); // balance renders
      expect(find.text('Main Checking'), findsNothing); // account implied
    });

    testWidgets('a multi-account list shows no balance (and keeps the account)',
        (tester) async {
      const scope = GroupScope(AccountGroup.spendable);
      await pumpRow(tester, rowFor(scope), scope, showBalance: false);
      expect(find.text(r'$880'), findsNothing); // suppressed
      expect(find.text('Main Checking'), findsOneWidget); // account named
    });

    testWidgets('a suppressed balance is not announced to a screen reader',
        (tester) async {
      final handle = tester.ensureSemantics();
      const scope = GroupScope(AccountGroup.spendable);
      await pumpRow(tester, rowFor(scope), scope, showBalance: false);
      expect(find.bySemanticsLabel(RegExp('balance')), findsNothing);
      handle.dispose();
    });
  });

  group('description toggle', () {
    testWidgets('the toggle flips the description line', (tester) async {
      const scope = AccountScope('a1');
      final row = rowFor(scope, note: 'Bakery & fruit');

      await pumpRow(tester, row, scope,
          showBalance: true, showDescription: false);
      expect(find.text('Bakery & fruit'), findsNothing); // off

      await pumpRow(tester, row, scope,
          showBalance: true, showDescription: true);
      expect(find.text('Bakery & fruit'), findsOneWidget); // on
    });

    testWidgets('a search-matched note reveals even with the toggle off',
        (tester) async {
      const scope = AccountScope('a1');
      final row = rowFor(scope, note: 'Bakery & fruit');
      await pumpRow(tester, row, scope,
          showBalance: true,
          showDescription: false,
          highlight: foldSearch('bakery'));
      // A matched note renders as a highlighted RichText, so match on content.
      expect(find.textContaining('Bakery'), findsOneWidget);
    });
  });
}
