import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// The opening balance is a floor, not a transaction: it follows the grammar of
// the ledger (a dated row in a day group) but takes no part in its arithmetic.
// These tests pin both halves of that split.

Account _asset(String id, String name, double opening) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: opening,
      openingDate: DateTime(2026, 8, 1),
    );

Account _liability(String id, String name, double signedOpening) => Account(
      id: id,
      name: name,
      group: AccountGroup.creditCards,
      currency: 'USD',
      startingBalance: signedOpening, // liabilities are stored negative
      openingDate: DateTime(2026, 8, 1),
    );

Category _cat(String id) => Category(
      id: id,
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

AppStore _store(List<Account> accounts, {List<Txn> txns = const []}) => AppStore(
      accounts: accounts,
      categories: [_cat('c-cat')],
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

void main() {
  group('grammar but not arithmetic', () {
    test('opening receipt is excluded from day total, count and the §2B guard',
        () {
      final store = _store([_asset('a1', 'Main Checking', 11046)]);
      store.addTxn(
        type: TxnType.expense,
        amount: 1100,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c-cat',
        date: DateTime(2026, 8, 1, 12),
      );
      const scope = AccountScope('a1');
      final rows = LedgerQuery(
        store: store,
        scope: scope,
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59),
      ).rows();
      expect(rows, hasLength(1));

      final group = DayGroup(date: DateTime(2026, 8, 1), rows: rows)
          .withOpening(OpeningEntry(store.accountById('a1')!));

      // The floor is not a row: it never enters the count…
      expect(group.rows, hasLength(1));
      // …nor the day total…
      expect(group.total, closeTo(rows.single.netContribution, 0.001));
      expect(group.total, closeTo(-1100, 0.001));
      // …nor the §2B guard, which would otherwise print a total on a day that
      // should have none.
      expect(group.showsDayTotal, isFalse, reason: 'one real row + a floor');
      // Sanity: the same single row *without* a floor also suppresses.
      expect(DayGroup(date: DateTime(2026, 8, 1), rows: rows).showsDayTotal,
          isFalse);
    });

    test('a day whose only row is the opening receipt shows a band, no total',
        () {
      final store = _store([_asset('a1', 'Main Checking', 11046)]);
      final group = DayGroup(
        date: DateTime(2026, 8, 1),
        rows: const [],
      ).withOpening(OpeningEntry(store.accountById('a1')!));
      expect(group.rows, isEmpty);
      expect(group.total, 0);
      expect(group.showsDayTotal, isFalse);
    });

    test('the receipt never becomes a transaction — stats and queries ignore it',
        () {
      final store = _store([_asset('a1', 'Main Checking', 11046)]);
      // No transactions exist, only the floor. Every aggregate reads zero.
      expect(store.txns, isEmpty);
      expect(store.txnsForAccount('a1'), isEmpty);
      expect(store.monthExpense(DateTime(2026, 8)), 0);
      expect(store.monthIncome(DateTime(2026, 8)), 0);
      // The scoped query — which powers the period chip's in/out — sees nothing.
      final q = LedgerQuery(
        store: store,
        scope: const AccountScope('a1'),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31, 23, 59, 59),
      );
      expect(q.rows(), isEmpty);
      expect(q.totalIn, 0);
      expect(q.totalOut, 0);
    });
  });

  group('the floor moves the whole column', () {
    test('changing the amount shifts every running balance by the delta', () {
      final store = _store([_asset('a1', 'Main Checking', 11046)]);
      final rent = store.addTxn(
        type: TxnType.expense,
        amount: 1100,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c-cat',
        date: DateTime(2026, 8, 1, 12),
      );
      final lunch = store.addTxn(
        type: TxnType.expense,
        amount: 54,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c-cat',
        date: DateTime(2026, 8, 2, 12),
      );

      final balBefore = store.balanceOf('a1');
      final rentBefore = store.runningBalanceAt('a1', rent);
      final lunchBefore = store.runningBalanceAt('a1', lunch);

      // 11046 → 12000 is a +954 shift.
      store.setOpeningBalance(store.accountById('a1')!, amount: 12000);

      expect(store.balanceOf('a1'), closeTo(balBefore + 954, 0.001));
      expect(store.runningBalanceAt('a1', rent), closeTo(rentBefore + 954, 0.001));
      expect(
          store.runningBalanceAt('a1', lunch), closeTo(lunchBefore + 954, 0.001));
    });

    test('deleting the floor (amount 0) removes the receipt and shifts balances',
        () {
      final store = _store([_asset('a1', 'Main Checking', 11046)]);
      final acc = store.accountById('a1')!;
      final before = store.balanceOf('a1');
      store.setOpeningBalance(acc, amount: 0, date: acc.openingDate);
      expect(acc.hasOpeningReceipt, isFalse); // no row renders
      expect(store.balanceOf('a1'), closeTo(before - 11046, 0.001));
    });
  });

  group('sign and shape', () {
    test('a liability floor is stored negative and read back split', () {
      final store = _store([_liability('cc', 'Amex', -6470)]);
      final cc = store.accountById('cc')!;
      final entry = OpeningEntry(cc);
      // Unsigned magnitude for the amount (§2.3), signed for the running
      // balance beneath it (§2.4).
      expect(entry.amount, closeTo(6470, 0.001));
      expect(entry.runningBalance, closeTo(-6470, 0.001));

      // Editing takes an unsigned magnitude and re-applies the liability sign.
      store.setOpeningBalance(cc, amount: 800);
      expect(cc.startingBalance, closeTo(-800, 0.001));
    });

    test('earliest transaction is the ceiling for the opening date', () {
      final store = _store(
        [_asset('a1', 'Main Checking', 11046)],
      );
      expect(store.earliestTxnDateForAccount('a1'), isNull);

      store.addTxn(
        type: TxnType.expense,
        amount: 54,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c-cat',
        date: DateTime(2026, 8, 2),
      );
      store.addTxn(
        type: TxnType.expense,
        amount: 12,
        currency: 'USD',
        fromRef: 'a1',
        toRef: 'c-cat',
        date: DateTime(2026, 8, 5),
      );
      final earliest = store.earliestTxnDateForAccount('a1')!;
      expect(earliest, DateTime(2026, 8, 2));

      // The validation rule the edit sheet enforces: an opening date after the
      // earliest transaction is rejected (a floor above what rests on it).
      DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
      bool tooLate(DateTime chosen) => chosen.isAfter(day(earliest));
      expect(tooLate(DateTime(2026, 8, 3)), isTrue); // day 3 > day 2 → blocked
      expect(tooLate(DateTime(2026, 8, 2)), isFalse); // same day is allowed
      expect(tooLate(DateTime(2026, 8, 1)), isFalse); // before is allowed
    });
  });

  group('the row', () {
    Future<void> pumpRow(
      WidgetTester tester,
      OpeningEntry entry, {
      ValueChanged<Account>? onEdit,
      ValueChanged<Account>? onCopy,
      ValueChanged<Account>? onDelete,
      NavigatorObserver? observer,
    }) async {
      final store = _store([entry.account]);
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers:
              observer == null ? <NavigatorObserver>[] : [observer],
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: OpeningBalanceRow(
                  entry: entry,
                  onEdit: onEdit,
                  onCopy: onCopy,
                  onDelete: onDelete,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('renders title, account name, an unsigned neutral amount, no chevron',
        (tester) async {
      final entry = OpeningEntry(_asset('a1', 'Main Checking', 11046));
      await pumpRow(tester, entry);

      expect(find.text('Opening balance'), findsOneWidget);
      expect(find.text('Main Checking'), findsOneWidget);
      // Unsigned amount, and equal to the running balance for an asset.
      expect(find.text(r'$11,046'), findsWidgets);
      // No chevron affordance (§2.5).
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      final amount = tester.widget<Text>(find.text(r'$11,046').first);
      expect(amount.style!.color, AppColors.transferAmount); // #EBEBF5, neutral
      expect(amount.style!.color, isNot(AppColors.positive));
      expect(amount.style!.color, isNot(AppColors.negative));
    });

    testWidgets('swipe menu is exactly Edit · Copy · Delete — no Move',
        (tester) async {
      final entry = OpeningEntry(_asset('a1', 'Main Checking', 11046));
      await pumpRow(
        tester,
        entry,
        onEdit: (_) {},
        onCopy: (_) {},
        onDelete: (_) {},
      );
      final swipe = tester.widget<SwipeActions>(find.byType(SwipeActions));
      expect(swipe.actions, hasLength(3));
      final labels = swipe.actions.map((a) => a.label).toList();
      expect(labels, ['Edit', 'Copy', 'Delete']);
      expect(labels, isNot(contains('Move')));
    });

    testWidgets('Copy is absent (not disabled) when no target is eligible',
        (tester) async {
      final entry = OpeningEntry(_asset('a1', 'Main Checking', 11046));
      await pumpRow(tester, entry, onEdit: (_) {}, onDelete: (_) {});
      final swipe = tester.widget<SwipeActions>(find.byType(SwipeActions));
      expect(swipe.actions.map((a) => a.label), ['Edit', 'Delete']);
    });

    testWidgets('tapping the row navigates nowhere', (tester) async {
      final observer = _CountingObserver();
      final entry = OpeningEntry(_asset('a1', 'Main Checking', 11046));
      await pumpRow(tester, entry, observer: observer);
      final pushesAtStart = observer.pushes;
      await tester.tap(find.text('Opening balance'));
      await tester.pumpAndSettle();
      expect(observer.pushes, pushesAtStart, reason: 'a floor has no destination');
    });

    testWidgets('screen reader announces it without a direction', (tester) async {
      final handle = tester.ensureSemantics();
      final entry = OpeningEntry(_asset('a1', 'Main Checking', 11046));
      await pumpRow(tester, entry);
      expect(find.bySemanticsLabel(RegExp('Opening balance')), findsOneWidget);
      // Never "income" / "expense".
      expect(find.bySemanticsLabel(RegExp('income', caseSensitive: false)),
          findsNothing);
      expect(find.bySemanticsLabel(RegExp('expense', caseSensitive: false)),
          findsNothing);
      handle.dispose();
    });
  });
}

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
