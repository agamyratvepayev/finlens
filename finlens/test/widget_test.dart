import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/main.dart';

void main() {
  testWidgets('Balance is the default tab and shows net worth', (tester) async {
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));

    expect(find.text('Balance'), findsWidgets);
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Spendable'), findsWidgets);
  });

  test('net worth is assets minus liabilities', () {
    final store = buildSeedStore();
    expect(store.netWorth, store.totalAssets - store.totalLiabilities);
    expect(store.totalLiabilities, greaterThan(0));
  });

  test('balances derive from starting balance plus transactions', () {
    final store = buildSeedStore();
    final account = store.accountById('a-checking')!;
    final before = store.balanceOf(account.id);

    store.addTxn(
      type: TxnType.expense,
      amount: 100,
      currency: 'USD',
      fromRef: account.id,
      toRef: 'c-groceries',
      date: DateTime(2026, 8, 9),
    );

    expect(store.balanceOf(account.id), before - 100);
  });

  test('removing a budget keeps the category and its transactions', () {
    final store = buildSeedStore();
    final category = store.categoryById('c-entertainment')!;
    final txnCount = store.txnCountForCategory(category.id);

    store.removeBudget(category);

    // Spec 5.5 — budget ≠ category.
    expect(category.monthlyBudget, isNull);
    expect(store.categoryById('c-entertainment'), isNotNull);
    expect(store.txnCountForCategory(category.id), txnCount);
    expect(store.budgetedCategories.contains(category), isFalse);
  });

  test('skipping a recurring task advances it without a ledger entry', () {
    final store = buildSeedStore();
    final task = store.taskById('k-netflix')!;
    final due = task.dueDate;
    final ledgerSize = store.txns.length;

    store.skipTask(task);

    // Spec 5.7 — skip writes nothing but still moves the series on.
    expect(store.txns.length, ledgerSize);
    expect(task.dueDate.isAfter(due), isTrue);
    expect(task.skippedDates, contains(due));
  });

  test('marking a task paid writes a transaction and advances the series', () {
    final store = buildSeedStore();
    final task = store.taskById('k-netflix')!;
    final due = task.dueDate;
    final ledgerSize = store.txns.length;

    store.markTaskPaid(
      task,
      amount: task.expectedAmount.abs(),
      date: AppStore.today,
      fromAccountId: task.linkedAccountId,
      toRef: task.categoryId!,
    );

    expect(store.txns.length, ledgerSize + 1);
    expect(task.dueDate.isAfter(due), isTrue);
  });

  test('rebalance moves net worth but not income or expense', () {
    final store = buildSeedStore();
    final month = DateTime(2026, 8);
    final income = store.monthIncome(month);
    final expense = store.monthExpense(month);
    final worth = store.netWorth;

    store.addTxn(
      type: TxnType.rebalance,
      amount: 1000,
      currency: 'USD',
      fromRef: 'a-gold',
      toRef: 'a-gold',
      date: DateTime(2026, 8, 9),
    );

    // Spec 6.2 — revaluation isolation.
    expect(store.monthIncome(month), income);
    expect(store.monthExpense(month), expense);
    expect(store.netWorth, worth + 1000);
  });

  test('a transfer fee is charged on top of the amount', () {
    final store = buildSeedStore();
    final from = store.balanceOf('a-checking');
    final to = store.balanceOf('a-family');

    store.addTxn(
      type: TxnType.transfer,
      amount: 200,
      currency: 'USD',
      fromRef: 'a-checking',
      toRef: 'a-family',
      date: DateTime(2026, 8, 9),
      fee: 5,
    );

    // Spec 3.4 — source pays amount + fee, destination receives the amount.
    expect(store.balanceOf('a-checking'), from - 205);
    expect(store.balanceOf('a-family'), to + 200);
  });

  test('an account with history is archived rather than deleted', () {
    final store = buildSeedStore();
    final account = store.accountById('a-checking')!;

    store.removeAccount(account);

    // Spec 6.2 — nothing with history is truly removed.
    expect(account.archived, isTrue);
    expect(store.accounts.contains(account), isFalse);
  });

  testWidgets('Spendable opens by default, other groups stay closed',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));

    // A Spendable child is visible without any tap...
    expect(find.text('Main Checking'), findsOneWidget);
    // ...while another group's children stay collapsed.
    expect(find.text('Gold Portfolio'), findsNothing);
  });

  testWidgets('groups list in documented order, assets before liabilities',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));

    double topOf(String label) =>
        tester.getTopLeft(find.text(label)).dy;

    expect(topOf('Spendable'), lessThan(topOf('Receivables')));
    expect(topOf('Receivables'), lessThan(topOf('Investments')));
    expect(topOf('Investments'), lessThan(topOf('Valuables')));
    expect(topOf('Valuables'), lessThan(topOf('Credit Cards')));
  });

  testWidgets('privacy mode masks amounts', (tester) async {
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));

    expect(find.textContaining(r'$'), findsWidgets);

    store.toggleMasked();
    await tester.pump();

    expect(find.textContaining('••••'), findsWidgets);
  });
}
