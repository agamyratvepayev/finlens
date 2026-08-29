import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/core/utils/fx.dart';

/// Insight's store API (spec §1 / §12). These are the tests that prove the
/// screen is not lying — the two identities in §0, the delegation refactor, the
/// empty-period rule, and the §9 FX fix.
void main() {
  final today = AppStore.today; // 2026-08-09

  DateRange month(int y, int m) =>
      DateRange(DateTime(y, m, 1), DateTime(y, m + 1, 0, 23, 59, 59, 999),
          preset: RangePreset.thisMonth);

  final august = RangePreset.thisMonth.resolve(today);
  final customJulAug = DateRange(
      DateTime(2026, 7, 15), DateTime(2026, 8, 15, 23, 59, 59, 999));

  void expectIdentities(AppStore s, DateRange w, {String? label}) {
    final net = s.netWorthChangeInWindow(w);

    // Flow identity: net = income − expense + revalued − transferLeak.
    final flow = s.inflowInWindow(w) -
        s.outflowInWindow(w) +
        s.revaluedInWindow(w) -
        s.transferLeakInWindow(w);
    expect((net - flow).abs(), lessThan(1e-6),
        reason: 'flow identity ${label ?? w.start}');

    // Stock identity: net = Σ over groups of groupChange.
    final stock = AccountGroup.values
        .fold(0.0, (sum, g) => sum + s.groupChangeInWindow(g, w));
    expect((net - stock).abs(), lessThan(1e-6),
        reason: 'stock identity ${label ?? w.start}');
  }

  group('the two identities (§0)', () {
    test('hold for the six named windows', () {
      final s = buildSeedStore();
      for (final p in RangePreset.values) {
        expectIdentities(s, p.resolve(today), label: p.name);
      }
      expectIdentities(s, customJulAug, label: 'custom 15 Jul – 15 Aug');
    });

    test('hold for twenty pseudo-random windows (fixed seed)', () {
      final s = buildSeedStore();
      final rnd = Random(20260809);
      for (var i = 0; i < 20; i++) {
        final start = DateTime(2025, 7, 1).add(Duration(days: rnd.nextInt(410)));
        final len = 1 + rnd.nextInt(140);
        final end = DateTime(start.year, start.month, start.day + len,
            23, 59, 59, 999);
        expectIdentities(s, DateRange(start, end), label: 'random #$i');
      }
    });

    test('August 2026 computes the documented figures', () {
      final s = buildSeedStore();
      expect(s.netWorthChangeInWindow(august), closeTo(4424.70, 0.01));
      expect(s.inflowInWindow(august), closeTo(6100, 0.01));
      expect(s.outflowInWindow(august), closeTo(2972, 0.01));
      expect(s.revaluedInWindow(august), closeTo(1300, 0.01));
      expect(s.transferLeakInWindow(august), closeTo(3.30, 0.01));
      expect(s.groupChangeInWindow(AccountGroup.spendable, august),
          closeTo(3554.70, 0.01));
      expect(s.groupChangeInWindow(AccountGroup.investments, august),
          closeTo(1300, 0.01));
      expect(s.groupChangeInWindow(AccountGroup.creditCards, august),
          closeTo(-430, 0.01));
    });

    test('the custom 15 Jul – 15 Aug window moves payables by +60', () {
      final s = buildSeedStore();
      expect(s.netWorthChangeInWindow(customJulAug), closeTo(3104.70, 0.01));
      expect(s.groupChangeInWindow(AccountGroup.payables, customJulAug),
          closeTo(60, 0.01));
    });
  });

  group('delegation refactor (§1)', () {
    test('spentInCategory equals its window twin for every category & month', () {
      final s = buildSeedStore();
      for (var m = DateTime(2025, 9); !m.isAfter(DateTime(2026, 8));
          m = DateTime(m.year, m.month + 1)) {
        for (final c in s.categories) {
          expect(s.spentInCategory(c.id, m),
              s.spentInCategoryWindow(c.id, month(m.year, m.month)),
              reason: '${c.id} ${m.year}-${m.month}');
        }
      }
    });

    test('the pinned August category figures are unchanged', () {
      final s = buildSeedStore();
      expect(s.spentInCategory('c-housing', DateTime(2026, 8)), closeTo(1140, 0.01));
      expect(s.monthIncome(DateTime(2026, 8)), closeTo(6100, 0.01));
      expect(s.monthExpense(DateTime(2026, 8)), closeTo(2972, 0.01));
    });
  });

  group('transferLeakInWindow (§0)', () {
    test('0 for the same-currency card payment, 3.30 for the FX transfer', () {
      final s = buildSeedStore();
      final cardpayDay = DateRange(
          DateTime(2026, 8, 5), DateTime(2026, 8, 5, 23, 59, 59, 999));
      final fxDay = DateRange(
          DateTime(2026, 8, 4), DateTime(2026, 8, 4, 23, 59, 59, 999));
      expect(s.transferLeakInWindow(cardpayDay), closeTo(0, 0.001));
      expect(s.transferLeakInWindow(fxDay), closeTo(3.30, 0.01));
    });
  });

  group('the empty-period rule (§6)', () {
    List<double> housingSixPeriods(AppStore s) {
      final windows = [for (var n = 5; n >= 0; n--) august.copyShifted(-n)];
      return [for (final w in windows) s.spentInCategoryWindow('c-housing', w)];
    }

    test('Housing renders Mar/—/May/—/Jul/Aug with a 1222.75 average', () {
      final s = buildSeedStore();
      final values = housingSixPeriods(s);
      expect(values[0], closeTo(1236, 0.01)); // Mar
      expect(values[1], closeTo(0, 0.01)); // Apr — empty
      expect(values[2], closeTo(1255, 0.01)); // May
      expect(values[3], closeTo(0, 0.01)); // Jun — empty
      expect(values[4], closeTo(1260, 0.01)); // Jul
      expect(values[5], closeTo(1140, 0.01)); // Aug

      final withData = values.where((v) => v > 0.005).toList();
      final avg = withData.reduce((a, b) => a + b) / withData.length;
      expect(withData.length, 4);
      expect(avg, closeTo(1222.75, 0.01)); // the honest average

      final sixAvg = values.reduce((a, b) => a + b) / 6;
      expect((sixAvg - avg).abs(), greaterThan(1)); // the six-way divide is a lie
    });

    test('Salary has only two periods with data — no average/trend', () {
      final s = buildSeedStore();
      final windows = [for (var n = 5; n >= 0; n--) august.copyShifted(-n)];
      final values = [for (final w in windows) s.earnedInCategoryWindow('c-salary', w)];
      final withData = values.where((v) => v > 0.005).toList();
      expect(withData.length, 2); // Jul + Aug only
    });
  });

  group('the contradiction warning predicate (§3.7)', () {
    bool warns(AppStore s, DateRange w) {
      final spentMore = s.outflowInWindow(w) > s.inflowInWindow(w);
      final rose = s.netWorthChangeInWindow(w) > 0;
      return spentMore == rose;
    }

    test('true for 3–9 Aug 2026, false for August', () {
      final s = buildSeedStore();
      expect(warns(s, RangePreset.thisWeek.resolve(today)), isTrue);
      expect(warns(s, august), isFalse);
    });
  });

  group('categoryFlowInWindow (§0)', () {
    test('returns the income and expense buckets for August', () {
      final s = buildSeedStore();
      final flow = s.categoryFlowInWindow(august);
      expect(flow.income['c-salary'], closeTo(5200, 0.01));
      expect(flow.income['c-freelance'], closeTo(900, 0.01));
      expect(flow.expense['c-housing'], closeTo(1140, 0.01));
      // No zero bar: the top expense category is not the whole block (this is
      // the regression the old `spent / max` scaling produced).
      final total = flow.expense.values.reduce((a, b) => a + b);
      final maxShare =
          flow.expense.values.reduce((a, b) => a > b ? a : b) / total;
      expect(maxShare, lessThan(1.0));
    });
  });

  group('the FX gap (§9)', () {
    test('August is all-USD, so the Ledger strip is unchanged', () {
      final s = buildSeedStore();
      expect(s.incomeInWindow(august), closeTo(6100, 0.01));
      expect(s.expenseInWindow(august), closeTo(2972, 0.01));
      expect(s.incomeInWindow(august) - s.expenseInWindow(august),
          closeTo(3128, 0.01));
    });

    test('March 2026 income is converted — €300 counts as \$330', () {
      final s = buildSeedStore();
      final march = month(2026, 3);
      final incomeTxns =
          s.txnsInWindow(march).where((t) => t.type == TxnType.income);
      final raw = incomeTxns.fold(0.0, (sum, t) => sum + t.amount);
      final converted =
          incomeTxns.fold(0.0, (sum, t) => sum + Fx.toBase(t.amount, t.currency));
      expect(s.inflowInWindow(march), closeTo(converted, 0.01));
      // The EUR freelance row makes converted differ from a raw fold (300 → 330).
      expect((converted - raw).abs(), greaterThan(1));
    });
  });
}
