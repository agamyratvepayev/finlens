import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/main.dart';

/// Covers the additive "Set aside" asset group (spec §1, §7). The group ships
/// empty, so these tests prove it by hand: enum placement, that a balance placed
/// in it counts toward assets, and that Balance never renders it while empty.
void main() {
  group('AccountGroup.setAside placement', () {
    test('is an asset and sorts between spendable and receivables', () {
      // The index-based `isAsset` is the trap the spec warns about: appended at
      // the end, setAside would silently become a liability.
      expect(AccountGroup.setAside.isAsset, isTrue);
      expect(AccountGroup.setAside.isLiability, isFalse);
      expect(AccountGroup.setAside.index,
          greaterThan(AccountGroup.spendable.index));
      expect(AccountGroup.setAside.index,
          lessThan(AccountGroup.receivables.index));
    });

    test('asset groups now number five', () {
      expect(AccountGroup.assets.length, 5);
      expect(AccountGroup.assets, contains(AccountGroup.setAside));
      // Declaration order on Balance: directly after Spendable.
      expect(AccountGroup.assets[0], AccountGroup.spendable);
      expect(AccountGroup.assets[1], AccountGroup.setAside);
    });
  });

  group('totals', () {
    late AppStore store;
    setUp(() => store = buildSeedStore());

    test('a Set aside account is included in totalAssets and net worth', () {
      final assetsBefore = store.totalAssets;
      final netBefore = store.netWorth;

      store.addAccount(
        name: 'Vacation Fund',
        group: AccountGroup.setAside,
        currency: 'USD',
        startingBalance: 500,
      );

      expect(store.groupTotal(AccountGroup.setAside), 500);
      expect(store.totalAssets, assetsBefore + 500);
      expect(store.netWorth, netBefore + 500);
    });
  });

  group('Balance rendering', () {
    Future<void> pumpBalance(WidgetTester tester, AppStore store) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FinLensApp(store: store));
      await tester.pumpAndSettle();
    }

    testWidgets('is absent from Balance while it holds no accounts',
        (tester) async {
      await pumpBalance(tester, buildSeedStore());
      expect(find.text('Set aside'), findsNothing);
    });

    testWidgets('appears, collapsed, once it holds one account; expands to it',
        (tester) async {
      final store = buildSeedStore();
      final familyWallet =
          store.accounts.firstWhere((a) => a.name == 'Family Wallet');
      store.updateAccount(familyWallet, group: AccountGroup.setAside);

      await pumpBalance(tester, store);

      // Header renders; collapsed by default (only Spendable opens on "all"),
      // so the moved child is not yet visible.
      expect(find.text('Set aside'), findsOneWidget);
      expect(find.text('Family Wallet'), findsNothing);

      // Tapping the group header expands it and lists the account.
      await tester.tap(find.text('Set aside'));
      await tester.pumpAndSettle();
      expect(find.text('Family Wallet'), findsOneWidget);
    });
  });
}
