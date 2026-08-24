import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';

// Retiring accounts and categories — store-level acceptance.
// `flutter test` hangs on the author's machine, so run these yourself:
//   flutter test test/archive_accounts_categories_test.dart

Account _account(
  String id,
  String name, {
  AccountGroup group = AccountGroup.spendable,
  double startingBalance = 0,
  bool archived = false,
}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: 'USD',
      startingBalance: startingBalance,
      archived: archived,
    );

Category _category(
  String id,
  String name, {
  CategoryType type = CategoryType.expense,
  double? budget,
  bool archived = false,
  DateTime? removedOn,
}) =>
    Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
      monthlyBudget: budget,
      archived: archived,
      removedOn: removedOn,
    );

Txn _expense(String id, String from, String to, double amount) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, 8, 5),
    );

AppStore _store({
  List<Account>? accounts,
  List<Category>? categories,
  List<Txn>? txns,
  List<Goal>? goals,
  List<Task>? tasks,
}) =>
    AppStore(
      accounts: accounts ?? [_account('a1', 'Checking')],
      categories: categories ?? [_category('c1', 'Groceries')],
      txns: txns ?? const <Txn>[],
      goals: goals ?? const <Goal>[],
      tasks: tasks ?? const <Task>[],
    );

void main() {
  group('restoreAccount', () {
    test('reverses an archive; the account reappears in the public getter',
        () {
      final store = _store(
        accounts: [_account('a1', 'Family Wallet', startingBalance: 500)],
        categories: [_category('c1', 'Groceries')],
        txns: [_expense('t1', 'a1', 'c1', 120)],
      );

      final acc = store.accountById('a1')!;
      store.removeAccount(acc); // has history → archived, not deleted

      expect(acc.archived, isTrue);
      expect(store.accounts.map((a) => a.id), isNot(contains('a1')));
      expect(store.archivedAccounts.map((a) => a.id), contains('a1'));

      store.restoreAccount(acc);

      expect(acc.archived, isFalse);
      expect(store.accounts.map((a) => a.id), contains('a1'));
      expect(store.archivedAccounts, isEmpty);
      // Balance and history intact: 500 starting − 120 spent.
      expect(store.balanceOf('a1'), 380);
      expect(store.txnsForAccount('a1'), hasLength(1));
    });

    test('archivedAccounts reads the private list, not the filtered one', () {
      final store = _store(
        accounts: [_account('a1', 'Old', archived: true)],
      );
      expect(store.accounts, isEmpty);
      expect(store.archivedAccounts.map((a) => a.id), ['a1']);
    });
  });

  group('restoreCategory', () {
    test('reverses an archive; the category reappears in pickers', () {
      final store = _store(categories: [_category('c1', 'Freelance')]);
      final cat = store.categoryById('c1')!;

      store.archiveCategory(cat);
      expect(cat.archived, isTrue);
      expect(store.categories, isEmpty);
      expect(store.categoriesOfType(CategoryType.expense), isEmpty);
      expect(store.archivedCategories.map((c) => c.id), ['c1']);

      store.restoreCategory(cat);
      expect(cat.archived, isFalse);
      expect(store.categories.map((c) => c.id), contains('c1'));
      expect(store.archivedCategories, isEmpty);
    });
  });

  group('archiveCategory', () {
    test('removes an existing budget and leaves removedOn set', () {
      final store = _store(categories: [_category('c1', 'Groceries', budget: 1000)]);
      final cat = store.categoryById('c1')!;

      expect(store.budgetedCategories.map((c) => c.id), contains('c1'));

      store.archiveCategory(cat);

      expect(cat.archived, isTrue);
      expect(cat.monthlyBudget, isNull);
      expect(cat.removedOn, AppStore.today);
      // It is now BOTH an archived category and a removed budget — two
      // independently restorable rows.
      expect(store.archivedCategories.map((c) => c.id), contains('c1'));
      expect(store.removedBudgets.map((c) => c.id), contains('c1'));
      expect(store.budgetedCategories, isEmpty);
      expect(store.categories, isEmpty);
    });

    test('a category with no budget archives with removedOn untouched', () {
      final store = _store(categories: [_category('c1', 'Freelance')]);
      final cat = store.categoryById('c1')!;

      store.archiveCategory(cat);

      expect(cat.archived, isTrue);
      expect(cat.removedOn, isNull);
      expect(store.removedBudgets, isEmpty);
      expect(store.archivedCategories.map((c) => c.id), ['c1']);
    });
  });

  group('archivedCount', () {
    test('counts archived goals, removed budgets, accounts and categories', () {
      final reached = Goal(
        id: 'g1',
        name: 'Trip',
        source: const GoalSource.account('a1'),
        targetAmount: 1000,
        createdAt: DateTime(2026, 1, 1),
        status: GoalStatus.reached,
        completedAt: DateTime(2026, 6, 1),
      );
      final store = _store(
        accounts: [
          _account('a1', 'Checking'),
          _account('a2', 'Old Wallet', archived: true),
        ],
        categories: [
          // Removed budget only (not archived).
          _category('c1', 'Rent', removedOn: DateTime(2026, 7, 1)),
          // Archived category with no budget (not a removed budget).
          _category('c2', 'Freelance',
              type: CategoryType.income, archived: true),
        ],
        goals: [reached],
      );

      expect(store.archivedGoals, hasLength(1));
      expect(store.removedBudgets, hasLength(1));
      expect(store.archivedAccounts, hasLength(1));
      expect(store.archivedCategories, hasLength(1));
      expect(store.archivedCount, 4);
    });
  });

  group('clearArchive', () {
    test('leaves archived accounts and categories alone', () {
      final abandoned = Goal(
        id: 'g1',
        name: 'Gym',
        source: const GoalSource.account('a1'),
        targetAmount: 1000,
        createdAt: DateTime(2026, 1, 1),
        status: GoalStatus.abandoned,
        stoppedAt: DateTime(2026, 6, 1),
      );
      final store = _store(
        accounts: [
          _account('a1', 'Checking'),
          _account('a2', 'Old Wallet', archived: true),
        ],
        categories: [
          _category('c1', 'Rent', removedOn: DateTime(2026, 7, 1)),
          _category('c2', 'Freelance',
              type: CategoryType.income, archived: true),
        ],
        goals: [abandoned],
      );

      store.clearArchive();

      // Goal and budget sections are emptied…
      expect(store.archivedGoals, isEmpty);
      expect(store.removedBudgets, isEmpty);
      // …but archived accounts and categories survive with their Restore.
      expect(store.archivedAccounts.map((a) => a.id), ['a2']);
      expect(store.archivedCategories.map((c) => c.id), ['c2']);
      // And they are still hidden from the public lists.
      expect(store.accounts.map((a) => a.id), ['a1']);
      expect(store.categories, isEmpty);
    });
  });

  group('tasksUsingCategory (§6 dangling-reference guard)', () {
    test('returns open tasks that book into the category', () {
      final task = Task(
        id: 'k1',
        title: 'Rent',
        linkedAccountId: 'a1',
        expectedAmount: -900,
        dueDate: DateTime(2026, 9, 1),
        icon: Icons.home_rounded,
        categoryId: 'c1',
      );
      final store = _store(
        categories: [_category('c1', 'Housing')],
        tasks: [task],
      );

      expect(store.tasksUsingCategory('c1').map((t) => t.id), ['k1']);
      expect(store.tasksUsingCategory('c2'), isEmpty);
    });
  });
}
