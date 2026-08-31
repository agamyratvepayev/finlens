import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/main.dart';

/// First-run Balance: with no accounts the header goes quiet — only the
/// NET WORTH label, the +, a — hero and "Nothing recorded yet" survive. The
/// populated screen is covered elsewhere (balance_filter_ui_test.dart); here we
/// prove the empty screen offers one thing to do, not eight ways to sort
/// nothing.
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

    // The + is the only control that still does something, so it stays.
    // (Icons.add_rounded also backs the empty-state button, hence findsWidgets.)
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('empty store renders a — hero, never \$0', (tester) async {
    await tester.pumpWidget(FinLensApp(store: emptyStore()));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('\$0'), findsNothing);
    // The instruction under the hero replaces the historical "as of" slot.
    expect(find.text('Nothing recorded yet'), findsOneWidget);
  });

  testWidgets('adding the first account brings the tool row back',
      (tester) async {
    final store = emptyStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);

    store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    await tester.pumpAndSettle();

    // The header filled in: the tools are back, the — hero is gone.
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('accounts all hidden by a filter still render the full header',
      (tester) async {
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
      startingBalance: 100,
    );
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

  testWidgets('empty state does not overflow at 320pt in Turkish',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = emptyStore()..setLocale(const Locale('tr'));
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // A RenderFlex overflow throws during layout; takeException surfaces it.
    expect(tester.takeException(), isNull);
    // The Turkish first-run title is showing.
    expect(find.text('Elinizdekiyle başlayın'), findsOneWidget);
  });
}
