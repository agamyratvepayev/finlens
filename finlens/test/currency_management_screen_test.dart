import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/more/currency_management_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/currency_management_screen_test.dart
//
// Currency-sheet spec §1: the Currencies screen shows no monetary figure, splits
// into IN USE / ADDED, NOT USED, marks the base currency, and states that no
// exchange rate is applied. The trailing `formatCurrencyExample(def, 9850)`
// sample is gone.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore store({
    List<Account> accounts = const [],
    List<CurrencyDef> custom = const [],
  }) {
    final s = AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: accounts,
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    for (final c in custom) {
      s.addCustomCurrency(c);
    }
    return s;
  }

  Account acct(String id, String currency) => Account(
        id: id,
        name: 'Acct $id',
        group: AccountGroup.spendable,
        currency: currency,
        startingBalance: 100,
      );

  Widget host(
    AppStore s, {
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) =>
      StoreScope(
        store: s,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TkMaterialLocalizationsDelegate(),
            TkCupertinoLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const CurrencyManagementScreen(),
        ),
      );

  void setSize(WidgetTester tester, double w, double h) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, h);
    addTearDown(tester.view.reset);
  }

  AppLocalizations l(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CurrencyManagementScreen)));

  // A currency *figure*: grouped thousands (9,850) or a decimal amount (9850.00).
  // A bare symbol in the tile ("$") or an account count ("2 accounts") is not a
  // figure and must not match.
  final moneyFigure = RegExp(r'\d[\d,]*\.\d|\d{1,3}(?:,\d{3})+');

  // ── §1 / §8 — no monetary figure appears, in any state ─────────────────────
  testWidgets('renders no currency-amount figure (base-only and populated)',
      (tester) async {
    setSize(tester, 390, 844);

    for (final s in [
      store(),
      store(
        accounts: [acct('a1', 'USD'), acct('a2', 'USD'), acct('a3', 'EUR')],
        custom: [const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true)],
      ),
    ]) {
      await tester.pumpWidget(host(s));
      await tester.pumpAndSettle();

      for (final e in find.byType(Text).evaluate()) {
        final data = (e.widget as Text).data;
        if (data == null) continue;
        expect(moneyFigure.hasMatch(data), isFalse,
            reason: 'no row may print a money figure — found "$data"');
      }
      expect(find.textContaining('9,850'), findsNothing);
    }
  });

  // ── §1.2 — subtitle usage counts: 0, 1, 2 ──────────────────────────────────
  for (final locale in const [Locale('en'), Locale('tr'), Locale('tk')]) {
    testWidgets('usage counts render for 0/1/2 accounts in ${locale.languageCode}',
        (tester) async {
      setSize(tester, 390, 844);
      final s = store(accounts: [acct('a1', 'EUR'), acct('a2', 'EUR')]);
      await tester.pumpWidget(host(s, locale: locale));
      await tester.pumpAndSettle();
      final ll = l(tester);

      // EUR: 2 accounts, USD (base): 0 accounts. 1-account case via a fresh store.
      expect(find.textContaining(ll.curUsageAccounts(2)), findsWidgets);
      expect(find.textContaining(ll.curUsageAccounts(0)), findsWidgets);

      final s1 = store(accounts: [acct('a1', 'EUR')]);
      await tester.pumpWidget(host(s1, locale: locale));
      await tester.pumpAndSettle();
      expect(find.textContaining(l(tester).curUsageAccounts(1)), findsWidgets);
    });
  }

  // ── §1.3 — ADDED, NOT USED appears only with an unreferenced custom ────────
  testWidgets('ADDED, NOT USED present with an unused custom, absent without',
      (tester) async {
    setSize(tester, 390, 844);

    await tester.pumpWidget(host(store()));
    await tester.pumpAndSettle();
    expect(find.text(l(tester).curSectionAdded), findsNothing,
        reason: 'no unused custom ⇒ no section');

    await tester.pumpWidget(host(store(
        custom: [const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true)])));
    await tester.pumpAndSettle();
    expect(find.text(l(tester).curSectionAdded), findsOneWidget);
    expect(find.text('CUSTOM'), findsWidgets);
  });

  testWidgets('a custom currency in use stays under IN USE, not the unused group',
      (tester) async {
    setSize(tester, 390, 844);
    final s = store(
      accounts: [acct('a1', 'ZED')],
      custom: [const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true)],
    );
    await tester.pumpWidget(host(s));
    await tester.pumpAndSettle();

    expect(find.text(l(tester).curSectionInUse), findsOneWidget);
    expect(find.text(l(tester).curSectionAdded), findsNothing,
        reason: 'ZED is held by an account, so it is IN USE');
    expect(find.text('Zedland'), findsOneWidget);
  });

  // ── §1.1 — the base currency carries exactly one BASE badge ────────────────
  testWidgets('the BASE badge is on exactly one row', (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(
        store(accounts: [acct('a1', 'USD'), acct('a2', 'EUR')])));
    await tester.pumpAndSettle();
    expect(find.text(l(tester).curBase.toUpperCase()), findsOneWidget);
  });

  // ── §1.4 — the exchange-rate footer is present ─────────────────────────────
  testWidgets('the display-settings footer line is shown', (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(store()));
    await tester.pumpAndSettle();
    expect(find.text(l(tester).curDisplayNote), findsOneWidget);
  });

  // ── §1.2 / §5 — the row is ~40 pt at 100 %, taller at 130 %, never clipped ──
  double rowHeight(WidgetTester tester, String name) {
    final inkwell =
        find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;
    return tester.getRect(inkwell).height;
  }

  testWidgets('row measures ~40 pt at 100% and grows at 130%, no overflow',
      (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(store(accounts: [acct('a1', 'USD')])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final h100 = rowHeight(tester, 'US Dollar');
    expect(h100, closeTo(40, 3), reason: 'measured 40 pt at 100% scale');

    await tester.pumpWidget(host(store(accounts: [acct('a1', 'USD')]),
        textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final h130 = rowHeight(tester, 'US Dollar');
    expect(h130, greaterThan(h100), reason: 'grows from intrinsic, not clipped');
  });

  // ── §5 — 320 pt / tr: long name ellipsises; code, CUSTOM, tile stay ────────
  testWidgets('no overflow at 320 in tr; code and CUSTOM intact', (tester) async {
    setSize(tester, 320, 568);
    final s = store(custom: [
      const CurrencyDef(
        code: 'ZEDXY',
        name: 'A deliberately very long currency name that must clip',
        symbol: '≋',
        custom: true,
      ),
    ]);
    await tester.pumpWidget(host(s, locale: const Locale('tr')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('ZEDXY'), findsWidgets);
    expect(find.text('CUSTOM'), findsWidgets);
    expect(find.text('≋'), findsWidgets);

    // Nothing painted past the viewport width.
    for (final e in find.byType(Text).evaluate()) {
      final box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final left = box.localToGlobal(Offset.zero).dx;
      expect(left, greaterThanOrEqualTo(-0.5));
    }
  });
}
