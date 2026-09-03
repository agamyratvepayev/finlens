import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/new_account_currency_test.dart

AppStore _emptyStore({
  List<Account> accounts = const [],
  List<CurrencyDef> currencies = const [],
}) =>
    AppStore(
      accounts: accounts,
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
      customCurrencies: currencies,
    );

void main() {
  tearDown(() => setCustomCurrencies(const []));

  group('custom currency formatting (spec §7a)', () {
    test('all four combinations of symbol present/absent × before/after', () {
      const before = CurrencyDef(
          code: 'AAA', name: 'A', symbol: 'ø', symbolBefore: true, custom: true);
      const after = CurrencyDef(
          code: 'BBB',
          name: 'B',
          symbol: 'ø',
          symbolBefore: false,
          custom: true);
      const codeBefore = CurrencyDef(
          code: 'CCC', name: 'C', symbolBefore: true, custom: true);
      const codeAfter = CurrencyDef(
          code: 'DDD', name: 'D', symbolBefore: false, custom: true);
      setCustomCurrencies([before, after, codeBefore, codeAfter]);

      // A symbol sits flush against the number; a code takes a space (§7a).
      expect(money(9850.5, currency: 'AAA'), 'ø9,850.50');
      expect(money(9850.5, currency: 'BBB'), '9,850.50ø');
      expect(money(9850.5, currency: 'CCC'), 'CCC 9,850.50');
      expect(money(9850.5, currency: 'DDD'), '9,850.50 DDD');
    });

    test('a symbol-less currency renders TMT-style code with a space', () {
      const def = CurrencyDef(
          code: 'ZZT', name: 'Zed', symbolBefore: true, custom: true);
      setCustomCurrencies([def]);
      expect(money(9850, currency: 'ZZT'), 'ZZT 9,850.00');

      const after = CurrencyDef(
          code: 'ZZT', name: 'Zed', symbolBefore: false, custom: true);
      setCustomCurrencies([after]);
      expect(money(9850, currency: 'ZZT'), '9,850.00 ZZT');
    });

    test('decimals follow the currency; zero decimals drop the fraction', () {
      const zero = CurrencyDef(
          code: 'NOD', name: 'No decimals', decimals: 0, custom: true);
      setCustomCurrencies([zero]);
      expect(money(9850.4, currency: 'NOD'), 'NOD 9,850');
    });

    test('the negative sign leads the whole token', () {
      const def = CurrencyDef(
          code: 'NEG', name: 'N', symbol: 'ø', symbolBefore: true, custom: true);
      setCustomCurrencies([def]);
      expect(money(-12, currency: 'NEG'), '−ø12.00');
    });

    test('formatCurrencyExample matches money() before registration', () {
      const def = CurrencyDef(
          code: 'PRV', name: 'Preview', symbol: 'p', symbolBefore: false, custom: true);
      // Not registered — the preview path must still format it.
      expect(formatCurrencyExample(def, 9850), '9,850.00p');
    });

    test('built-in currencies are untouched by the custom branch', () {
      setCustomCurrencies(const []);
      // Value-driven decimals: cents on small amounts, whole on headline figures.
      expect(money(15.99, currency: 'USD'), r'$15.99');
      expect(money(185700, currency: 'USD'), r'$185,700');
    });
  });

  group('duplicate-code guard (spec §7a)', () {
    test('an existing built-in or custom code is detected', () {
      expect(currencyCodeExists('USD'), isTrue);
      expect(currencyCodeExists('usd'), isTrue); // uppercased
      expect(currencyCodeExists('QQQ'), isFalse);
      setCustomCurrencies([
        const CurrencyDef(code: 'QQQ', name: 'Q', custom: true),
      ]);
      expect(currencyCodeExists('QQQ'), isTrue);
    });
  });

  group('recent currencies (spec §6)', () {
    test('derives from accounts in use, most-recent first, deduplicated', () {
      final store = _emptyStore(accounts: [
        Account(
            id: 'a1',
            name: 'A',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
        Account(
            id: 'a2',
            name: 'B',
            group: AccountGroup.spendable,
            currency: 'EUR',
            startingBalance: 0),
        Account(
            id: 'a3',
            name: 'C',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
      ]);
      // Newest first, USD deduped to a single (newest) entry.
      expect(store.recentCurrencyCodes, ['USD', 'EUR']);
    });

    test('empty when no accounts', () {
      expect(_emptyStore().recentCurrencyCodes, isEmpty);
    });
  });

  group('backup round-trip (spec §7 / schemaVersion 1 → 2)', () {
    test('an account with a custom icon-emoji and colour survives', () {
      final store = _emptyStore(
        accounts: [
          Account(
            id: 'a1',
            name: 'Wallet',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 250,
            emoji: '💰',
            colorValue: 0xFF30D158,
          ),
        ],
        currencies: [
          const CurrencyDef(
              code: 'MYC',
              name: 'My Coin',
              symbol: 'µ',
              decimals: 3,
              symbolBefore: false,
              custom: true),
        ],
      );

      final json = encodeBackup(store, exportedAt: DateTime(2026, 9, 3));
      final restored = decodeBackup(json).source;

      final a = restored.snapshotAccounts.single;
      expect(a.emoji, '💰');
      expect(a.colorValue, 0xFF30D158);

      final c = restored.snapshotCustomCurrencies.single;
      expect(c.code, 'MYC');
      expect(c.name, 'My Coin');
      expect(c.symbol, 'µ');
      expect(c.decimals, 3);
      expect(c.symbolBefore, isFalse);
    });

    test('a backup written at the previous schemaVersion still decodes', () {
      // A minimal v1 document — no color_argb, no icon_emoji, no currencies key.
      const v1 = '''
{"format":"finlens-backup","schemaVersion":1,"exportedAt":0,
 "meta":{"id_seq":1000,"tag_schema":1,"budget_history_since":0},
 "accounts":[{"id":"a1","name":"Old","group_name":"spendable",
   "currency":"USD","starting_balance":100,
   "hidden":0,"archived":0,"count_as_spendable":1}],
 "categories":[],"txns":[],"tags":[],"goals":[],"tasks":[]}
''';
      final doc = decodeBackup(v1);
      final a = doc.source.snapshotAccounts.single;
      expect(a.name, 'Old');
      // New fields take their defaults.
      expect(a.emoji, isNull);
      expect(a.colorValue, isNull);
      expect(doc.source.snapshotCustomCurrencies, isEmpty);
    });
  });
}
