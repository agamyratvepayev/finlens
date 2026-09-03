import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/quick_add_form_test.dart

AppStore _store() => AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const QuickAddScreen(initialType: QuickAddType.expense),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the pinned validation bar is gone (§3)', (tester) async {
    await _pump(tester, _store());
    // The old bar rendered "Enter an amount" permanently; now nothing does
    // until Save is tapped.
    expect(find.text('Enter an amount'), findsNothing);
    // Save is present (nav bar) and there is only one of it.
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save on an incomplete form names the amount, does not save',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    await tester.tap(find.text('Save'));
    await tester.pump(); // start snackbar + pulse
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(store.txns, isEmpty); // nothing written
  });

  testWidgets('after filling the amount, Save names From next (§3)',
      (tester) async {
    final store = _store();
    await _pump(tester, store);
    // The numeric keypad is open on a new expense; enter an amount.
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Choose an account'), findsOneWidget);
    expect(store.txns, isEmpty);
  });

  testWidgets('Split action is disabled and states its reason (§7)',
      (tester) async {
    await _pump(tester, _store());
    // The full-width Split action names what it does and, with no amount,
    // states why it is unavailable.
    expect(find.text('Split into several categories'), findsOneWidget);
    expect(find.text('Enter an amount first.'), findsOneWidget);
    // Tapping the disabled action opens nothing.
    await tester.tap(find.text('Split into several categories'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
  });

  testWidgets('setting a repeat creates one transaction and one Planner rule',
      (tester) async {
    final store = _store();
    // Both refs pre-filled (from=account, to=category) so the flow needs no
    // pickers; the keypad supplies the amount.
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const QuickAddScreen(
          initialType: QuickAddType.expense,
          fixedFromAccountId: 'a1',
          fixedToAccountId: 'g',
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    // Open the Repeat row, choose Monthly, confirm.
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    // One transaction now, one Planner Task, linked to each other. No future
    // occurrences are written up front (§1).
    expect(store.txns.length, 1);
    expect(store.tasks.length, 1);
    expect(store.txns.single.recurrenceTaskId, store.tasks.single.id);
  });

  testWidgets('clearing a repeat removes the rule and leaves the transaction',
      (tester) async {
    final task = Task(
      id: 'k1',
      title: 'Rent',
      linkedAccountId: 'a1',
      expectedAmount: -5,
      dueDate: DateTime(2026, 9, 15),
      icon: Icons.repeat_rounded,
      repeats: RepeatFrequency.monthly,
    );
    final txn = Txn(
      id: 't1',
      type: TxnType.expense,
      amount: 5,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'g',
      date: DateTime(2026, 8, 15),
      recurrenceTaskId: 'k1',
    );
    final store = AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: [txn],
      goals: const [],
      tasks: [task],
    );
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: QuickAddScreen(
          initialType: QuickAddType.expense,
          editing: txn,
        ),
      ),
    ));
    await tester.pump();
    // Editing loads the existing rule: the Repeat row shows "Monthly". Open it
    // and switch to Never.
    expect(find.text('Monthly'), findsOneWidget);
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    // The rule is gone; the transaction survives, no longer linked (§1).
    expect(store.tasks, isEmpty);
    expect(store.txns.length, 1);
    expect(store.txns.single.recurrenceTaskId, isNull);
  });
}
