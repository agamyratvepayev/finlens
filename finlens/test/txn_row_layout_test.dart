import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Layout/geometry tests for the stacked TxnRow (Ledger tab + account-detail
// perspective). Fonts and colours are unchanged from before — only the row's
// structure and heights are exercised here.
//
// NOTE: measured heights are intrinsic (padding + content) and vary a point or
// two with font metrics, so assertions use tolerances. Because the icon tile
// (34pt) plus vertical padding (2×9pt) already sums to 52pt, a title-only row
// is icon-dominated at ~52pt: the 44pt floor is a non-binding safety minimum,
// never the actual height. Turkish descender clearance still needs a visual
// check on-device.

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

Txn _expense(
        {String note = '',
        List<String> tags = const [],
        String id = 'e1'}) =>
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

Txn _transfer({String note = '', List<String> tags = const []}) => Txn(
      id: 't1',
      type: TxnType.transfer,
      amount: 500,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'a2',
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
  group('heights', () {
    testWidgets('description + meta line ≈ 66; without meta ≈ 52; meta adds height',
        (tester) async {
      // Ledger tab (no perspective): the account name shows -> meta line present.
      final withMeta = await _pump(
          tester, _store(), _expense(note: 'Bakery & fruit'));
      expect(withMeta, closeTo(66, 7));

      // Account-detail perspective: account implied, no tag -> no meta line.
      final noMeta = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          perspective: 'a1');
      expect(noMeta, closeTo(52, 7));

      // The meta line is what makes the taller row taller.
      expect(withMeta, greaterThan(noMeta + 8));
    });

    testWidgets('title only (no description, no meta) is never under 44',
        (tester) async {
      final h = await _pump(tester, _store(), _expense(), perspective: 'a1');
      expect(h, greaterThanOrEqualTo(44));
      // Icon-dominated: lands ~52, not clamped to 44.
      expect(h, closeTo(52, 7));
    });
  });

  testWidgets('account name shows on the Ledger, absent on account detail',
      (tester) async {
    // Ledger tab: account varies row to row, so it is printed.
    await _pump(tester, _store(), _expense());
    expect(find.text('Main Checking'), findsOneWidget);

    // Account detail: the header already states the account -> row omits it.
    await _pump(tester, _store(), _expense(), perspective: 'a1');
    expect(find.text('Main Checking'), findsNothing);
  });

  testWidgets('with no description the balance sits on the amount line',
      (tester) async {
    await _pump(tester, _store(), _expense(),
        perspective: 'a1', runningBalance: 5430);

    final amountDy = tester.getCenter(find.text(r'$120')).dy;
    final balanceDy = tester.getCenter(find.text(r'$5,430')).dy;
    expect((amountDy - balanceDy).abs(), lessThan(2.0));
  });

  testWidgets('a transfer without a tag renders no meta line', (tester) async {
    final h = await _pump(
        tester, _store(), _transfer(note: 'Partial payment before statement'));
    // Title + description, no meta -> the shorter band, not the ~66 three-line.
    expect(h, lessThan(60));
    // The account path is only in the title; it is not repeated in a meta line.
    expect(find.textContaining('Main Checking →'), findsNothing);
  });

  testWidgets('the meta line aligns with the text column (44pt indent)',
      (tester) async {
    await _pump(tester, _store(), _expense(note: 'Bakery & fruit'));
    // The category title and the account meta both start at the text column's
    // left edge (icon 34 + gap 10 = 44pt from the row content's left edge).
    final titleLeft = tester.getTopLeft(find.text('Groceries')).dx;
    final metaLeft = tester.getTopLeft(find.text('Main Checking')).dx;
    expect((titleLeft - metaLeft).abs(), lessThan(0.5));
  });

  testWidgets('a long account name ellipsizes while the tag stays visible',
      (tester) async {
    final store = _store(accounts: [
      _acc('a1', 'An extremely long account name that will not fit'),
      _acc('a2', 'Cash Wallet'),
    ]);
    await _pump(tester, store, _expense(tags: const ['side']), width: 220);

    expect(find.text('#side'), findsOneWidget); // tag stays whole
    final acct = tester.widget<Text>(
        find.text('An extremely long account name that will not fit'));
    expect(acct.overflow, TextOverflow.ellipsis);
  });

  testWidgets('no overflow at 130% text scale', (tester) async {
    await _pump(tester, _store(),
        _expense(note: 'Bakery & fruit', tags: const ['side']),
        textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
