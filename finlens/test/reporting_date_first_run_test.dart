import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/balance_screen.dart' show BalanceScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 025 — a past reporting date is not a first run. Balance must tell the two
// empty states apart: "nothing has ever been added" (the genuine first run) and
// "nothing existed on that date" (the historical-empty pane), and the date a
// user can actually set (openingDate) must be the date visibility reads.

Account _asset(
  String id,
  String name, {
  required DateTime openingDate,
  DateTime? openedOn,
  double opening = 100,
}) =>
    Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: opening,
      openedOn: openedOn,
      openingDate: openingDate,
    );

AppStore _store(List<Account> accounts) => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: accounts,
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

const _appDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  TkMaterialLocalizationsDelegate(),
  TkCupertinoLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: _appDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: BalanceScreen()),
      ),
    );

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BalanceScreen)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('widget · which empty screen', () {
    testWidgets(
        'accounts exist but none opened by the reporting date → historical pane, '
        'not the first-run pane, and the header stays live', (tester) async {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1)),
        _asset('a2', 'Savings', openingDate: DateTime(2026, 8, 1)),
      ]);
      store.setAsOf(DateTime(2026, 7, 1)); // before every opening
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final l = _l(tester);
      // The historical sentence, not the first-run one.
      expect(find.text(l.balNothingYetTitle), findsOneWidget);
      expect(find.text(l.balNoAccountsYet), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      // The header stays live: the + and the eye are both present, and the
      // "as of" line prints — this is a report of a date, not a blank slate.
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      expect(find.textContaining('as of'), findsOneWidget);
    });

    testWidgets('an empty store → the genuine first-run pane', (tester) async {
      final store = _store(const []);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final l = _l(tester);
      expect(find.text(l.balNoAccountsYet), findsOneWidget);
      expect(find.text(l.balNothingYetTitle), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsNothing);
    });

    testWidgets('tapping "Back to today" clears the reporting date and the list '
        'returns', (tester) async {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1)),
      ]);
      store.setAsOf(DateTime(2026, 7, 1));
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final l = _l(tester);
      expect(find.text(l.balNothingYetTitle), findsOneWidget);

      await tester.tap(find.text(l.balBackToToday));
      await tester.pumpAndSettle();

      expect(store.isHistorical, isFalse);
      expect(store.asOf, isNull);
      // The populated list is back.
      expect(find.text(l.balNothingYetTitle), findsNothing);
      expect(find.text('Main'), findsOneWidget);
    });

    testWidgets('the message names the earliest opening across ALL accounts, '
        'including one the cutoff hides', (tester) async {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1)),
        // Older, and also hidden by the cutoff below — it must still be the date
        // the message reports.
        _asset('a2', 'Old', openingDate: DateTime(2026, 6, 15)),
      ]);
      store.setAsOf(DateTime(2026, 5, 1)); // before both
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('15 Jun 2026'), findsOneWidget);
      expect(find.textContaining('1 Aug 2026'), findsNothing);
    });
  });

  group('unit · existsFrom and visibility', () {
    test('existsFrom prefers openingDate, falls back to openedOn, else null', () {
      final store = _store(const []);
      final both = Account(
        id: 'x',
        name: 'X',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0,
        openedOn: DateTime(2026, 3, 1),
        openingDate: DateTime(2026, 1, 1),
      );
      expect(store.existsFrom(both), DateTime(2026, 1, 1));

      final onlyOpened = Account(
        id: 'y',
        name: 'Y',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0,
        openedOn: DateTime(2026, 3, 1),
      );
      expect(store.existsFrom(onlyOpened), DateTime(2026, 3, 1));

      final neither = Account(
        id: 'z',
        name: 'Z',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0,
      );
      expect(store.existsFrom(neither), isNull);
    });

    test('§2c — an account created today with its opening balance back-dated to '
        '1 January is visible, with that balance, on a 1 August reporting date',
        () {
      final store = _store(const []);
      final acc = store.addAccount(
        name: 'Backdated',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0,
      );
      // Created today (clock = 9 Aug): openedOn is today, openingDate is today.
      // The opening-balance sheet then back-dates the floor to 1 January.
      store.setOpeningBalance(acc, amount: 500, date: DateTime(2026, 1, 1));

      store.setAsOf(DateTime(2026, 8, 1));
      expect(store.accounts.map((a) => a.id), contains('a1000'));
      expect(store.balanceOf(acc.id), 500);
      expect(store.netWorth, 500);
    });

    test('an account whose opening date is after the cutoff stays hidden', () {
      final store = _store([
        _asset('a1', 'Future', openingDate: DateTime(2026, 8, 20)),
      ]);
      store.setAsOf(DateTime(2026, 8, 1));
      expect(store.accounts, isEmpty);
    });

    test('net worth on a date before everything is 0, not null and not stale',
        () {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1), opening: 3500),
      ]);
      store.setAsOf(DateTime(2026, 7, 1));
      expect(store.netWorth, 0);
      expect(store.netWorth, isNotNull);
    });

    test('earliestAccountOpening spans the whole book, cutoff-independent', () {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1)),
        _asset('a2', 'Old', openingDate: DateTime(2026, 6, 15)),
      ]);
      store.setAsOf(DateTime(2026, 5, 1)); // both hidden
      expect(store.accounts, isEmpty);
      expect(store.earliestAccountOpening, DateTime(2026, 6, 15));
    });
  });

  group('regression · today is unchanged', () {
    test('at the live date every account is visible, as before', () {
      final store = _store([
        _asset('a1', 'Main', openingDate: DateTime(2026, 8, 1), opening: 100),
        _asset('a2', 'Savings', openingDate: DateTime(2026, 8, 1), opening: 250),
      ]);
      // No asOf set → live (today = 9 Aug, after both openings).
      expect(store.isHistorical, isFalse);
      expect(store.accounts.length, 2);
      expect(store.netWorth, 350);
    });
  });
}
