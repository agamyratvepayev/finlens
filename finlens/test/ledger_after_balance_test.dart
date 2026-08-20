import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

// Unit tests for AppStore.ledgerAfterBalances — the per-row after-balance the
// Ledger tab prints on line 2 (spec §4.5). One chronological pass builds the
// whole map; each row shows the balance of the account it displays.

Account _acc(String id, AccountGroup group, double start) => Account(
      id: id,
      name: id,
      group: group,
      currency: 'USD',
      startingBalance: start,
    );

Category _cat(String id, CategoryType type) => Category(
      id: id,
      name: id,
      type: type,
      icon: Icons.circle,
      color: const Color(0xFF30D158),
    );

Txn _txn(
  String id,
  TxnType type,
  double amount,
  String from,
  String to,
  int day, {
  double? toAmount,
  double? fee,
}) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, 8, day),
      toAmount: toAmount,
      fee: fee,
    );

AppStore _store(List<Txn> txns) => AppStore(
      accounts: [
        _acc('cash', AccountGroup.spendable, 1000),
        _acc('card', AccountGroup.creditCards, -200), // liability: negative
      ],
      categories: [
        _cat('groc', CategoryType.expense),
        _cat('sal', CategoryType.income),
      ],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

void main() {
  test('expense shows the paying account after the debit', () {
    final store = _store([_txn('t1', TxnType.expense, 120, 'cash', 'groc', 3)]);
    expect(store.ledgerAfterBalances()['t1'], 880); // 1000 − 120
  });

  test('income shows the receiving account after the credit', () {
    final store = _store([_txn('t1', TxnType.income, 500, 'sal', 'cash', 3)]);
    expect(store.ledgerAfterBalances()['t1'], 1500); // 1000 + 500
  });

  test('a transfer books both sides; the row shows the destination', () {
    // Aug 3 expense first, then the Aug 4 transfer moves cash → card.
    final store = _store([
      _txn('t1', TxnType.expense, 120, 'cash', 'groc', 3),
      _txn('t2', TxnType.transfer, 300, 'cash', 'card', 4),
    ]);
    final after = store.ledgerAfterBalances();
    expect(after['t1'], 880); // cash after the expense
    expect(after['t2'], 100); // card (destination): −200 + 300
  });

  test('a negative result keeps its sign', () {
    final store = _store([_txn('t1', TxnType.expense, 250, 'card', 'groc', 6)]);
    expect(store.ledgerAfterBalances()['t1'], -450); // −200 − 250
  });

  test('balances accumulate in chronological order across a shared account', () {
    final store = _store([
      _txn('t1', TxnType.expense, 120, 'cash', 'groc', 3),
      _txn('t2', TxnType.income, 500, 'sal', 'cash', 5),
    ]);
    final after = store.ledgerAfterBalances();
    expect(after['t1'], 880); // 1000 − 120
    expect(after['t2'], 1380); // 880 + 500
  });

  test('the map is rebuilt after a mutation (no stale after-balance survives)',
      () {
    final store = _store([_txn('t1', TxnType.expense, 120, 'cash', 'groc', 3)]);
    expect(store.ledgerAfterBalances()['t1'], 880);
    store.addTxn(
      type: TxnType.expense,
      amount: 80,
      currency: 'USD',
      fromRef: 'cash',
      toRef: 'groc',
      date: DateTime(2026, 8, 2), // dated earlier → shifts t1's after-balance
    );
    expect(store.ledgerAfterBalances()['t1'], 800); // 1000 − 80 − 120
  });
}
