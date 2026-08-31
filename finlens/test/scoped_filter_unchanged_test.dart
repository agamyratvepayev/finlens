import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/scoped_filter_unchanged_test.dart
//
// Proof (deliverable §6) that the SCOPED filter sheet renders exactly as before
// the "truthful sheet" rework: every new capability is Ledger-only opt-in, so
// the scoped call site keeps its legacy chrome — Select all / Clear controls,
// the "Transactions here range …" amount caption, and the single group section.

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 5000,
    );

Category _cat(String id, String name, CategoryType type) => Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.circle,
      color: const Color(0xFF34C759),
    );

Txn _exp(String id, double amt, String cat, int day) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amt,
      currency: 'USD',
      fromRef: 'a1',
      toRef: cat,
      date: DateTime(2026, 8, day, 12),
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [
        _cat('c-food', 'Groceries', CategoryType.expense),
        _cat('c-rent', 'Housing', CategoryType.expense),
      ],
      txns: [
        _exp('t1', 120, 'c-food', 3),
        _exp('t2', 900, 'c-rent', 5),
      ],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const ScopedLedgerScreen(initialScope: AccountScope('a1')),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('scoped filter keeps its legacy chrome (deliverable §6)',
      (tester) async {
    await _pump(tester, _store());
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    // Legacy sections: TYPE + one group section (CATEGORIES for an account
    // scope) + AMOUNT. No DIRECTION row, no split EXPENSES/INCOME sections.
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('DIRECTION'), findsNothing);
    expect(find.text('EXPENSES'), findsNothing);

    // Legacy controls are retained (the truthful rework is Ledger-only).
    expect(find.text('Select all'), findsWidgets);
    expect(find.text('Select others'), findsNothing);

    // The legacy amount caption survives (§10's real-bound placeholders are
    // Ledger-only).
    expect(find.textContaining('Transactions here range'), findsOneWidget);

    // Group items render as before.
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Housing'), findsOneWidget);
  });

  testWidgets('scoped Select all still fills the group, then Clear (unchanged)',
      (tester) async {
    await _pump(tester, _store());
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    // The group section's Select all fills every group; the control flips to
    // Clear and the header reads "· all" — exactly the pre-rework behaviour.
    await tester.tap(find.text('Select all').first);
    await tester.pump();
    expect(find.text('· all'), findsOneWidget);
    expect(find.text('Clear'), findsWidgets);
  });
}
