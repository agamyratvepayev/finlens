import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/balance/balance_screen.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/features/balance/widgets/account_rows.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/negative_balance_sign_test.dart
//
// Task 011 — "a balance that went negative must say so". A balance renders
// unsigned while its sign agrees with its account's kind, and signed the moment
// it contradicts it. Colour follows the figure, not the kind.

const _minus = '−'; // the true minus glyph money() prints, not a hyphen

AppStore _store({
  double wallet = 0,
  AccountGroup group = AccountGroup.spendable,
  List<Txn> txns = const [],
}) =>
    AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      baseCurrency: 'USD',
      accounts: [
        Account(
          id: 'w',
          name: 'Wallet',
          group: group,
          currency: 'USD',
          startingBalance: wallet,
        ),
      ],
      categories: [
        Category(
          id: 'g',
          name: 'Groceries',
          type: CategoryType.expense,
          icon: Icons.circle,
          color: const Color(0xFF34C759),
        ),
      ],
      txns: txns,
      goals: const [],
      tasks: const [],
    );

Txn _expense(String id, double amount) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: 'USD',
      fromRef: 'w',
      toRef: 'g',
      date: DateTime(2026, 8, 8),
    );

Widget _host(Widget child, AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('money — the five rows of the §1 table', () {
    test('asset at +2,500 is unsigned', () {
      expect(money(2500, signless: true), r'$2,500');
    });
    test('asset at −100 shows its minus', () {
      // signless is turned off the moment the figure contradicts its kind.
      expect(money(-100, signless: false), '$_minus\$100');
    });
    test('liability at −800 is unsigned (agrees with kind)', () {
      expect(money(-800, signless: true), r'$800');
    });
    test('liability at +50 shows a plus (in credit)', () {
      expect(money(50, signless: false, showSign: true), r'+$50');
    });
    test('net worth at −500 shows its minus', () {
      expect(money(-500, signless: false), '$_minus\$500');
    });
  });

  group('AmountText.balance widget renders each row', () {
    Future<String> render(WidgetTester tester, double value,
        {required bool isLiability}) async {
      await tester.pumpWidget(_host(
        AmountText.balance(value, isLiability: isLiability),
        _store(),
      ));
      await tester.pump();
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    testWidgets('asset +2,500 → \$2,500', (tester) async {
      expect(await render(tester, 2500, isLiability: false), r'$2,500');
    });
    testWidgets('asset −100 → −\$100', (tester) async {
      expect(await render(tester, -100, isLiability: false), '$_minus\$100');
    });
    testWidgets('liability −800 → \$800', (tester) async {
      expect(await render(tester, -800, isLiability: true), r'$800');
    });
    testWidgets('liability +50 → +\$50', (tester) async {
      expect(await render(tester, 50, isLiability: true), r'+$50');
    });
    testWidgets('net worth −500 (asset-side) → −\$500', (tester) async {
      expect(await render(tester, -500, isLiability: false), '$_minus\$500');
    });
  });

  // The reported bug, end to end. A zero-balance Spendable account with a $100
  // expense. Against the CURRENT code this is RED: the row printed "$100" in the
  // ordinary secondary colour. After task 011 it reads "−$100" in amountChildNeg.
  testWidgets('Balance account row shows −\$100 in amountChildNeg after an '
      'expense takes a 0 account below zero', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store(wallet: 0, txns: [_expense('t1', 100)]);
    expect(store.balanceOf('w'), -100); // arithmetic was never at fault

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: const Scaffold(body: BalanceScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // Expand Spendable if it is not already, so the account child row is on
    // screen. Tapping the group's name zone toggles it.
    final accountRow = find.byType(AccountRow);
    if (accountRow.evaluate().isEmpty) {
      await tester.tap(find.text('Wallet').first);
      await tester.pumpAndSettle();
    }

    final amount = tester.widget<Text>(
      find.descendant(
        of: find.byType(AccountRow),
        matching: find.text('$_minus\$100'),
      ),
    );
    expect(amount.style?.color, AppColors.amountChildNeg);
  });

  testWidgets('an asset row still at +2,500 is unchanged (secondary, unsigned)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store(wallet: 2500);
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: const Scaffold(body: BalanceScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    if (find.byType(AccountRow).evaluate().isEmpty) {
      await tester.tap(find.text('Wallet').first);
      await tester.pumpAndSettle();
    }
    final amount = tester.widget<Text>(
      find.descendant(
        of: find.byType(AccountRow),
        matching: find.text(r'$2,500'),
      ),
    );
    expect(amount.style?.color, AppColors.textSecondary);
  });

  // Both halves of the transaction detail agree: the PAID WITH row's "balance
  // after" prints the signed running balance (−$100), which the account row on
  // Balance now matches. PAID WITH always used plain money() and so was already
  // signed — this pins that the two screens no longer disagree.
  testWidgets('detail PAID WITH shows the signed −\$100 running balance',
      (tester) async {
    final store = _store(wallet: 0, txns: [_expense('t1', 100)]);
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: const SameTransactionsScreen(originTxnId: 't1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PAID WITH'), findsOneWidget);
    // The running balance after the expense: 0 − 100 = −100, in the account's
    // own currency, signed.
    expect(find.text('$_minus\$100'), findsWidgets);
  });
}
