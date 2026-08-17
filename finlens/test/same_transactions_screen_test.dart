import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/account_detail_screen.dart';
import 'package:finlens/features/balance/same_transactions.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

Txn tx(String id, TxnType type, String from, String to,
        {DateTime? date, double amount = 10}) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: date ?? DateTime(2026, 8, 9),
    );

AppStore storeWith(List<Txn> txns) => AppStore(
      accounts: const <Account>[],
      categories: const <Category>[],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget host(AppStore store, Widget child, {GlobalKey<NavigatorState>? navKey}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.dark,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('tapping a transaction row opens the read-only screen, not the editor',
      (tester) async {
    final store = buildSeedStore();
    final account = store.accounts.firstWhere((a) => a.name == 'Main Checking');

    await tester
        .pumpWidget(host(store, AccountDetailScreen(accountId: account.id)));
    await tester.pumpAndSettle();

    expect(find.byType(TxnRow), findsWidgets);
    await tester.tap(find.byType(TxnRow).first);
    await tester.pumpAndSettle();

    // A tap reaches the read-only Same-transactions screen — never the editor.
    expect(find.byType(SameTransactionsScreen), findsOneWidget);
  });

  testWidgets('changing the range recomputes the summary (TOTAL) and list',
      (tester) async {
    // Two $10 expenses on one key, in different months. today = 9 Aug 2026.
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
      tx('b', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 6, 1)),
    ]);

    await tester
        .pumpWidget(host(store, const SameTransactionsScreen(originTxnId: 'a')));

    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.thisMonth));
    await tester.pumpAndSettle();
    // This month: only 'a' → TOTAL $10, so $20 is nowhere.
    expect(find.text('\$20'), findsNothing);

    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();
    // All time: both → TOTAL $20 (the summed metric, not a row amount).
    expect(find.text('\$20'), findsOneWidget);
  });

  testWidgets('deleting the originating transaction pops the screen',
      (tester) async {
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
      tx('b', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 7, 1)),
    ]);
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
        host(store, const Scaffold(), navKey: navKey));
    navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const SameTransactionsScreen(originTxnId: 'a')));
    await tester.pumpAndSettle();
    expect(find.byType(SameTransactionsScreen), findsOneWidget);

    store.deleteTxn(store.txnById('a')!);
    await tester.pumpAndSettle();

    // With no subject left, the screen pops itself.
    expect(find.byType(SameTransactionsScreen), findsNothing);
  });
}
