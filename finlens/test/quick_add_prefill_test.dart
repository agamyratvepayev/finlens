import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/quick_add_prefill_test.dart
//
// Task 054 — a drill-down's `+ Add` PREFILLS From without LOCKING it, and a
// type switch carries the account rather than dropping it.

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      baseCurrency: 'USD',
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
        Account(
            id: 'a2',
            name: 'Euro Wallet',
            group: AccountGroup.spendable,
            currency: 'EUR',
            startingBalance: 50),
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

Future<void> _pumpQuickAdd(
  WidgetTester tester,
  AppStore store, {
  String? initialFromAccountId,
  String? fixedFromAccountId,
  QuickAddType type = QuickAddType.expense,
}) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: QuickAddScreen(
        initialType: type,
        initialFromAccountId: initialFromAccountId,
        fixedFromAccountId: fixedFromAccountId,
      ),
    ),
  ));
  await tester.pump();
}

/// The [TxnFieldRow] whose value renders [value].
Finder _rowWithValue(String value) =>
    find.ancestor(of: find.text(value), matching: find.byType(TxnFieldRow));

void main() {
  // ── §1 · The prefilled From row is editable ───────────────────────────────

  testWidgets('initialFromAccountId prefills From and leaves it editable',
      (tester) async {
    await _pumpQuickAdd(tester, _store(), initialFromAccountId: 'a1');

    // The account name is shown in the From row.
    final fromRow = _rowWithValue('Cash');
    expect(fromRow, findsOneWidget);

    // Its label reads in the editable colour, not the locked grey.
    final label =
        tester.widget<Text>(find.descendant(of: fromRow, matching: find.text('From')));
    expect(label.style?.color, AppColors.textPrimary);

    // The editable-only down chevron is present in the row.
    expect(
      find.descendant(
          of: fromRow, matching: find.byIcon(Icons.keyboard_arrow_down_rounded)),
      findsOneWidget,
    );

    // Tapping it opens the account picker titled "Payment account".
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Payment account'), findsOneWidget);
  });

  testWidgets('picking another account moves From and the currency follows',
      (tester) async {
    await _pumpQuickAdd(tester, _store(), initialFromAccountId: 'a1');
    // Starts on the USD account.
    expect(find.widgetWithText(CurrencyChip, 'USD'), findsOneWidget);

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro Wallet'));
    await tester.pumpAndSettle();

    // From now shows the picked account, and the chip follows its currency.
    expect(_rowWithValue('Euro Wallet'), findsOneWidget);
    expect(find.widgetWithText(CurrencyChip, 'EUR'), findsOneWidget);
    expect(find.widgetWithText(CurrencyChip, 'USD'), findsNothing);
  });

  testWidgets('the picker offers + New, which opens the New account sheet',
      (tester) async {
    await _pumpQuickAdd(tester, _store(), initialFromAccountId: 'a1');
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();

    // The create action the drill-down could not reach before is present…
    expect(find.text('New account'), findsOneWidget);
    await tester.tap(find.text('New account'));
    await tester.pumpAndSettle();
    // …and it opens the New account form (its create footer is on screen).
    expect(find.text('Create & select'), findsOneWidget);
  });

  // ── §2 · A type switch carries the account ────────────────────────────────

  Future<void> switchTypeTo(WidgetTester tester, String label) async {
    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Expense → Income carries the account into To, and back into From',
      (tester) async {
    await _pumpQuickAdd(tester, _store(), initialFromAccountId: 'a1');
    expect(find.descendant(of: _rowWithValue('Cash'), matching: find.text('From')),
        findsOneWidget);

    await switchTypeTo(tester, 'Income');
    // The account was not dropped; it moved to the To (account) slot.
    expect(find.text('Cash'), findsOneWidget);
    expect(find.descendant(of: _rowWithValue('Cash'), matching: find.text('To')),
        findsOneWidget);

    await switchTypeTo(tester, 'Expense');
    // …and back to From.
    expect(find.descendant(of: _rowWithValue('Cash'), matching: find.text('From')),
        findsOneWidget);
  });

  testWidgets('Expense → Transfer keeps From, editable, picker says Source account',
      (tester) async {
    await _pumpQuickAdd(tester, _store(), initialFromAccountId: 'a1');
    await switchTypeTo(tester, 'Transfer');

    final fromRow = _rowWithValue('Cash');
    expect(find.descendant(of: fromRow, matching: find.text('From')),
        findsOneWidget);
    // Editable: the row opens the transfer's source picker.
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Source account'), findsOneWidget);
  });

  // ── §1d · The fixed (archive) path is untouched ───────────────────────────

  testWidgets('a fixed From (archive transfer) stays locked: grey, no chevron, inert',
      (tester) async {
    await _pumpQuickAdd(tester, _store(),
        fixedFromAccountId: 'a1', type: QuickAddType.transfer);

    final fromRow = _rowWithValue('Cash');
    final label =
        tester.widget<Text>(find.descendant(of: fromRow, matching: find.text('From')));
    expect(label.style?.color, AppColors.textSecondary);
    expect(
      find.descendant(
          of: fromRow, matching: find.byIcon(Icons.keyboard_arrow_down_rounded)),
      findsNothing,
    );

    // A tap opens nothing — the row is not an InkWell.
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Source account'), findsNothing);
  });

  // ── §1c · The scoped ledger wires the prefill, never the lock ─────────────

  Future<void> pumpScoped(WidgetTester tester, AppStore store, LedgerScope scope) async {
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ScopedLedgerScreen(initialScope: scope),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('one-account scope: + Add prefills (not locks) that account',
      (tester) async {
    await pumpScoped(tester, _store(), const AccountScope('a1'));
    await tester.tap(find.widgetWithText(FilledButton, '+  Add'));
    await tester.pumpAndSettle();

    final screen = tester.widget<QuickAddScreen>(find.byType(QuickAddScreen));
    expect(screen.initialFromAccountId, 'a1');
    expect(screen.fixedFromAccountId, isNull);
  });

  testWidgets('multi-account group scope: + Add prefills nothing',
      (tester) async {
    await pumpScoped(
        tester, _store(), const GroupScope(AccountGroup.spendable));
    await tester.tap(find.widgetWithText(FilledButton, '+  Add'));
    await tester.pumpAndSettle();

    final screen = tester.widget<QuickAddScreen>(find.byType(QuickAddScreen));
    expect(screen.initialFromAccountId, isNull);
    expect(screen.fixedFromAccountId, isNull);
  });
}
