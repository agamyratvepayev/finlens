import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/dev_seed_data.dart';
import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/same_transactions.dart';

// Verification for the development data seeder. `flutter test` hangs on the
// author's machine, so these are the acceptance gate — run them yourself:
//   flutter test test/dev_seed_test.dart
// The generator is deterministic (fixed RNG + AppStore.today), so a pass here
// is a pass everywhere.

final DateTime _today = AppStore.today;

/// Does [t] touch [accountId] in an account role?
bool _touches(Txn t, String accountId) {
  switch (t.type) {
    case TxnType.expense:
      return t.fromRef == accountId;
    case TxnType.income:
      return t.toRef == accountId;
    case TxnType.transfer:
      return t.fromRef == accountId || t.toRef == accountId;
    case TxnType.rebalance:
      return t.toRef == accountId;
  }
}

/// Counts txns per (category+account+direction / transfer) key, using the app's
/// own keying so the numbers match the Same-transactions screen.
Map<SameKey, List<Txn>> _byKey(List<Txn> txns) {
  final out = <SameKey, List<Txn>>{};
  for (final t in txns) {
    out.putIfAbsent(SameKey.of(t), () => []).add(t);
  }
  return out;
}

void main() {
  final txns = buildDevTxns(_today);

  group('reconciliation (§4)', () {
    test('each account back-computes to its documented target balance', () {
      final prod = buildSeedStore();
      final dev = buildDevSeedStore();
      for (final a in prod.accounts) {
        expect(dev.balanceOf(a.id), closeTo(prod.balanceOf(a.id), 0.01),
            reason: 'account ${a.id} drifted from its target');
      }
    });

    test('net worth matches the untouched fixture', () {
      expect(buildDevSeedStore().netWorth,
          closeTo(buildSeedStore().netWorth, 0.01));
    });
  });

  group('transfers', () {
    test('every transfer references two distinct real accounts', () {
      final dev = buildDevSeedStore();
      final ids = {for (final a in dev.accounts) a.id};
      final transfers = txns.where((t) => t.type == TxnType.transfer);
      expect(transfers, isNotEmpty);
      for (final t in transfers) {
        expect(ids.contains(t.fromRef), isTrue, reason: 'bad from ${t.fromRef}');
        expect(ids.contains(t.toRef), isTrue, reason: 'bad to ${t.toRef}');
        expect(t.fromRef == t.toRef, isFalse);
        expect(t.amount, greaterThan(0));
      }
    });

    test('a directional pair exists in both directions', () {
      final keys = _byKey(txns).keys.whereType<TransferKey>().toSet();
      expect(keys.contains(const TransferKey('a-checking', 'a-amex')), isTrue);
      expect(keys.contains(const TransferKey('a-amex', 'a-checking')), isTrue);
    });

    test('at least five transfers on one directional pair', () {
      final list = txns
          .where((t) =>
              t.type == TxnType.transfer &&
              t.fromRef == 'a-checking' &&
              t.toRef == 'a-amex')
          .length;
      expect(list, greaterThanOrEqualTo(5));
    });

    test('a cross-currency transfer exists (EUR ↔ USD) with a toAmount', () {
      final fx = txns.where((t) =>
          t.type == TxnType.transfer &&
          t.fromRef == 'a-cash-eur' &&
          t.toRef == 'a-cash-usd' &&
          t.toAmount != null);
      expect(fx, isNotEmpty);
    });
  });

  group('day distribution (§5)', () {
    late Map<int, int> byDay; // bucket size -> number of days of that size
    setUp(() {
      final perDay = <DateTime, int>{};
      for (final t in txns) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        perDay[d] = (perDay[d] ?? 0) + 1;
      }
      byDay = {};
      for (final n in perDay.values) {
        byDay[n] = (byDay[n] ?? 0) + 1;
      }
    });

    test('minimum counts of 1-, 2-, 3+- and 5+-transaction days hold', () {
      final ones = byDay[1] ?? 0;
      final twos = byDay[2] ?? 0;
      final threePlus =
          byDay.entries.where((e) => e.key >= 3).fold(0, (s, e) => s + e.value);
      final fivePlus =
          byDay.entries.where((e) => e.key >= 5).fold(0, (s, e) => s + e.value);
      expect(ones, greaterThanOrEqualTo(10));
      expect(twos, greaterThanOrEqualTo(8));
      expect(threePlus, greaterThanOrEqualTo(6));
      expect(fivePlus, greaterThanOrEqualTo(1));
    });

    test('a day nets to zero', () {
      final signed = <DateTime, double>{};
      for (final t in txns) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        final delta = switch (t.type) {
          TxnType.income => t.amount,
          TxnType.expense => -t.amount,
          _ => 0.0,
        };
        signed[d] = (signed[d] ?? 0) + delta;
      }
      expect(signed.values.any((v) => v.abs() < 0.001), isTrue);
    });
  });

  group('same-transactions keys (§5)', () {
    late Map<SameKey, List<Txn>> keyed;
    setUp(() => keyed = _byKey(txns));

    test('at least three keys have 8+ transactions', () {
      final big = keyed.values.where((l) => l.length >= 8).length;
      expect(big, greaterThanOrEqualTo(3));
    });

    test('a key has exactly one, and another exactly two', () {
      expect(keyed.values.any((l) => l.length == 1), isTrue);
      expect(keyed.values.any((l) => l.length == 2), isTrue);
    });

    test('a key spans under 14 days so its frequency line hides', () {
      final hidden = keyed.values.where((l) {
        final sorted = [...l]..sort((a, b) => b.date.compareTo(a.date));
        return SameStats.of(sorted, _today).perMonth == null && l.length >= 2;
      });
      expect(hidden, isNotEmpty);
    });

    test('the same category appears on two different accounts', () {
      final groceriesExpense = keyed.keys.whereType<LedgerKey>().where((k) =>
          k.categoryId == 'c-groceries' && k.direction == TxnType.expense);
      expect(groceriesExpense.map((k) => k.accountId).toSet().length,
          greaterThanOrEqualTo(2));
    });
  });

  group('coverage (§2)', () {
    test('every category appears on at least five transactions', () {
      final store = buildDevSeedStore();
      for (final c in store.categories) {
        final n = txns.where((t) {
          if (t.type == TxnType.expense) return t.toRef == c.id;
          if (t.type == TxnType.income) return t.fromRef == c.id;
          return false;
        }).length;
        expect(n, greaterThanOrEqualTo(5), reason: 'category ${c.id} has $n');
      }
    });

    test('spendable accounts carry 5+ of each applicable type', () {
      for (final id in ['a-checking', 'a-cash-usd', 'a-cash-eur', 'a-family']) {
        for (final type in [TxnType.expense, TxnType.income, TxnType.transfer]) {
          final n = txns
              .where((t) => t.type == type && _touches(t, id))
              .length;
          expect(n, greaterThanOrEqualTo(5),
              reason: '$id has $n of $type');
        }
      }
    });
  });

  group('negative running balance (§5)', () {
    test('Family Wallet dips below zero before recovering', () {
      final dev = buildDevSeedStore();
      final family = txns.where((t) => _touches(t, 'a-family'));
      final minRunning = family
          .map((t) => dev.runningBalanceAt('a-family', t))
          .fold(double.infinity, (m, v) => v < m ? v : m);
      expect(minRunning, lessThan(0));
      // ...yet the final balance is the positive documented target.
      expect(dev.balanceOf('a-family'), greaterThan(0));
    });
  });

  group('text & layout stress (§5)', () {
    test('has empty, long, and Turkish-descender descriptions', () {
      expect(txns.any((t) => t.note.isEmpty), isTrue);
      expect(txns.any((t) => t.note.length >= 60), isTrue);
      expect(txns.any((t) => t.note.contains('ğ') || t.note.contains('Ş')),
          isTrue);
    });

    test('at least ten tagged transactions across three or more tags', () {
      final tagged = txns.where((t) => t.tags.isNotEmpty).length;
      final distinct = {for (final t in txns) ...t.tags};
      expect(tagged, greaterThanOrEqualTo(10));
      expect(distinct.length, greaterThanOrEqualTo(3));
    });
  });

  group('determinism & reset (§7)', () {
    test('building twice yields the identical record set', () {
      final a = buildDevTxns(_today);
      final b = buildDevTxns(_today);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id);
        expect(a[i].amount, b[i].amount);
        expect(a[i].date, b[i].date);
      }
      expect(buildDevSeedStore().txns.length, buildDevSeedStore().txns.length);
    });

    test('reset (the untouched fixture) contains no seeded records', () {
      expect(buildSeedStore().txns.any(isDevSeededTxn), isFalse);
      expect(buildDevSeedStore().txns.every(isDevSeededTxn), isTrue);
    });
  });

  group('runtime seed/reset menu (loadFrom)', () {
    test('seeding an existing store swaps in the dev history', () {
      final store = buildSeedStore();
      final prod = buildSeedStore();
      store.loadFrom(buildDevSeedStore());
      expect(store.txns.length, buildDevSeedStore().txns.length);
      expect(store.txns.every(isDevSeededTxn), isTrue);
      // Balances still reconcile to the documented targets after the swap.
      for (final a in prod.accounts) {
        expect(store.balanceOf(a.id), closeTo(prod.balanceOf(a.id), 0.01),
            reason: 'account ${a.id} drifted after loadFrom');
      }
    });

    test('seeding twice yields the same record count (idempotent)', () {
      final store = buildSeedStore();
      store.loadFrom(buildDevSeedStore());
      final once = store.txns.length;
      store.loadFrom(buildDevSeedStore());
      expect(store.txns.length, once);
    });

    test('reset removes every seeded record', () {
      final store = buildSeedStore();
      store.loadFrom(buildDevSeedStore());
      store.loadFrom(buildSeedStore());
      expect(store.txns.any(isDevSeededTxn), isFalse);
      expect(store.txns.length, buildSeedStore().txns.length);
    });

    test('loaded preferences survive the swap', () {
      final store = buildSeedStore();
      store.toggleMasked();
      expect(store.masked, isTrue);
      store.loadFrom(buildDevSeedStore());
      expect(store.masked, isTrue, reason: 'in-place swap must preserve prefs');
    });
  });

  test('report: counts and opening balances', () {
    final prod = buildSeedStore();
    final dev = buildDevSeedStore();
    debugPrint('── Seeded transactions: ${txns.length} total ──');
    for (final a in dev.accounts) {
      final n = txns.where((t) => _touches(t, a.id)).length;
      debugPrint('${a.id.padRight(14)} txns=$n  '
          'opening=${a.startingBalance.toStringAsFixed(2).padLeft(10)}  '
          'balance=${dev.balanceOf(a.id).toStringAsFixed(2).padLeft(10)}  '
          '(target ${prod.balanceOf(a.id).toStringAsFixed(2)})');
    }
    for (final c in dev.categories) {
      final n = txns.where((t) {
        if (t.type == TxnType.expense) return t.toRef == c.id;
        if (t.type == TxnType.income) return t.fromRef == c.id;
        return false;
      }).length;
      debugPrint('${c.id.padRight(16)} txns=$n');
    }
    expect(txns, isNotEmpty);
  });
}
