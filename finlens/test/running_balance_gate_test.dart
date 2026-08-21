import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/trans_filter.dart';

// Unit tests for the balance predicate (balance spec §1). A running-balance
// column is legible only when three things hold at once: one account, a date
// sort, and nothing narrowed. Each condition is exercised failing alone, then
// all three passing — plus the one-account group, which must qualify because the
// predicate derives from the account COUNT, not the scope class.

LedgerListShape _shape({
  int accountCount = 1,
  TransSort sort = TransSort.dateNewest,
  bool narrowed = false,
}) =>
    LedgerListShape(
      accountCount: accountCount,
      sort: sort,
      narrowed: narrowed,
    );

void main() {
  test('all three conditions hold → the balance shows', () {
    expect(_shape().showsRunningBalance, isTrue);
    // The other date sort qualifies too — reading down, the tape grows.
    expect(_shape(sort: TransSort.dateOldest).showsRunningBalance, isTrue);
  });

  test('more than one account → no balance (interleaved tapes)', () {
    expect(_shape(accountCount: 2).showsRunningBalance, isFalse);
    expect(_shape(accountCount: 8).showsRunningBalance, isFalse);
  });

  test('a one-account group qualifies (count, not scope class)', () {
    // A GroupScope holding exactly one account is a tape.
    expect(_shape(accountCount: 1).isSingleAccount, isTrue);
    expect(_shape(accountCount: 1).showsRunningBalance, isTrue);
  });

  test('a non-date sort → no balance (the column is arbitrary)', () {
    for (final s in [
      TransSort.amountHigh,
      TransSort.amountLow,
      TransSort.byName,
    ]) {
      expect(_shape(sort: s).showsRunningBalance, isFalse,
          reason: '$s must suppress the balance');
    }
  });

  test('narrowed (filter / search / direction chip) → no balance', () {
    expect(_shape(narrowed: true).showsRunningBalance, isFalse);
  });

  test('only one condition failing is enough to suppress it', () {
    // Single account + date sort, but narrowed.
    expect(_shape(narrowed: true).showsRunningBalance, isFalse);
    // Single account + not narrowed, but amount sort.
    expect(_shape(sort: TransSort.amountHigh).showsRunningBalance, isFalse);
    // Date sort + not narrowed, but multi-account.
    expect(_shape(accountCount: 3).showsRunningBalance, isFalse);
  });
}
