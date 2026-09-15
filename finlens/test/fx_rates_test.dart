import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/fx_rates_test.dart
//
// Tasks 021a/021b/021d/021e: rates are editable store data; a missing rate
// silences balance totals; every entry freezes its own rate and base value so
// correcting a rate never rewrites the past; switching the reporting currency
// re-expresses history through one factor.

Account _acc(String id, String currency,
        {double startingBalance = 0,
        AccountGroup group = AccountGroup.spendable}) =>
    Account(
      id: id,
      name: id,
      group: group,
      currency: currency,
      startingBalance: startingBalance,
      openedOn: DateTime(2026, 1, 1),
    );

AppStore _store({List<Account> accounts = const [], List<Txn> txns = const []}) =>
    AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: accounts,
      categories: const [],
      txns: txns,
      goals: const [],
      tasks: const [],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('rateFor / setRate (021a §1)', () {
    test('base is 1; a seeded code is its rate; an unknown code is null', () {
      final s = _store(accounts: [_acc('a', 'USD')]);
      expect(s.baseCurrency, 'USD');
      expect(s.rateFor('USD'), 1.0);
      // EUR seeded from Fx._perUnit: 1 USD = 1/1.10 ≈ 0.909 EUR.
      expect(s.rateFor('EUR'), closeTo(1 / 1.10, 0.0001));
      // A currency the seed table does not know has NO rate.
      expect(s.rateFor('BAM'), isNull);
    });

    test('setRate refuses 0 and negatives, and stamps the date', () {
      final s = _store(accounts: [_acc('a', 'USD')]);
      s.setRate('BAM', 0);
      expect(s.rateFor('BAM'), isNull);
      s.setRate('BAM', -3);
      expect(s.rateFor('BAM'), isNull);
      s.setRate('BAM', 2.0);
      expect(s.rateFor('BAM'), 2.0);
      expect(s.rateSetAt('BAM'), isNotNull);
    });

    test('the base rate is never stored — it is 1 by definition', () {
      final s = _store(accounts: [_acc('a', 'USD')]);
      s.setRate('USD', 5);
      expect(s.rateFor('USD'), 1.0);
    });
  });

  group('a missing rate silences balance totals (021a §2)', () {
    test('balanceInBase is null for an unrated currency', () {
      final s = _store(accounts: [_acc('a', 'BAM', startingBalance: 2000)]);
      expect(s.balanceInBase('a'), isNull);
      s.setRate('BAM', 2.0);
      expect(s.balanceInBase('a'), closeTo(1000, 0.01));
    });

    test('group/net totals are null when one account is unrated — even at 0', () {
      final s = _store(accounts: [
        _acc('usd', 'USD', startingBalance: 500),
        _acc('bam', 'BAM', startingBalance: 0), // zero balance, still unrated
      ]);
      expect(s.groupTotal(AccountGroup.spendable), isNull);
      expect(s.totalAssets, isNull);
      expect(s.netWorth, isNull);
      // Once the rate is entered, every total returns.
      s.setRate('BAM', 2.0);
      expect(s.totalAssets, closeTo(500, 0.01));
      expect(s.netWorth, closeTo(500, 0.01));
    });

    test('a fully-rated store shows a number and no missing codes', () {
      final s = _store(accounts: [
        _acc('usd', 'USD', startingBalance: 100),
        _acc('eur', 'EUR', startingBalance: 100),
      ]);
      expect(s.hasMissingRate, isFalse);
      // 100 USD + 100 EUR (= 110 USD) = 210.
      expect(s.netWorth, closeTo(210, 0.5));
    });
  });

  group('flows freeze their base value (021b §2)', () {
    test('a base-currency entry stores rate 1 and amountBase == amount', () {
      final s = _store(accounts: [_acc('a', 'USD')], txns: []);
      final cat = _addExpenseCat(s);
      final t = s.addTxn(
        type: TxnType.expense,
        amount: 50,
        currency: 'USD',
        fromRef: 'a',
        toRef: cat,
        date: DateTime(2026, 8, 1),
      );
      expect(t.rateToBase, 1.0);
      expect(t.amountBase, 50);
    });

    test('a foreign entry freezes, and a later rate change never moves it', () {
      final s = _store(accounts: [_acc('e', 'EUR', startingBalance: 1000)]);
      final cat = _addExpenseCat(s);
      final t = s.addTxn(
        type: TxnType.expense,
        amount: 100,
        currency: 'EUR',
        fromRef: 'e',
        toRef: cat,
        date: DateTime(2026, 8, 1),
      );
      // 100 EUR at the seeded rate ≈ 110 USD.
      expect(t.amountBase, closeTo(110, 0.5));
      final flowBefore = s.monthExpense(DateTime(2026, 8, 1));
      final balBefore = s.balanceInBase('e');
      // Correct the EUR rate: flows are frozen, balances follow the new rate.
      s.setRate('EUR', 2.0); // 1 USD = 2 EUR now
      expect(s.monthExpense(DateTime(2026, 8, 1)), flowBefore);
      expect(s.balanceInBase('e'), isNot(closeTo(balBefore!, 0.5)));
    });
  });

  group('switching the reporting currency (021e §2)', () {
    test('amountBase ×f, rateToBase ÷f, and ratios are preserved', () {
      final s = _store(accounts: [_acc('a', 'USD', startingBalance: 1000)]);
      final cat = _addExpenseCat(s);
      final t1 = s.addTxn(
          type: TxnType.expense,
          amount: 100,
          currency: 'USD',
          fromRef: 'a',
          toRef: cat,
          date: DateTime(2026, 7, 1));
      final t2 = s.addTxn(
          type: TxnType.expense,
          amount: 300,
          currency: 'USD',
          fromRef: 'a',
          toRef: cat,
          date: DateTime(2026, 8, 1));
      final ratioBefore = t2.amountBase / t1.amountBase;
      final f = s.rateFor('EUR')!; // USD → EUR factor
      s.setBaseCurrency('EUR', factor: f);
      expect(s.baseCurrency, 'EUR');
      expect(t1.amountBase, closeTo(100 * f, 0.01));
      expect(t1.rateToBase, closeTo(1 / f, 0.0001));
      // The ratio between two historical figures is unchanged.
      expect(t2.amountBase / t1.amountBase, closeTo(ratioBefore, 0.0001));
      // The old base joins the table at 1/f; the new base leaves it.
      expect(s.rateFor('USD'), closeTo(1 / f, 0.0001));
      expect(s.snapshotRates.containsKey('EUR'), isFalse);
      // The change record is kept.
      expect(s.lastBaseCurrencyChange?.from, 'USD');
      expect(s.lastBaseCurrencyChange?.to, 'EUR');
    });

    test('a switch with no rate for the target is refused', () {
      final s = _store(accounts: [_acc('a', 'USD')]);
      s.setBaseCurrency('BAM'); // BAM has no rate
      expect(s.baseCurrency, 'USD');
    });
  });

  group('goals and budgets carry a currency (021d)', () {
    test('an account goal is measured natively and holds when the rate moves',
        () {
      final s = _store(accounts: [_acc('e', 'EUR', startingBalance: 500)]);
      final g = s.addGoal(
        name: 'Trip',
        source: GoalSource.account('e'),
        targetAmount: 1000,
      );
      expect(g.currency, 'EUR');
      final before = s.goalMetrics(g).progress;
      s.setRate('EUR', 5.0); // rate moves; native balance does not
      expect(s.goalMetrics(g).progress, closeTo(before, 0.0001));
    });
  });
}

/// Adds an expense category and returns its id.
String _addExpenseCat(AppStore s) {
  final c = s.addCategory(
    name: 'Food',
    type: CategoryType.expense,
    icon: Icons.category_rounded,
    color: Colors.grey,
  );
  return c.id;
}
