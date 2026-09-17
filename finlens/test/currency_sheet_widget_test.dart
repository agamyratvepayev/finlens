import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_theme.dart';

/// The Add/Edit currency sheet's four defects (spec §3) and its two modes.
///
/// §3a in particular passed unnoticed for as long as it did because nothing
/// asserted a divider was ever *drawn*: `_hair()` is a `height: 1` box with no
/// width, correct between stacked rows and invisible inside a `Row`, so the
/// layout comment described a rule that never painted.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore emptyStore() => AppStore(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)), 
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Widget host(AppStore store, Widget Function(BuildContext) onReady) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Builder(builder: onReady)),
        ),
      );

  /// Opens the sheet from a tap so it gets a real route, as in the app.
  Future<void> openAdd(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(host(
      store,
      (context) => TextButton(
        onPressed: () => showAddCurrencySheet(context),
        child: const Text('open'),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openEdit(
      WidgetTester tester, AppStore store, CurrencyDef def) async {
    await tester.pumpWidget(host(
      store,
      (context) => TextButton(
        onPressed: () => showEditCurrencySheet(context, def),
        child: const Text('open'),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Every vertical rule painted inside the sheet: a 1pt-wide, non-zero-height
  /// box. A `_hair()` misused inside a Row would have width 0 and match nothing.
  List<Size> verticalRules(WidgetTester tester) {
    final out = <Size>[];
    for (final e in find.byType(Container).evaluate()) {
      final size = (e.renderObject as RenderBox?)?.size;
      if (size == null) continue;
      if (size.width == 1 && size.height > 1) out.add(size);
    }
    return out;
  }

  // ── task 033 §2 — the side-by-side pairs (and their vertical rules) are gone ─
  // Code/Name and Symbol/Position used to sit two-abreast, separated by a
  // vertical hairline. Task 033 stacks every row single-file, so there is no
  // vertical rule left to draw — the format card is a plain column of rows.
  testWidgets('the format card stacks single rows — no vertical rules',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());

    expect(verticalRules(tester), isEmpty,
        reason: 'the paired side-by-side layout retired with the split branch');
  });

  // ── §3b — the truncating switch is gone, replaced by Before | After ────────
  testWidgets('Position is a two-option segmented control, not a switch',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());

    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.byType(Switch), findsNothing,
        reason: 'the switch retired with its truncating label');
    expect(find.textContaining('Before amount'), findsNothing);
  });

  testWidgets('tapping After flips the preview to a trailing token',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());
    await tester.enterText(find.byType(TextField).first, 'TMT');
    await tester.pumpAndSettle();

    // Symbol left empty → the token falls back to the code and takes a space.
    expect(find.text('TMT\u00A09,850.00'), findsOneWidget);

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    expect(find.text('9,850.00\u00A0TMT'), findsOneWidget,
        reason: 'exactly what the Turkmenistan user asked for');
  });

  // ── §6 — the sheet fits at 320pt / 130% in every locale ────────────────────
  // Task 033 dropped the split-at-large-scale layout (the rows are single-file
  // now) and sets the supported ceiling at 130% per its acceptance list; the
  // old 200% target belonged to the paired layout that no longer exists.
  for (final locale in const [
    Locale('en'),
    Locale('ru'),
    Locale('tr'),
    Locale('tk')
  ]) {
    testWidgets(
        'the sheet does not overflow at 320×568 / 130% in '
        '${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(StoreScope(
        store: emptyStore(),
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          // Exactly main.dart's list: flutter_localizations ships no Turkmen, so
          // the tk shims must precede the Global* delegates or a Material widget
          // under tk throws "No MaterialLocalizations found".
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
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
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

      expect(tester.takeException(), isNull);
    });
  }

  // ── §3c — FormRow right-aligns a short value ──────────────────────────────
  testWidgets('FormRow\'s value reaches the right edge, not the midpoint',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(
        body: SizedBox(
          width: 300,
          child: FormRow(label: 'Decimal places', value: '2'),
        ),
      ),
    ));

    final row = tester.getRect(find.byType(FormRow));
    final value = tester.getRect(find.text('2'));
    // Insets.md = 12 of horizontal padding on the row.
    expect(value.right, moreOrLessEquals(row.right - 12, epsilon: 1.0),
        reason: 'a short value used to sit at the card midpoint');
    expect(value.right, greaterThan(row.center.dx + 100),
        reason: 'nowhere near the 50% mark');
  });

  // ── §2 — the two modes ─────────────────────────────────────────────────────
  testWidgets('edit mode shows the values and locks code & name as FormRows',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openEdit(tester, emptyStore(), currencyDef('TMT'));

    expect(find.text('Edit currency'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Add currency'), findsNothing);

    // Task 033 §2: a locked field is a plain FormRow with a value, not an
    // editable-but-read-only TextField. Code and Name both show their value and
    // both carry the padlock FormRow draws.
    expect(find.text('TMT'), findsWidgets, reason: 'code shown as a value');
    expect(find.text('Turkmen Manat'), findsWidgets);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2),
        reason: 'code and name are both locked ISO facts');

    // Neither the code nor the name is a TextField any more — they cannot be
    // typed into at all.
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(f.controller?.text == 'TMT' && f.readOnly == false, isFalse);
    }
  });

  testWidgets('add mode keeps its own title, button and editable code',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());

    expect(find.text('Add a currency'), findsOneWidget);
    expect(find.text('Add currency'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly, isFalse);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('an overridden built-in offers Reset to default, not Delete',
      (tester) async {
    // Tall enough that the whole sheet builds, so the destructive action at its
    // foot needs no scrolling to assert on.
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = emptyStore();
    store.updateCustomCurrency(
        const CurrencyDef(code: 'TMT', name: 'Turkmen Manat'));

    await openEdit(tester, store, currencyDef('TMT'));

    expect(find.text('Reset to default'), findsOneWidget,
        reason: 'dropping an override is not a delete');
    expect(find.text('Delete currency'), findsNothing);
  });

  testWidgets('a custom currency offers Delete, not Reset', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = emptyStore();
    store.addCustomCurrency(
        const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));

    await openEdit(tester, store, currencyDef('ZZZ'));

    expect(find.text('Delete currency'), findsOneWidget);
    expect(find.text('Reset to default'), findsNothing,
        reason: 'there is no built-in behind it to fall back to');
  });

  testWidgets('deleting a custom currency in use is blocked, and the block '
      'names the account', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = emptyStore();
    store.addCustomCurrency(
        const CurrencyDef(code: 'ZZZ', name: 'Zed', custom: true));
    store.addAccount(
      name: 'Cash box',
      group: AccountGroup.spendable,
      currency: 'ZZZ',
      startingBalance: 10,
    );

    await openEdit(tester, store, currencyDef('ZZZ'));
    await tester.tap(find.text('Delete currency'));
    await tester.pumpAndSettle();

    // Named, not cascaded — and it says the one thing to do first.
    expect(find.textContaining('Can’t delete'), findsOneWidget);
    expect(find.textContaining('Cash box'), findsOneWidget);
    expect(find.textContaining('Move that account'), findsOneWidget);

    // Nothing was removed.
    expect(store.snapshotCustomCurrencies.any((c) => c.code == 'ZZZ'), isTrue);
    expect(store.accountsUsingCurrency('ZZZ'), hasLength(1));
  });

  testWidgets('the create path still refuses a duplicate code', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openAdd(tester, emptyStore());
    await tester.enterText(find.byType(TextField).first, 'USD');
    await tester.pumpAndSettle();

    expect(find.text('This code is already in use.'), findsOneWidget);
  });

  testWidgets('editing a built-in does not report its own code as duplicate',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openEdit(tester, emptyStore(), currencyDef('TMT'));
    expect(find.text('This code is already in use.'), findsNothing,
        reason: 'an override must reuse the built-in code');
    expect(find.text('Save changes'), findsOneWidget);
  });
}
