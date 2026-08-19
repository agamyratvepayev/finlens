import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/utils/formatters.dart';

void main() {
  // An otherwise-empty month, so only the rows added here count.
  final month = DateTime(2027, 3);

  group('Month summary IN / OUT / LEFT (spec §1)', () {
    test('transfers are excluded from IN, OUT, and therefore LEFT', () {
      final store = buildSeedStore();

      store.addTxn(
        type: TxnType.income,
        amount: 1000,
        currency: 'USD',
        fromRef: 'c-salary', // income category
        toRef: 'a-checking', // destination account
        date: month,
      );
      store.addTxn(
        type: TxnType.expense,
        amount: 300,
        currency: 'USD',
        fromRef: 'a-checking',
        toRef: 'c-groceries',
        date: month,
      );

      final inBefore = store.monthIncome(month);
      final outBefore = store.monthExpense(month);

      // Moving the user's own money between accounts must not register as
      // income or expense.
      store.addTxn(
        type: TxnType.transfer,
        amount: 500,
        currency: 'USD',
        fromRef: 'a-checking',
        toRef: 'a-cash-usd',
        date: month,
      );

      expect(store.monthIncome(month), inBefore, reason: 'transfer not income');
      expect(store.monthExpense(month), outBefore, reason: 'transfer not out');
      expect(store.monthIncome(month), 1000);
      expect(store.monthExpense(month), 300);

      // LEFT = IN − OUT, transfer excluded.
      expect(store.monthIncome(month) - store.monthExpense(month), 700);
    });

    test('LEFT keeps its minus sign when the month is overspent', () {
      final store = buildSeedStore();

      store.addTxn(
        type: TxnType.income,
        amount: 100,
        currency: 'USD',
        fromRef: 'c-salary',
        toRef: 'a-checking',
        date: month,
      );
      store.addTxn(
        type: TxnType.expense,
        amount: 300,
        currency: 'USD',
        fromRef: 'a-checking',
        toRef: 'c-groceries',
        date: month,
      );

      final left = store.monthIncome(month) - store.monthExpense(month);
      expect(left, -200);

      // The card renders LEFT with its sign (unlike IN/OUT), so a below-zero
      // month reads as a true minus — U+2212, not a hyphen (spec §1.2).
      expect(money(left), startsWith('−'));
      // A positive LEFT carries no sign.
      expect(money(200).startsWith('−'), isFalse);
    });
  });
}
