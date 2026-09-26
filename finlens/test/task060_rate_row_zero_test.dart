import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/more/currency_management_screen.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task060_rate_row_zero_test.dart
//
// Task 060 · an empty rate reads 0 in its currency, not Set rate.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore store({String base = 'TMT', List<Account> accounts = const []}) =>
      AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: accounts,
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
        baseCurrency: base,
      );

  Widget host(AppStore s, void Function(BuildContext) onOpen,
          {double textScale = 1.0}) =>
      StoreScope(
        store: s,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
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

  Future<void> openEdit(WidgetTester tester, AppStore s, CurrencyDef d,
      {double textScale = 1.0}) async {
    await tester.pumpWidget(
        host(s, (c) => showEditCurrencySheet(c, d), textScale: textScale));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester, AppStore s) async {
    await tester.pumpWidget(host(s, (c) => showAddCurrencySheet(c)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final rateRow = find.byKey(const Key('curRowRate'));

  Finder fieldIn(String key) => find.descendant(
      of: find.byKey(Key(key)), matching: find.byType(EditableText));

  TextField rateField(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(of: rateRow, matching: find.byType(TextField)));

  Text codeText(WidgetTester tester, String code) => tester.widget<Text>(
      find.descendant(of: rateRow, matching: find.text(code)));

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // ── empty, unfocused: dim 0 + code, no Set rate ─────────────────────────────
  testWidgets('an unrated currency shows hint 0 and its code, both dim',
      (tester) async {
    setSize(tester, const Size(390, 844));

    await openEdit(tester, store(), currencyDef('USD')); // base TMT, no rate

    final field = rateField(tester);
    expect(field.decoration?.hintText, '0');
    expect(field.decoration?.hintStyle?.color, AppColors.textTertiary);
    expect(field.decoration?.hintStyle?.fontSize, 14.5);
    expect(field.decoration?.hintStyle?.fontWeight, FontWeight.w600);

    final code = codeText(tester, 'USD');
    expect(code.style?.color, AppColors.textTertiary);
    expect(code.style?.fontSize, 14.5);
    expect(code.style?.fontWeight, FontWeight.w600);

    expect(find.text('Set rate'), findsNothing);
    expect(find.bySemanticsLabel('Clear'), findsNothing);
  });

  // ── §1e — the field announces the sentence the eye reads ───────────────────
  testWidgets('semantics: an empty row announces 1 TMT = 0 USD', (tester) async {
    setSize(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);

    await openEdit(tester, store(), currencyDef('USD'));
    expect(find.bySemanticsLabel('1 TMT = 0 USD'), findsOneWidget);

    await tester.enterText(fieldIn('curRowRate'), '3.5');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1 TMT = 3.5 USD'), findsOneWidget);
  });

  // ── empty, focused: caret + 0 + code, outline present ───────────────────────
  testWidgets('focused and empty: still hint 0 + code, with the focus outline',
      (tester) async {
    setSize(tester, const Size(390, 844));

    await openEdit(tester, store(), currencyDef('USD'));

    await tester.tap(rateRow);
    await tester.pumpAndSettle();
    expect(
        tester.widget<EditableText>(fieldIn('curRowRate')).focusNode.hasFocus,
        isTrue);

    // Hint and code unchanged by focus.
    expect(rateField(tester).decoration?.hintText, '0');
    expect(codeText(tester, 'USD').style?.color, AppColors.textTertiary);

    // The accent outline wraps the row.
    final outlined = tester.widgetList<Container>(find.byType(Container)).where(
      (c) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.border is Border &&
            (d.border as Border).top.color ==
                AppColors.accent.withValues(alpha: 0.55);
      },
    );
    expect(outlined, isNotEmpty);
  });

  // ── typing: white figure, grey code, clear button; only the reserve moves ──
  testWidgets(
      'typing 3.5 turns the figure white and the code grey; the code only '
      'shifts by the 34pt clear-button reserve', (tester) async {
    setSize(tester, const Size(390, 844));

    await openEdit(tester, store(), currencyDef('USD'));

    final dxEmpty =
        tester.getTopLeft(find.descendant(of: rateRow, matching: find.text('USD'))).dx;

    await tester.enterText(fieldIn('curRowRate'), '3.5');
    await tester.pumpAndSettle();

    expect(rateField(tester).style?.color, AppColors.textPrimary);
    expect(codeText(tester, 'USD').style?.color, AppColors.textSecondary);
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);

    // The figure sits in the flexible member, so its width never pushes the
    // code; the only motion on empty → filled is the 34pt reserve appearing
    // for the overlaid clear button (a designed exception to "nothing moves" —
    // see the task 060 report).
    final dxFilled =
        tester.getTopLeft(find.descendant(of: rateRow, matching: find.text('USD'))).dx;
    expect(dxEmpty - dxFilled, moreOrLessEquals(34, epsilon: 0.6));
  });

  // ── blur with an empty field returns to 0 + code ───────────────────────────
  testWidgets('blurring an empty unrated field returns to 0 + code',
      (tester) async {
    setSize(tester, const Size(390, 844));

    await openEdit(tester, store(), currencyDef('USD'));

    await tester.tap(rateRow);
    await tester.pumpAndSettle();
    tester.widget<EditableText>(fieldIn('curRowRate')).focusNode.unfocus();
    await tester.pumpAndSettle();

    expect(rateField(tester).decoration?.hintText, '0');
    expect(codeText(tester, 'USD').style?.color, AppColors.textTertiary);
    expect(find.text('Set rate'), findsNothing);
  });

  // ── §2 — add mode draws the partial code being typed ───────────────────────
  testWidgets('add mode: typing code ab shows 0 AB', (tester) async {
    setSize(tester, const Size(390, 844));

    await openAdd(tester, store(base: 'TMT'));

    await tester.enterText(fieldIn('curRowCode'), 'ab');
    await tester.pumpAndSettle();

    expect(rateField(tester).decoration?.hintText, '0');
    final code = codeText(tester, 'AB');
    expect(code.style?.color, AppColors.textTertiary);
  });

  // ── global boundary — the Currencies list keeps Set rate ───────────────────
  testWidgets('the Currencies list still shows Set rate for an in-use unrated '
      'currency', (tester) async {
    setSize(tester, const Size(390, 844));

    final s = store(base: 'TMT', accounts: [
      Account(
        id: 'a1',
        name: 'Card',
        group: AccountGroup.spendable,
        currency: 'USD', // in use, no rate stored
        startingBalance: 100,
      ),
    ]);

    await tester.pumpWidget(StoreScope(
      store: s,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TkMaterialLocalizationsDelegate(),
          TkCupertinoLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CurrencyManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Set rate'), findsOneWidget);
  });

  // ── §3 — the row is one height across all four states, both extremes ───────
  for (final (size, label) in const [
    (Size(390, 844), '390×844'),
    (Size(320, 568), '320×568'),
  ]) {
    testWidgets('row height is identical empty/focused/filled at $label',
        (tester) async {
      setSize(tester, size);

      await openEdit(tester, store(), currencyDef('USD'));

      // The nearest ancestor Container absorbs the focused outline's margin,
      // so its size is comparable across focus states (pad arithmetic: 12 =
      // 3 margin + 9 pad).
      double rowHeight() => tester
          .getSize(find.ancestor(of: rateRow, matching: find.byType(Container)).first)
          .height;

      final emptyUnfocused = rowHeight();

      await tester.tap(rateRow);
      await tester.pumpAndSettle();
      final emptyFocused = rowHeight();

      await tester.enterText(fieldIn('curRowRate'), '3.4965');
      await tester.pumpAndSettle();
      final filledFocused = rowHeight();

      tester.widget<EditableText>(fieldIn('curRowRate')).focusNode.unfocus();
      await tester.pumpAndSettle();
      final filledUnfocused = rowHeight();

      for (final h in [emptyFocused, filledFocused, filledUnfocused]) {
        expect(h, moreOrLessEquals(emptyUnfocused, epsilon: 1.0));
      }
      expect(tester.takeException(), isNull);
    });
  }

  // ── §3 — one line, no overflow, across the width/scale/code matrix ─────────
  for (final width in const [320.0, 360.0, 390.0]) {
    for (final scale in const [1.0, 1.3]) {
      for (final code in const ['USD', 'USDT']) {
        testWidgets(
            'no overflow, one line: ${width.toInt()}pt / '
            '${(scale * 100).toInt()}% / $code', (tester) async {
          setSize(tester, Size(width, 760));

          final def = code == 'USD'
              ? currencyDef('USD')
              : const CurrencyDef(
                  code: 'USDT',
                  name: 'Tether',
                  symbol: null,
                  decimals: 2,
                  symbolBefore: true,
                  custom: true);

          await openEdit(tester, store(), def, textScale: scale);
          expect(tester.takeException(), isNull);

          // Empty: label, 0 hint and code share the line; the flexible field
          // (the figure's slot) keeps a workable free width.
          final free = tester
              .getSize(find.descendant(
                  of: rateRow, matching: find.byType(TextField)))
              .width;
          expect(free, greaterThan(60),
              reason: 'free width for the figure at ${width.toInt()}pt/$scale');

          await tester.enterText(fieldIn('curRowRate'), '3.4965');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
