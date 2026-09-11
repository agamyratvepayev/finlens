import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/backup_codec.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/fx.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/base_currency_test.dart
//
// Task 12: the base currency is a stored setting, seeded silently from the first
// account, never re-derived on its own, and read live so every total repaints.

Account _acc(
  String id,
  String currency, {
  double startingBalance = 0,
  AccountGroup group = AccountGroup.spendable,
  DateTime? openedOn,
}) =>
    Account(
      id: id,
      name: id,
      group: group,
      currency: currency,
      startingBalance: startingBalance,
      openedOn: openedOn,
    );

AppStore _store({List<Account> accounts = const []}) => AppStore(
      accounts: accounts,
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('resolveBaseCurrency — the pure resolver (§2a)', () {
    test('a stored value always wins', () {
      expect(
        AppStore.resolveBaseCurrency('EUR', [_acc('a', 'TMT')], 'USD'),
        'EUR',
      );
    });

    test('with nothing stored, the oldest account decides (upgrade repair)', () {
      final accounts = [
        _acc('new', 'EUR', openedOn: DateTime(2026, 8, 1)),
        _acc('old', 'TMT', openedOn: DateTime(2026, 1, 1)),
      ];
      expect(AppStore.resolveBaseCurrency(null, accounts, 'USD'), 'TMT');
    });

    test('with no stored value and no accounts, the device locale decides', () {
      expect(AppStore.resolveBaseCurrency(null, const [], 'TMT'), 'TMT');
    });

    test('with nothing at all, USD is the floor', () {
      expect(AppStore.resolveBaseCurrency(null, const [], null), 'USD');
      expect(AppStore.resolveBaseCurrency('', const [], null), 'USD');
    });

    test('oldestAccountCurrency: null-dated accounts sort oldest by list order',
        () {
      // No openedOn anywhere → the first-inserted account is the oldest.
      final accounts = [_acc('first', 'TMT'), _acc('second', 'EUR')];
      expect(AppStore.oldestAccountCurrency(accounts), 'TMT');
      expect(AppStore.oldestAccountCurrency(const []), isNull);
    });
  });

  group('the silent seed (§1)', () {
    test('creating the first account writes the base; a second does not move it',
        () {
      final store = _store();
      store.addAccount(
        name: 'Cash',
        group: AccountGroup.spendable,
        currency: 'TMT',
        startingBalance: 500,
      );
      expect(store.baseCurrency, 'TMT');

      store.addAccount(
        name: 'Euro pocket',
        group: AccountGroup.spendable,
        currency: 'EUR',
        startingBalance: 100,
      );
      expect(store.baseCurrency, 'TMT', reason: 'a second account never reseeds');
    });

    test('deleting the first account leaves the base alone', () {
      final store = _store();
      final first = store.addAccount(
        name: 'Cash',
        group: AccountGroup.spendable,
        currency: 'TMT',
        startingBalance: 500,
      );
      store.addAccount(
        name: 'Euro pocket',
        group: AccountGroup.spendable,
        currency: 'EUR',
        startingBalance: 100,
      );
      store.removeAccount(first); // no history → truly removed
      expect(store.accountById(first.id), isNull);
      expect(store.baseCurrency, 'TMT');
    });

    test("editing the first account's currency leaves the base alone", () {
      final store = _store();
      final first = store.addAccount(
        name: 'Cash',
        group: AccountGroup.spendable,
        currency: 'TMT',
        startingBalance: 500,
      );
      store.updateAccount(first, currency: 'EUR');
      expect(first.currency, 'EUR');
      expect(store.baseCurrency, 'TMT');
    });
  });

  group('no invented conversion for a single-currency user (§0/§7)', () {
    test('a single-TMT store nets the raw sum, not sum × the invented rate', () {
      final store = _store(accounts: [_acc('a', 'TMT', startingBalance: 500)]);
      // The base resolves to TMT (the only account), so Fx.rate('TMT','TMT') is
      // 1 and the invented 0.286 never runs.
      expect(store.baseCurrency, 'TMT');
      expect(store.netWorth, 500);
      // The bug this guards: 500 × _perUnit['TMT'] == 143.
      expect(store.netWorth, isNot(closeTo(143, 1)));
    });
  });

  group('changing the base recomputes and repaints (§6)', () {
    test('setBaseCurrency notifies and every total is reread live', () {
      final store = _store(accounts: [
        _acc('u', 'USD', startingBalance: 100),
        _acc('t', 'TMT', startingBalance: 100),
      ]);
      // Oldest account is USD, so the base starts there.
      expect(store.baseCurrency, 'USD');
      final usdNet = store.netWorth; // 100 + 100·0.286 = 128.6

      var notified = 0;
      store.addListener(() => notified++);

      store.setBaseCurrency('TMT');
      expect(notified, greaterThan(0));
      expect(store.baseCurrency, 'TMT');
      final tmtNet = store.netWorth; // 100/0.286 + 100 ≈ 449.65
      expect(tmtNet, isNot(closeTo(usdNet, 0.01)));
      expect(tmtNet, closeTo(100 / 0.286 + 100, 0.01));
    });

    test('setting the same base is a no-op (no notify)', () {
      final store = _store(accounts: [_acc('u', 'USD', startingBalance: 100)]);
      var notified = 0;
      store.addListener(() => notified++);
      store.setBaseCurrency('USD');
      expect(notified, 0);
    });
  });

  group('backup carries the base, and old backups derive it (§4)', () {
    test('a backup with the base restores it verbatim', () {
      final store = _store(accounts: [_acc('a', 'TMT', startingBalance: 500)]);
      store.setBaseCurrency('USD'); // deliberately not an account's currency
      final restored =
          decodeBackup(encodeBackup(store, exportedAt: DateTime(2026, 9, 11)))
              .source;
      expect(restored.baseCurrency, 'USD');
    });

    test('a backup written before this change derives from the oldest account',
        () {
      // A current-schema document whose meta omits base_currency — exactly what
      // a pre-change build wrote.
      const json = '''
{"format":"finlens-backup","schemaVersion":6,"exportedAt":0,
 "meta":{"id_seq":1000,"tag_schema":1,"budget_history_since":0},
 "accounts":[
   {"id":"a1","name":"EUR","group_name":"spendable","currency":"EUR",
    "starting_balance":100,"hidden":0,"archived":0,"count_as_spendable":1},
   {"id":"a2","name":"USD","group_name":"spendable","currency":"USD",
    "starting_balance":100,"hidden":0,"archived":0,"count_as_spendable":1}],
 "categories":[],"budgets":[],"txns":[],"tags":[],"goals":[],"tasks":[],
 "currencies":[]}
''';
      final source = decodeBackup(json).source;
      // No key on the source → its getter falls back to the oldest account.
      expect(source.baseCurrency, 'EUR');

      // And adopting it into a live store pins that derived value.
      final live = _store();
      live.loadFrom(source);
      expect(live.baseCurrency, 'EUR');
    });
  });

  test('Fx rate table is untouched — TMT still stands in at 0.286', () {
    // The invented rate is another task; this test documents that it is still
    // present and that base=TMT simply routes around it.
    expect(Fx.rate('TMT', 'TMT'), 1.0);
    expect(Fx.convert(500, 'TMT', 'USD'), closeTo(143, 0.5));
    expect(Fx.convert(500, 'TMT', 'TMT'), 500);
  });
}
