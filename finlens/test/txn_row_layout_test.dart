import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/search_fold.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Layout/geometry tests for the redesigned TxnRow (Ledger tab). Two compact
// lines by default (title/amount over account/tags/balance); the description is
// a third line behind the global toggle (spec §4). Heights are intrinsic
// (padding + content) with a 44pt floor, so assertions use tolerances.

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store({List<Account>? accounts}) => AppStore(
      accounts: accounts ??
          [_acc('a1', 'Main Checking'), _acc('a2', 'Cash Wallet')],
      categories: [_cat('c-cat', 'Groceries')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Txn _expense({
  String note = '',
  List<String> tags = const [],
  String id = 'e1',
}) =>
    Txn(
      id: id,
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c-cat',
      date: DateTime(2026, 8, 5),
      note: note,
      tags: tags,
    );

Future<double> _pump(
  WidgetTester tester,
  AppStore store,
  Txn txn, {
  String? perspective,
  double? runningBalance,
  double? afterBalance,
  bool showDescription = false,
  String? searchQuery,
  double width = 360,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TxnRow(
                txn: txn,
                perspectiveAccountId: perspective,
                runningBalance: runningBalance,
                afterBalance: afterBalance,
                showDescription: showDescription,
                searchQuery: searchQuery,
                onTap: () {},
                onEdit: () {},
                onCopy: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return tester.getSize(find.byType(TxnRow)).height;
}

void main() {
  group('toggle & description line', () {
    testWidgets('a noteless row keeps its height across toggle states',
        (tester) async {
      final off = await _pump(tester, _store(), _expense(), afterBalance: 880);
      final on = await _pump(tester, _store(), _expense(),
          afterBalance: 880, showDescription: true);
      expect(on, closeTo(off, 0.5)); // no note -> no third line either way
    });

    testWidgets('a noted row grows by one line when the toggle is on',
        (tester) async {
      final off = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'), afterBalance: 880);
      final on = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          afterBalance: 880, showDescription: true);
      expect(off, closeTo(44, 6)); // two lines, floor binds
      expect(on, greaterThan(off + 6)); // description adds a line
    });

    testWidgets('toggle on but empty note renders no third line',
        (tester) async {
      final noted = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          afterBalance: 880, showDescription: true);
      final noteless = await _pump(tester, _store(), _expense(),
          afterBalance: 880, showDescription: true);
      expect(noteless, lessThan(noted - 6));
    });
  });

  group('remaining balance (line 2)', () {
    testWidgets('the amount is unsigned/red while a negative balance keeps its '
        'minus', (tester) async {
      await _pump(tester, _store(), _expense(), afterBalance: -300);
      expect(find.text(r'$120'), findsOneWidget); // amount unsigned
      expect(find.text('−\$120'), findsNothing);
      expect(find.text('−\$300'), findsOneWidget); // balance signed
    });

    testWidgets('a non-negative balance shows unsigned on line 2',
        (tester) async {
      await _pump(tester, _store(), _expense(), afterBalance: 5430);
      expect(find.text(r'$5,430'), findsOneWidget);
    });
  });

  group('line-2 overflow order', () {
    testWidgets('tags collapse to "#first +n" before the account truncates',
        (tester) async {
      final store = _store(accounts: [
        _acc('a1', 'An extremely long account name that will not fit here'),
        _acc('a2', 'Cash Wallet'),
      ]);
      await _pump(tester, store,
          _expense(tags: const ['commute', 'side']),
          afterBalance: 5430, width: 320);

      // The tag run collapsed; the full run is gone; the balance still shows.
      expect(find.text('#commute +1'), findsOneWidget);
      expect(find.text('#commute #side'), findsNothing);
      expect(find.text(r'$5,430'), findsOneWidget);

      final acct = tester.widget<Text>(find
          .text('An extremely long account name that will not fit here'));
      expect(acct.overflow, TextOverflow.ellipsis);
    });
  });

  group('search reveals a hidden note', () {
    testWidgets('a matched note opens even with the toggle off, and closes '
        'when the search clears', (tester) async {
      final off = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'), afterBalance: 880);
      final matched = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          afterBalance: 880, searchQuery: foldSearch('bakery'));
      final unmatched = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          afterBalance: 880, searchQuery: foldSearch('zzz'));

      expect(matched, greaterThan(off + 6)); // note revealed
      expect(unmatched, closeTo(off, 1)); // non-match stays closed
    });
  });

  group('account label', () {
    testWidgets('shows on the Ledger, absent on an account-detail perspective',
        (tester) async {
      await _pump(tester, _store(), _expense(), afterBalance: 880);
      expect(find.text('Main Checking'), findsOneWidget);

      await _pump(tester, _store(), _expense(),
          perspective: 'a1', runningBalance: 880);
      expect(find.text('Main Checking'), findsNothing);
    });
  });

  testWidgets('no overflow at 130% text scale', (tester) async {
    await _pump(tester, _store(),
        _expense(note: 'Bakery & fruit', tags: const ['side']),
        afterBalance: 5430, showDescription: true, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
