import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/new_account_test.dart

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, void Function(BuildContext) onTap) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('sign convention (spec §5.4)', () {
    test('a liability created with 15000 is stored as −15000', () {
      final store = _store();
      final created = store.addAccount(
        name: 'Amex',
        group: AccountGroup.creditCards,
        currency: 'USD',
        startingBalance: 15000,
      );
      expect(created.startingBalance, -15000);
      expect(store.balanceOf(created.id), -15000);
    });

    test('an asset keeps its positive opening balance', () {
      final store = _store();
      final created = store.addAccount(
        name: 'Savings',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 500,
      );
      expect(created.startingBalance, 500);
    });
  });

  testWidgets('the create action is in the picker header, once', (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => pickAccount(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Exactly one "New account" affordance, in the header (no bottom row).
    expect(find.text('New account'), findsOneWidget);
  });

  testWidgets('selecting Bank Loans reveals Amount owed and Payment day',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Nothing group-specific before a group is chosen.
    expect(find.text('Starting balance'), findsNothing);

    await tester.tap(find.text('Bank Loans'));
    await tester.pumpAndSettle();
    expect(find.text('Amount owed'), findsOneWidget);
    expect(find.text('Payment day'), findsOneWidget);
    expect(find.text('Starting balance'), findsNothing);

    await tester.tap(find.text('Spendable'));
    await tester.pumpAndSettle();
    expect(find.text('Starting balance'), findsOneWidget);
    expect(find.text('Amount owed'), findsNothing);
    expect(find.text('Payment day'), findsNothing);
    expect(find.text('Credit limit'), findsNothing);
  });

  testWidgets('Credit limit shows only for Credit Cards', (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Credit limit'), findsOneWidget);
    expect(find.text('Amount owed'), findsOneWidget);
  });

  testWidgets('switching group and back preserves the credit limit',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();
    // Fields in order: name(0), balance(1), credit limit(2).
    await tester.enterText(find.byType(TextField).at(2), '5000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bank Loans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();

    final limit = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(limit.controller?.text, '5000');
  });

  testWidgets('a duplicate name shows an inline error (case-insensitive)',
      (tester) async {
    final store = _store(); // has "Main Checking"
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  main checking  ');
    await tester.pumpAndSettle();
    expect(
        find.text('An account with this name already exists'), findsOneWidget);
  });
}
