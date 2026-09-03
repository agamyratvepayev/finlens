import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/features/balance/balance_screen.dart';
import 'package:finlens/features/insight/insight_screen.dart';
import 'package:finlens/features/shell/app_shell.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/app_bottom_nav.dart';
import 'package:finlens/theme/app_theme.dart';

/// The empty and first-run states of Insight (empty-states spec §1–§6 / §11).
/// The order of §1, the four bodies, the header per state, the actions, the
/// no-opacity rule, and layout at every width × scale × locale.
void main() {
  final today = AppStore.today; // 2026-08-09

  // ── Fixtures ────────────────────────────────────────────────────────────────

  AppStore emptyStore() =>
      AppStore(accounts: [], categories: [], txns: [], goals: [], tasks: []);

  // State 2: accounts exist, nothing recorded. Three spendable accounts; the
  // first carries the whole standing balance so the holdings line reads a total.
  AppStore accountsNoTxns({double first = 12000}) {
    final s = emptyStore();
    s.addAccount(
        name: 'Cash',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: first);
    s.addAccount(
        name: 'Bank',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0);
    s.addAccount(
        name: 'Wallet',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0);
    return s;
  }

  // State 3: seed, every account hidden by the account filter.
  AppStore everythingHidden() {
    final s = buildSeedStore();
    var f = const BalanceFilter();
    for (final a in s.accounts) {
      f = f.toggleAccount(s, a);
    }
    s.setInsightAccountFilter(f);
    return s;
  }

  // A month window with no records anywhere near the seed's data.
  DateRange emptyMonth() =>
      RangePreset.thisMonth.resolve(today).copyShifted(-40);

  // §6: window August (has records in B), but B is hidden so the visible window
  // is empty while the unfiltered window is not.
  ({AppStore store, DateRange window}) emptyByFilter() {
    final cat = Category(
        id: 'c-food',
        name: 'Food',
        type: CategoryType.expense,
        icon: Icons.fastfood_rounded,
        color: Colors.red);
    final s = AppStore(
        accounts: [], categories: [cat], txns: [], goals: [], tasks: []);
    final a = s.addAccount(
        name: 'Visible',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100);
    final b = s.addAccount(
        name: 'Hidden',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100);
    // One expense from B inside the August window — the record the filter hides.
    s.addTxn(
        type: TxnType.expense,
        amount: 50,
        currency: 'USD',
        fromRef: b.id,
        toRef: cat.id,
        date: DateTime(2026, 8, 5));
    // A record from the visible account in July, so the back link has a
    // destination the reader can actually see.
    s.addTxn(
        type: TxnType.expense,
        amount: 20,
        currency: 'USD',
        fromRef: a.id,
        toRef: cat.id,
        date: DateTime(2026, 7, 5));
    // Hide B; A stays visible but has no records in the window.
    s.setInsightAccountFilter(
        const BalanceFilter().toggleAccount(s, b));
    // Sanity: A is still visible, so this is state 4 (§6), not state 3.
    expect(s.insightAccountFilter.visibleAccountIds(s), contains(a.id));
    return (store: s, window: RangePreset.thisMonth.resolve(today));
  }

  // ── Widget harness (mirrors insight_layout_test) ────────────────────────────

  Widget app(
    AppStore store, {
    Locale locale = const Locale('en'),
    double scale = 1.0,
    Size size = const Size(390, 844),
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(body: InsightScreen()),
            ),
          ),
        ),
      );

  // ── Unit — the §1 ordering ──────────────────────────────────────────────────
  group('insightEmptyState — §1 ordering', () {
    test('stops at the first matching cause', () {
      expect(
          insightEmptyState(
              noAccounts: true,
              noRecords: true,
              everythingHidden: true,
              windowEmptyForVisible: true),
          InsightEmpty.noAccounts);
      expect(
          insightEmptyState(
              noAccounts: false,
              noRecords: true,
              everythingHidden: true,
              windowEmptyForVisible: true),
          InsightEmpty.noRecords);
      expect(
          insightEmptyState(
              noAccounts: false,
              noRecords: false,
              everythingHidden: true,
              windowEmptyForVisible: true),
          InsightEmpty.allHidden);
      expect(
          insightEmptyState(
              noAccounts: false,
              noRecords: false,
              everythingHidden: false,
              windowEmptyForVisible: true),
          InsightEmpty.emptyWindow);
      expect(
          insightEmptyState(
              noAccounts: false,
              noRecords: false,
              everythingHidden: false,
              windowEmptyForVisible: false),
          InsightEmpty.none);
    });

    test('no accounts wins even with a stale filter set', () {
      // A reader with no accounts cannot have a filter problem.
      expect(
          insightEmptyState(
              noAccounts: true,
              noRecords: true,
              everythingHidden: true,
              windowEmptyForVisible: true),
          InsightEmpty.noAccounts);
    });
  });

  // ── Unit — nearestWindowWithRecords (unfiltered) ────────────────────────────
  group('nearestWindowWithRecords — unfiltered', () {
    // A store with a single expense on the given day, spendable→food.
    AppStore oneTxnOn(DateTime day) {
      final cat = Category(
          id: 'c-food',
          name: 'Food',
          type: CategoryType.expense,
          icon: Icons.fastfood_rounded,
          color: Colors.red);
      final s = AppStore(
          accounts: [], categories: [cat], txns: [], goals: [], tasks: []);
      final a = s.addAccount(
          name: 'A',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 100);
      s.addTxn(
          type: TxnType.expense,
          amount: 10,
          currency: 'USD',
          fromRef: a.id,
          toRef: cat.id,
          date: day);
      return s;
    }

    DateRange monthOf(int y, int m) =>
        DateRange(DateTime(y, m, 1), DateTime(y, m + 1, 0, 23, 59, 59, 999),
            preset: RangePreset.thisMonth);

    test('a backwards hit is found', () {
      final s = oneTxnOn(DateTime(2026, 5, 10)); // May
      final from = monthOf(2026, 8); // August, empty
      final r = s.nearestWindowWithRecords(from);
      expect(r, isNotNull);
      expect(r!.start.month, 5);
      expect(r.start.isBefore(from.start), isTrue); // past → ←
    });

    test('a forwards-only hit is found when data is entirely later', () {
      final s = oneTxnOn(DateTime(2026, 8, 10)); // August
      final from = monthOf(2026, 5); // May, empty, precedes all data
      final r = s.nearestWindowWithRecords(from);
      expect(r, isNotNull);
      expect(r!.start.month, 8);
      expect(r.start.isAfter(from.start), isTrue); // future → →
    });

    test('null on an empty ledger, and it terminates', () {
      final s = emptyStore();
      expect(s.nearestWindowWithRecords(monthOf(2026, 8)), isNull);
    });

    test('skips two empty neighbours to reach the third', () {
      final s = oneTxnOn(DateTime(2026, 5, 10)); // May
      // From August: Jul empty, Jun empty, May has data — one call, three steps.
      final r = s.nearestWindowWithRecords(monthOf(2026, 8));
      expect(r, isNotNull);
      expect(r!.start.month, 5);
    });
  });

  // ── Unit — nearestWindowWithRecords (filtered) ──────────────────────────────
  test('nearestWindowWithRecords ignores a hidden-account period', () {
    final cat = Category(
        id: 'c-food',
        name: 'Food',
        type: CategoryType.expense,
        icon: Icons.fastfood_rounded,
        color: Colors.red);
    final s = AppStore(
        accounts: [], categories: [cat], txns: [], goals: [], tasks: []);
    final a = s.addAccount(
        name: 'A',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100);
    final b = s.addAccount(
        name: 'B',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 100);
    // May: only B (hidden). March: A (visible).
    s.addTxn(
        type: TxnType.expense,
        amount: 10,
        currency: 'USD',
        fromRef: b.id,
        toRef: cat.id,
        date: DateTime(2026, 5, 10));
    s.addTxn(
        type: TxnType.expense,
        amount: 10,
        currency: 'USD',
        fromRef: a.id,
        toRef: cat.id,
        date: DateTime(2026, 3, 10));

    final from = DateRange(
        DateTime(2026, 8, 1), DateTime(2026, 8, 31, 23, 59, 59, 999),
        preset: RangePreset.thisMonth);
    final visible = {a.id};
    final r = s.nearestWindowWithRecords(from, visible: visible);
    expect(r, isNotNull);
    // May is hidden-only, so the search skips it and lands on March.
    expect(r!.start.month, 3);
  });

  // ── Widget — state selection & header buttons ───────────────────────────────
  group('state selection and header buttons', () {
    Future<void> pump(WidgetTester tester, AppStore store) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));
    }

    bool hasFilter() =>
        find.byIcon(Icons.filter_alt_outlined).evaluate().isNotEmpty ||
        find.byIcon(Icons.filter_alt_rounded).evaluate().isNotEmpty;
    bool hasEye() =>
        find.byIcon(Icons.visibility_rounded).evaluate().isNotEmpty ||
        find.byIcon(Icons.visibility_off_rounded).evaluate().isNotEmpty;
    bool hasAdd() => find.byIcon(Icons.add_rounded).evaluate().isNotEmpty;

    testWidgets('state 1 — no accounts: no header, intro body, Balance signpost',
        (tester) async {
      await pump(tester, emptyStore());
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.insEmptyNoAccountsTitle), findsOneWidget);
      // The header is absent entirely — no filter, eye, add, or window chevron.
      expect(hasFilter(), isFalse);
      expect(hasEye(), isFalse);
      expect(hasAdd(), isFalse);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      // No creation action; the signpost points to Balance.
      expect(find.text(l.moreAddAccount), findsNothing);
      expect(find.text(l.insStartInBalance), findsOneWidget);
    });

    testWidgets('state 2 — no records: same body, no header, Ledger signpost',
        (tester) async {
      await pump(tester, accountsNoTxns());
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // States 1 and 2 share one body — same title, no hero/holdings line.
      expect(find.text(l.insEmptyNoAccountsTitle), findsOneWidget);
      expect(find.textContaining('3 accounts'), findsNothing);
      // Still no records → the whole header is gone, eye included (§1).
      expect(hasFilter(), isFalse);
      expect(hasEye(), isFalse);
      expect(hasAdd(), isFalse);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      // Accounts exist, so the signpost points to Ledger.
      expect(find.text(l.insStartInLedger), findsOneWidget);
    });

    testWidgets('state 3 — everything hidden: filter filled, no add',
        (tester) async {
      await pump(tester, everythingHidden());
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.insEmptyAllHiddenTitle), findsOneWidget);
      // The active glyph is the filled variant.
      expect(find.byIcon(Icons.filter_alt_rounded), findsOneWidget);
      expect(hasEye(), isTrue);
      expect(hasAdd(), isFalse);
      expect(find.text(l.insEmptyShowAll), findsOneWidget);
    });

    testWidgets('state 4 — empty window: names the window and its destination',
        (tester) async {
      final s = buildSeedStore()..setInsightWindow(emptyMonth());
      await pump(tester, s);
      expect(find.textContaining('No records in'), findsOneWidget);
      expect(find.textContaining('Go to'), findsOneWidget);
      expect(hasFilter(), isTrue);
      expect(hasEye(), isTrue);
      expect(hasAdd(), isFalse);
    });

    testWidgets('the + appears in no state', (tester) async {
      for (final store in <AppStore>[
        emptyStore(),
        accountsNoTxns(),
        everythingHidden(),
        buildSeedStore()..setInsightWindow(emptyMonth()),
        buildSeedStore(), // populated
      ]) {
        await pump(tester, store);
        expect(hasAdd(), isFalse);
      }
    });

    testWidgets('no records → no header children; one record → window+filter+eye',
        (tester) async {
      // No records: header absent, so no window chevron, filter or eye.
      await pump(tester, accountsNoTxns());
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(hasFilter(), isFalse);
      expect(hasEye(), isFalse);

      // A populated store restores the full header.
      await pump(tester, buildSeedStore());
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(hasFilter(), isTrue);
      expect(hasEye(), isTrue);
      expect(hasAdd(), isFalse);
    });

    testWidgets('no accounts wins even with a stale filter (ordering)',
        (tester) async {
      // A store with no accounts but a non-empty filter still shows state 1.
      final s = emptyStore();
      s.setInsightAccountFilter(
          const BalanceFilter(hiddenAccountIds: {'ghost'}));
      await pump(tester, s);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l.insEmptyNoAccountsTitle), findsOneWidget);
    });
  });

  // ── Widget — the §6 filter sub-case ─────────────────────────────────────────
  testWidgets('empty-by-filter shows the hidden count and both actions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final f = emptyByFilter();
    await tester.pumpWidget(app(f.store..setInsightWindow(f.window)));
    await tester.pump(const Duration(milliseconds: 300));

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.textContaining('No records in'), findsOneWidget);
    // Second line: the hidden count.
    expect(find.text(l.insEmptyHiddenByFilter(1)), findsOneWidget);
    // Both actions.
    expect(find.text(l.insEmptyShowAll), findsOneWidget);
    expect(find.textContaining('Go to'), findsOneWidget);
  });

  // ── Widget — the actions ────────────────────────────────────────────────────
  group('actions', () {
    testWidgets('Show all accounts clears the account filter only',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = everythingHidden();
      // A category filter is also set, to prove it is left untouched.
      store.setInsightCategoryFilter({'c-groceries'});
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l.insEmptyShowAll));
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.insightAccountFilter.isActive, isFalse);
      expect(store.insightCategoryFilter, contains('c-groceries'));
    });

    testWidgets('the link sets insightWindow and leaves store.period alone',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = buildSeedStore()..setInsightWindow(emptyMonth());
      final period0 = store.period;
      final window0 = store.insightWindow;
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.textContaining('Go to'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.insightWindow, isNot(window0),
          reason: 'the window moved to the nearest data');
      expect(store.period, period0, reason: 'store.period must not move');
      // The destination is no longer empty for the reader.
      expect(store.txnsInWindow(store.insightWindow), isNotEmpty);
    });
  });

  // ── Widget — the signpost link (spec §4) ────────────────────────────────────
  group('signpost link', () {
    // Wraps InsightScreen in an AppShellScope that records goToTab calls.
    Widget scoped(AppStore store, void Function(NavTab) onGo) => StoreScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark,
            home: Scaffold(
              body: AppShellScope(goToTab: onGo, child: const InsightScreen()),
            ),
          ),
        );

    testWidgets('no accounts → Balance; accounts but no records → Ledger',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      NavTab? got;
      await tester.pumpWidget(scoped(emptyStore(), (t) => got = t));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(l.insStartInBalance));
      expect(got, NavTab.balance);

      got = null;
      await tester.pumpWidget(scoped(accountsNoTxns(), (t) => got = t));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(l.insStartInLedger));
      expect(got, NavTab.ledger);
    });

    testWidgets('through the real shell it switches tab without scroll-to-top',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Accounts but no records → state 2, so the signpost is present and every
      // shell screen still has data to build.
      await tester.pumpWidget(StoreScope(
        store: accountsNoTxns(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: const AppShell(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      // Move to Insight via the bottom nav (a genuine tab change).
      await tester.tap(find.text(l.navInsight));
      await tester.pump(const Duration(milliseconds: 300));

      int signal() =>
          tester.widget<BalanceScreen>(find.byType(BalanceScreen)).scrollToTopSignal;
      final before = signal();

      await tester.tap(find.text(l.insStartInLedger));
      await tester.pump(const Duration(milliseconds: 300));

      // The scroll-to-top signal Balance carries is untouched — goToTab is a
      // plain tab change, not a re-tap.
      expect(signal(), before,
          reason: 'goToTab must not bump the scroll-to-top signal');
    });

    testWidgets('the empty block exposes exactly one button node',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(app(emptyStore()));
      await tester.pump(const Duration(milliseconds: 300));
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      // Exactly one node in the block declares button semantics — the signpost.
      final buttons = find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.button ?? false));
      expect(buttons, findsOneWidget);
      // And that one wraps the link itself.
      expect(find.descendant(of: buttons, matching: find.text(l.insStartInBalance)),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('scrolls and stays hit-testable at 130% on 320×568',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          app(emptyStore(), scale: 1.3, size: const Size(320, 568)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final l = await AppLocalizations.delegate.load(const Locale('en'));
      final link = find.text(l.insStartInBalance);
      expect(link, findsOneWidget);
      await tester.ensureVisible(link);
      await tester.tap(link); // no AppShellScope here → a safe no-op
    });

    testWidgets('no header → the body starts at the top (no reserved gap)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(emptyStore()));
      await tester.pump(const Duration(milliseconds: 300));

      // The scaffold's scroll view fills the body from y=0 (the SafeArea top
      // inset is 0 in this view); a phantom header row would push it down.
      final top = tester.getTopLeft(find.byType(SingleChildScrollView)).dy;
      expect(top, 0);
    });
  });

  // ── Widget — no opacity on text anywhere in the empty bodies ─────────────────
  testWidgets('no Opacity widget in any empty state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final store in <AppStore>[
      emptyStore(),
      accountsNoTxns(),
      everythingHidden(),
      buildSeedStore()..setInsightWindow(emptyMonth()),
    ]) {
      await tester.pumpWidget(app(store));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Opacity), findsNothing);
    }
  });

  // ── Widget — layout at every width × scale × locale ─────────────────────────
  const sizes = <String, Size>{
    '390x844': Size(390, 844),
    '360x640': Size(360, 640),
    '320x568': Size(320, 568),
  };

  final fixtures = <String, AppStore Function()>{
    'noAccounts': emptyStore,
    'noRecords': accountsNoTxns,
    'allHidden': everythingHidden,
    'emptyWindow': () => buildSeedStore()..setInsightWindow(emptyMonth()),
  };

  for (final fx in fixtures.entries) {
    for (final size in sizes.entries) {
      for (final scale in const [1.0, 1.3]) {
        for (final locale in const [Locale('en'), Locale('ru')]) {
          testWidgets(
              '${fx.key} lays out at ${size.key} · ${scale}x · ${locale.languageCode}',
              (tester) async {
            tester.view.physicalSize = size.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
                app(fx.value(), locale: locale, scale: scale, size: size.value));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
