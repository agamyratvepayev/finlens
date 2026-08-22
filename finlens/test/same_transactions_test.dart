import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/same_transactions.dart';

Txn tx(
  String id,
  TxnType type,
  String from,
  String to, {
  DateTime? date,
  double amount = 10,
  String note = '',
}) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: date ?? DateTime(2026, 8, 1),
      note: note,
    );

AppStore storeWith(List<Txn> txns) => AppStore(
      accounts: const <Account>[],
      categories: const <Category>[],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

void main() {
  group('keyOf — the composite key', () {
    test('same category on different accounts → ONE key (spec §2)', () {
      // The key widened to the category: a Groceries expense from Checking and
      // one from Cash share a list, so they must share a key and hash.
      // expense: fromRef = account, toRef = category
      final a = tx('1', TxnType.expense, 'acc-checking', 'cat-groceries');
      final b = tx('2', TxnType.expense, 'acc-cash', 'cat-groceries');
      expect(SameKey.of(a), SameKey.of(b));
      final byKey = {SameKey.of(a): 'x'};
      expect(byKey[SameKey.of(b)], 'x');
    });

    test('same category and account, opposite directions → different keys', () {
      final expense = tx('1', TxnType.expense, 'acc-checking', 'cat-groceries');
      // income: fromRef = category, toRef = account
      final income = tx('2', TxnType.income, 'cat-groceries', 'acc-checking');
      expect(SameKey.of(expense) == SameKey.of(income), isFalse);
    });

    test('A→B and B→A transfers → different keys', () {
      final ab = tx('1', TxnType.transfer, 'acc-a', 'acc-b');
      final ba = tx('2', TxnType.transfer, 'acc-b', 'acc-a');
      expect(SameKey.of(ab) == SameKey.of(ba), isFalse);
    });

    test('differing descriptions, same cat+account+direction → one key', () {
      final w1 = tx('1', TxnType.expense, 'acc-checking', 'cat-groceries',
          note: 'Weekly shop');
      final w2 = tx('2', TxnType.expense, 'acc-checking', 'cat-groceries',
          note: 'Bakery & fruit');
      final w3 = tx('3', TxnType.expense, 'acc-checking', 'cat-groceries',
          note: 'Market run');
      expect(SameKey.of(w1), SameKey.of(w2));
      expect(SameKey.of(w2), SameKey.of(w3));
      // Usable as a map key (equal hashCode).
      final byKey = {SameKey.of(w1): 'x'};
      expect(byKey[SameKey.of(w3)], 'x');
    });
  });

  group('index query', () {
    test('a transfer (one row) is listed once and counted once', () {
      final transfer =
          tx('t1', TxnType.transfer, 'acc-a', 'acc-b', amount: 50);
      final store = storeWith([transfer]);
      final list = store.sameTransactions(SameKey.of(transfer));
      expect(list.where((t) => t.id == 't1').length, 1);
      expect(SameStats.of(list, DateTime(2026, 8, 16), window: null).total, 50);
      expect(SameStats.of(list, DateTime(2026, 8, 16), window: null).count, 1);
    });

    test('an income key never returns expenses', () {
      final store = storeWith([
        tx('1', TxnType.expense, 'acc-checking', 'cat-salary'),
        tx('2', TxnType.income, 'cat-salary', 'acc-checking'),
      ]);
      final incomeKey = SameKey.of(store.txnById('2')!);
      final list = store.sameTransactions(incomeKey);
      expect(list.map((t) => t.id), ['2']);
    });

    test('results are newest-first and range-filtered', () {
      final store = storeWith([
        tx('old', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 6, 1)),
        tx('new', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
      ]);
      final key = SameKey.of(store.txnById('new')!);
      expect(store.sameTransactions(key).map((t) => t.id), ['new', 'old']);
      final julyOn = store.sameTransactions(key, from: DateTime(2026, 7, 1));
      expect(julyOn.map((t) => t.id), ['new']);
    });
  });

  group('stats()', () {
    test('one transaction: count 1, no frequency', () {
      final s = SameStats.of([tx('1', TxnType.expense, 'a', 'c')],
          DateTime(2026, 8, 16), window: null);
      expect(s.count, 1);
      expect(s.perMonth, isNull);
    });

    test('two transactions ≥14 days apart give a frequency', () {
      final list = [
        tx('n', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
        tx('o', TxnType.expense, 'a', 'c', date: DateTime(2026, 7, 5)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 16), window: null);
      expect(s.count, 2);
      expect(s.spanDays, 35);
      expect(s.perMonth, isNotNull);
    });

    test('a span under 14 days hides the frequency', () {
      final list = [
        tx('n', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
        tx('o', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 2)),
      ];
      expect(SameStats.of(list, DateTime(2026, 8, 16), window: null).perMonth, isNull);
    });

    test('acceptance fixture: Groceries · Main Checking, 7 entries', () {
      final dates = [
        DateTime(2026, 8, 9),
        DateTime(2026, 8, 1),
        DateTime(2026, 7, 28),
        DateTime(2026, 7, 19),
        DateTime(2026, 7, 5),
        DateTime(2026, 6, 21),
        DateTime(2026, 6, 12),
      ];
      final amounts = <double>[120, 186, 142, 168, 155, 163, 98];
      final list = [
        for (var i = 0; i < dates.length; i++)
          tx('$i', TxnType.expense, 'acc', 'cat',
              date: dates[i], amount: amounts[i]),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 16), window: null);
      expect(s.total, 1032);
      expect(s.count, 7);
      expect(s.average.round(), 147);
      expect(s.spanDays, 58);
      expect(s.perMonth!, closeTo(3.7, 0.1));
      expect(s.perMonth!.round(), 4);
      expect(s.lastDaysAgo, 7);
    });

    test('mixed-currency list totals in base currency (spec §3)', () {
      // The widened key can span currencies, so the aggregate folds each row
      // through Fx: €42 → 46.2 base (rate 1.10), $120 → 120. Total 166.2.
      final list = [
        Txn(
          id: 'e',
          type: TxnType.expense,
          amount: 42,
          currency: 'EUR',
          fromRef: 'acc-a',
          toRef: 'cat',
          date: DateTime(2026, 8, 9),
        ),
        Txn(
          id: 'u',
          type: TxnType.expense,
          amount: 120,
          currency: 'USD',
          fromRef: 'acc-b',
          toRef: 'cat',
          date: DateTime(2026, 8, 1),
        ),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 16), window: null);
      expect(s.total, closeTo(166.2, 0.001));
      expect(s.count, 2);
      expect(s.average, closeTo(83.1, 0.001));
    });
  });

  group('SameStats.of — window denominator (§1)', () {
    // Helper: the standard "Last 3 months" preset shape (1 Jun → 31 Aug 23:59).
    DateRange q3() =>
        DateRange(DateTime(2026, 6, 1), DateTime(2026, 8, 31, 23, 59, 59, 999));
    // The standard "This month" preset shape (1 Aug → 31 Aug 23:59).
    DateRange aug() =>
        DateRange(DateTime(2026, 8, 1), DateTime(2026, 8, 31, 23, 59, 59, 999));

    test('a bounded window longer than the span wins', () {
      // Two matches clustered in two days inside a three-month window: the rate
      // reflects the window the user chose, not the cluster's 1-day span.
      final list = [
        tx('n', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
        tx('o', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 8)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 9), window: q3());
      expect(s.spanDays, 1);
      expect(s.denominatorDays, 70); // 1 Jun → 9 Aug (clamped), inclusive
      expect(s.perMonth, isNotNull);
    });

    test('a span longer than the window (future-dated txn) keeps the span', () {
      // A transaction dated after today, inside a window whose end was clamped:
      // max holds the denominator at the real data span, never below it.
      final list = [
        tx('future', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 15)),
        tx('old', TxnType.expense, 'a', 'c', date: DateTime(2026, 6, 1)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 9),
          window: DateRange(
              DateTime(2026, 6, 1), DateTime(2026, 8, 20, 23, 59, 59, 999)));
      expect(s.spanDays, 75); // 1 Jun → 15 Aug
      expect(s.denominatorDays, s.spanDays); // window (70) < span (75)
    });

    test('a null window uses the span (All time)', () {
      final list = [
        tx('n', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
        tx('o', TxnType.expense, 'a', 'c', date: DateTime(2026, 6, 30)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 9), window: null);
      expect(s.spanDays, 40);
      expect(s.denominatorDays, 40);
    });

    test('a window under 14 days hides the rate (This month, early)', () {
      final list = [
        tx('n', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 2)),
        tx('o', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 1)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 3), window: aug());
      expect(s.denominatorDays, 3); // 1 Aug → 3 Aug, inclusive
      expect(s.perMonth, isNull);
    });

    test('the same window later in the month shows the rate', () {
      final list = [
        tx('one', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 5)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 28), window: aug());
      expect(s.denominatorDays, 28);
      expect(s.perMonth, isNotNull);
    });

    test('a window ending after today is clamped to today', () {
      final list = [
        tx('one', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 9), window: q3());
      // Not the full 92-day preset span — clamped to 1 Jun → 9 Aug = 70.
      expect(s.denominatorDays, 70);
    });

    test('one transaction over three months rounds to 0', () {
      // The honest answer the old span-based rule hid: one match in a long
      // window is "Less than once a month", not a suppressed line.
      final list = [
        tx('one', TxnType.expense, 'a', 'c', date: DateTime(2026, 8, 9)),
      ];
      final s = SameStats.of(list, DateTime(2026, 8, 22), window: q3());
      expect(s.perMonth, isNotNull);
      expect(s.perMonth!.round(), 0);
    });
  });

  group('range preference persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('default is Last 3 months', () async {
      final choice = await SameRangeChoice.load();
      expect(choice.isCustom, isFalse);
      expect(choice.preset, SameRangePreset.last3Months);
    });

    test('a preset round-trips', () async {
      await const SameRangeChoice.preset(SameRangePreset.last6Months).save();
      final restored = await SameRangeChoice.load();
      expect(restored.preset, SameRangePreset.last6Months);
    });

    test('a custom range round-trips', () async {
      await SameRangeChoice.custom(DateTime(2026, 6, 1), DateTime(2026, 8, 15))
          .save();
      final restored = await SameRangeChoice.load();
      expect(restored.isCustom, isTrue);
      expect(restored.customStart, DateTime(2026, 6, 1));
      expect(restored.customEnd, DateTime(2026, 8, 15));
    });

    test('setting the range never touches the period chip', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = buildSeedStore();
      final periodBefore = store.period;
      final asOfBefore = store.asOf;
      store.setSameListRange(
          const SameRangeChoice.preset(SameRangePreset.last6Months));
      expect(store.period, periodBefore);
      expect(store.asOf, asOfBefore);
      expect(store.sameListRange.preset, SameRangePreset.last6Months);
    });
  });
}
