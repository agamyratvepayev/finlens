import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/currency_editor_033_test.dart
//
// Task 033 · one row height, one typed rate, one spacing rule.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  // ─────────────────────────────────────────────────────────────────────────
  // §4 — the spacing rule (unit)
  // ─────────────────────────────────────────────────────────────────────────

  // A whole 570 at two decimals renders "570.00" through the custom branch.
  const n = '570.00';

  CurrencyDef def(String code, String? symbol, {required bool before}) =>
      CurrencyDef(
          code: code,
          name: code,
          symbol: symbol,
          decimals: 2,
          symbolBefore: before,
          custom: true);

  group('§4 spacing — a letter token takes a space, both positions', () {
    // Every built-in whose SYMBOL contains a letter. Glued before §4
    // ("Kč570"), spaced after ("Kč 570") — this is the change's blast radius.
    const letterSymbols = <(String, String)>[
      ('TMT', 'm'),
      ('CZK', 'Kč'),
      ('HUF', 'Ft'),
      ('IDR', 'Rp'),
      ('LKR', 'Rs'),
      ('NPR', 'Rs'),
      ('PKR', 'Rs'),
      ('MYR', 'RM'),
      ('PEN', 'S/'),
      ('PLN', 'zł'),
      ('RON', 'lei'),
      ('ZAR', 'R'),
      ('BRL', r'R$'),
      ('TWD', r'NT$'),
    ];
    for (final (code, sym) in letterSymbols) {
      test('$code ($sym) is spaced on both sides', () {
        expect(formatCurrencyExample(def(code, sym, before: true), 570),
            '$sym $n');
        expect(formatCurrencyExample(def(code, sym, before: false), 570),
            '$n $sym');
      });
    }
  });

  group('§4 spacing — a glyph token hugs the number, unchanged', () {
    // Every kind of glyph symbol. `$570` must stay exactly as it is.
    const glyphSymbols = <(String, String)>[
      ('USD', r'$'),
      ('EUR', '€'),
      ('GBP', '£'),
      ('JPY', '¥'),
      ('TRY', '₺'),
      ('RUB', '₽'),
      ('KRW', '₩'),
      ('INR', '₹'),
      ('THB', '฿'),
      ('VND', '₫'),
    ];
    for (final (code, sym) in glyphSymbols) {
      test('$code ($sym) hugs on both sides', () {
        expect(formatCurrencyExample(def(code, sym, before: true), 570),
            '$sym$n');
        expect(formatCurrencyExample(def(code, sym, before: false), 570),
            '$n$sym');
      });
    }
  });

  test('a code-only token stays spaced (BAM), unchanged', () {
    expect(formatCurrencyExample(def('BAM', null, before: true), 2000),
        'BAM\u00A02,000.00');
    expect(formatCurrencyExample(def('BAM', null, before: false), 2000),
        '2,000.00\u00A0BAM');
  });

  test('§4 is Unicode-aware — non-ASCII letters take the space too', () {
    // The test that catches an ASCII-only implementation: ł, č and Cyrillic лв
    // are letters; an ASCII regex would glue all three.
    for (final t in const ['zł', 'Kč', 'лв', 'S/', r'R$', 'm']) {
      expect(formatCurrencyExample(def('X', t, before: true), 570), '$t $n',
          reason: '$t is (or contains) a letter → spaced');
    }
    for (final t in const [r'$', '€', '₺', '₩']) {
      expect(formatCurrencyExample(def('X', t, before: true), 570), '$t$n',
          reason: '$t is a glyph → flush');
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // §1/§2/§3 — the sheet (widget)
  // ─────────────────────────────────────────────────────────────────────────

  AppStore emptyStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Widget host(AppStore store, void Function(BuildContext) onOpen,
          {Locale locale = const Locale('en'),
          double textScale = 1.0,
          List<NavigatorObserver> observers = const []}) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          navigatorObservers: observers,
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
              builder: (c) => TextButton(
                onPressed: () => onOpen(c),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openEdit(WidgetTester tester, AppStore store, CurrencyDef d,
      {Locale locale = const Locale('en'),
      double textScale = 1.0,
      List<NavigatorObserver> observers = const []}) async {
    await tester.pumpWidget(host(store, (c) => showEditCurrencySheet(c, d),
        locale: locale, textScale: textScale, observers: observers));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(host(store, (c) => showAddCurrencySheet(c)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The EditableText inside a keyed row, for enterText / focus assertions.
  Finder fieldIn(String key) => find.descendant(
      of: find.byKey(Key(key)), matching: find.byType(EditableText));

  // ── §1/§2 — every row is the same height as Decimal places ─────────────────
  testWidgets('all six rows render the same height (within 1px)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openEdit(tester, emptyStore(), currencyDef('TMT'));

    double h(String k) => tester.getSize(find.byKey(Key(k))).height;
    final keys = const [
      'curRowRate',
      'curRowCode',
      'curRowName',
      'curRowSymbol',
      'curRowPosition',
      'curRowDecimals',
    ];
    final ref = h('curRowDecimals'); // Decimal places is the yardstick.
    for (final k in keys) {
      expect(h(k), moreOrLessEquals(ref, epsilon: 1.0),
          reason: '$k must be as tall as Decimal places');
    }
  });

  testWidgets('the Preview value is 14.5 w600 and follows the new spacing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openEdit(tester, emptyStore(), currencyDef('TMT'));

    // TMT built-in seeds symbol 'm', before — 'm' is a letter, so the preview
    // is spaced: 'm 9,850.00'.
    final preview = tester.widget<Text>(find.text('m 9,850.00'));
    expect(preview.style?.fontSize, 14.5);
    expect(preview.style?.fontWeight, FontWeight.w600);
  });

  // ── §3 — the rate is typed in place; no sheet opens ────────────────────────
  testWidgets('tapping the rate opens no sheet — the number is typed in the row',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final observer = _PushCounter();
    await openEdit(tester, emptyStore(), currencyDef('TMT'),
        observers: [observer]);

    final baseline = observer.pushes; // includes the sheet's own push.
    await tester.tap(find.byKey(const Key('curRowRate')));
    await tester.pumpAndSettle();

    expect(observer.pushes, baseline,
        reason: 'no promptDecimal sheet is pushed any more');
    expect(tester.widget<EditableText>(fieldIn('curRowRate')).focusNode.hasFocus,
        isTrue,
        reason: 'the tap focused the field instead');
  });

  testWidgets('the clear button appears only with a value, and clearing shows '
      'Set rate', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = emptyStore();
    store.setRate('TMT', 3.4965); // a rated currency

    await openEdit(tester, store, currencyDef('TMT'));

    // Seeded with the stored rate → the clear button is present.
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    expect(find.text('3.4965'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear'));
    await tester.pumpAndSettle();

    // Dropped to the designed Set-rate state; the clear button is gone.
    expect(find.text('Set rate'), findsOneWidget);
    expect(find.bySemanticsLabel('Clear'), findsNothing);
  });

  // ── §2 — add mode still types Code, Name and Symbol ────────────────────────
  testWidgets('add mode still types Code, Name and Symbol', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());

    await tester.enterText(fieldIn('curRowCode'), 'abc');
    await tester.enterText(fieldIn('curRowName'), 'My Coin');
    await tester.enterText(fieldIn('curRowSymbol'), 'µ');
    await tester.pumpAndSettle();

    // Code uppercases as it always did.
    expect(find.text('ABC'), findsWidgets);
    expect(find.text('My Coin'), findsWidgets);
    expect(find.text('µ'), findsWidgets);
  });

  // ── §2/§4 — the preview updates live from symbol, position and decimals ────
  testWidgets('the preview updates live and carries the new spacing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());

    await tester.enterText(fieldIn('curRowCode'), 'TMT');
    await tester.pumpAndSettle();
    // Symbol empty → token is the code, spaced.
    expect(find.text('TMT\u00A09,850.00'), findsOneWidget);

    // A letter symbol is spaced too (§4), live.
    await tester.enterText(fieldIn('curRowSymbol'), 'zł');
    await tester.pumpAndSettle();
    expect(find.text('zł\u00A09,850.00'), findsOneWidget);

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    expect(find.text('9,850.00\u00A0zł'), findsOneWidget);
  });

  // ── §6 — no overflow across widths, scales and locales ─────────────────────
  for (final width in const [320.0, 360.0, 390.0]) {
    for (final scale in const [1.0, 1.3]) {
      for (final locale in const [
        Locale('en'),
        Locale('tr'),
        Locale('tk'),
        Locale('ru')
      ]) {
        testWidgets(
            'no overflow at ${width.toInt()}pt / ${(scale * 100).toInt()}% / '
            '${locale.languageCode}', (tester) async {
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await openEdit(tester, emptyStore(), currencyDef('TMT'),
              locale: locale, textScale: scale);
          expect(tester.takeException(), isNull);

          // …and again with the keyboard up (a bottom inset).
          tester.view.viewInsets = const FakeViewPadding(bottom: 320);
          addTearDown(() => tester.view.resetViewInsets());
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

class _PushCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}
