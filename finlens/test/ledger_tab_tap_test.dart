import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/features/ledger/transfer_detail_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Spec §1 — the Ledger tab's row tap now opens a read-only screen, never the
// editor. A transfer opens TransferDetailScreen; everything else opens the
// Same-transactions list. QuickAddScreen must never appear from a tap.
//
// AppStore.today is 9 Aug 2026 and the default period is that month, so a txn
// dated in August 2026 lands in the Ledger window.

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

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: LedgerScreen()),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('tapping a non-transfer row opens SameTransactionsScreen, never '
      'the editor', (tester) async {
    final store = AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Groceries')],
      txns: [
        Txn(
          id: 'e1',
          type: TxnType.expense,
          amount: 120,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'c1',
          date: DateTime(2026, 8, 5),
        ),
      ],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    expect(find.byType(TxnRow), findsOneWidget);
    await tester.tap(find.byType(TxnRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(SameTransactionsScreen), findsOneWidget);
    expect(find.byType(QuickAddScreen), findsNothing);
  });

  testWidgets('tapping a transfer row opens TransferDetailScreen, never the '
      'Same-transactions screen', (tester) async {
    final store = AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Savings')],
      categories: const <Category>[],
      txns: [
        Txn(
          id: 't1',
          type: TxnType.transfer,
          amount: 50,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'a2',
          date: DateTime(2026, 8, 6),
        ),
      ],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    expect(find.byType(TxnRow), findsOneWidget);
    await tester.tap(find.byType(TxnRow).first);
    await tester.pumpAndSettle();

    expect(find.byType(TransferDetailScreen), findsOneWidget);
    expect(find.byType(SameTransactionsScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsNothing);
  });
}
