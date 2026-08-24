import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/same_transactions.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/theme/app_theme.dart';

Txn tx(String id, TxnType type, String from, String to,
        {DateTime? date, double amount = 10}) =>
    Txn(
      id: id,
      type: type,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: date ?? DateTime(2026, 8, 9),
    );

AppStore storeWith(List<Txn> txns) => AppStore(
      accounts: const <Account>[],
      categories: const <Category>[],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

Widget host(AppStore store, Widget child, {GlobalKey<NavigatorState>? navKey}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.dark,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // The row-tap wiring (a tap opens this read-only screen, never the editor —
  // spec §1) now lives on the Balance drill-down's LedgerTxnRow and is covered
  // by same_transactions_tap_test.dart. The screen's own behaviour is exercised
  // directly below.

  testWidgets('changing the range recomputes the summary (TOTAL) and list',
      (tester) async {
    // Two $10 expenses on one key, in different months. today = 9 Aug 2026.
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
      tx('b', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 6, 1)),
    ]);

    await tester
        .pumpWidget(host(store, const SameTransactionsScreen(originTxnId: 'a')));

    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.thisMonth));
    await tester.pumpAndSettle();
    // This month: only 'a' → TOTAL $10, so $20 is nowhere.
    expect(find.text('\$20'), findsNothing);

    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();
    // All time: both → TOTAL $20 (the summed metric, not a row amount).
    expect(find.text('\$20'), findsOneWidget);
  });

  testWidgets('a note-less expense row shows the account on line 1, never the '
      'category as a title (spec §4)', (tester) async {
    final store = AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Groceries')],
      txns: [
        tx('e1', TxnType.expense, 'a1', 'c1', date: DateTime(2026, 8, 5)),
      ],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(host(
        store, const SameTransactionsScreen(originTxnId: 'e1', showAll: true)));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    // The account leads line 1 — it appears exactly once (only in the row now
    // that the subtitle is just the direction word).
    expect(find.text('Main Checking'), findsOneWidget);
    // The category is the screen's heading, never repeated as a row title: a
    // note-less row that borrowed it would make this findsNWidgets(2).
    expect(find.text('Groceries'), findsOneWidget);
    // The subtitle is the direction alone (spec §6).
    expect(find.text('Expense'), findsOneWidget);
  });

  testWidgets('a transfer row carries no account line — only the header names '
      'the accounts (spec §4)', (tester) async {
    final store = AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Savings')],
      categories: const <Category>[],
      txns: [
        tx('t1', TxnType.transfer, 'a1', 'a2', date: DateTime(2026, 8, 5)),
      ],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(host(
        store, const SameTransactionsScreen(originTxnId: 't1', showAll: true)));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    // No bare account text anywhere: the path is one string in both the header
    // and the row, so a standalone account line would be the only source of it.
    expect(find.text('Main Checking'), findsNothing);
    expect(find.text('Savings'), findsNothing);
    // The "A → B" path appears in the header title and the row's own line.
    expect(find.text('Main Checking → Savings'), findsWidgets);
  });

  // Spec §5/§9 — the one-line stats band must fit at 320pt with four-digit
  // values, and must not clip at 130% text scale (it wraps/grows instead).
  AppStore band12() => AppStore(
        accounts: [_acc('a1', 'Main Checking')],
        categories: [_cat('c1', 'Groceries')],
        txns: [
          for (var i = 0; i < 12; i++)
            tx('e$i', TxnType.expense, 'a1', 'c1',
                date: DateTime(2026, 8, 1).add(Duration(days: i)), amount: 154),
        ],
        goals: const <Goal>[],
        tasks: const <Task>[],
      );

  testWidgets('stats band fits one line at 320pt with four-digit TOTAL',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = band12();
    await tester.pumpWidget(
        host(store, const SameTransactionsScreen(originTxnId: 'e0')));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // no RenderFlex overflow at 320pt
    // Each pair renders as one Text.rich (KEY value), so match the joined text.
    expect(find.text('TOTAL \$1,848'), findsOneWidget);
    expect(find.text('AVG \$154'), findsOneWidget);
    expect(find.text('COUNT 12'), findsOneWidget);
  });

  testWidgets('stats band does not clip at 320pt / 130% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = band12();
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const SameTransactionsScreen(originTxnId: 'e0'),
        ),
      ),
    ));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    // Nothing clips — the band grows from intrinsic height instead (spec §8).
    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL \$1,848'), findsOneWidget);
    expect(find.text('COUNT 12'), findsOneWidget);
  });

  // §5 — the frequency line reappears for a recent cluster in a long window.
  // Three expenses on 8–9 Aug (span 1 day) that the old span-based rule hid:
  // with the window as the denominator (Last 3 months, today 9 Aug → 70 days)
  // the honest rate is ~1/month, so the line renders.
  AppStore eatingOut() => AppStore(
        accounts: [_acc('a1', 'Main Checking')],
        categories: [_cat('c1', 'Eating out')],
        txns: [
          tx('e1', TxnType.expense, 'a1', 'c1', date: DateTime(2026, 8, 9)),
          tx('e2', TxnType.expense, 'a1', 'c1', date: DateTime(2026, 8, 9)),
          tx('e3', TxnType.expense, 'a1', 'c1', date: DateTime(2026, 8, 8)),
        ],
        goals: const <Goal>[],
        tasks: const <Task>[],
      );

  testWidgets('Eating out at Last 3 months renders the frequency line',
      (tester) async {
    final store = eatingOut();
    await tester.pumpWidget(
        host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.last3Months));
    await tester.pumpAndSettle();

    // The line renders (it was suppressed under the span-based denominator).
    expect(find.textContaining('a month'), findsOneWidget);
    expect(find.textContaining('last one today'), findsOneWidget);
  });

  testWidgets('a once-a-month rate reads the singular "time a month"',
      (tester) async {
    final store = eatingOut();
    await tester.pumpWidget(
        host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.last3Months));
    await tester.pumpAndSettle();

    // n == 1 → "About 1 time a month", never "times".
    expect(find.textContaining('time a month'), findsOneWidget);
    expect(find.textContaining('times a month'), findsNothing);
  });

  // ── Nav bar: the ••• must be right-aligned ─────────────────────────────────
  // The bar is Padding(fromLTRB(sm,sm,sm,0), child: SizedBox(height: 42, Row)).
  // The SizedBox spans the padded content width, so its right edge IS the bar's
  // right padding — the ••• should end flush against it.
  Finder navBar() =>
      find.byWidgetPredicate((w) => w is SizedBox && w.height == 42).first;
  Finder moreButton() =>
      find.widgetWithIcon(IconButton, Icons.more_horiz_rounded);

  testWidgets('the ••• sits flush with the nav bar right edge', (tester) async {
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
    ]);
    await tester.pumpWidget(host(store,
        const SameTransactionsScreen(originTxnId: 'a', backLabel: 'Ledger')));
    await tester.pumpAndSettle();

    final bar = tester.getRect(navBar());
    final more = tester.getRect(moreButton());
    expect((bar.right - more.right).abs(), lessThan(2),
        reason: "the ••• ink ends within 2px of the bar's right padding");
  });

  testWidgets('a long back label ellipsises and does not move the •••',
      (tester) async {
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
    ]);
    await tester.pumpWidget(host(
        store,
        const SameTransactionsScreen(
            originTxnId: 'a',
            backLabel: 'Cash (EUR Wallet) — a very long back label indeed')));
    await tester.pumpAndSettle();

    // No RenderFlex overflow: the bounded Align width lets the label ellipsise.
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(navBar());
    final more = tester.getRect(moreButton());
    expect((bar.right - more.right).abs(), lessThan(2),
        reason: 'the ••• stays at the edge regardless of label length');
  });

  testWidgets('tapping the empty middle of the nav bar does not pop',
      (tester) async {
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
    ]);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(host(store, const Scaffold(), navKey: navKey));
    navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const SameTransactionsScreen(
            originTxnId: 'a', backLabel: 'Ledger')));
    await tester.pumpAndSettle();
    expect(find.byType(SameTransactionsScreen), findsOneWidget);

    // The InkWell wraps only the back control; the Expanded's dead centre is
    // not a back button. Tapping it must leave the screen in place.
    await tester.tapAt(tester.getRect(navBar()).center);
    await tester.pumpAndSettle();
    expect(find.byType(SameTransactionsScreen), findsOneWidget);
  });

  testWidgets('deleting the originating transaction pops the screen',
      (tester) async {
    final store = storeWith([
      tx('a', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 8, 9)),
      tx('b', TxnType.expense, 'acc', 'cat', date: DateTime(2026, 7, 1)),
    ]);
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
        host(store, const Scaffold(), navKey: navKey));
    navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => const SameTransactionsScreen(originTxnId: 'a')));
    await tester.pumpAndSettle();
    expect(find.byType(SameTransactionsScreen), findsOneWidget);

    store.deleteTxn(store.txnById('a')!);
    await tester.pumpAndSettle();

    // With no subject left, the screen pops itself.
    expect(find.byType(SameTransactionsScreen), findsNothing);
  });
}
