import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/ledger/ledger_day.dart';

// Only `type` and `amount` matter to LedgerDay; the refs are placeholders.
Txn _txn(TxnType type, double amount) => Txn(
      id: 't',
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: 'a',
      toRef: 'b',
      date: DateTime(2026, 8, 1),
    );

LedgerDay _day(List<Txn> txns) {
  final d = LedgerDay(DateTime(2026, 8, 1));
  d.txns.addAll(txns);
  return d;
}

void main() {
  group('LedgerDay.showsDayTotal — count-based threshold of three (spec §4)', () {
    test('zero rows never show — the group would not render', () {
      expect(_day([]).showsDayTotal, isFalse);
    });

    test('one row hides the total — it would copy the row below it', () {
      expect(_day([_txn(TxnType.expense, 40)]).showsDayTotal, isFalse);
    });

    test('two rows hide the total — one adjacent subtraction', () {
      expect(
        _day([_txn(TxnType.income, 900), _txn(TxnType.expense, 132)])
            .showsDayTotal,
        isFalse,
      );
    });

    test('two large rows still hide — the accepted trade-off, not a bug', () {
      expect(
        _day([_txn(TxnType.income, 5000), _txn(TxnType.expense, 4800)])
            .showsDayTotal,
        isFalse,
      );
    });

    test('three rows always show', () {
      expect(
        _day([
          _txn(TxnType.expense, 240),
          _txn(TxnType.expense, 130),
          _txn(TxnType.expense, 54),
        ]).showsDayTotal,
        isTrue,
      );
    });

    test('three rows netting to zero still show — as \$0', () {
      final d = _day([
        _txn(TxnType.income, 500),
        _txn(TxnType.expense, 500),
        _txn(TxnType.expense, 0),
      ]);
      expect(d.showsDayTotal, isTrue);
      expect(d.total, 0);
    });

    test('three rows whose net equals one row still show', () {
      // +500, −500, −320 → net −320, which equals the third row's amount.
      final d = _day([
        _txn(TxnType.income, 500),
        _txn(TxnType.expense, 500),
        _txn(TxnType.expense, 320),
      ]);
      expect(d.showsDayTotal, isTrue);
      expect(d.total, -320);
    });
  });

  group('LedgerDay.total — transfers/revaluations contribute nothing (spec §4)',
      () {
    test('a lone transfer moves the net by 0 and, as one row, hides it', () {
      final d = _day([_txn(TxnType.transfer, 500)]);
      expect(d.total, 0);
      expect(d.showsDayTotal, isFalse);
    });

    test('three transfers net to zero but the total still renders', () {
      final d = _day([
        _txn(TxnType.transfer, 500),
        _txn(TxnType.transfer, 200),
        _txn(TxnType.transfer, 50),
      ]);
      expect(d.total, 0);
      expect(d.showsDayTotal, isTrue);
    });

    test('a revaluation contributes nothing to the net', () {
      final d = _day([
        _txn(TxnType.rebalance, 1000),
        _txn(TxnType.income, 100),
      ]);
      expect(d.total, 100);
    });

    test('income adds, expense subtracts', () {
      final d = _day([
        _txn(TxnType.income, 900),
        _txn(TxnType.expense, 132),
      ]);
      expect(d.total, 900 - 132);
    });
  });
}
