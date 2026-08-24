import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_order.dart';

void main() {
  late AppStore store;

  setUp(() {
    // setBalanceOrder/Sort persist through SharedPreferences; the mock lets the
    // fire-and-forget writes succeed under test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = buildSeedStore();
  });

  group('moveWithinGroup — relative move by visible neighbour', () {
    test('worked example: a hidden trailing item keeps its place', () {
      // Full [Spendable, Receivables, Investments, Valuables] with Valuables
      // hidden; drag Investments to the top.
      final result = CustomOrder.moveWithinGroup(
        ['sp', 're', 'in', 'va'],
        'in',
        0,
        ['sp', 're', 'in'],
      );
      expect(result, ['in', 'sp', 're', 'va']);
    });

    test('drop in front of a visible item with a hidden one between', () {
      // Full [A, H, B], H hidden -> visible [A, B]; move B before A.
      final result = CustomOrder.moveWithinGroup(['A', 'H', 'B'], 'B', 0,
          ['A', 'B']);
      expect(result, ['B', 'A', 'H']);
    });

    test('drop at the end of a group whose last entry is hidden', () {
      // Full [A, B, H], H hidden -> visible [A, B]; move A to the end.
      final result = CustomOrder.moveWithinGroup(['A', 'B', 'H'], 'A', 2,
          ['A', 'B']);
      expect(result, ['B', 'A', 'H']);
    });

    test('a group with a single visible item is a no-op', () {
      final result = CustomOrder.moveWithinGroup(['A', 'H'], 'A', 1, ['A']);
      expect(result, ['A', 'H']);
    });

    test('an out-of-range target clamps to the end, nothing lost', () {
      final result = CustomOrder.moveWithinGroup(
          ['A', 'B', 'C'], 'A', 999, ['A', 'B', 'C']);
      expect(result, ['B', 'C', 'A']);
    });
  });

  group('orderedCategories — always fixed declaration order', () {
    test('is the declaration order regardless of stored account order', () {
      final g = AccountGroup.valuables;
      final o = CustomOrder(accountOrder: {
        g: store.accountsIn(g).map((a) => a.id).toList()
      });
      expect(o.orderedCategories(assets: true), AccountGroup.assets);
      expect(o.orderedCategories(assets: false), AccountGroup.liabilities);
    });
  });

  group('orderedAccounts', () {
    test('empty order is data order', () {
      const g = AccountGroup.valuables;
      expect(
        const CustomOrder().orderedAccounts(store, g).map((a) => a.id),
        store.accountsIn(g).map((a) => a.id),
      );
    });

    test('known ids first, new ones appended in data order', () {
      const g = AccountGroup.valuables;
      final data = store.accountsIn(g);
      final last = data.last.id;
      final o = CustomOrder(accountOrder: {
        g: [last]
      });
      final r = o.orderedAccounts(store, g).map((a) => a.id).toList();
      expect(r.first, last);
      expect(r.toSet(), data.map((a) => a.id).toSet());
    });

    test('deleted / stale ids drop out', () {
      const g = AccountGroup.valuables;
      final o = CustomOrder(accountOrder: {
        g: ['gone', ...store.accountsIn(g).map((a) => a.id)]
      });
      final r = o.orderedAccounts(store, g).map((a) => a.id).toList();
      expect(r, isNot(contains('gone')));
      expect(r.toSet(), store.accountsIn(g).map((a) => a.id).toSet());
    });
  });

  group('fromStored — validation never re-parents', () {
    test('an account id stored under a foreign group is dropped', () {
      final spendId = store.accountsIn(AccountGroup.spendable).first.id;
      final o = CustomOrder.fromStored(store, {
        'assets': ['valuables'],
        'liabilities': <String>[],
        'accounts': {
          'valuables': [spendId]
        },
      });
      expect(o.accountOrder[AccountGroup.valuables] ?? const [],
          isNot(contains(spendId)));
    });

    test('valid account ids are kept', () {
      final val =
          store.accountsIn(AccountGroup.valuables).map((a) => a.id).toList();
      final o = CustomOrder.fromStored(store, {
        'accounts': {'valuables': val},
      });
      expect(o.accountOrder[AccountGroup.valuables], val);
    });

    test('garbage decodes to an unconfigured order', () {
      expect(CustomOrder.fromStored(store, 'nope').isConfigured, isFalse);
    });
  });

  group('category order migration — legacy keys ignored', () {
    test('legacy assets/liabilities keys are ignored on load', () {
      final val =
          store.accountsIn(AccountGroup.valuables).map((a) => a.id).toList();
      // A payload written by an older build that still stored category order.
      final o = CustomOrder.fromStored(store, {
        'assets': ['valuables', 'spendable'],
        'liabilities': ['creditCards'],
        'accounts': {'valuables': val},
      });
      // The category keys vanish; the account order survives intact.
      expect(o.accountOrder[AccountGroup.valuables], val);
      expect(o.isConfigured, isTrue);
    });

    test('save (toJson) omits category keys entirely', () {
      final val =
          store.accountsIn(AccountGroup.valuables).map((a) => a.id).toList();
      final json = CustomOrder(accountOrder: {AccountGroup.valuables: val})
          .toJson();
      expect(json.containsKey('assets'), isFalse);
      expect(json.containsKey('liabilities'), isFalse);
      expect(json.keys, ['accounts']);
      // One load→save cycle therefore cleans legacy keys out of stored JSON.
      final reloaded = CustomOrder.fromStored(store, {
        'assets': ['valuables'],
        'accounts': {'valuables': val},
      }).toJson();
      expect(reloaded.containsKey('assets'), isFalse);
    });
  });

  group('withAccountMove clamps to the group', () {
    test('a wild target lands the item last, group intact', () {
      const g = AccountGroup.valuables;
      final ids = store.accountsIn(g).map((a) => a.id).toList();
      final o = const CustomOrder().withAccountMove(
        store,
        group: g,
        moved: ids.first,
        visibleTargetIndex: 999,
        visibleOrder: ids,
      );
      final r = o.accountOrder[g]!;
      expect(r.last, ids.first);
      expect(r.toSet(), ids.toSet());
    });
  });

  group('sort selection + undo semantics', () {
    test('a drag from an automatic sort flips to Custom; undo restores both',
        () {
      expect(store.balanceSort, AccountSort.valueDesc);
      final beforeOrder = store.balanceOrder;
      final beforeSort = store.balanceSort;

      const g = AccountGroup.valuables;
      final ids = store.accountsIn(g).map((a) => a.id).toList();
      final next = const CustomOrder().withAccountMove(
        store,
        group: g,
        moved: ids.last,
        visibleTargetIndex: 0,
        visibleOrder: ids,
      );

      // What _applyDrag does on drop:
      store.setBalanceOrder(next, sort: AccountSort.custom);
      expect(store.balanceSort, AccountSort.custom);
      expect(store.balanceOrder.accountOrder[g]!.first, ids.last);

      // What Undo does:
      store.setBalanceOrder(beforeOrder, sort: beforeSort);
      expect(store.balanceSort, AccountSort.valueDesc);
      expect(store.balanceOrder.isConfigured, isFalse);
    });

    test('custom is distinct and excluded from the automatic list', () {
      expect(AccountSort.custom.label, 'Custom');
      expect(AccountSort.automatic, hasLength(4));
      expect(AccountSort.automatic, isNot(contains(AccountSort.custom)));
    });
  });

  group('sortIsActive — the toolbar indicator predicate', () {
    // A configured order for the seed store, so the Custom-with-a-real-drag
    // case has something to point at.
    CustomOrder configuredOrder() {
      const g = AccountGroup.valuables;
      return CustomOrder(
        accountOrder: {g: store.accountsIn(g).map((a) => a.id).toList()},
      );
    }

    test('the default sort (valueDesc) is not active', () {
      expect(store.balanceSort, AccountSort.defaultSort);
      expect(store.sortIsActive, isFalse);
    });

    test('every non-default automatic sort is active', () {
      for (final sort in const [
        AccountSort.valueAsc,
        AccountSort.nameAsc,
        AccountSort.activity,
      ]) {
        store.setBalanceSort(sort);
        expect(store.sortIsActive, isTrue, reason: '$sort should be active');
      }
    });

    test('an automatic sort is active regardless of the stored order', () {
      store.setBalanceOrder(configuredOrder(), sort: AccountSort.nameAsc);
      expect(store.sortIsActive, isTrue);
    });

    test('Custom with nothing arranged yet is NOT active', () {
      store.setBalanceOrder(const CustomOrder(), sort: AccountSort.custom);
      expect(store.balanceSort, AccountSort.custom);
      expect(store.balanceOrder.isConfigured, isFalse);
      expect(store.sortIsActive, isFalse);
    });

    test('Custom after a real drag IS active', () {
      store.setBalanceOrder(configuredOrder(), sort: AccountSort.custom);
      expect(store.balanceOrder.isConfigured, isTrue);
      expect(store.sortIsActive, isTrue);
    });

    test('a configured order under the default sort is still not active', () {
      // Order configured, but the mode is back to the default: the list is in
      // default order, so the indicator must stay dark.
      store.setBalanceOrder(configuredOrder(), sort: AccountSort.valueDesc);
      expect(store.sortIsActive, isFalse);
    });
  });
}
