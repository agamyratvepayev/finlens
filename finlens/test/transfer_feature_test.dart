import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/transfer_detail_screen.dart';
import 'package:finlens/theme/app_theme.dart';

/// Spec §2–§5 invariants for transfers. The day-total assertions avoid the
/// prompt's worked figure ($522), whose arithmetic references the full seed
/// fixture; instead they assert the *guarantee* directly on a synthetic day:
/// a transfer adds nothing to the net yet still counts as a row.
Account _acc(String id, String name,
        {AccountGroup group = AccountGroup.spendable,
        String currency = 'USD',
        double start = 1000}) =>
    Account(
      id: id,
      name: name,
      group: group,
      currency: currency,
      startingBalance: start,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: Colors.orange,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Savings')],
      categories: [_cat('c1', 'Groceries')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(theme: AppTheme.dark, home: child),
    );

void main() {
  group('§4 — a transfer contributes 0 to the day total but still counts', () {
    test('day total excludes the transfer; the row count still includes it', () {
      final store = _store();
      final day = DateTime(2026, 8, 10);
      for (final a in const [240.0, 130.0, 54.0]) {
        store.addTxn(
          type: TxnType.expense,
          amount: a,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'c1',
          date: day,
        );
      }
      store.addTxn(
        type: TxnType.transfer,
        amount: 200,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'a2',
        date: day,
      );

      final q = LedgerQuery(
        store: store,
        scope: const AllAccountsScope(),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59),
      );
      final group = DayGroup(date: day, rows: q.rows());

      expect(group.rows.length, 4, reason: 'the transfer is one of four rows');
      // 240 + 130 + 54 = 424 out; the transfer adds nothing.
      expect(group.total, -424);
      expect(group.showsDayTotal, isTrue,
          reason: 'four rows clear the count threshold');
    });

    test('a day whose only row is an internal transfer shows no total', () {
      final store = _store();
      final day = DateTime(2026, 8, 11);
      store.addTxn(
        type: TxnType.transfer,
        amount: 300,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'a2',
        date: day,
      );
      final q = LedgerQuery(
        store: store,
        scope: const AllAccountsScope(),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59),
      );
      final group = DayGroup(date: day, rows: q.rows());
      expect(group.rows.length, 1);
      expect(group.total, 0);
      expect(group.showsDayTotal, isFalse);
    });
  });

  group('§1 — one event, one row', () {
    test('a transfer is a single record and resolves to a single row', () {
      final store = _store();
      final t = store.addTxn(
        type: TxnType.transfer,
        amount: 500,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'a2',
        date: DateTime(2026, 8, 5),
      );
      final q = LedgerQuery(
        store: store,
        scope: const AllAccountsScope(),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59),
      );
      final rowsForT = q.rows().where((r) => r.txn.id == t.id).toList();
      expect(rowsForT.length, 1, reason: 'no de-duplication needed — one record');
    });
  });

  group('§6 — cross-currency keeps each leg in its own currency and a rate', () {
    test('the source and destination amounts and the rate are all preserved',
        () {
      final store = AppStore(
        accounts: [
          _acc('u', 'USD Account', currency: 'USD'),
          _acc('e', 'EUR Account', currency: 'EUR'),
        ],
        categories: const <Category>[],
        txns: const <Txn>[],
        goals: const <Goal>[],
        tasks: const <Task>[],
      );
      final t = store.addTxn(
        type: TxnType.transfer,
        amount: 100, // source: 100 USD
        currency: 'USD',
        fromRef: 'u',
        toRef: 'e',
        date: DateTime(2026, 8, 6),
        toAmount: 91, // destination: 91 EUR
        exchangeRate: 0.91,
      );
      expect(t.currency, 'USD');
      expect(t.amount, 100);
      expect(t.toAmount, 91);
      expect(t.exchangeRate, 0.91);
    });
  });

  group('§5 — read-only transfer detail', () {
    testWidgets('shows both accounts, both signed legs, and Net worth Unchanged',
        (tester) async {
      final store = _store();
      final t = store.addTxn(
        type: TxnType.transfer,
        amount: 500,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'a2',
        date: DateTime(2026, 8, 5),
      );

      await tester.pumpWidget(
        _host(store, TransferDetailScreen(txnId: t.id, backLabel: 'Ledger')),
      );
      await tester.pumpAndSettle();

      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('TO'), findsOneWidget);
      expect(find.text('Main Checking'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      // Signs appear here and only here (true U+2212 minus / plus).
      expect(find.text('−\$500'), findsOneWidget);
      expect(find.text('+\$500'), findsOneWidget);
      expect(find.text('Unchanged'), findsOneWidget);
      // The hero carries no "Transfer" label — the glyph says it.
      expect(find.text('Transfer'), findsNothing);
    });
  });

  // The bar is Padding(fromLTRB(sm,sm,sm,0), child: SizedBox(height: 42, Row));
  // the SizedBox spans the padded content width, so its right edge is the bar's
  // right padding — the ••• should end flush against it, not float in.
  group('nav bar — the ••• is right-aligned', () {
    Finder navBar() =>
        find.byWidgetPredicate((w) => w is SizedBox && w.height == 42).first;
    Finder moreButton() =>
        find.widgetWithIcon(IconButton, Icons.more_horiz_rounded);

    Txn seedTransfer(AppStore store) => store.addTxn(
          type: TxnType.transfer,
          amount: 500,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'a2',
          date: DateTime(2026, 8, 5),
        );

    testWidgets('the ••• sits flush with the nav bar right edge',
        (tester) async {
      final store = _store();
      final t = seedTransfer(store);
      await tester.pumpWidget(
          _host(store, TransferDetailScreen(txnId: t.id, backLabel: 'Ledger')));
      await tester.pumpAndSettle();

      final bar = tester.getRect(navBar());
      final more = tester.getRect(moreButton());
      expect((bar.right - more.right).abs(), lessThan(2),
          reason: "the ••• ink ends within 2px of the bar's right padding");
    });

    testWidgets('a long back label ellipsises and does not move the •••',
        (tester) async {
      final store = _store();
      final t = seedTransfer(store);
      await tester.pumpWidget(_host(
          store,
          TransferDetailScreen(
              txnId: t.id,
              backLabel: 'Cash (EUR Wallet) — a very long back label indeed')));
      await tester.pumpAndSettle();

      // No RenderFlex overflow: the bounded Align width lets it ellipsise.
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(navBar());
      final more = tester.getRect(moreButton());
      expect((bar.right - more.right).abs(), lessThan(2),
          reason: 'the ••• stays at the edge regardless of label length');
    });

    testWidgets('tapping the empty middle of the nav bar does not pop',
        (tester) async {
      final store = _store();
      final t = seedTransfer(store);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          navigatorKey: navKey,
          theme: AppTheme.dark,
          home: const Scaffold(),
        ),
      ));
      navKey.currentState!.push(MaterialPageRoute(
          builder: (_) =>
              TransferDetailScreen(txnId: t.id, backLabel: 'Ledger')));
      await tester.pumpAndSettle();
      expect(find.byType(TransferDetailScreen), findsOneWidget);

      // The InkWell wraps only the back control, not the Expanded — the dead
      // centre of the bar must not act as a back button.
      await tester.tapAt(tester.getRect(navBar()).center);
      await tester.pumpAndSettle();
      expect(find.byType(TransferDetailScreen), findsOneWidget);
    });
  });
}
