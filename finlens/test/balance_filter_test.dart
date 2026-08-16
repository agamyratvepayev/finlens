import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_filter.dart';

void main() {
  late AppStore store;

  setUp(() => store = buildSeedStore());

  Account accountNamed(String name) =>
      store.accounts.firstWhere((a) => a.name == name);

  group('toggleState', () {
    test('all visible is on, none visible is off, some visible is mixed', () {
      const none = BalanceFilter();
      expect(none.toggleState(store, AccountGroup.spendable), ToggleState.on);

      final hidden = none.toggleGroup(store, AccountGroup.spendable);
      expect(hidden.toggleState(store, AccountGroup.spendable),
          ToggleState.off);

      final partial = none.toggleAccount(store, accountNamed('Family Wallet'));
      expect(partial.toggleState(store, AccountGroup.spendable),
          ToggleState.mixed);
    });

    test('a group whose accounts are all individually hidden reads off', () {
      var f = const BalanceFilter();
      for (final a in store.accountsIn(AccountGroup.spendable)) {
        f = f.toggleAccount(store, a);
      }
      // Never mixed-with-zero-visible: the invariant the UI depends on.
      expect(f.toggleState(store, AccountGroup.spendable), ToggleState.off);
      expect(f.isGroupVisible(store, AccountGroup.spendable), isFalse);
    });
  });

  group('group switch transitions', () {
    test('on -> off hides the group and every account under it', () {
      final f = const BalanceFilter().toggleGroup(store, AccountGroup.valuables);
      expect(f.toggleState(store, AccountGroup.valuables), ToggleState.off);
      for (final a in store.accountsIn(AccountGroup.valuables)) {
        expect(f.hiddenAccountIds, contains(a.id));
      }
    });

    test('mixed -> on, not -> off', () {
      final mixed =
          const BalanceFilter().toggleAccount(store, accountNamed('Family Wallet'));
      expect(mixed.toggleState(store, AccountGroup.spendable),
          ToggleState.mixed);

      final next = mixed.toggleGroup(store, AccountGroup.spendable);
      expect(next.toggleState(store, AccountGroup.spendable), ToggleState.on);
      expect(next.isActive, isFalse);
    });

    test('off -> on restores every account', () {
      final off = const BalanceFilter().toggleGroup(store, AccountGroup.valuables);
      final on = off.toggleGroup(store, AccountGroup.valuables);
      expect(on.toggleState(store, AccountGroup.valuables), ToggleState.on);
      expect(on.isActive, isFalse);
    });
  });

  group('account switch transitions', () {
    test('reviving an off group leaves exactly one account visible', () {
      final off = const BalanceFilter().toggleGroup(store, AccountGroup.valuables);
      final target = store.accountsIn(AccountGroup.valuables).first;

      final revived = off.toggleAccount(store, target);

      expect(revived.toggleState(store, AccountGroup.valuables),
          ToggleState.mixed);
      expect(
        revived.visibleAccounts(store, AccountGroup.valuables).map((a) => a.id),
        [target.id],
      );
    });

    test('hiding the last visible account closes the group', () {
      var f = const BalanceFilter();
      final accounts = store.accountsIn(AccountGroup.spendable);
      for (final a in accounts.take(accounts.length - 1)) {
        f = f.toggleAccount(store, a);
      }
      expect(f.toggleState(store, AccountGroup.spendable), ToggleState.mixed);

      f = f.toggleAccount(store, accounts.last);
      expect(f.toggleState(store, AccountGroup.spendable), ToggleState.off);
      expect(f.hiddenGroups, contains(AccountGroup.spendable));
    });

    test('re-showing a hidden account returns the group to on', () {
      final hidden =
          const BalanceFilter().toggleAccount(store, accountNamed('Family Wallet'));
      final shown =
          hidden.toggleAccount(store, accountNamed('Family Wallet'));
      expect(shown.toggleState(store, AccountGroup.spendable), ToggleState.on);
      expect(shown.isActive, isFalse);
    });
  });

  group('hiddenItemCount', () {
    test('a hidden group counts once, not once per account', () {
      final f = const BalanceFilter().toggleGroup(store, AccountGroup.valuables);
      expect(f.hiddenItemCount(store), 1);
    });

    test('a partly hidden group counts its hidden accounts', () {
      final f =
          const BalanceFilter().toggleAccount(store, accountNamed('Family Wallet'));
      expect(f.hiddenItemCount(store), 1);
    });

    test('nothing hidden counts zero', () {
      expect(const BalanceFilter().hiddenItemCount(store), 0);
    });
  });

  group('acceptance fixtures', () {
    test('unfiltered baseline', () {
      const f = BalanceFilter();
      expect(f.sectionTotal(store, assets: true), closeTo(223305, 1));
      expect(f.netWorth(store), closeTo(193635, 1));
    });

    test('hiding Valuables', () {
      final f = const BalanceFilter().toggleGroup(store, AccountGroup.valuables);
      expect(f.sectionTotal(store, assets: true), closeTo(73305, 1));
      expect(f.netWorth(store), closeTo(43635, 1));
      expect(f.isGroupVisible(store, AccountGroup.valuables), isFalse);

      // Percentages recompute against the new denominator.
      final assets = f.sectionTotal(store, assets: true);
      double pct(AccountGroup g) => f.filteredTotal(store, g) / assets * 100;
      expect(pct(AccountGroup.spendable), closeTo(30.6, 0.1));
      expect(pct(AccountGroup.receivables), closeTo(4.4, 0.1));
      expect(pct(AccountGroup.investments), closeTo(65.1, 0.1));
    });

    test('hiding only Family Wallet', () {
      final f =
          const BalanceFilter().toggleAccount(store, accountNamed('Family Wallet'));
      expect(f.sectionTotal(store, assets: true), closeTo(221605, 1));
      expect(f.netWorth(store), closeTo(191935, 1));
      expect(f.filteredTotal(store, AccountGroup.spendable), closeTo(20705, 1));
      expect(f.visibleAccounts(store, AccountGroup.spendable).length, 3);
    });

    test('hiding everything nets to zero without dividing by it', () {
      var f = const BalanceFilter();
      for (final g in AccountGroup.values) {
        f = f.toggleGroup(store, g);
      }
      expect(f.sectionTotal(store, assets: true), 0);
      expect(f.sectionTotal(store, assets: false), 0);
      expect(f.netWorth(store), 0);
    });
  });

  group('persistence hygiene', () {
    test('ids that no longer exist are pruned on load', () {
      final restored = BalanceFilter.fromStored(
        groups: ['valuables', 'not_a_group'],
        accounts: ['a_deleted_account'],
        store: store,
      );
      expect(restored.hiddenGroups, {AccountGroup.valuables});
      // A stale id must never make the button look active on its own.
      expect(restored.hiddenAccountIds, isEmpty);
    });

    test('a stale-only filter restores as inactive', () {
      final restored = BalanceFilter.fromStored(
        groups: const [],
        accounts: const ['gone'],
        store: store,
      );
      expect(restored.isActive, isFalse);
    });
  });
}
