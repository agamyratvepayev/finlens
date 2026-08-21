import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';

/// Unit tests for the Ledger tab's range-lens window: the store accessor, the
/// windowed queries, and the has-data grouped queries that feed the Period
/// sheet's dots. No widgets — pure store behaviour.

Account _acc(String id) => Account(
      id: id,
      name: id,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 0,
    );

Txn _tx(String id, TxnType type, String from, String to, double amount,
        DateTime date) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: date,
    );

AppStore _store(List<Txn> txns) => AppStore(
      accounts: [_acc('A')],
      categories: const <Category>[],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

void main() {
  group('ledgerWindow reflects the lens; month otherwise', () {
    test('no lens → the calendar month of `period`', () {
      final store = _store(const [])..period = DateTime(2026, 8);
      expect(store.isRangeLensActive, isFalse);
      expect(store.ledgerWindow.start, DateTime(2026, 8, 1));
      expect(store.ledgerWindow.end.month, 8);
      expect(store.ledgerWindow.end.day, 31); // last of August
    });

    test('applyRangeLens replaces the window; clear restores the month', () {
      final store = _store(const [])..period = DateTime(2026, 8);
      final lens =
          DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59));
      store.applyRangeLens(lens);
      expect(store.isRangeLensActive, isTrue);
      expect(store.ledgerWindow.start, DateTime(2026, 8, 6));
      expect(store.ledgerWindow.days, 4); // 6,7,8,9 Aug

      store.clearRangeLens();
      expect(store.isRangeLensActive, isFalse);
      expect(store.ledgerWindow.start, DateTime(2026, 8, 1));
    });

    test('picking a month clears an active lens (same store path)', () {
      final store = _store(const [])..period = DateTime(2026, 8);
      store.applyRangeLens(
          DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59)));
      store.period = DateTime(2026, 3); // month pick
      expect(store.isRangeLensActive, isFalse);
      expect(store.ledgerWindow.start, DateTime(2026, 3, 1));
    });

    test('a swipe during a lens clears it and leaves period untouched', () {
      final store = _store(const [])..period = DateTime(2026, 3);
      store.applyRangeLens(
          DateRange(DateTime(2026, 8, 6), DateTime(2026, 8, 9, 23, 59, 59)));
      store.shiftPeriod(-1); // swipe while lens active
      expect(store.isRangeLensActive, isFalse);
      // Exit lands on the month the lens was set from — direction is ignored —
      // matching the header's × clear, not jumping to today.
      expect(store.period, DateTime(2026, 3));
      expect(store.ledgerWindow.start, DateTime(2026, 3, 1));

      // A subsequent swipe now steps months normally from that month.
      store.shiftPeriod(-1);
      expect(store.period, DateTime(2026, 2));
    });
  });

  group('windowed income/expense/day count cross month boundaries', () {
    late AppStore store;
    setUp(() {
      store = _store([
        _tx('i1', TxnType.income, 'cat', 'A', 100, DateTime(2026, 7, 30)),
        _tx('e1', TxnType.expense, 'A', 'cat', 40, DateTime(2026, 8, 2)),
        _tx('i2', TxnType.income, 'cat', 'A', 200, DateTime(2026, 8, 5)),
      ]);
    });

    test('a range spanning Jul→Aug sums only what falls inside it', () {
      final w = DateRange(
          DateTime(2026, 7, 28), DateTime(2026, 8, 3, 23, 59, 59, 999));
      expect(store.txnsInWindow(w).map((t) => t.id).toSet(), {'i1', 'e1'});
      expect(store.incomeInWindow(w), 100);
      expect(store.expenseInWindow(w), 40);
      expect(w.days, 7); // 28,29,30,31 Jul + 1,2,3 Aug
    });

    test('a single-day window is inclusive of that whole day', () {
      final w = DateRange(
          DateTime(2026, 8, 5), DateTime(2026, 8, 5, 23, 59, 59, 999));
      expect(store.txnsInWindow(w).map((t) => t.id).toSet(), {'i2'});
      expect(w.days, 1);
    });
  });

  group('has-data grouped queries (Period sheet dots)', () {
    test('ledgerMonthsWithData returns the months holding txns for a year', () {
      final store = _store([
        _tx('a', TxnType.expense, 'A', 'cat', 5, DateTime(2026, 3, 4)),
        _tx('b', TxnType.expense, 'A', 'cat', 5, DateTime(2026, 3, 20)),
        _tx('c', TxnType.income, 'cat', 'A', 5, DateTime(2026, 7, 1)),
        _tx('d', TxnType.income, 'cat', 'A', 5, DateTime(2025, 11, 1)),
      ]);
      expect(store.ledgerMonthsWithData(2026), {3, 7});
      expect(store.ledgerMonthsWithData(2025), {11});
      expect(store.ledgerMonthsWithData(2024), isEmpty);
    });

    test('ledgerDaysWithData returns day-only dates for a month', () {
      final store = _store([
        _tx('a', TxnType.expense, 'A', 'cat', 5, DateTime(2026, 8, 4, 9)),
        _tx('b', TxnType.expense, 'A', 'cat', 5, DateTime(2026, 8, 4, 18)),
        _tx('c', TxnType.income, 'cat', 'A', 5, DateTime(2026, 8, 20)),
      ]);
      expect(store.ledgerDaysWithData(DateTime(2026, 8)),
          {DateTime(2026, 8, 4), DateTime(2026, 8, 20)});
    });

    test('earliestTxnYear is the year floor for the stepper', () {
      final store = _store([
        _tx('a', TxnType.expense, 'A', 'cat', 5, DateTime(2026, 3, 4)),
        _tx('b', TxnType.income, 'cat', 'A', 5, DateTime(2025, 11, 1)),
      ]);
      expect(store.earliestTxnYear, 2025);
    });
  });

  group('against the shipped seed fixture', () {
    test('data spans Sep 2025 – Aug 2026 with the acceptance dot pattern', () {
      final store = buildSeedStore();
      // 2026: Jan–Aug all have data; Sep–Dec are future (no data yet).
      final y2026 = store.ledgerMonthsWithData(2026);
      for (var m = 1; m <= 8; m++) {
        expect(y2026.contains(m), isTrue, reason: '2026-$m should have data');
      }
      // 2025: Sep–Dec have data; Jan–Aug are empty (dim-but-selectable).
      final y2025 = store.ledgerMonthsWithData(2025);
      for (var m = 9; m <= 12; m++) {
        expect(y2025.contains(m), isTrue, reason: '2025-$m should have data');
      }
      for (var m = 1; m <= 8; m++) {
        expect(y2025.contains(m), isFalse, reason: '2025-$m should be empty');
      }
      // The `‹` floor is 2025.
      expect(store.earliestTxnYear, 2025);
    });
  });
}
