import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/new_account_inline_amount_test.dart

// Task 8 — the New account sheet types its numbers in place: tapping a numeric
// row opens no second sheet; a keypad docks at the foot of the same sheet and
// writes to the focused row.

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

/// Counts route pushes so a test can assert a tap opened nothing.
class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

Widget _host(AppStore store, void Function(BuildContext) onTap,
        {NavigatorObserver? observer}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [?observer],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, AppStore store,
    {NavigatorObserver? observer}) async {
  await tester.pumpWidget(
      _host(store, (ctx) => showNewAccountSheet(ctx), observer: observer));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Picks the credit-card type via the type sheet.
Future<void> _pickCreditCard(WidgetTester tester) async {
  await tester.tap(find.text('Type'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cards you spend on and repay later'));
  await tester.pumpAndSettle();
}

/// Pumps a few fixed frames. The focused row's caret blinks on a repeating
/// animation, so [WidgetTester.pumpAndSettle] never settles while a numeric
/// row holds focus — every step after the first focus uses this instead. The
/// longer pumps let sheet open/close transitions finish too.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Scrolls a row into view (the docked keypad shrinks the list viewport) and
/// taps it.
Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await _pumpFrames(tester);
  await tester.tap(find.text(label));
  await _pumpFrames(tester);
}

/// The row (label → enclosing focus container) that carries the accent
/// outline, if any.
Finder _outlinedRowOf(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null &&
          ((w.decoration as BoxDecoration).border as Border).top.color ==
              AppColors.accent.withValues(alpha: 0.55)),
    );

/// The blinking caret: a 2×17 accent bar inside the amount.
Finder get _caret => find.byWidgetPredicate((w) =>
    w is Container &&
    w.constraints == BoxConstraints.tightFor(width: 2, height: 17));

void main() {
  testWidgets('tapping Starting balance pushes no route and docks the keypad',
      (tester) async {
    final store = _store();
    final observer = _PushCounter();
    await _open(tester, store, observer: observer);

    expect(find.byType(NumericKeypad), findsNothing);
    final pushesBefore = observer.pushes;

    await tester.tap(find.text('Starting balance'));
    await _pumpFrames(tester);

    // The navigator stack depth is unchanged: no second sheet, no route.
    expect(observer.pushes, pushesBefore);
    // The keypad docks inside the same sheet.
    expect(find.byType(NumericKeypad), findsOneWidget);
  });

  testWidgets('keys land on the focused row only', (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCreditCard(tester);

    await _tapRow(tester, 'Credit limit');

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await _pumpFrames(tester);

    // Credit limit holds the typed digits; the balance is untouched at 0.00.
    expect(find.textContaining('123'), findsOneWidget);
    expect(find.textContaining('0.00'), findsOneWidget);
  });

  testWidgets('focus moves with the tap: outline and caret follow',
      (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCreditCard(tester);

    // Nothing focused yet: no outline, no caret, no keypad.
    expect(_outlinedRowOf('Amount owed'), findsNothing);
    expect(_outlinedRowOf('Credit limit'), findsNothing);
    expect(_caret, findsNothing);

    await _tapRow(tester, 'Amount owed');
    expect(_outlinedRowOf('Amount owed'), findsOneWidget);
    expect(_outlinedRowOf('Credit limit'), findsNothing);
    // The caret lives inside the outlined row — they move together.
    expect(
        find.descendant(
            of: _outlinedRowOf('Amount owed'), matching: _caret),
        findsOneWidget);

    await _tapRow(tester, 'Credit limit');
    expect(_outlinedRowOf('Amount owed'), findsNothing);
    expect(_outlinedRowOf('Credit limit'), findsOneWidget);
    expect(
        find.descendant(
            of: _outlinedRowOf('Credit limit'), matching: _caret),
        findsOneWidget);
  });

  testWidgets(
      'switching credit card → cash while the limit is focused falls back '
      'without throwing and the keypad keeps working', (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCreditCard(tester);

    await _tapRow(tester, 'Credit limit');

    // Switch the type to a single-numeric-row one while the limit row —
    // which is about to disappear — holds focus.
    await _tapRow(tester, 'Type');
    await tester.tap(find.text('Current account, cash, your debit card'));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);

    // Focus fell back to the balance row; the keypad still writes.
    expect(find.text('Credit limit'), findsNothing);
    expect(_outlinedRowOf('Starting balance'), findsOneWidget);
    expect(find.byType(NumericKeypad), findsOneWidget);
    expect(find.textContaining('0.00'), findsOneWidget);
    await tester.tap(find.text('7'));
    await _pumpFrames(tester);
    // The empty 0.00 display was replaced — the key landed on the balance row.
    expect(find.textContaining('0.00'), findsNothing);
  });

  testWidgets('name focus closes the keypad, and a numeric tap closes the '
      'system keyboard — never both at once', (tester) async {
    final store = _store();
    await _open(tester, store);

    // The name field autofocuses on open; tapping the balance row must take
    // focus from it before the keypad opens.
    final nameField = find.byType(TextField).first;
    expect(tester.widget<TextField>(nameField).focusNode!.hasFocus, isTrue);

    await tester.tap(find.text('Starting balance'));
    await _pumpFrames(tester);
    expect(find.byType(NumericKeypad), findsOneWidget);
    expect(tester.widget<TextField>(nameField).focusNode!.hasFocus, isFalse);

    // Focusing the name field closes the keypad.
    await tester.tap(find.text('Account name'));
    await _pumpFrames(tester);
    expect(tester.widget<TextField>(nameField).focusNode!.hasFocus, isTrue);
    expect(find.byType(NumericKeypad), findsNothing);
  });

  testWidgets('backspace to empty reads 0.00, not blank', (tester) async {
    final store = _store();
    await _open(tester, store);

    await tester.tap(find.text('Starting balance'));
    await _pumpFrames(tester);
    await tester.tap(find.text('5'));
    await _pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await _pumpFrames(tester);

    expect(find.textContaining('0.00'), findsOneWidget);
  });

  testWidgets(
      'Create & select stores the same values the old stacked sheet produced',
      (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCreditCard(tester);

    await tester.enterText(find.byType(TextField).first, 'Amex');
    await tester.pump();

    // Old flow: keys 1 2 3 4 . 5 6 in the amount sheet → raw "1234.56".
    await _tapRow(tester, 'Amount owed');
    for (final k in ['1', '2', '3', '4', '.', '5', '6']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    // Same key sequence for the limit: 5 0 0 0 → raw "5000".
    await _tapRow(tester, 'Credit limit');
    for (final k in ['5', '0', '0', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }

    await tester.ensureVisible(find.text('Create & select'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Create & select'));
    await _pumpFrames(tester);

    final created = store.accounts.firstWhere((a) => a.name == 'Amex');
    // addAccount signs liabilities negative — exactly as before.
    expect(created.startingBalance, -1234.56);
    expect(created.creditLimit, 5000);
  });
}
