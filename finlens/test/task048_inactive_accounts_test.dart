import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/persistence/store_mappers.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 048 §2 — inactive accounts. `flutter test` hangs on the author's machine,
// so these are written, not run here; verify with `flutter analyze` and run the
// file yourself:  flutter test test/task048_inactive_accounts_test.dart
//
// An inactive account stays in every list, total and report; only the account
// picker leaves it out, behind a "Show inactive (N)" row that reveals an
// INACTIVE card. It is independent of `hidden` and `archived`.

Account _acc(
  String id,
  String name, {
  AccountGroup group = AccountGroup.spendable,
  bool hidden = false,
  bool inactive = false,
}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: 'USD',
      startingBalance: 1000,
      hidden: hidden,
      inactive: inactive,
    );

AppStore _store(List<Account> accounts) => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: accounts,
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _pickerHost(AppStore store, {void Function(Account?)? onPicked}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final a = await pickAccount(ctx);
                  onPicked?.call(a);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openPicker(WidgetTester tester, AppStore store,
    {void Function(Account?)? onPicked}) async {
  await tester.pumpWidget(_pickerHost(store, onPicked: onPicked));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Widget _editHost(AppStore store, String accountId) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx)
                    .push(MaterialPageRoute<EditAccountOutcome>(
                        builder: (_) =>
                            EditAccountScreen(accountId: accountId))),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('the mapper carries inactive', () {
    test('accountToMap writes 1 for an inactive account', () {
      expect(accountToMap(_acc('a1', 'X', inactive: true))['inactive'], 1);
      expect(accountToMap(_acc('a2', 'Y'))['inactive'], 0);
    });

    test('a map without the column decodes to active (false)', () {
      final map = accountToMap(_acc('a1', 'X', inactive: true))
        ..remove('inactive');
      expect(accountFromMap(map).inactive, isFalse);
    });
  });

  group('the picker hides inactive behind a Show inactive row', () {
    testWidgets(
        'active shown, inactive behind the toggle, hidden never appears',
        (tester) async {
      final store = _store([
        _acc('a1', 'Main Checking'),
        _acc('a2', 'Savings'),
        _acc('a3', 'Old Card', group: AccountGroup.creditCards, inactive: true),
        _acc('a4', 'Hidden Wallet', hidden: true, inactive: true),
      ]);
      await _openPicker(tester, store);

      // Active accounts are listed; the inactive one is not, but its toggle is.
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Old Card'), findsNothing);
      expect(find.text('Show inactive (1)'), findsOneWidget);
      // The hidden account (inactive or not) is never offered, and is not
      // counted — the count is 1, not 2.
      expect(find.text('Hidden Wallet'), findsNothing);

      // Reveal them: the INACTIVE card and the row appear; the toggle flips.
      await tester.tap(find.text('Show inactive (1)'));
      await tester.pumpAndSettle();
      expect(find.text('INACTIVE'), findsOneWidget);
      expect(find.text('Old Card'), findsOneWidget);
      expect(find.text('Hide inactive'), findsOneWidget);
      expect(find.text('Hidden Wallet'), findsNothing);
    });

    testWidgets('tapping an inactive row pops that account', (tester) async {
      Account? picked;
      final store = _store([
        _acc('a1', 'Main Checking'),
        _acc('a3', 'Old Card', inactive: true),
      ]);
      await _openPicker(tester, store, onPicked: (a) => picked = a);

      await tester.tap(find.text('Show inactive (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old Card'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.id, 'a3');
      // It stays inactive — picking does not reactivate it.
      expect(store.accountById('a3')!.inactive, isTrue);
    });

    testWidgets('no inactive accounts → no Show inactive row', (tester) async {
      final store = _store([
        _acc('a1', 'Main Checking'),
        _acc('a2', 'Savings'),
      ]);
      await _openPicker(tester, store);
      expect(find.textContaining('Show inactive'), findsNothing);
    });

    testWidgets(
        'only inactive accounts → search field and toggle, not the empty state',
        (tester) async {
      final store = _store([
        _acc('a3', 'Old Card', inactive: true),
      ]);
      await _openPicker(tester, store);
      expect(find.text('No accounts yet'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Show inactive (1)'), findsOneWidget);
    });

    testWidgets(
        'a query matching only the inactive account shows the toggle, no no-match',
        (tester) async {
      final store = _store([
        _acc('a1', 'Main Checking'),
        _acc('a2', 'Savings'),
        _acc('a3', 'Old Card', inactive: true),
      ]);
      await _openPicker(tester, store);
      await tester.enterText(find.byType(TextField), 'Old');
      await tester.pumpAndSettle();

      expect(find.textContaining('No account matches'), findsNothing);
      expect(find.text('Show inactive (1)'), findsOneWidget);
    });
  });

  group('Edit account toggles inactive', () {
    testWidgets('turning Inactive on and off round-trips through Save',
        (tester) async {
      final store = _store([_acc('a1', 'Main Checking')]);
      await tester.pumpWidget(_editHost(store, 'a1'));

      // On.
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.accountById('a1')!.inactive, isTrue);

      // Off.
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.accountById('a1')!.inactive, isFalse);
    });
  });
}
