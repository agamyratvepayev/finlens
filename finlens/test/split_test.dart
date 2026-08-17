import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
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
        tags: ['shop'],
        note: 'Weekly');
    first.splitGroupId = first.id;
    store.addTxn(
        type: TxnType.expense,
        amount: 50,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'h',
        date: date,
        tags: ['shop'],
        note: 'Weekly',
        splitGroupId: first.id);

    final group =
        store.txns.where((t) => t.splitGroupId == first.id).toList();
    expect(group.length, 2);
    // Same account, date, note, tag on every line; own category and amount.
    expect(group.every((t) => t.fromRef == 'a1'), isTrue);
    expect(group.every((t) => t.date == date), isTrue);
    expect(group.every((t) => t.note == 'Weekly'), isTrue);
    expect(group.every((t) => t.tags.contains('shop')), isTrue);
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
}
