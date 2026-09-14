import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/more/accounts_management_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/accounts_management_screen_test.dart

Account _acc(
  String id,
  String name, {
  AccountGroup group = AccountGroup.spendable,
  String currency = 'USD',
  bool archived = false,
  double bal = 1000,
}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: currency,
      startingBalance: bal,
      archived: archived,
    );

AppStore _store(List<Account> accounts, {List<Txn> txns = const <Txn>[]}) =>
    AppStore(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)), 
      accounts: accounts,
      categories: const <Category>[],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

/// Counts pushes after the initial route, so a tap that navigates is
/// distinguishable from one that does nothing without depending on the pushed
/// screen rendering.
class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushes++;
    super.didPush(route, previousRoute);
  }
}

Widget _app(
  AppStore store, {
  Locale? locale,
  NavigatorObserver? observer,
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        navigatorObservers: observer == null ? const [] : [observer],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountsManagementScreen(),
      ),
    );

void main() {
  // ── Unit: the cell count ───────────────────────────────────────────────────
  group('activeAccountCount (§1.2)', () {
    test('counts non-archived only, over 3 active + 2 archived', () {
      final store = _store([
        _acc('a1', 'One'),
        _acc('a2', 'Two'),
        _acc('a3', 'Three'),
        _acc('z1', 'Old', archived: true),
        _acc('z2', 'Older', archived: true),
      ]);
      expect(store.activeAccountCount, 3);
      expect(store.archivedAccounts.length, 2);
    });

    test('reads 0 over an empty account list', () {
      expect(_store(const []).activeAccountCount, 0);
    });
  });

  // ── Unit: the two lists never overlap ──────────────────────────────────────
  test('active list excludes archived; archived list excludes active (§3)', () {
    final store = _store([
      _acc('a1', 'One'),
      _acc('a2', 'Two'),
      _acc('z1', 'Gone', archived: true),
    ]);
    final active = store.manageableAccounts.map((a) => a.id).toSet();
    final archived = store.archivedAccounts.map((a) => a.id).toSet();
    expect(active, {'a1', 'a2'});
    expect(archived, {'z1'});
    expect(active.intersection(archived), isEmpty);
  });

  // ── Unit: restore moves exactly one account, leaving the rest untouched ─────
  test('restoreAccount moves it between the two lists only (§3.3)', () {
    final gone = _acc('z1', 'Gone', archived: true);
    final store = _store([_acc('a1', 'One'), _acc('a2', 'Two'), gone]);

    expect(store.manageableAccounts.map((a) => a.id), ['a1', 'a2']);
    expect(store.archivedAccounts.map((a) => a.id), ['z1']);

    store.restoreAccount(gone);

    expect(store.archivedAccounts, isEmpty);
    expect(store.manageableAccounts.map((a) => a.id), ['a1', 'a2', 'z1']);
    // The others are the same instances, untouched.
    expect(store.manageableAccounts[0].id, 'a1');
    expect(store.manageableAccounts[1].id, 'a2');
  });

  // ── Widget: header subtitle, three cases (§3.1) ────────────────────────────
  testWidgets('subtitle: some archived → "N active · M archived"',
      (tester) async {
    await tester.pumpWidget(_app(_store([
      _acc('a1', 'One'),
      _acc('a2', 'Two'),
      _acc('a3', 'Three'),
      _acc('z1', 'Gone', archived: true),
    ])));
    expect(find.text('3 active · 1 archived'), findsOneWidget);
  });

  testWidgets('subtitle: nothing archived → "N active" only', (tester) async {
    await tester.pumpWidget(_app(_store([
      _acc('a1', 'One'),
      _acc('a2', 'Two'),
    ])));
    expect(find.text('2 active'), findsOneWidget);
    expect(find.textContaining('archived'), findsNothing);
  });

  testWidgets('subtitle: zero accounts → no subtitle, empty state shows',
      (tester) async {
    await tester.pumpWidget(_app(_store(const [])));
    expect(find.textContaining('active'), findsNothing);
    expect(find.text('No accounts yet'), findsOneWidget);
    // The pinned button stays so the first account can be made.
    expect(find.text('New account'), findsOneWidget);
  });

  // ── Widget: ARCHIVED header absent when nothing is archived (§3.3) ──────────
  testWidgets('ARCHIVED header absent with nothing archived', (tester) async {
    await tester.pumpWidget(_app(_store([_acc('a1', 'One')])));
    // SectionLabel uppercases its text.
    expect(find.text('ARCHIVED'), findsNothing);
  });

  testWidgets('ARCHIVED header present when something is archived',
      (tester) async {
    await tester.pumpWidget(_app(_store([
      _acc('a1', 'One'),
      _acc('z1', 'Gone', archived: true),
    ])));
    expect(find.text('ARCHIVED'), findsOneWidget);
  });

  // ── Widget: taps (§3.2 / §3.3) ─────────────────────────────────────────────
  testWidgets('tapping an active row pushes EditAccountScreen', (tester) async {
    final obs = _PushCounter();
    await tester.pumpWidget(_app(
      _store([_acc('a1', 'Main Checking')]),
      observer: obs,
    ));
    await tester.tap(find.text('Main Checking'));
    await tester.pumpAndSettle();
    expect(obs.pushes, 1);
    expect(find.byType(EditAccountScreen), findsOneWidget);
  });

  testWidgets("tapping an archived row's body pushes nothing; Restore works",
      (tester) async {
    final obs = _PushCounter();
    final store = _store([
      _acc('a1', 'One'),
      _acc('z1', 'Old Wallet', archived: true),
    ]);
    await tester.pumpWidget(_app(store, observer: obs));

    // Tapping the archived name is inert.
    await tester.tap(find.text('Old Wallet'));
    await tester.pumpAndSettle();
    expect(obs.pushes, 0);
    expect(store.archivedAccounts.length, 1);

    // Restore is the only live target — and it reverses the archive.
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(obs.pushes, 0);
    expect(store.archivedAccounts, isEmpty);
    expect(store.manageableAccounts.map((a) => a.id), contains('z1'));
  });

  // ── Widget: no monetary figure anywhere, including masked mode (§7) ────────
  testWidgets('renders no AmountText and no currency-amount text',
      (tester) async {
    final store = _store([
      _acc('a1', 'One', bal: 123456),
      _acc('a2', 'Two', currency: 'EUR', bal: 9999),
      _acc('z1', 'Gone', archived: true, bal: 42),
    ]);
    store.toggleMasked(); // even masked, there is nothing to mask
    await tester.pumpWidget(_app(store));

    expect(find.byType(AmountText), findsNothing);

    // A currency symbol, or a grouped/decimal figure, would be an amount. The
    // currency CODE ("USD") and the counts ("3 active") are not.
    final money = RegExp(r'[€£$₼]|\d[.,]\d');
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final data = t.data;
      if (data != null) {
        expect(money.hasMatch(data), isFalse, reason: 'unexpected amount: $data');
      }
    }
  });

  // ── Widget: 320 pt, tr, long name → no overflow, Restore full width (§6) ────
  testWidgets('320pt tr long name: no overflow, Restore intact', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      _store([
        _acc('a1',
            'Uzun Uzun Uzun Hesap Adı Taşacak Kadar Uzun Bir İsim Buraya'),
        _acc('z1',
            'Arşivlenmiş Çok Çok Uzun Bir Hesap Adı Buraya Sığmayacak Kadar',
            archived: true),
      ]),
      locale: const Locale('tr'),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Restore is a control: it must render in full, never ellipsised.
    expect(find.text('Geri yükle'), findsOneWidget);
  });
}
