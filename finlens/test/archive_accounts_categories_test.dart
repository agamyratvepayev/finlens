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
  bool archived = false,
}) =>
    Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
      archived: archived,
    );

/// A monthly category budget for [catId] (budgets-as-object spec §A). A removed
/// budget carries an [archivedAt] — the migration's `removedOn`.
Budget _budget(String catId, {double limit = 1000, DateTime? archivedAt}) =>
    Budget(
      id: 'b-$catId',
      name: catId,
      scope: BudgetScope.categories,
      targets: {catId},
      limit: limit,
      anchor: DateTime(2026, 1, 1),
      archivedAt: archivedAt,
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
  List<Budget>? budgets,
  List<Txn>? txns,
  List<Goal>? goals,
  List<Task>? tasks,
}) =>
    AppStore(
      accounts: accounts ?? [_account('a1', 'Checking')],
      categories: categories ?? [_category('c1', 'Groceries')],
      budgets: budgets ?? const <Budget>[],
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
      final store = _store(
        categories: [_category('c1', 'Groceries')],
        budgets: [_budget('c1', limit: 1000)],
      );
      final cat = store.categoryById('c1')!;

      expect(store.budgetedCategories.map((c) => c.id), contains('c1'));

      store.archiveCategory(cat);

      expect(cat.archived, isTrue);
      expect(store.monthlyLimitOf(cat), isNull);
      expect(store.removedOnOf(cat), AppStore.today);
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
      expect(store.removedOnOf(cat), isNull);
      expect(store.removedBudgets, isEmpty);
      expect(store.archivedCategories.map((c) => c.id), ['c1']);
    });
  });

  group('archivedCount', () {
    test('counts goals, removed budgets and accounts — NOT archived categories (§2.4)',
        () {
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
          _category('c1', 'Rent'),
          // Archived category with no budget (not a removed budget).
          _category('c2', 'Freelance',
              type: CategoryType.income, archived: true),
        ],
        budgets: [_budget('c1', archivedAt: DateTime(2026, 7, 1))],
        goals: [reached],
      );

      expect(store.archivedGoals, hasLength(1));
      expect(store.removedBudgets, hasLength(1));
      expect(store.archivedAccounts, hasLength(1));
      expect(store.archivedCategories, hasLength(1));
      // Archived categories live in the category management screen now, so they
      // no longer contribute to the Archive's count: 1 goal + 1 budget + 1
      // account = 3, not 4.
      expect(store.archivedCount, 3);
    });
  });

  group('scoped clear (§6.3)', () {
    AppStore build() {
      final abandoned = Goal(
        id: 'g1',
        name: 'Gym',
        source: const GoalSource.account('a1'),
        targetAmount: 1000,
        createdAt: DateTime(2026, 1, 1),
        status: GoalStatus.abandoned,
        stoppedAt: DateTime(2026, 6, 1),
      );
      return _store(
        accounts: [
          _account('a1', 'Checking'),
          _account('a2', 'Old Wallet', archived: true),
        ],
        categories: [
          _category('c1', 'Rent'),
          _category('c2', 'Freelance',
              type: CategoryType.income, archived: true),
        ],
        budgets: [_budget('c1', archivedAt: DateTime(2026, 7, 1))],
        goals: [abandoned],
      );
    }

    test('clearFinished leaves accounts, budgets and unfinished goals alone', () {
      final store = build();
      store.clearFinished();
      // The abandoned goal is UNFINISHED, not FINISHED — untouched.
      expect(store.archivedGoals.map((g) => g.id), ['g1']);
      expect(store.removedBudgets, hasLength(1));
      expect(store.archivedAccounts.map((a) => a.id), ['a2']);
      expect(store.archivedCategories.map((c) => c.id), ['c2']);
    });

    test('clearUnfinished removes abandoned goals but keeps the rest', () {
      final store = build();
      store.clearUnfinished();
      expect(store.archivedGoals, isEmpty);
      // Removed budgets sit in CAN COME BACK now — no clear touches them (§6.3).
      expect(store.removedBudgets, hasLength(1));
      // Archived accounts and categories survive with their Restore.
      expect(store.archivedAccounts.map((a) => a.id), ['a2']);
      expect(store.archivedCategories.map((c) => c.id), ['c2']);
      // Still hidden from the public account list.
      expect(store.accounts.map((a) => a.id), ['a1']);
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
