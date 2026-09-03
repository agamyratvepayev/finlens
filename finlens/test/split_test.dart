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

    test('a zero (or negative) line is not balanced', () {
      expect(splitBalanced(150, [_line('c1', 150), _line('c2', 0)]), isFalse);
      expect(splitBalanced(100, [_line('c1', 120), _line('c2', -20)]), isFalse);
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
