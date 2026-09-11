import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transfer_edit_roundtrip_test.dart
//
// The bug this pins: editing a cross-currency transfer's amount left `toAmount`
// (and the rate) at their stale values, because the edit path called
// `updateTxn` without them. That silently corrupts the destination balance.

Account _acc(String id, String name, String currency, {double start = 5000}) =>
    Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: currency,
      startingBalance: start,
    );

AppStore _crossStore(Txn seed) => AppStore(
      accounts: [
        _acc('usd', 'USD Wallet', 'USD'),
        _acc('eur', 'EUR Wallet', 'EUR'),
      ],
      categories: const <Category>[],
      txns: [seed],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Txn _crossTransfer() => Txn(
      id: 't-fx',
      type: TxnType.transfer,
      amount: 200,
      currency: 'USD',
      fromRef: 'usd',
      toRef: 'eur',
      date: DateTime(2026, 8, 4, 16, 20),
      exchangeRate: 0.9,
      toAmount: 180, // 200 × 0.9
    );

void main() {
  group('Task 1 — the edit path round-trips a transfer', () {
    testWidgets(
        'changing a cross-currency transfer amount moves toAmount with it',
        (tester) async {
      final txn = _crossTransfer();
      final store = _crossStore(txn);

      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: QuickAddScreen(
            initialType: QuickAddType.transfer,
            editing: txn,
          ),
        ),
      ));
      await tester.pump();

      // Editing opens with the keypad closed; tapping the hero opens it.
      await tester.tap(find.byType(NumericHeroCard));
      await tester.pump();
      // 200 → 2000 (append a digit — the simplest amount change).
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      final saved = store.txns.single;
      expect(saved.amount, 2000);
      // The destination figure tracked the amount at the rate on screen —
      // 2000 × 0.9 — instead of staying at its stale 180.
      expect(saved.toAmount, 1800.0);
      expect(saved.exchangeRate, 0.9);
      // And the derived destination balance moved with it.
      expect(store.balanceOf('eur'), 5000 + 1800.0);
    });
  });

  group('Task 1 — updateTxn FX field semantics', () {
    test('passing exchangeRate/toAmount overwrites the stored values', () {
      final txn = _crossTransfer();
      final store = _crossStore(txn);

      store.updateTxn(txn,
          amount: 2000, exchangeRate: 0.92, toAmount: 1840.0);

      expect(txn.amount, 2000);
      expect(txn.exchangeRate, 0.92);
      expect(txn.toAmount, 1840.0);
      expect(txn.editedCount, 1);
    });

    test('omitting them keeps the stored values (the ?? keep fallback)', () {
      final txn = _crossTransfer();
      final store = _crossStore(txn);

      store.updateTxn(txn, note: 'renamed');

      expect(txn.exchangeRate, 0.9);
      expect(txn.toAmount, 180);
    });

    test('clearExchange nulls both FX fields (cross → same-currency edit)', () {
      final txn = _crossTransfer();
      final store = _crossStore(txn);

      store.updateTxn(txn, clearExchange: true);

      expect(txn.exchangeRate, isNull);
      expect(txn.toAmount, isNull);
    });
  });
}
