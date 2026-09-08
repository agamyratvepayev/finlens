import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';

/// Persistence for edited and deleted currencies (spec §5). `store_mappers`
/// already round-trips custom currencies including `symbol_before`; editing and
/// deleting must go through that same path and nothing new.
///
/// Both directions of the compatibility question §5 asks about are covered:
/// a backup written *before* this change restored after it, and one written
/// after restored on a build without it.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  test('an override survives a backup/restore round trip, formatting and all',
      () {
    final store = emptyStore();
    store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'TMT',
      startingBalance: 9850,
    );
    // Edit built-in TMT the way the Turkmenistan user wants it.
    store.updateCustomCurrency(const CurrencyDef(
      code: 'TMT',
      name: 'Turkmen Manat',
      symbol: null,
      decimals: 2,
      symbolBefore: false,
    ));
    expect(money(9850, currency: 'TMT'), '9,850.00 TMT');

    final json = encodeBackup(store, exportedAt: DateTime(2026, 9, 8));

    // Land in a fresh process: no registry, no store.
    setCustomCurrencies(const []);
    expect(money(9850, currency: 'TMT'), 'm9,850',
        reason: 'the built-in is back until the backup is restored');

    final restored = decodeBackup(json).source;
    expect(restored.snapshotCustomCurrencies.single.code, 'TMT');
    expect(restored.snapshotCustomCurrencies.single.symbolBefore, isFalse);
    expect(restored.snapshotCustomCurrencies.single.symbol, isNull);
    // The AppStore constructor re-registers, so formatting is live again.
    expect(money(9850, currency: 'TMT'), '9,850.00 TMT');
    expect(restored.accountsUsingCurrency('TMT').single.name, 'Wallet');
  });

  test('a reset persists as the absence of the override', () {
    final store = emptyStore();
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'Turkmen Manat'));
    store.removeCustomCurrency('TMT');

    final restored =
        decodeBackup(encodeBackup(store, exportedAt: DateTime(2026, 9, 8)))
            .source;
    expect(restored.snapshotCustomCurrencies, isEmpty);
    expect(money(9850, currency: 'TMT'), 'm9,850',
        reason: 'the shipped definition is in charge again');
  });

  // ── §5, direction 1: a backup written BEFORE this change ──────────────────
  test('a pre-change backup still restores', () {
    // Exactly what the old build wrote: custom currencies only ever under codes
    // no built-in claimed, and the same five columns. Nothing in this task
    // changed the schema, so this is byte-shape-identical to an old file.
    final store = emptyStore();
    store.addCustomCurrency(const CurrencyDef(
      code: 'MNT',
      name: 'Manat',
      symbol: null,
      decimals: 2,
      symbolBefore: false,
      custom: true,
    ));
    final legacy = encodeBackup(store, exportedAt: DateTime(2026, 9, 8));

    setCustomCurrencies(const []);
    final restored = decodeBackup(legacy).source;

    // The MNT workaround the user was driven to still loads and still formats.
    expect(restored.snapshotCustomCurrencies.single.code, 'MNT');
    expect(money(9850, currency: 'MNT'), '9,850.00 MNT');
  });

  test('the currency row shape is unchanged, so old and new files interleave',
      () {
    // The map an override writes has the same keys, in the same types, as the
    // map a plain custom currency has always written — which is why a file from
    // either build loads in the other.
    final override = currencyDefToMap(const CurrencyDef(
        code: 'TMT', name: 'Turkmen Manat', symbolBefore: false, custom: true));
    final plain = currencyDefToMap(const CurrencyDef(
        code: 'MNT', name: 'Manat', symbolBefore: false, custom: true));

    expect(override.keys.toSet(), plain.keys.toSet());
    expect(override.keys.toSet(),
        {'code', 'name', 'symbol', 'decimals', 'symbol_before'});
    // And it reads back identically.
    final back = currencyDefFromMap(override);
    expect(back.code, 'TMT');
    expect(back.symbolBefore, isFalse);
    expect(back.custom, isTrue);
  });

  // ── §5, direction 2: a backup written AFTER, restored on an OLD build ─────
  test('a post-change backup carries nothing an old build cannot read', () {
    final store = emptyStore();
    store.updateCustomCurrency(const CurrencyDef(
      code: 'TMT',
      name: 'Turkmen Manat',
      symbolBefore: false,
    ));
    final map = jsonDecode(encodeBackup(store, exportedAt: DateTime(2026, 9, 8)))
        as Map<String, Object?>;
    final rows = (map['currencies'] as List).cast<Map<String, Object?>>();

    // No new key, no new table — an old build's decoder reads this file whole.
    expect(rows.single.keys.toSet(),
        {'code', 'name', 'symbol', 'decimals', 'symbol_before'});
    expect(map.containsKey('currency_overrides'), isFalse,
        reason: 'an override is an ordinary custom currency, not a new concept');

    // The one behavioural difference on an old build, stated plainly: it would
    // load this row as a custom currency under a built-in's code. `currencyDef`
    // has always preferred custom over built-in, so even the old build formats
    // it the new way — the only thing it lacks is the UI to change it back.
    setCustomCurrencies(
        rows.map(currencyDefFromMap).toList(growable: false));
    expect(money(9850, currency: 'TMT'), '9,850.00 TMT');
  });
}
