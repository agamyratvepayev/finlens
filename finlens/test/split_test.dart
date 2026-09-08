import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/split_test.dart

double _sum(List<double> xs) => xs.fold(0.0, (a, b) => a + b);

SplitLine _line(String cat, double amt) =>
    SplitLine(categoryId: cat, amount: amt);

void main() {
  _splitEntryTests();
  group('splitEvenly distributes the remainder so the sum is exact (§2/§5)', () {
    test(r'$100 across 3 lines → 33.34 / 33.33 / 33.33', () {
      final s = splitEvenly(100, 3);
      expect(s, [33.34, 33.33, 33.33]);
      expect(_sum(s), closeTo(100, 1e-9));
    });

    test(r'$0.05 across 3 lines sums to exactly 0.05', () {
      final s = splitEvenly(0.05, 3);
      expect(_sum(s), closeTo(0.05, 1e-9));
    });

    test(r'$1,000.00 across 3 lines → 333.34 / 333.33 / 333.33', () {
      final s = splitEvenly(1000, 3);
      expect(s, [333.34, 333.33, 333.33]);
      expect(_sum(s), closeTo(1000, 1e-9));
    });

    test('an even split always reconciles to the total (resolves an overage)',
        () {
      // The helper divides the total, so it is exact whatever the lines held
      // before — the button's use for fixing an over-assignment (§7).
      for (final n in [2, 3, 4, 7]) {
        expect(_sum(splitEvenly(1200, n)), closeTo(1200, 1e-9));
      }
    });
  });

  test('a blank line contributes nothing and never balances (§5/§8)', () {
    expect(SplitLine().isBlank, isTrue);
    expect(SplitLine(amount: 0).isBlank, isFalse);
    final lines = [SplitLine(categoryId: 'c1', amount: 100), SplitLine(categoryId: 'c2')];
    expect(splitAssigned(lines), 100);
    expect(splitRemaining(200, lines), 100);
    expect(splitBalanced(200, lines), isFalse); // blank line → not committable
  });

  group('splitBalanced gates Apply (§2)', () {
    test('a single line is never a split', () {
      expect(splitBalanced(100, [_line('c1', 100)]), isFalse);
    });

    test('two lines summing to the total are balanced', () {
      expect(splitBalanced(200, [_line('c1', 150), _line('c2', 50)]), isTrue);
    });

    test('a non-zero remainder is not balanced', () {
      expect(splitBalanced(200, [_line('c1', 150), _line('c2', 40)]), isFalse);
    });

    // Re-baselined. The old rule demanded every line be `> 0`, so an
    // intentional "this category gets nothing" share could never be committed.
    // §8 replaces it with: the remainder is zero and no line is *unassigned*.
    // An explicit 0 is assigned; only null is not.
    test('an explicitly-zero line IS balanced (§8)', () {
      expect(splitBalanced(150, [_line('c1', 150), _line('c2', 0)]), isTrue);
    });

    test('an unassigned line is not balanced even at a zero remainder (§8)', () {
      expect(
        splitBalanced(150, [_line('c1', 150), SplitLine(categoryId: 'c2')]),
        isFalse,
      );
    });

    // Collateral, and flagged rather than hidden: dropping the `> 0` test also
    // dropped the sign check, so a negative share that happens to reconcile now
    // passes. It is unreachable from the sheet — the keypad has no minus key and
    // no code path writes a negative amount — and §8 defines the rule as
    // remainder-plus-assigned with no mention of sign, so no guard was invented
    // here. Pinned so the widening is visible if it ever becomes reachable.
    test('a negative line that reconciles is now accepted (unreachable in UI)',
        () {
      expect(splitBalanced(100, [_line('c1', 120), _line('c2', -20)]), isTrue);
    });

    test('a line without a category is not balanced', () {
      expect(
          splitBalanced(100, [SplitLine(amount: 50), _line('c2', 50)]), isFalse);
    });
  });

  test('changing the amount after applying leaves lines untouched (§5)', () {
    final lines = [_line('c1', 150), _line('c2', 50)]; // balanced at 200
    expect(splitRemaining(200, lines), closeTo(0, 1e-9));
    // The total changes; the lines are NOT rescaled — remainder goes non-zero.
    expect(splitRemaining(220, lines), closeTo(20, 1e-9));
    expect(lines[0].amount, 150);
    expect(lines[1].amount, 50);
    expect(splitBalanced(220, lines), isFalse);
  });

  test('a split stores one transaction per line sharing a splitGroupId (§2)',
      () {
    final store = AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
        Category(
            id: 'h',
            name: 'Household',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

    final date = DateTime(2026, 8, 5);
    final first = store.addTxn(
        type: TxnType.expense,
        amount: 150,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'g',
        date: date,
        tagIds: ['shop'],
        note: 'Weekly');
    first.splitGroupId = first.id;
    store.addTxn(
        type: TxnType.expense,
        amount: 50,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'h',
        date: date,
        tagIds: ['shop'],
        note: 'Weekly',
        splitGroupId: first.id);

    final group =
        store.txns.where((t) => t.splitGroupId == first.id).toList();
    expect(group.length, 2);
    // Same account, date, note, tag on every line; own category and amount.
    expect(group.every((t) => t.fromRef == 'a1'), isTrue);
    expect(group.every((t) => t.date == date), isTrue);
    expect(group.every((t) => t.note == 'Weekly'), isTrue);
    expect(group.every((t) => t.tagIds.contains('shop')), isTrue);
    expect(group.map((t) => t.toRef).toSet(), {'g', 'h'});
    // A plain transaction has no group.
    final plain = store.addTxn(
        type: TxnType.expense,
        amount: 5,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'g',
        date: date);
    expect(plain.splitGroupId, isNull);
  });

  test('a split group survives encodeBackup → decodeBackup with grouping intact',
      () {
    final store = AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
        Category(
            id: 'h',
            name: 'Household',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

    final date = DateTime(2026, 8, 5);
    final first = store.addTxn(
        type: TxnType.expense,
        amount: 800,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'g',
        date: date);
    first.splitGroupId = first.id;
    store.addTxn(
        type: TxnType.expense,
        amount: 400,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'h',
        date: date,
        splitGroupId: first.id);

    final json = encodeBackup(store, exportedAt: DateTime(2026, 9, 3));
    final restored = decodeBackup(json).source;

    final group =
        restored.txns.where((t) => t.splitGroupId == first.id).toList();
    expect(group.length, 2);
    expect(group.map((t) => t.amount).toSet(), {800.0, 400.0});
    expect(group.map((t) => t.toRef).toSet(), {'g', 'h'});
  });
}

// ── Added with the keypad change ─────────────────────────────────────────────

void _splitEntryTests() {
  group('splitEvenly distributes the leftover one each (§7)', () {
    test(r'$100.00 over three lines sums to exactly $100.00', () {
      final s = splitEvenly(100, 3);
      expect(s, [33.34, 33.33, 33.33]);
      expect((s.fold<double>(0, (a, b) => a + b) * 100).round(), 10000);
    });

    test(r'$100.00 over seven lines spreads the leftover, not dumps it', () {
      final s = splitEvenly(100, 7);
      // Was 14.32 + 14.28×6 — exact, but the whole rounding error on line 1.
      expect(s, [14.29, 14.29, 14.29, 14.29, 14.28, 14.28, 14.28]);
      expect((s.fold<double>(0, (a, b) => a + b) * 100).round(), 10000);
    });

    test(r'$0.01 over three lines', () {
      final s = splitEvenly(0.01, 3);
      expect(s, [0.01, 0.0, 0.0]);
      expect((s.fold<double>(0, (a, b) => a + b) * 100).round(), 1);
    });

    test(r'$208,957.00 over seven lines', () {
      final s = splitEvenly(208957, 7);
      expect((s.fold<double>(0, (a, b) => a + b) * 100).round(), 20895700);
    });

    test('a single line takes the whole total', () {
      expect(splitEvenly(100, 1), [100.0]);
    });

    test('zero lines yields nothing', () => expect(splitEvenly(100, 0), isEmpty));
  });

  group('the remainder boundaries (§5)', () {
    SplitLine l(double? a) => SplitLine(categoryId: 'c', amount: a);

    test('one minor unit short is under', () {
      expect(splitRemaining(100, [l(50), l(49.99)]), closeTo(0.01, 1e-9));
    });

    test('exact is zero within the cent epsilon', () {
      expect(splitRemaining(100, [l(50), l(50)]).abs(), lessThan(kMoneyEpsilon));
    });

    test('one minor unit over is negative', () {
      expect(splitRemaining(100, [l(50), l(50.01)]), closeTo(-0.01, 1e-9));
    });

    test('a blank line contributes nothing', () {
      expect(splitRemaining(100, [l(40), l(null)]), 60);
    });
  });

  group('Done enablement (§8)', () {
    SplitLine l(double? a) => SplitLine(categoryId: 'c', amount: a);

    test('remainder zero with an unassigned line is disabled', () {
      expect(splitBalanced(100, [l(100), l(null)]), isFalse);
    });

    test('remainder zero with an explicit zero line is enabled', () {
      expect(splitBalanced(100, [l(100), l(0)]), isTrue);
    });

    test('a non-zero remainder is disabled', () {
      expect(splitBalanced(100, [l(50), l(40)]), isFalse);
    });

    test('a line with no category is disabled', () {
      expect(
        splitBalanced(100, [SplitLine(amount: 50), l(50)]),
        isFalse,
      );
    });

    test('a single line is not a split', () {
      expect(splitBalanced(100, [l(100)]), isFalse);
    });
  });
}
