import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';

/// Currency editing (spec §0–§2). A user in Turkmenistan wants `9,850.00 TMT`;
/// the shipped built-in renders `m9,850.00`, and nothing about any currency
/// could be edited once it existed — so they invented a currency under `MNT`
/// (the Mongolian tugrik) purely to get the formatting they wanted. A formatting
/// limitation produced semantically wrong data.
///
/// The resolution order needed for the fix already existed: `currencyDef`
/// prefers a custom entry over a built-in of the same code, and
/// `customCurrencyDef` is the switch that sends `money` down the metadata
/// branch. Only the duplicate guard stood in the way, and only on create.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // The registry is a module global shared by every test in the file; start
    // each one from the shipped catalog so order cannot matter.
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

  // ── The headline: an override beats the built-in ───────────────────────────
  test('a custom def under a built-in code wins, and money() follows it', () {
    // Shipped TMT: symbol `m`, before the amount. Note the *legacy* formatter
    // drops cents on a whole value, so this is `m9,850` — §0 quotes it as
    // `m9,850.00`, but the symbol-first shape it is really about is the same,
    // and §6's own `CODE 1,234` example shows the same rule.
    expect(money(9850, currency: 'TMT'), 'm9,850');
    expect(currencyDef('TMT').symbol, 'm');

    final store = emptyStore();
    // What the edit sheet writes: symbol cleared, Position = After (§6).
    store.updateCustomCurrency(const CurrencyDef(
      code: 'TMT',
      name: 'Turkmen Manat',
      symbol: null,
      decimals: 2,
      symbolBefore: false,
      custom: true,
    ));

    expect(currencyDef('TMT').custom, isTrue,
        reason: 'the override, not the built-in, resolves');
    expect(customCurrencyDef('TMT'), isNotNull,
        reason: 'money() must take the metadata branch');
    // The token falls back to the code and takes a space — CurrencyDef's own
    // spacing rule, unchanged by this task.
    expect(money(9850, currency: 'TMT'), '9,850.00 TMT');
  });

  test('reset removes the override and the built-in returns byte-for-byte', () {
    final store = emptyStore();
    final shipped = builtInCurrencyDef('TMT')!;

    store.updateCustomCurrency(const CurrencyDef(
      code: 'TMT',
      name: 'Turkmen Manat',
      symbolBefore: false,
      custom: true,
    ));
    expect(money(9850, currency: 'TMT'), '9,850.00 TMT');

    store.removeCustomCurrency('TMT');

    final back = currencyDef('TMT');
    expect(back.code, shipped.code);
    expect(back.name, shipped.name);
    expect(back.symbol, shipped.symbol);
    expect(back.decimals, shipped.decimals);
    expect(back.symbolBefore, shipped.symbolBefore);
    expect(back.custom, isFalse);
    expect(customCurrencyDef('TMT'), isNull,
        reason: 'the metadata branch is off again');
    // Back on the legacy value-driven path, cents and all.
    expect(money(9850, currency: 'TMT'), 'm9,850');
    expect(money(15.99, currency: 'TMT'), 'm15.99');
  });

  test('kBuiltInCurrencies is never mutated by an override or a reset', () {
    final store = emptyStore();
    final before = kBuiltInCurrencies.firstWhere((c) => c.code == 'TMT');
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'X', symbolBefore: false));
    final during = kBuiltInCurrencies.firstWhere((c) => c.code == 'TMT');
    expect(during.symbol, before.symbol);
    expect(during.symbolBefore, before.symbolBefore);
    expect(during.name, before.name);
    store.removeCustomCurrency('TMT');
    expect(kBuiltInCurrencies.firstWhere((c) => c.code == 'TMT').symbol, 'm');
  });

  // ── The guard: create stays guarded, edit does not ─────────────────────────
  group('currencyCodeExists', () {
    test('still rejects a duplicate on the create path', () {
      expect(currencyCodeExists('TMT'), isTrue, reason: 'built-in');
      expect(currencyCodeExists('tmt'), isTrue, reason: 'case-insensitive');
      expect(currencyCodeExists('ZZZ'), isFalse);

      final store = emptyStore();
      store.addCustomCurrency(
          const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
      expect(currencyCodeExists('ZZZ'), isTrue, reason: 'now a custom');
    });

    test('does not block the edit path for the row being edited', () {
      // Editing TMT must be able to write a def under TMT.
      expect(currencyCodeExists('TMT', excluding: 'TMT'), isFalse);
      expect(currencyCodeExists('TMT', excluding: 'tmt'), isFalse,
          reason: 'the exemption is case-insensitive too');
      // But it still guards every *other* code.
      expect(currencyCodeExists('USD', excluding: 'TMT'), isTrue);
    });
  });

  // ── Delete: only custom, only when nothing uses it ─────────────────────────
  group('delete', () {
    test('an unused custom currency is removed', () {
      final store = emptyStore();
      store.addCustomCurrency(
          const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
      expect(store.currencyInUse('ZZZ'), isFalse);

      store.removeCustomCurrency('ZZZ');
      expect(store.snapshotCustomCurrencies.any((c) => c.code == 'ZZZ'),
          isFalse);
      // Anything still naming the code falls back to the synthesised
      // `CODE 1,234` default (§6).
      expect(money(1234, currency: 'ZZZ'), 'ZZZ 1,234');
    });

    test('a currency an account holds is in use, and the block names it', () {
      final store = emptyStore();
      store.addCustomCurrency(
          const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
      store.addAccount(
        name: 'Cash box',
        group: AccountGroup.spendable,
        currency: 'ZZZ',
        startingBalance: 10,
      );

      expect(store.currencyInUse('ZZZ'), isTrue);
      expect(store.accountsUsingCurrency('ZZZ').single.name, 'Cash box');
    });

    test('a currency only transactions carry is still in use, and counted', () {
      final store = emptyStore();
      final wallet = store.addAccount(
        name: 'Wallet',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100,
      );
      final food = store.addCategory(
        name: 'Food',
        type: CategoryType.expense,
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF5E5CE6),
      );
      store.addCustomCurrency(
          const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
      store.addTxn(
        type: TxnType.expense,
        amount: 5,
        currency: 'ZZZ',
        fromRef: wallet.id,
        toRef: food.id,
        date: DateTime.now(),
      );

      expect(store.accountsUsingCurrency('ZZZ'), isEmpty);
      expect(store.txnCountForCurrency('ZZZ'), 1);
      expect(store.currencyInUse('ZZZ'), isTrue,
          reason: 'the block must fire on transactions too, not just accounts');
    });

    test('removing a currency touches no account and no transaction', () {
      final store = emptyStore();
      store.addCustomCurrency(
          const CurrencyDef(code: 'TMT', name: 'Manat', symbolBefore: false));
      final a = store.addAccount(
        name: 'Wallet',
        group: AccountGroup.spendable,
        currency: 'TMT',
        startingBalance: 100,
      );

      store.removeCustomCurrency('TMT');

      // Reset is not a delete: the account keeps its code and its balance.
      expect(store.accountById(a.id)!.currency, 'TMT');
      expect(store.accountById(a.id)!.startingBalance, 100);
    });
  });

  // ── One override per code (§6) ─────────────────────────────────────────────
  test('editing the same built-in twice leaves one override, never two', () {
    final store = emptyStore();
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'First', symbolBefore: false));
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'Second', symbolBefore: false));

    final rows =
        store.snapshotCustomCurrencies.where((c) => c.code == 'TMT').toList();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Second');
  });

  test('an override is flagged as shadowing a built-in; a pure custom is not',
      () {
    final store = emptyStore();
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'Manat', symbolBefore: false));
    store.addCustomCurrency(
        const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));

    expect(isOverriddenBuiltIn('TMT'), isTrue, reason: 'subtitle · Edited');
    expect(isOverriddenBuiltIn('ZZZ'), isFalse, reason: 'no built-in to shadow');
    expect(isOverriddenBuiltIn('USD'), isFalse, reason: 'not overridden');
  });

  // ── The list: once, never twice (§1) ───────────────────────────────────────
  test('a custom currency that is also in use is listed once, under ADDED BY '
      'YOU', () {
    final store = emptyStore();
    store.addCustomCurrency(
        const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
    store.addAccount(
      name: 'Cash box',
      group: AccountGroup.spendable,
      currency: 'ZZZ',
      startingBalance: 10,
    );

    // The screen's own de-duplication: IN USE drops codes that have an override.
    final customCodes = {for (final c in store.snapshotCustomCurrencies) c.code};
    final inUse = store
        .currencyCodesInUse()
        .where((c) => !customCodes.contains(c))
        .toList();

    expect(store.currencyCodesInUse(), contains('ZZZ'),
        reason: 'it really is in use');
    expect(inUse, isNot(contains('ZZZ')),
        reason: 'but IN USE must not list it a second time');
    expect(customCodes, contains('ZZZ'));
    // And the More ▸ Data count matches what the screen renders.
    expect(store.currencyRowCount, inUse.length + customCodes.length);
  });

  test('the base currency is always in use even with an empty store', () {
    expect(emptyStore().currencyCodesInUse(), contains('USD'));
  });

  // ── Decimals follow through to the preview and the badge (§6) ──────────────
  test('decimals 0 and 3 are honoured by preview and by money()', () {
    final store = emptyStore();
    store.updateCustomCurrency(const CurrencyDef(
        code: 'TMT', name: 'Manat', decimals: 0, symbolBefore: false));
    expect(money(9850, currency: 'TMT'), '9,850 TMT');
    expect(formatCurrencyExample(currencyDef('TMT'), 9850), '9,850 TMT');

    store.updateCustomCurrency(const CurrencyDef(
        code: 'TMT', name: 'Manat', decimals: 3, symbolBefore: false));
    expect(money(9850, currency: 'TMT'), '9,850.000 TMT');
  });

  test('a cleared symbol falls the token back to the code, for the badge too',
      () {
    final store = emptyStore();
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'Manat', symbol: ''));
    expect(currencyDef('TMT').token, 'TMT',
        reason: 'the list badge renders def.token');
    expect(currencyDef('TMT').tokenIsSymbol, isFalse);
  });
}
