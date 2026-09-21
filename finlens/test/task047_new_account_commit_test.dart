import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task047_new_account_commit_test.dart
//
// Task 047 — the New account sheet commits what is on screen: a dangling
// operator is dropped and the figure before it saved (`52 +` → 52), never read
// as 0; a row that still cannot resolve (`52 ÷ 0`) disables Create & select.

const _plus = '+';
const _times = '×'; // × U+00D7
const _divide = '÷'; // ÷ U+00F7

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: const <Account>[],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNewAccountSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

/// The focused row's caret blinks forever, so pumpAndSettle never settles while
/// a numeric row holds focus — pump fixed frames instead.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _open(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(_host(store));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pickType(WidgetTester tester, String description) async {
  await tester.tap(find.text('Type'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(description));
  await tester.pumpAndSettle();
}

Future<void> _pickCash(WidgetTester tester) =>
    _pickType(tester, 'Current account, cash, your debit card');

Future<void> _pickCreditCard(WidgetTester tester) =>
    _pickType(tester, 'Cards you spend on and repay later');

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await _pumpFrames(tester);
  await tester.tap(find.text(label));
  await _pumpFrames(tester);
}

/// Taps a keypad key by its glyph, scoped to the docked keypad so a `+` in the
/// header (there is none here, but scoping is cheap insurance) is never hit.
Future<void> _key(WidgetTester tester, String glyph) async {
  await tester.tap(
      find.descendant(of: find.byType(NumericKeypad), matching: find.text(glyph)));
  await tester.pump();
}

/// The Create & select FilledButton — its onPressed is null while disabled.
FilledButton _footerButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Create & select'),
        matching: find.byType(FilledButton),
      ),
    );

Future<void> _create(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create & select'));
  await _pumpFrames(tester);
  await tester.tap(find.text('Create & select'));
  await _pumpFrames(tester);
}

void main() {
  testWidgets('52 + commits 52, not 0', (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCash(tester);
    await tester.enterText(find.byType(TextField).first, 'Wallet');
    await tester.pump();

    await _tapRow(tester, 'Starting balance');
    await _key(tester, '5');
    await _key(tester, '2');
    await _key(tester, _plus);
    await _pumpFrames(tester);

    // Button stays enabled on a dangling operator (there is still a figure).
    expect(_footerButton(tester).onPressed, isNotNull);

    await _create(tester);
    final created = store.accounts.firstWhere((a) => a.name == 'Wallet');
    expect(created.startingBalance, 52);
  });

  testWidgets(
      'credit card: Amount owed 1234.56, Credit limit 5000 × → −1234.56 / 5000',
      (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCreditCard(tester);
    await tester.enterText(find.byType(TextField).first, 'Amex');
    await tester.pump();

    await _tapRow(tester, 'Amount owed');
    for (final k in ['1', '2', '3', '4', '.', '5', '6']) {
      await _key(tester, k);
    }
    // A dangling × on the limit is dropped; 5000 is committed.
    await _tapRow(tester, 'Credit limit');
    for (final k in ['5', '0', '0', '0']) {
      await _key(tester, k);
    }
    await _key(tester, _times);
    await _pumpFrames(tester);

    expect(_footerButton(tester).onPressed, isNotNull);
    await _create(tester);

    final created = store.accounts.firstWhere((a) => a.name == 'Amex');
    expect(created.startingBalance, -1234.56); // liabilities signed negative
    expect(created.creditLimit, 5000);
  });

  testWidgets('52 + then leaving the row (name field) trims to 52 on screen',
      (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCash(tester);

    await _tapRow(tester, 'Starting balance');
    await _key(tester, '5');
    await _key(tester, '2');
    await _key(tester, _plus);
    await _pumpFrames(tester);
    // While focused the row shows the pending operator.
    expect(find.textContaining('52 +'), findsOneWidget);

    // Leaving the row (focusing the name field) trims the dangling operator, so
    // the row now shows the number that will be saved.
    await tester.tap(find.text('Account name'));
    await _pumpFrames(tester);
    expect(find.textContaining('52 +'), findsNothing);
    expect(find.textContaining('52'), findsWidgets);
  });

  testWidgets('52 ÷ 0 disables Create & select; fixing it re-enables and saves 26',
      (tester) async {
    final store = _store();
    await _open(tester, store);
    await _pickCash(tester);
    await tester.enterText(find.byType(TextField).first, 'Wallet');
    await tester.pump();

    await _tapRow(tester, 'Starting balance');
    await _key(tester, '5');
    await _key(tester, '2');
    await _key(tester, _divide);
    await _key(tester, '0');
    await _pumpFrames(tester);

    // 52 ÷ 0 cannot resolve — the button is disabled, not a silent 0.
    expect(_footerButton(tester).onPressed, isNull);

    // Backspace the 0, type 2 → 52 ÷ 2 = 26.
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await _key(tester, '2');
    await _pumpFrames(tester);
    expect(_footerButton(tester).onPressed, isNotNull);

    await _create(tester);
    final created = store.accounts.firstWhere((a) => a.name == 'Wallet');
    expect(created.startingBalance, 26);
  });
}
