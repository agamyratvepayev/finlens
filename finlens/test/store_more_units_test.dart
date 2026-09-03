import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

/// Store-level units for the More rebuild: category delete/update (§3.4), locale
/// seeding (§7.1), and the archived-count invariant (§2.4 / §6).
void main() {
  group('deleteCategory refusal (§3.4)', () {
    test('refuses a category with transactions, and changes nothing', () {
      final store = buildSeedStore();
      final used = store.categories
          .firstWhere((c) => store.txnCountForCategory(c.id) > 0);
      final before = store.categories.length;

      expect(store.deleteCategory(used), isFalse);
      expect(store.categories.length, before);
      expect(store.categoryById(used.id), isNotNull);
    });

    test('refuses a budgeted (but unused) category', () {
      final store = buildSeedStore();
      final budgeted = store.addCategory(
        name: 'Test budget',
        type: CategoryType.expense,
        icon: Icons.savings_rounded,
        color: const Color(0xFF34C759),
        monthlyBudget: 100,
      );
      expect(store.txnCountForCategory(budgeted.id), 0); // no transactions
      expect(store.deleteCategory(budgeted), isFalse); // …but a budget refers
      expect(store.categoryById(budgeted.id), isNotNull);
    });

    test('deletes a fresh, unbudgeted, unused category outright', () {
      final store = buildSeedStore();
      final fresh = store.addCategory(
        name: 'Scratch',
        type: CategoryType.expense,
        icon: Icons.category_rounded,
        color: const Color(0xFF0A84FF),
        monthlyBudget: null,
      );
      expect(store.deleteCategory(fresh), isTrue);
      expect(store.categoryById(fresh.id), isNull);
    });
  });

  group('updateCategory (§3.4)', () {
    test('renames / re-icons / recolours; type never changes', () {
      final store = buildSeedStore();
      final c = store.categoriesOfType(CategoryType.expense).first;
      final type = c.type;

      store.updateCategory(c,
          name: 'Renamed',
          icon: Icons.rocket_launch_rounded,
          color: const Color(0xFFFF375F));

      expect(c.name, 'Renamed');
      expect(c.icon, Icons.rocket_launch_rounded);
      expect(c.color, const Color(0xFFFF375F));
      expect(c.type, type); // untouched — flipping it is not allowed
    });
  });

  group('locale seeding (§7.1)', () {
    test('a stored value always wins', () {
      expect(AppStore.resolveInitialLocale('ru', const [Locale('fr')]),
          const Locale('ru'));
    });
    test('no stored value + a spoken device language seeds it', () {
      expect(AppStore.resolveInitialLocale(null, const [Locale('tr')]),
          const Locale('tr'));
      expect(AppStore.resolveInitialLocale(null, const [Locale('tk')]),
          const Locale('tk'));
    });
    test('no stored value + an unspoken device language falls back to English',
        () {
      expect(AppStore.resolveInitialLocale(null, const [Locale('fr')]),
          const Locale('en'));
      expect(AppStore.resolveInitialLocale(null, const []), const Locale('en'));
    });
    test('the first spoken device language among several wins', () {
      expect(
          AppStore.resolveInitialLocale(
              null, const [Locale('fr'), Locale('tk')]),
          const Locale('tk'));
    });
  });

  group('archivedCount agreement (§2.4 / §6)', () {
    test('equals the four sections\' rows and excludes archived categories', () {
      final store = buildSeedStore();
      final rows = store.archivedGoals.length + // FINISHED + UNFINISHED goals
          store.completedTasks.length + //           FINISHED + UNFINISHED tasks
          store.pausedTasks.length + //              CAN COME BACK
          store.removedBudgets.length + //            CAN COME BACK
          store.archivedAccounts.length + //          CAN COME BACK
          store.deletedTasks.length; //               RECENTLY DELETED
      expect(store.archivedCount, rows);

      // Archiving a category grows archivedCategories but NOT archivedCount — it
      // lives in the management screen now.
      final before = store.archivedCount;
      final victim = store.categoriesOfType(CategoryType.expense).firstWhere(
          (c) =>
              store.monthlyBudgetForCategory(c.id) == null &&
              store.removedOnOf(c) == null);
      store.archiveCategory(victim);
      expect(store.archivedCategories, contains(victim));
      expect(store.archivedCount, before);
    });
  });
}
