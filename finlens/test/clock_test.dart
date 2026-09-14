import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/diagnostics/clock_damage_report.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/formatters.dart';

/// The clock — regression net (spec §10).
///
/// Do NOT run with `flutter test` on this machine (the runner hangs); these are
/// authored for the user to run. They pin the clock with [Clock.fixed] and prove
/// that `today`/`now` behave and that every date-dependent figure resolves to
/// the injected clock rather than the wall clock.
void main() {
  final pinned = DateTime(2026, 8, 9, 14, 32);

  AppStore storeAt(DateTime at) => AppStore.empty(clock: Clock.fixed(at));

  group('today / now semantics', () {
    test('today returns midnight; now returns the instant; they agree on day',
        () {
      final s = storeAt(pinned);
      expect(s.today, DateTime(2026, 8, 9));
      expect(s.now, pinned);
      expect(s.today.year, s.now.year);
      expect(s.today.month, s.now.month);
      expect(s.today.day, s.now.day);
    });

    test('a fixed clock at 14:32 reproduces the old constant\'s day', () {
      // The pre-clock code used a static `DateTime(2026, 8, 9, 14, 32)`. A store
      // pinned to that instant must report the same day everywhere.
      final s = storeAt(pinned);
      expect(s.today, DateTime(2026, 8, 9));
    });

    test('consecutive-day clocks straddling midnight land on different days',
        () {
      final before = storeAt(DateTime(2026, 8, 9, 23, 59, 59));
      final after = storeAt(DateTime(2026, 8, 10, 0, 0, 1));
      expect(before.today, DateTime(2026, 8, 9));
      expect(after.today, DateTime(2026, 8, 10));
      expect(before.today == after.today, isFalse);
    });
  });

  group('period controls open on the period containing today', () {
    void expectContains(DateTime at) {
      final s = storeAt(at);
      final today = s.today;
      // Ledger + Planner month.
      expect(s.period.year, today.year);
      expect(s.period.month, today.month);
      // Insight window.
      final w = s.insightWindow;
      expect(w.start.isAfter(today), isFalse);
      expect(w.end.isBefore(today), isFalse);
      // Schedule completed range.
      final c = s.completedRange;
      expect(c.start.isAfter(today), isFalse);
      expect(c.end.isBefore(today), isFalse);
    }

    test('mid-month', () => expectContains(DateTime(2026, 8, 9, 14, 32)));
    test('month boundary', () => expectContains(DateTime(2026, 12, 31, 23, 0)));
    test('year boundary', () => expectContains(DateTime(2026, 1, 1, 0, 30)));
  });

  group('addTxn stamps createdAt from the real instant (§5b, forward only)', () {
    test('createdAt is now, not the (editable) transaction date', () {
      final s = AppStore(
        clock: Clock.fixed(pinned),
        accounts: [
          Account(
              id: 'a1',
              name: 'A',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 0),
        ],
        categories: [
          Category(
              id: 'c1',
              name: 'C',
              type: CategoryType.expense,
              icon: Icons.abc,
              color: const Color(0xFF000000)),
        ],
        txns: const [],
        goals: const [],
        tasks: const [],
      );
      final backdated = DateTime(2026, 7, 1);
      final t = s.addTxn(
        type: TxnType.expense,
        amount: 10,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c1',
        date: backdated,
      );
      expect(t.date, backdated);
      expect(t.createdAt, pinned); // the real instant, not the date
    });
  });

  group('_isSuspect (§5a)', () {
    Txn tx(String id, DateTime date, {DateTime? createdAt}) => Txn(
          id: id,
          type: TxnType.expense,
          amount: 1,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'c1',
          date: date,
          createdAt: createdAt,
        );

    test('flags only a 9-Aug record recorded later', () {
      // dated 9 Aug, created 9 Aug → not suspect.
      expect(
          isSuspectTxn(tx('a', DateTime(2026, 8, 9),
              createdAt: DateTime(2026, 8, 9, 10))),
          isFalse);
      // dated 9 Aug, created 20 Aug → suspect.
      expect(
          isSuspectTxn(tx('b', DateTime(2026, 8, 9),
              createdAt: DateTime(2026, 8, 20))),
          isTrue);
      // dated 20 Aug, created 20 Aug → not suspect.
      expect(
          isSuspectTxn(tx('c', DateTime(2026, 8, 20),
              createdAt: DateTime(2026, 8, 20))),
          isFalse);
      // no explicit createdAt (defaults to date) → not suspect.
      expect(isSuspectTxn(tx('d', DateTime(2026, 8, 9))), isFalse);
    });
  });

  group('damage report is read-only (§5)', () {
    test('leaves the record list identical', () {
      final s = AppStore(
        clock: Clock.fixed(pinned),
        accounts: [
          Account(
              id: 'a1',
              name: 'A',
              group: AccountGroup.spendable,
              currency: 'USD',
              startingBalance: 0),
        ],
        categories: [
          Category(
              id: 'c1',
              name: 'C',
              type: CategoryType.expense,
              icon: Icons.abc,
              color: const Color(0xFF000000)),
        ],
        txns: [
          Txn(
              id: 't1',
              type: TxnType.expense,
              amount: 5,
              currency: 'USD',
              fromRef: 'a1',
              toRef: 'c1',
              date: DateTime(2026, 8, 9)),
          Txn(
              id: 't2',
              type: TxnType.expense,
              amount: 7,
              currency: 'USD',
              fromRef: 'a1',
              toRef: 'c1',
              date: DateTime(2026, 8, 20)),
        ],
        goals: const [],
        tasks: const [],
      );

      List<(String, DateTime, double)> snap() => [
            for (final t in s.snapshotTxns) (t.id, t.date, t.amount),
          ];
      final before = snap();
      final report = analyzeClockDamage(s);
      final after = snap();

      expect(after, before); // deep equality — nothing moved
      // createdAt defaulted to date on both, so this is an upper bound.
      expect(report.createdAtInformative, isFalse);
      expect(report.aug9Txns.length, 1); // only t1 is dated 9 Aug
      expect(report.suspectTxns, isEmpty); // degenerate createdAt → no suspects
    });
  });

  group('day-count arithmetic is right in every month (§10)', () {
    test('leap February and a 31-day month', () {
      expect(daysInMonth(DateTime(2024, 2, 1)), 29); // leap
      expect(daysInMonth(DateTime(2026, 2, 1)), 28); // non-leap
      expect(daysInMonth(DateTime(2026, 8, 1)), 31);
      expect(daysInMonth(DateTime(2026, 4, 1)), 30);
    });
  });

  group('the seed fixture is pinned and unchanged', () {
    test('buildSeedStore reports the mockups\' day', () {
      expect(buildSeedStore().today, DateTime(2026, 8, 9));
    });
  });
}
