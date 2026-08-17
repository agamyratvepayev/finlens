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

  testWidgets('Split is non-interactive until an amount is entered (§2)',
      (tester) async {
    await _pump(tester, _store());
    // Tapping the disabled Split toggle opens nothing.
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(find.text('Split by category'), findsNothing);
  });
}
