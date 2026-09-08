import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// The account picker offers **one** create action, in **one** place.
///
/// It used to move: with accounts, `+ New account` sat in the header; with none,
/// the header action vanished and a 48pt filled button took its place in the
/// body. So the affordance jumped from the middle of the sheet to the top-right
/// corner the moment the first account existed, and changed shape and label on
/// the way. The category picker had it right all along — its `actions:` list is
/// unconditional and its empty body carries no button — and this is the account
/// picker matching it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  AppStore storeWith(int n) {
    final s = emptyStore();
    for (var i = 0; i < n; i++) {
      s.addAccount(
        name: 'Account $i',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100,
      );
    }
    return s;
  }

  Widget host(AppStore store, {double textScale = 1.0}) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pickAccount(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openPicker(WidgetTester tester, AppStore store,
      {double textScale = 1.0}) async {
    await tester.pumpWidget(host(store, textScale: textScale));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The header action, addressed by its visible text.
  Finder headerAction() => find.text('New');

  /// The [Semantics] widget wrapping [inner] — the configuration a reader is
  /// handed. Asserted at the widget rather than the compiled node because
  /// `find.bySemanticsLabel` does not reach the sheet's overlay route here.
  /// InkWell and friends contribute their own unlabelled [Semantics] wrappers,
  /// so take the nearest ancestor that actually carries a label.
  Semantics semanticsAround(WidgetTester tester, Finder inner) =>
      tester
          .widgetList<Semantics>(
            find.ancestor(of: inner, matching: find.byType(Semantics)),
          )
          .firstWhere((w) => w.properties.label != null);

  // ── The action is present in every state ───────────────────────────────────
  testWidgets('the header action is present with zero accounts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, emptyStore());

    expect(headerAction(), findsOneWidget,
        reason: 'this is the state where it used to disappear');
    expect(find.text('No accounts yet'), findsOneWidget,
        reason: 'the empty body still renders');
  });

  testWidgets('the header action is present with accounts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, storeWith(3));
    expect(headerAction(), findsOneWidget);
  });

  testWidgets('the header action survives a query that matches nothing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Ten accounts brings the search field out.
    await openPicker(tester, storeWith(12));
    await tester.enterText(find.byType(TextField).first, 'zzzznomatch');
    await tester.pumpAndSettle();

    expect(headerAction(), findsOneWidget);
  });

  testWidgets('excludeId hiding every account is still state 1, with the action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeWith(1);
    final only = store.snapshotAccounts.single.id;
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => pickAccount(context, excludeId: only),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(headerAction(), findsOneWidget,
        reason: 'it was absent here before — that was the bug');
  });

  testWidgets('a filter hiding every account keeps the action too',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(StoreScope(
      store: storeWith(3),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => pickAccount(context, filter: (_) => false),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(headerAction(), findsOneWidget);
  });

  // ── Tapping it from the empty state ────────────────────────────────────────
  testWidgets('tapping the header action with zero accounts opens New account',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, emptyStore());
    await tester.tap(headerAction());
    await tester.pumpAndSettle();

    // The New account sheet is over the picker.
    expect(find.text('New account'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ── The visible text and the spoken label differ ───────────────────────────
  // The one assertion that stops a future edit from collapsing the two again.
  testWidgets('it reads "New" but announces "New account"', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    await openPicker(tester, storeWith(2));

    expect(headerAction(), findsOneWidget, reason: 'the rendered Text is "New"');
    expect(find.text('New account'), findsNothing,
        reason: 'the long label is not drawn');

    // …but the semantics node carries the full name.
    final sem = semanticsAround(tester, headerAction());
    expect(sem.properties.button, isTrue);
    expect(sem.properties.label, 'New account',
        reason: 'a reader must still hear "New account"');
    // And the wrapper excludes its children, or the node would read
    // "New account / + / New".
    expect(sem.excludeSemantics, isTrue);
    handle.dispose();
  });

  testWidgets('the other pickers keep one string for both', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(StoreScope(
      store: emptyStore(),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(
              onPressed: () =>
                  pickCategory(context, type: CategoryType.expense),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // semanticsLabel is null here, so the fallback keeps them identical.
    expect(find.text('New'), findsOneWidget);
    expect(semanticsAround(tester, find.text('New')).properties.label, 'New');
    handle.dispose();
  });

  // ── The empty body carries no second control ───────────────────────────────
  testWidgets('the empty body contains no FilledButton', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, emptyStore());

    expect(find.byType(FilledButton), findsNothing,
        reason: 'the 48pt filled create button is gone');
    // And nothing was put in its place: heading + one caption line, no more.
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.textContaining('Tap'), findsNothing,
        reason: 'no pointer sentence was added');
  });

  testWidgets('the empty body keeps its header semantics node', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    await openPicker(tester, emptyStore());

    // This wrapper carries `header: true` and no label, so select on the flag.
    final header = tester
        .widgetList<Semantics>(find.ancestor(
          of: find.text('No accounts yet'),
          matching: find.byType(Semantics),
        ))
        .where((w) => w.properties.header == true);
    expect(header, isNotEmpty,
        reason: 'the empty body keeps its own Semantics(header: true) node');
    handle.dispose();
  });

  // ── The sheet shrinks, because it is contentSized ──────────────────────────
  testWidgets('the empty sheet is shorter than the populated one', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // One store, mutated between the two opens, so the sheet is rebuilt from
    // the same widget tree and only the account count differs.
    final store = emptyStore();
    await tester.pumpWidget(host(store));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The sheet is content-sized, so its top edge is how tall it is: the lower
    // the top, the shorter the sheet.
    final emptyTop = tester.getRect(find.text('Select account')).top;

    // Dismiss before re-opening, or the live sheet obscures the open button.
    Navigator.of(tester.element(find.text('Select account'))).pop();
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      store.addAccount(
        name: 'Account $i',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100,
      );
    }
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fullTop = tester.getRect(find.text('Select account')).top;

    expect(emptyTop, greaterThan(fullTop),
        reason: 'losing the 48pt button + Insets.xl shortens the empty sheet');
    debugPrint('SHEETTOP|empty=$emptyTop|populated=$fullTop');
  });

  // ── Contrast: the ink is the pale accent, on both glyphs ───────────────────
  testWidgets('the action renders accentLight, not accent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, storeWith(2));

    // accent #5E5CE6 measures 3.36:1 on the sheet's #1C1C1E ground — under AA's
    // 4.5:1 for 14.5pt text. accentLight measures 7.52:1.
    expect(tester.widget<Text>(find.text('New')).style!.color,
        AppColors.accentLight);
    expect(tester.widget<Text>(find.text('+')).style!.color,
        AppColors.accentLight);
  });

  // ── The 44pt tap target survives the 48pt button leaving ───────────────────
  testWidgets('the header action keeps a ≥44pt tap target', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openPicker(tester, emptyStore());

    final box = tester.getRect(find.ancestor(
      of: headerAction(),
      matching: find.byType(ConstrainedBox),
    ).first);
    expect(box.height, greaterThanOrEqualTo(44));
  });

  // ── 320pt / 130% in ru and tk: title + action + Cancel must fit ────────────
  for (final locale in const [Locale('ru'), Locale('tk')]) {
    testWidgets(
        'the header row fits at 320pt / 130% in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(StoreScope(
        store: storeWith(2),
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          // main.dart's list: flutter_localizations ships no Turkmen, so the tk
          // shims must precede the Global* delegates.
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
                onPressed: () => pickAccount(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'no overflow in the title / action / Cancel row');
    });
  }
}
