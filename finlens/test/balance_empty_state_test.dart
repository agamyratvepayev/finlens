import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/main.dart';

/// First-run Balance: with no accounts the header's three text slots go quiet —
/// no NET WORTH label, no — hero, no "Nothing recorded yet". Only the + stays,
/// unmoved. The empty state below states the benefit and offers a single
/// low-emphasis text action. The populated screen is covered elsewhere
/// (balance_filter_ui_test.dart); here we prove the empty screen offers one
/// thing to do, not eight ways to sort nothing.
void main() {
  // The store's fire-and-forget preference writes need a mock backing store.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  AppStore oneAccountStore({double balance = 100}) {
    final store = AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: balance,
    );
    return store;
  }

  // Icons that only appear when the full apparatus renders.
  final toolIcons = <IconData>[
    Icons.swap_vert_rounded, // sort
    Icons.unfold_more_rounded, // collapse-all (expand glyph)
    Icons.unfold_less_rounded,
    Icons.filter_alt_outlined, // filter
    Icons.filter_alt_rounded,
    Icons.search_rounded, // search
    Icons.visibility_rounded, // privacy eye
    Icons.visibility_off_rounded,
  ];

  testWidgets(
      'empty store hides date pill, eye, sort, collapse, filter and search; '
      'keeps the +', (tester) async {
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    // None of the tools are in the tree — absent, not disabled.
    for (final icon in toolIcons) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon should be absent');
    }
    // The date pill's "Today" label is gone too.
    expect(find.text('Today'), findsNothing);

    // The + is the only header control that survives, so it stays.
    // Two add glyphs now: the header's 22pt control, and the hint's inline 13pt
    // mark in the fourth row — the same pair the Ledger and the Planner have
    // always shown. The header one is what "keeps the +" is about.
    final addGlyphs = tester
        .widgetList<Icon>(find.byIcon(Icons.add_rounded))
        .map((i) => i.size)
        .toList();
    expect(addGlyphs, containsAll(<double>[22, 13]));
  });

  testWidgets(
      'empty store: the three header text slots are absent from the tree, not '
      'hidden', (tester) async {
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    // The NET WORTH label ("Net worth"), the — hero and the "Nothing recorded
    // yet" delta line all find nothing. This is the regression test: it is RED
    // against the previous build, which rendered all three.
    expect(find.text('Net worth'), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.text('Nothing recorded yet'), findsNothing);
    // And never a fabricated \$0.
    expect(find.text('\$0'), findsNothing);
  });

  testWidgets('empty store: the empty-state copy and action read correctly',
      (tester) async {
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    expect(find.text('Start with what you have'), findsOneWidget);
    expect(
      find.text('You never have to work out how much you actually have.'),
      findsOneWidget,
    );
    // The fourth row names what fills the screen, and Balance is filled by the
    // header + above it — the same sentence the Ledger and the Planner show.
    // It used to be an "Add an account" text button, a second create control
    // two rows under the + it duplicated.
    expect(find.textContaining('above'), findsOneWidget);
    expect(find.text('Add an account'), findsNothing);
  });

  testWidgets('empty store: the fourth row carries no create control at all',
      (tester) async {
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    // Neither a filled pill nor the low-emphasis text button it replaced: the
    // hint is a sentence, and the only create affordance is the header +.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('empty store: the + sits at the same coordinates as when '
      'populated', (tester) async {
    // The empty state also draws the hint's inline 13pt add mark, and `.first`
    // reaches that one — so address the header control by its 22pt glyph.
    Offset headerPlus(WidgetTester t) => t.getTopLeft(find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && w.size == 22));

    // Empty.
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();
    final emptyPlus = headerPlus(tester);

    // Populated (same viewport).
    await tester.pumpWidget(FinLensApp(store: oneAccountStore()));
    await tester.pumpAndSettle();
    final populatedPlus = headerPlus(tester);

    expect(emptyPlus, populatedPlus,
        reason: 'the + must not move between the two states');
  });

  testWidgets('mutual exclusion: header text and empty state are never both '
      'present', (tester) async {
    // Empty: empty state present, header text absent.
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();
    expect(find.text('Start with what you have'), findsOneWidget);
    expect(find.text('Net worth'), findsNothing);

    // Populated: header text present, empty state absent.
    await tester.pumpWidget(FinLensApp(store: oneAccountStore()));
    await tester.pumpAndSettle();
    expect(find.text('Start with what you have'), findsNothing);
    expect(find.text('Net worth'), findsOneWidget);
  });

  testWidgets('one account at \$0 renders the full header, not the empty state',
      (tester) async {
    await tester.pumpWidget(FinLensApp(store: oneAccountStore(balance: 0)));
    await tester.pumpAndSettle();

    // Zero is a figure the user put there; the full header renders it.
    expect(find.text('\$0'), findsWidgets);
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    expect(find.text('Start with what you have'), findsNothing);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('adding the first account fades the header text in with no '
      'exception', (tester) async {
    final store = emptyStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    expect(find.text('Net worth'), findsNothing);

    store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    // Past the 180ms cross-fade.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('deleting the last account returns to the zero-data screen',
      (tester) async {
    final store = oneAccountStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Net worth'), findsOneWidget);

    store.removeAccount(store.accounts.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Net worth'), findsNothing);
    expect(find.text('Start with what you have'), findsOneWidget);
  });

  testWidgets('accounts all hidden by a filter still render the full header',
      (tester) async {
    final store = oneAccountStore();
    // Hide the only group: accounts exist, so this is a filtered empty, not a
    // first run.
    store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.spendable));

    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Full header: the tools are the only way back.
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    // Not the first-run empty state.
    expect(find.text('Start with what you have'), findsNothing);
    expect(find.text('—'), findsNothing);
    // The filtered-away notice offers the way out.
    expect(find.text('No visible categories'), findsOneWidget);
  });

  testWidgets('two accounts summing to zero show \$0 and the full header — '
      'not a new user', (tester) async {
    final store = AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    store.addAccount(
      name: 'Cash',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    store.addAccount(
      name: 'Card',
      group: AccountGroup.creditCards,
      currency: 'USD',
      startingBalance: 100, // liability held as -100 → net worth 0
    );

    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Zero is the answer here, not a blank.
    expect(find.text('\$0'), findsWidgets);
    expect(find.text('—'), findsNothing);
    // Full header, not the first-run state.
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    expect(find.text('Start with what you have'), findsNothing);
  });

  for (final width in <double>[390, 360, 320]) {
    testWidgets('empty state does not overflow at ${width.toInt()}pt',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(FinLensApp(store: emptyStore()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Start with what you have'), findsOneWidget);
    });
  }

  testWidgets('empty state does not overflow at 320pt / 130% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final locale in <String>['tr', 'ru', 'tk']) {
    testWidgets('empty state does not overflow at 320pt in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = emptyStore()..setLocale(Locale(locale));
      await tester.pumpWidget(FinLensApp(store: store));
      await tester.pumpAndSettle();

      // A RenderFlex overflow throws during layout; takeException surfaces it.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty state Turkish title uses the formal register',
      (tester) async {
    final store = emptyStore()..setLocale(const Locale('tr'));
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Elinizdekiyle başlayın'), findsOneWidget);
    // The link this asserted is retired; the fourth row is the shared hint.
    expect(find.textContaining('ile başla'), findsOneWidget);
  });
}
