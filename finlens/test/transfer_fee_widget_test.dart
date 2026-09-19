import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/transfer_sections.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transfer_fee_widget_test.dart
//
// The Transfer form's UI acceptance (Transfer-fee spec §2/§3/§5/§9). Accounts
// are pre-filled with fixedFrom/ToAccountId so the tests never have to drive the
// account picker; the numeric hero blinks forever, so these pump fixed frames
// rather than pumpAndSettle.

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 12)),
      baseCurrency: 'USD',
      accounts: [
        Account(
            id: 'a1',
            name: 'My Wallet',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 10000),
        Account(
            id: 'a2',
            name: 'Family Wallet',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 0),
        Account(
            id: 'a3',
            name: 'Euro Wallet',
            group: AccountGroup.spendable,
            currency: 'EUR',
            startingBalance: 0),
      ],
      categories: [
        Category(
            id: 'c-fee',
            name: 'Bank Fee',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF8E8E93)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

final _navKey = GlobalKey<NavigatorState>();

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        navigatorKey: _navKey,
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    );

Future<void> _openTransfer(WidgetTester tester, AppStore store,
    {required String from, required String to}) async {
  await tester.pumpWidget(_host(store));
  _navKey.currentState!.push(MaterialPageRoute<void>(
    builder: (_) => QuickAddScreen(
      initialType: QuickAddType.transfer,
      fixedFromAccountId: from,
      fixedToAccountId: to,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('Fee button shows for a same-currency transfer and opens the '
      'section (§3.1)', (tester) async {
    await _openTransfer(tester, _store(), from: 'a1', to: 'a2');

    // The button stands where the section will open.
    expect(find.text('Fee'), findsOneWidget);
    expect(find.byType(TransferFeeButton), findsOneWidget);

    await tester.tap(find.text('Fee'));
    await tester.pump();

    // Replaced in place by the section: an uppercased FEE header, a Remove
    // action, and an empty category row.
    expect(find.byType(TransferFeeButton), findsNothing);
    expect(find.text('FEE'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Choose category'), findsOneWidget);
  });

  testWidgets('tapping Rate opens no modal — no sheet, no Done (§2)',
      (tester) async {
    await _openTransfer(tester, _store(), from: 'a1', to: 'a3'); // USD → EUR

    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('Done'), findsNothing);

    final field = find.byType(TextField);
    expect(field, findsOneWidget); // only the rate field
    await tester.tap(field);
    await tester.pump();

    // No route/sheet appeared; the old modal's Done button is gone for good.
    expect(find.text('Done'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the rate row height is identical resting and focused (§2)',
      (tester) async {
    await _openTransfer(tester, _store(), from: 'a1', to: 'a3');

    final row = find.byType(InRowNumberField);
    expect(row, findsOneWidget);
    final resting = tester.getSize(row).height;

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.getSize(row).height, resting);
  });

  testWidgets('the summary is absent on a plain same-currency transfer and '
      'appears once a fee is entered (§5)', (tester) async {
    await _openTransfer(tester, _store(), from: 'a1', to: 'a2');

    // Enter an amount of 5 on the keypad.
    await tester.tap(find.text('5'));
    await tester.pump();
    // No fee, same currency → no summary.
    expect(find.textContaining('Leaves'), findsNothing);

    // Add a fee.
    await tester.tap(find.text('Fee'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '2'); // fee amount field
    await tester.pump();

    // A fee makes the two sides differ, so the summary shows.
    expect(find.textContaining('Leaves'), findsOneWidget);
    expect(find.textContaining('Arrives'), findsOneWidget);
  });

  testWidgets('masked mode hides both summary figures (§5)', (tester) async {
    final store = _store()..toggleMasked();
    await _openTransfer(tester, store, from: 'a1', to: 'a2');

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('Fee'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();

    // The Leaves/Arrives figures render masked ("$••••"), not as numbers.
    expect(find.textContaining('••••'), findsWidgets);
  });

  testWidgets('the fee category row opens the expense picker listing Bank Fee '
      '(§3.2)', (tester) async {
    await _openTransfer(tester, _store(), from: 'a1', to: 'a2');
    await tester.tap(find.text('Fee'));
    await tester.pump();

    await tester.tap(find.text('Choose category')); // the category row
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bank Fee'), findsWidgets);
  });
}
