import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';

final _today = AppStore.today; // 2026-08-09 14:32

DateTime _d(int y, int m, int day) => DateTime(y, m, day);

Account _acc(String id) => Account(
      id: id,
      name: id,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 0,
    );

Txn _tx(String id, TxnType type, String from, String to, double amount) => Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, 8, 5),
    );

void main() {
  group('whole-period bounds (never clamped to today)', () {
    test('This month → 1–31 Aug', () {
      final r = RangePreset.thisMonth.resolve(_today);
      expect(r.start, _d(2026, 8, 1));
      expect((r.end.month, r.end.day), (8, 31));
    });

    test('Last month → 1–31 Jul', () {
      final r = RangePreset.lastMonth.resolve(_today);
      expect(r.start, _d(2026, 7, 1));
      expect((r.end.month, r.end.day), (7, 31));
    });

    test('This week → 3–9 Aug (Mon–Sun)', () {
      final r = RangePreset.thisWeek.resolve(_today);
      expect(r.start, _d(2026, 8, 3));
      expect((r.end.month, r.end.day), (8, 9));
    });

    test('Last week → 27 Jul – 2 Aug', () {
      final r = RangePreset.lastWeek.resolve(_today);
      expect(r.start, _d(2026, 7, 27));
      expect((r.end.month, r.end.day), (8, 2));
    });

    test('Last 3 months → 1 Jun – 31 Aug', () {
      final r = RangePreset.last3Months.resolve(_today);
      expect(r.start, _d(2026, 6, 1));
      expect((r.end.month, r.end.day), (8, 31));
    });

    test('This year → 1 Jan – 31 Dec, NOT clamped to today', () {
      final r = RangePreset.thisYear.resolve(_today);
      expect(r.start, _d(2026, 1, 1));
      expect((r.end.month, r.end.day), (12, 31));
    });
  });

  group('cursor stepping is by whole unit', () {
    test('Last 3 months steps a whole block: 1 Jun–31 Aug → 1 Mar–31 May', () {
      final back = RangePreset.last3Months.resolve(_today).copyShifted(-1);
      expect(back.start, _d(2026, 3, 1));
      expect((back.end.month, back.end.day), (5, 31));
    });

    test('This year steps whole years', () {
      final back = RangePreset.thisYear.resolve(_today).copyShifted(-1);
      expect(back.start, _d(2025, 1, 1));
      expect((back.end.month, back.end.day), (12, 31));
    });

    test('Last month cursor is the previous month; ‹ reaches the one before',
        () {
      final last = RangePreset.lastMonth.resolve(_today);
      expect(last.start, _d(2026, 7, 1));
      final before = last.copyShifted(-1);
      expect(before.start, _d(2026, 6, 1));
      expect((before.end.month, before.end.day), (6, 30));
    });
  });

  group('in/out totals for one account (index-backed query)', () {
    late AppStore store;
    setUp(() {
      store = AppStore(
        accounts: [_acc('A'), _acc('B'), _acc('C')],
        categories: const <Category>[],
        txns: [
          _tx('inc', TxnType.income, 'cat', 'A', 900), // → in
          _tx('exp', TxnType.expense, 'A', 'cat', 100), // → out
          _tx('tout', TxnType.transfer, 'A', 'B', 50), // leaving A → out
          _tx('tin', TxnType.transfer, 'B', 'A', 30), // arriving at A → in
          _tx('other', TxnType.transfer, 'B', 'C', 70), // neither is A
        ],
        goals: const <Goal>[],
        tasks: const <Task>[],
      );
    });

    LedgerQuery queryFor(LedgerScope scope) {
      final r = RangePreset.thisMonth.resolve(_today);
      return LedgerQuery(store: store, scope: scope, start: r.start, end: r.end);
    }

    test('income + incoming transfer in; expense + outgoing transfer out', () {
      final q = queryFor(const AccountScope('A'));
      expect(q.totalIn, 930); // 900 + 30
      expect(q.totalOut, 150); // 100 + 50
    });

    test('a transfer between two other accounts never appears on this account',
        () {
      final q = queryFor(const AccountScope('A'));
      expect(q.rows().any((r) => r.txn.id == 'other'), isFalse);
    });

    test('the account index returns only txns touching that account', () {
      final touching = store.txnsForAccounts({'A'}).map((t) => t.id).toSet();
      expect(touching, {'inc', 'exp', 'tout', 'tin'});
      expect(touching.contains('other'), isFalse);
    });
  });

  group('unit persists, cursor resets to today', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('a saved unit round-trips and lands on the current period', () async {
      await savePeriodUnit('account_period_unit', PeriodUnit.year);
      final unit = await loadPeriodUnit('account_period_unit');
      expect(unit, PeriodUnit.year);

      // The cursor is not stored: launch lands on the period containing today.
      final landing = currentPresetFor(unit).resolve(_today);
      expect(landing.start, _d(2026, 1, 1));
      expect((landing.end.month, landing.end.day), (12, 31));
    });

    test('default unit is month', () async {
      expect(await loadPeriodUnit('account_period_unit'), PeriodUnit.month);
    });
  });
}
