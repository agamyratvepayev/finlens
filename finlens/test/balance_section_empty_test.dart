import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/features/balance/balance_screen.dart'
    show BalanceScreen, BalanceSection;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/shared/widgets/section_header.dart'
    show SectionIndicator, HorizontalSectionSwipe;
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 009 — Balance's empty sections.
///
/// "Empty has causes, and they are different screens." A section that owns no
/// account of its kind ([SectionEmptyCause.noAccounts]) is a fact about the
/// user's money; a section whose accounts are all filter-hidden
/// ([SectionEmptyCause.allFiltered]) is a fact about their filter. Each gets its
/// own block, and neither shows a $0 hero for a total that means nothing.
void main() {
  // The store's fire-and-forget preference writes need a mock backing store.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// One asset account, no liabilities → LIABILITIES is section-empty.
  AppStore assetsOnlyStore() {
    final store = emptyStore();
    store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    return store;
  }

  /// One liability account, no assets → ASSETS is section-empty.
  AppStore liabilitiesOnlyStore({double balance = 100}) {
    final store = emptyStore();
    store.addAccount(
      name: 'Visa',
      group: AccountGroup.creditCards,
      currency: 'USD',
      startingBalance: balance, // held as -balance
    );
    return store;
  }

  /// One asset account with its whole group hidden → the section owns accounts
  /// but the filter leaves nothing visible: the all-filtered state.
  AppStore allFilteredStore() {
    final store = assetsOnlyStore();
    store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.spendable));
    return store;
  }

  const appDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    TkMaterialLocalizationsDelegate(),
    TkCupertinoLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  Widget host(AppStore store, Widget screen) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: appDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: screen),
        ),
      );

  /// Advance the section indicator from its default (All) to [target] by tapping
  /// the label — which also proves the indicator stays tappable while a pane
  /// sits behind the header.
  Future<void> toSection(WidgetTester tester, BalanceSection target) async {
    for (var i = 0; i < target.index; i++) {
      await tester.tap(find.byType(SectionIndicator));
      await tester.pumpAndSettle();
    }
  }

  // ── Section-empty: the two "no account of this kind" blocks ─────────────────

  testWidgets(
      'LIABILITIES with no liability account shows the No debts block and no '
      'hero, ratio or tool row', (tester) async {
    await tester.pumpWidget(host(assetsOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.liabilities);

    // The good-news block, naming the section, never the app.
    expect(find.text('No debts'), findsOneWidget);
    expect(find.text('Nothing to pay off right now.'), findsOneWidget);

    // No figure where nothing exists: no hero, and never a fabricated $0.
    expect(find.text('\$0'), findsNothing);
    // No tool row at all — nothing to sort, collapse, filter or search.
    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsNothing);

    // Row 1 survives: the label says where you are, the date and eye are shared
    // controls, the + is the only create affordance.
    expect(find.text('Liabilities'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets(
      'ASSETS with no asset account shows the Nothing here yet block, same '
      'chrome rules', (tester) async {
    await tester.pumpWidget(host(liabilitiesOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.assets);

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('Cash, bank, savings and valuables live in this section.'),
      findsOneWidget,
    );
    expect(find.text('\$0'), findsNothing);
    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsNothing);
    expect(find.text('Assets'), findsOneWidget); // the section label
  });

  // ── All-filtered: the one state with a way out ──────────────────────────────

  testWidgets(
      'all accounts hidden shows the All hidden block, a reduced tool row and '
      'the counter as prose in the block', (tester) async {
    await tester.pumpWidget(host(allFilteredStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('All hidden by the filter'), findsOneWidget);
    // The count rides in the block message (the header carries no counter).
    expect(find.text('1 account in this section is hidden.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Adjust filter'), findsOneWidget);

    // No hero, and the old per-section notice is gone.
    expect(find.text('\$0'), findsNothing);
    expect(find.text('No visible categories'), findsNothing);

    // Reduced tool row: filter (active) + search only.
    expect(find.byIcon(Icons.filter_alt_rounded), findsWidgets); // block + tool
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
    expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);
    expect(find.byIcon(Icons.unfold_less_rounded), findsNothing);
  });

  testWidgets('Adjust filter opens the filter sheet — the hit-test proof',
      (tester) async {
    await tester.pumpWidget(host(allFilteredStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // The button sits in a pane BEHIND the HitTestBehavior.opaque swipe layer.
    // Placed as the swipe's sibling it would render and do nothing; as a
    // descendant it takes the tap. This is the test that catches that mistake.
    await tester.tap(find.widgetWithText(TextButton, 'Adjust filter'));
    await tester.pumpAndSettle();

    // The shared account-filter sheet is up (its header action).
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('No visible categories appears nowhere', (tester) async {
    await tester.pumpWidget(host(allFilteredStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No visible categories'), findsNothing);
  });

  // ── The swipe still works from an empty section ─────────────────────────────

  testWidgets('a horizontal swipe out of an empty section changes section',
      (tester) async {
    await tester.pumpWidget(host(assetsOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.liabilities);
    expect(find.text('No debts'), findsOneWidget);

    // Leftward drag over the pane → advance (wraps liabilities → net worth). The
    // drag recognizer wins the arena even though the pane is behind the chrome.
    await tester.drag(
        find.byType(HorizontalSectionSwipe), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.text('No debts'), findsNothing);
    expect(find.text('Net worth'), findsOneWidget);
  });

  // ── Chrome on the populated screen is untouched ─────────────────────────────

  testWidgets('a populated section keeps its hero and all four tools',
      (tester) async {
    await tester.pumpWidget(host(assetsOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // NET WORTH, populated: the hero and every tool render as before.
    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text('\$100'), findsWidgets);
    expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget); // sort
    expect(find.byIcon(Icons.search_rounded), findsOneWidget); // search
    // The filter is off, so its outlined glyph shows.
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    // The Assets list section header still renders on the All view.
    expect(find.text('ASSETS'), findsOneWidget);
  });

  // ── The zero-liability colour fix (§5.1) ────────────────────────────────────

  Text hero(WidgetTester tester) => tester.widget<Text>(find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.style?.fontWeight == FontWeight.w700 &&
            (w.style?.fontSize ?? 0) >= 20 &&
            (w.data ?? '').contains(RegExp(r'\d')),
      ));

  testWidgets('a liability total of exactly zero renders neutral, not red',
      (tester) async {
    // A paid-off card: the section owns an account (so the hero renders) that
    // sums to exactly zero.
    await tester
        .pumpWidget(host(liabilitiesOnlyStore(balance: 0), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.liabilities);

    // Nothing owed is not an alarm — colour is good/bad, not a section badge.
    expect(hero(tester).style!.color, AppColors.textPrimary);
  });

  testWidgets('a non-zero liability total stays red', (tester) async {
    await tester
        .pumpWidget(host(liabilitiesOnlyStore(balance: 100), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.liabilities);

    expect(hero(tester).style!.color, AppColors.negative);
  });

  // ── One icon line across the three new blocks and a first-run reference ─────

  testWidgets(
      'the block icon lands on the same y as a first-run block for all three '
      'new states (390×844)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The block's backdrop glyph is 24pt; the reduced tool row's filter glyph is
    // 15pt, so a size-24 predicate targets the block, not the tool.
    double blockIcon(IconData icon) => tester
        .getCenter(find.byWidgetPredicate(
            (w) => w is Icon && w.icon == icon && w.size == 24))
        .dy;

    // Reference: the Ledger first-run icon, same viewport.
    await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
    await tester.pumpAndSettle();
    final ref = tester
        .getCenter(find.byWidgetPredicate((w) =>
            w is Icon && w.icon == Icons.receipt_long_rounded && w.size == 24))
        .dy;

    await tester.pumpWidget(host(assetsOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.liabilities);
    final noDebts = blockIcon(Icons.credit_card_off_rounded);

    await tester.pumpWidget(host(liabilitiesOnlyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    await toSection(tester, BalanceSection.assets);
    final noAssets = blockIcon(Icons.account_balance_wallet_rounded);

    await tester.pumpWidget(host(allFilteredStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    final allHidden = blockIcon(Icons.filter_alt_rounded);

    for (final e in <String, double>{
      'noDebts': noDebts,
      'noAssets': noAssets,
      'allHidden': allHidden,
    }.entries) {
      expect(e.value, moreOrLessEquals(ref, epsilon: 0.5),
          reason: '${e.key} icon centre ${e.value} ≠ ledger first-run $ref');
    }
  });

  // ── Layout sweep: the three states never overflow ───────────────────────────

  for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'no overflow in any empty state at ${size.width.toInt()}×'
          '${size.height.toInt()} / ${(scale * 100).toInt()}%', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(
            tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Section-empty (No debts).
        await tester.pumpWidget(host(assetsOnlyStore(), const BalanceScreen()));
        await tester.pumpAndSettle();
        await toSection(tester, BalanceSection.liabilities);
        expect(tester.takeException(), isNull, reason: 'No debts');

        // Section-empty (Nothing here yet).
        await tester
            .pumpWidget(host(liabilitiesOnlyStore(), const BalanceScreen()));
        await tester.pumpAndSettle();
        await toSection(tester, BalanceSection.assets);
        expect(tester.takeException(), isNull, reason: 'Nothing here yet');

        // All-filtered.
        await tester.pumpWidget(host(allFilteredStore(), const BalanceScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'All hidden');
      });
    }
  }
}
