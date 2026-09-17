import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/currency_picker_widget_test.dart
//
// Currency-sheet spec: the picker opens at half height and grows on demand (§1),
// each row swipes to Edit (and, for an unused custom currency, Delete) (§3), a
// user-added currency carries a CUSTOM tag (§3.1), and a standard currency's
// code and name are read-only while its symbol/position/decimals stay editable
// (§4). None of it touches a stored amount (§4.1).

const _title = 'Currency'; // l.eaCurrency in en

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore store({
    List<Account> accounts = const [],
    List<Txn> txns = const [],
  }) =>
      AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: accounts,
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
    ValueChanged<String?>? onPicked,
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
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final r = await pickCurrency(context, 'USD');
                  onPicked?.call(r);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  void setSize(WidgetTester tester, double w, double h) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, h);
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The picker's own opaque rounded surface, scoped to its title.
  Finder surface() => find.ancestor(
        of: find.text(_title),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius ==
                  const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      );

  // ── §1 — opens at half the screen ──────────────────────────────────────────
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('opens at ~half height on ${size.width}×${size.height}',
        (tester) async {
      setSize(tester, size.width, size.height);
      await tester.pumpWidget(host(store()));
      await open(tester);

      final h = tester.getRect(surface()).height;
      expect(h, closeTo(size.height * 0.5, size.height * 0.08),
          reason: '0.5 initial fraction of the window');
    });
  }

  testWidgets('at 130% on 320×568 opens taller than half, nothing clipped',
      (tester) async {
    setSize(tester, 320, 568);
    await tester.pumpWidget(host(store(), textScale: 1.3));
    await open(tester);

    expect(tester.takeException(), isNull);
    final h = tester.getRect(surface()).height;
    // 0.5 × 1.3 = 0.65 → visibly taller than half, still under the ceiling.
    expect(h, greaterThan(568 * 0.5));
    expect(h, lessThan(568 * 0.96));
  });

  testWidgets('header, + Add, Cancel and search are visible at the initial size',
      (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(store()));
    await open(tester);

    final box = tester.getRect(surface());
    for (final f in [
      find.text(_title),
      find.text('Add'),
      find.text('Cancel'),
      find.byType(TextField),
    ]) {
      expect(f, findsWidgets);
      final r = tester.getRect(f.first);
      expect(r.top, greaterThanOrEqualTo(box.top - 1));
      expect(r.bottom, lessThanOrEqualTo(box.bottom + 1),
          reason: 'reachable without scrolling');
    }
  });

  // ── §1.1 — focusing search grows the sheet, and it stays grown ─────────────
  testWidgets('focusing search grows the sheet; clearing does not shrink it',
      (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(store()));
    await open(tester);

    final before = tester.getRect(surface()).height;
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final grown = tester.getRect(surface()).height;
    expect(grown, greaterThan(before + 40), reason: 'search focus expands it');

    // Type then clear the query — the sheet must not spring back.
    await tester.enterText(find.byType(TextField).first, 'US');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(tester.getRect(surface()).height, closeTo(grown, 2));
  });

  // ── §2 — the tap still selects and pops ────────────────────────────────────
  testWidgets('tapping a row returns its code and pops the sheet',
      (tester) async {
    setSize(tester, 390, 844);
    String? picked;
    await tester.pumpWidget(host(store(), onPicked: (v) => picked = v));
    await open(tester);

    await tester.tap(find.text('Euro').last);
    await tester.pumpAndSettle();

    expect(picked, 'EUR');
    expect(find.text(_title), findsNothing);
  });

  // ── §3 — swipe reveals Edit (all) and Delete (unused custom only) ──────────
  testWidgets('standard→1 action, unused custom→2, in-use custom→1',
      (tester) async {
    setSize(tester, 390, 844);
    final s = store(accounts: [acct('a1', 'USD'), acct('a2', 'YEN')]);
    s.addCustomCurrency(
        const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true));
    s.addCustomCurrency(
        const CurrencyDef(code: 'YEN', name: 'Yenland', custom: true));

    await tester.pumpWidget(host(s));
    await open(tester);

    int actionsFor(String name) {
      final f = find.ancestor(
        of: find.text(name).last,
        matching: find.byType(SwipeActions),
      );
      return tester.widget<SwipeActions>(f).actions.length;
    }

    expect(actionsFor('US Dollar'), 1, reason: 'standard: Edit only');
    expect(actionsFor('Zedland'), 2, reason: 'unused custom: Edit + Delete');
    expect(actionsFor('Yenland'), 1,
        reason: 'custom in use by an account: Edit only, no disabled Delete');
  });

  testWidgets('a custom row carries the CUSTOM tag; a standard row does not',
      (tester) async {
    setSize(tester, 390, 844);
    final s = store();
    s.addCustomCurrency(
        const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true));

    await tester.pumpWidget(host(s));
    await open(tester);

    expect(find.text('CUSTOM'), findsOneWidget);
  });

  testWidgets('swipe actions are exposed as custom semantics actions',
      (tester) async {
    setSize(tester, 390, 844);
    final s = store();
    s.addCustomCurrency(
        const CurrencyDef(code: 'ZED', name: 'Zedland', custom: true));

    await tester.pumpWidget(host(s));
    await open(tester);

    bool exposes(String label) => find
        .byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.customSemanticsActions != null &&
            w.properties.customSemanticsActions!.keys
                .any((a) => a.label == label))
        .evaluate()
        .isNotEmpty;

    expect(exposes('Edit'), isTrue);
    expect(exposes('Delete'), isTrue, reason: 'unused custom exposes Delete');
  });

  // ── §4 — the edit form's field enablement across the three cases ───────────
  Future<void> openEdit(WidgetTester tester, AppStore s, CurrencyDef def) async {
    await tester.pumpWidget(StoreScope(
      store: s,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditCurrencySheet(context, def),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // Task 033 §2: Code and Name are no longer editable-but-read-only TextFields.
  // A locked field is a plain FormRow with the padlock FormRow draws; only the
  // fields that are actually typable (symbol, and the rate) are TextFields. So
  // "code & name are read-only" now means "they are not TextFields at all".
  testWidgets('standard edit: code & name are locked FormRows, symbol editable',
      (tester) async {
    setSize(tester, 390, 844);
    await openEdit(tester, store(), currencyDef('TMT'));

    // Two padlocks: the Code and Name FormRows.
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    expect(find.text('TMT'), findsWidgets, reason: 'code shown as a value');
    expect(find.text('Turkmen Manat'), findsWidgets);

    // The symbol IS editable — the field carrying the built-in's 'm'.
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    final symbol = fields.firstWhere((f) => f.controller?.text == 'm');
    expect(symbol.readOnly, isFalse, reason: 'symbol — the user\'s choice');
  });

  testWidgets('custom edit: name & symbol editable, code a locked FormRow',
      (tester) async {
    setSize(tester, 390, 844);
    final s = store();
    s.addCustomCurrency(const CurrencyDef(
        code: 'ZED', name: 'Zedland', symbol: 'z', custom: true));

    await openEdit(tester, s, currencyDef('ZED'));

    // One padlock: the code. A custom currency's name stays the user's.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('ZED'), findsWidgets, reason: 'code shown as a value');

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    final name = fields.firstWhere((f) => f.controller?.text == 'Zedland');
    expect(name.readOnly, isFalse, reason: 'a custom name is the user\'s');
    final symbol = fields.firstWhere((f) => f.controller?.text == 'z');
    expect(symbol.readOnly, isFalse);
  });

  testWidgets('add: all fields editable', (tester) async {
    setSize(tester, 390, 844);
    await tester.pumpWidget(host(store()));
    await tester.pumpWidget(StoreScope(
      store: store(),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddCurrencySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].readOnly, isFalse);
    expect(fields[1].readOnly, isFalse);
    expect(fields[2].readOnly, isFalse);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  // ── §4 — Preview reflects position and decimals live ───────────────────────
  testWidgets('Preview updates when position flips and decimals change',
      (tester) async {
    setSize(tester, 390, 1200);
    await tester.pumpWidget(StoreScope(
      store: store(),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddCurrencySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'TMT');
    await tester.pumpAndSettle();
    expect(find.text('TMT 9,850.00'), findsOneWidget);

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    expect(find.text('9,850.00 TMT'), findsOneWidget);

    // Drop to 0 decimals.
    await tester.tap(find.text('Decimal places'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0').last);
    await tester.pumpAndSettle();
    expect(find.text('9,850 TMT'), findsOneWidget);
  });

  // ── §5 — 320pt / tr: name ellipsises, code + CUSTOM + symbol stay ──────────
  testWidgets('no overflow at 320 in tr, code/CUSTOM/symbol intact',
      (tester) async {
    setSize(tester, 320, 568);
    final s = store();
    s.addCustomCurrency(const CurrencyDef(
        code: 'ZEDXY',
        name: 'A deliberately very long currency name that must clip',
        symbol: '≋',
        custom: true));

    await tester.pumpWidget(host(s, locale: const Locale('tr')));
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('ZEDXY'), findsWidgets); // code never truncates
    expect(find.text('≋'), findsWidgets); // symbol never truncates
  });

  // ── Unit — the in-use predicate the delete guard reads ─────────────────────
  test('currencyInUse: base, account, txn-only, and unreferenced', () {
    final s = store(
      accounts: [acct('a1', 'USD')],
      txns: [
        Txn(
          id: 't1',
          type: TxnType.expense,
          amount: 12,
          currency: 'JPY',
          fromRef: 'a1',
          toRef: 'g',
          date: DateTime(2026, 8, 1),
        ),
      ],
    );
    // The delete guard reads currencyInUse OR the base currency (§3's _isInUse).
    bool inUse(String c) => s.currencyInUse(c) || s.baseCurrency == c;
    expect(inUse(s.baseCurrency), isTrue, reason: 'base currency counts');
    expect(inUse('USD'), isTrue, reason: 'held by an account');
    expect(inUse('JPY'), isTrue, reason: 'named by a transaction');
    expect(inUse('AUD'), isFalse, reason: 'referenced by nothing, not base');
  });

  // ── Unit — changing decimals touches no stored amount ──────────────────────
  test('changing a currency\'s decimals leaves stored amounts byte-identical',
      () {
    final s = store(
      accounts: [
        Account(
          id: 'a1',
          name: 'Cash',
          group: AccountGroup.spendable,
          currency: 'ZED',
          startingBalance: 1234.56,
        ),
      ],
      txns: [
        Txn(
          id: 't1',
          type: TxnType.expense,
          amount: 78.90,
          currency: 'ZED',
          fromRef: 'a1',
          toRef: 'g',
          date: DateTime(2026, 8, 1),
        ),
      ],
    );
    s.addCustomCurrency(
        const CurrencyDef(code: 'ZED', name: 'Zedland', decimals: 2, custom: true));

    s.updateCustomCurrency(
        const CurrencyDef(code: 'ZED', name: 'Zedland', decimals: 0, custom: true));

    expect(s.accounts.firstWhere((a) => a.id == 'a1').startingBalance, 1234.56);
    expect(s.txns.firstWhere((t) => t.id == 't1').amount, 78.90);
  });
}
