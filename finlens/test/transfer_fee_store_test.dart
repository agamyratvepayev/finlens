import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/transfer_math.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transfer_fee_store_test.dart
//
// Store-level outcomes of the Transfer fee (Transfer-fee spec §4): the two
// records the form writes, the net/gross balances, the fee counting as an
// expense while the transfer contributes nothing, and the delete cascade.

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 12)),
      baseCurrency: 'USD',
      accounts: [
        Account(
            id: 'a1',
            name: 'My Wallet',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 10000),
        Account(
            id: 'a2',
            name: 'Family Wallet',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
      ],
      categories: [
        Category(
            id: 'c-fee',
            name: 'Bank Fee',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF8E8E93)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

final _d = DateTime(2026, 8, 9);

/// Replicates exactly what QuickAdd's create-transfer save does (§4): a fee
/// expense first (so the transfer can hold its id), then the transfer carrying
/// the net and linked to the fee.
({Txn transfer, Txn? fee}) _writeTransfer(
  AppStore store, {
  required double gross,
  double fee = 0,
  String? feeCategory,
  required String from,
  required String to,
}) {
  final net = transferNet(gross, fee);
  Txn? feeTxn;
  if (fee > 0) {
    feeTxn = store.addTxn(
      type: TxnType.expense,
      amount: fee,
      currency: 'USD',
      fromRef: from,
      toRef: feeCategory!,
      date: _d,
    );
  }
  final t = store.addTxn(
    type: TxnType.transfer,
    amount: net,
    currency: 'USD',
    fromRef: from,
    toRef: to,
    date: _d,
    feeTxnId: feeTxn?.id,
  );
  return (transfer: t, fee: feeTxn);
}

void main() {
  final month = DateTime(2026, 8, 1);

  test('2,000 gross, 5 fee, same currency → transfer 1,995 + expense 5 (§9)',
      () {
    final store = _store();
    final r = _writeTransfer(store,
        gross: 2000, fee: 5, feeCategory: 'c-fee', from: 'a1', to: 'a2');

    expect(r.transfer.type, TxnType.transfer);
    expect(r.transfer.amount, 1995);
    expect(r.transfer.fromRef, 'a1');
    expect(r.transfer.toRef, 'a2');

    expect(r.fee, isNotNull);
    expect(r.fee!.type, TxnType.expense);
    expect(r.fee!.amount, 5);
    expect(r.fee!.fromRef, 'a1');
    expect(r.fee!.toRef, 'c-fee');

    // The two are joined (§4.1).
    expect(r.transfer.feeTxnId, r.fee!.id);

    // Source pays the gross; the destination receives the net.
    expect(store.balanceOf('a1'), 10000 - 2000);
    expect(store.balanceOf('a2'), 1995);
  });

  test('the fee counts toward its category and expense; the transfer does not',
      () {
    final store = _store();
    _writeTransfer(store,
        gross: 2000, fee: 5, feeCategory: 'c-fee', from: 'a1', to: 'a2');

    expect(store.spentInCategory('c-fee', month), 5);
    expect(store.monthExpense(month), 5);
    expect(store.monthIncome(month), 0);
  });

  test('a fee of 0 writes no second record (§9)', () {
    final store = _store();
    final r = _writeTransfer(store, gross: 2000, fee: 0, from: 'a1', to: 'a2');

    expect(r.fee, isNull);
    expect(r.transfer.amount, 2000);
    expect(r.transfer.feeTxnId, isNull);
    expect(store.txns.where((t) => t.type == TxnType.expense), isEmpty);
    expect(store.balanceOf('a1'), 10000 - 2000);
    expect(store.balanceOf('a2'), 2000);
  });

  test('deleting the transfer deletes its fee — no orphan (§4.1 / §9)', () {
    final store = _store();
    final r = _writeTransfer(store,
        gross: 2000, fee: 5, feeCategory: 'c-fee', from: 'a1', to: 'a2');
    expect(store.txns.length, 2);

    store.deleteTxn(r.transfer);

    expect(store.txns, isEmpty);
    expect(store.balanceOf('a1'), 10000);
    expect(store.balanceOf('a2'), 0);
  });

  test('feeTxnId survives the persistence mapper round-trip', () {
    final store = _store();
    final r = _writeTransfer(store,
        gross: 2000, fee: 5, feeCategory: 'c-fee', from: 'a1', to: 'a2');
    // The join is a real field on the transfer, not a runtime-only association.
    expect(r.transfer.feeTxnId, isNotNull);
    expect(store.txnById(r.transfer.feeTxnId!), isNotNull);
  });
}
