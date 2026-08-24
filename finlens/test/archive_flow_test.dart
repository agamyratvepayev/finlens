import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Retiring accounts and categories — widget acceptance.
// `flutter test` hangs on the author's machine, so run these yourself:
//   flutter test test/archive_flow_test.dart

Account _account(
  String id,
  String name, {
  AccountGroup group = AccountGroup.spendable,
  double startingBalance = 0,
}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: 'USD',
      startingBalance: startingBalance,
    );

Category _category(String id, String name, {bool archived = false}) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
      archived: archived,
    );

Txn _income(String id, String to, double amount) => Txn(
      id: id,
      type: TxnType.income,
      amount: amount,
      currency: 'USD',
      fromRef: 'cat-income',
      toRef: to,
      date: DateTime(2026, 8, 5),
    );

Txn _expense(String id, String from, String to, double amount) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, 8, 5),
    );

void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 @3x
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpEditAccount(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EditAccountScreen(accountId: 'a1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'archiving a non-zero balance account is refused and offers Move money',
      (tester) async {
    _portrait(tester);
    final store = AppStore(
      accounts: [_account('a1', 'Cash (USD Wallet)', startingBalance: 5000)],
      categories: const <Category>[],
      // An income of 199 gives it history AND a $5,199 balance.
      txns: [_income('t1', 'a1', 199)],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
    await _pumpEditAccount(tester, store);

    // The row now reads "Archive this account", not "Remove this account".
    expect(find.text('Archive this account'), findsOneWidget);
    expect(find.text('Remove this account'), findsNothing);

    await tester.tap(find.text('Archive this account'));
    await tester.pumpAndSettle();

    // The Move-money sheet, not the archive impact list.
    expect(find.textContaining('out first'), findsOneWidget);
    expect(find.text('Move money'), findsOneWidget);
    // The now-impossible "drops by" impact line never appears.
    expect(find.textContaining('drops by'), findsNothing);
    expect(find.textContaining('stay in the Ledger'), findsNothing);
  });

  testWidgets('archiving a zero-balance account proceeds to the impact list',
      (tester) async {
    _portrait(tester);
    final store = AppStore(
      accounts: [_account('a1', 'Cash (USD Wallet)', startingBalance: 100)],
      categories: [_category('c1', 'Groceries')],
      // 100 starting − 100 spent = 0, and the account has history.
      txns: [_expense('t1', 'a1', 'c1', 100)],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
    await _pumpEditAccount(tester, store);

    await tester.tap(find.text('Archive this account'));
    await tester.pumpAndSettle();

    // The archive impact list, not the Move-money sheet.
    expect(find.text('Move money'), findsNothing);
    expect(find.text('Archive account'), findsOneWidget); // confirm button
    expect(find.textContaining('stay in the Ledger'), findsOneWidget);
    // The "{group} drops by {balance}" line is gone for good.
    expect(find.textContaining('drops by'), findsNothing);
  });

  testWidgets("an archived category's past transactions still render its name",
      (tester) async {
    _portrait(tester);
    final store = AppStore(
      accounts: [_account('a1', 'Checking')],
      categories: [_category('c1', 'Groceries', archived: true)],
      txns: [_expense('t1', 'a1', 'c1', 42)],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    // The category is out of every picker…
    expect(store.categories, isEmpty);
    // …but the ledger row still resolves and renders its name.
    final txn = store.txnById('t1')!;
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TxnRow(
            txn: txn,
            onTap: () {},
            onEdit: () {},
            onCopy: () {},
            onDelete: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
  });
}
