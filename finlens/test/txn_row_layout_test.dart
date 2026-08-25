import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/search_fold.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// Layout/geometry tests for the Ledger-tab TxnRow. Two compact lines by default
// (title · #tag · amount over account · balance); the description is a third
// line behind the global toggle (spec §4). The tag rides the title line now, so
// the title wins and the tag yields — see the "title wins" group below and the
// dedicated txn_row_tags_test.dart. The main Ledger tab renders NO running balance — its
// list interleaves every account, so a per-row figure reconciles against no
// series (balance spec §1). A balance appears only on the account-detail
// perspective (`perspectiveAccountId` + `runningBalance`), a single account's
// tape. Heights are intrinsic (padding + content) with a 44pt floor, so
// assertions use tolerances.

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
      final off = await _pump(tester, _store(), _expense());
      final on = await _pump(tester, _store(), _expense(),
          showDescription: true);
      expect(on, closeTo(off, 0.5)); // no note -> no third line either way
    });

    testWidgets('a noted row grows by one line when the toggle is on',
        (tester) async {
      final off = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'));
      final on = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          showDescription: true);
      expect(off, closeTo(44, 6)); // two lines, floor binds
      expect(on, greaterThan(off + 6)); // description adds a line
    });

    testWidgets('toggle on but empty note renders no third line',
        (tester) async {
      final noted = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          showDescription: true);
      final noteless = await _pump(tester, _store(), _expense(),
          showDescription: true);
      expect(noteless, lessThan(noted - 6));
    });
  });

  group('no running balance on the Ledger tab', () {
    testWidgets('the amount is unsigned/red and no balance figure renders',
        (tester) async {
      await _pump(tester, _store(), _expense());
      expect(find.text(r'$120'), findsOneWidget); // amount unsigned
      expect(find.text('−\$120'), findsNothing);
      // The tab interleaves every account, so the row shows no second figure at
      // all — only its own amount (balance spec §1).
      final dollarTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').startsWith(r'$'))
          .toList();
      expect(dollarTexts.length, 1);
    });

    testWidgets('the account name still names line 2', (tester) async {
      await _pump(tester, _store(), _expense());
      expect(find.text('Main Checking'), findsOneWidget);
    });

    testWidgets('the perspective row (a single account tape) DOES show a '
        'balance', (tester) async {
      // The one path that renders a balance: an account-detail perspective.
      await _pump(tester, _store(), _expense(),
          perspective: 'a1', runningBalance: 5430);
      expect(find.text(r'$5,430'), findsOneWidget);
    });
  });

  group('title-line tag overflow order — the title wins', () {
    // The tag left line 2 for the title line (spec §1). Its rule is the OPPOSITE
    // of the old meta-line order: a category title is the row's identity, so it
    // lays out whole and the tag collapses/drops before the title ellipsizes —
    // never a truncated "Transportation" beside a whole "#groceries".
    Category longCat() => Category(
          id: 'c-cat',
          name: 'Groceries, household and everyday essentials',
          type: CategoryType.expense,
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFF30D158),
        );

    AppStore longTitleStore() => AppStore(
          accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Cash Wallet')],
          categories: [longCat()],
          txns: const <Txn>[],
          goals: const <Goal>[],
          tasks: const <Task>[],
        );

    testWidgets('a long title stays; the tag drops rather than truncating it',
        (tester) async {
      await _pump(tester, longTitleStore(),
          _expense(tags: const ['commute', 'side']),
          width: 320);

      // The title alone fills the region, so the tag drops entirely — neither
      // the full run nor the collapsed form is drawn.
      expect(find.text('#commute #side'), findsNothing);
      expect(find.text('#commute +1'), findsNothing);

      // The title is the element that yields to width — it ellipsizes; it is
      // never truncated to keep a tag whole (there is no whole tag here).
      final title = tester.widget<Text>(
          find.text('Groceries, household and everyday essentials'));
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a short title keeps its tag; only the tag collapses when tight',
        (tester) async {
      // Title 'Groceries' fits whole; three tags exceed the slack, so the run
      // collapses to "#first +n" — the tag yields, the title does not. Width 390
      // (the standard portrait width) leaves room for the collapsed run but not
      // the full one.
      await _pump(tester, _store(),
          _expense(tags: const ['fun', 'weekend', 'split']),
          width: 390);

      expect(find.text('#fun +2'), findsOneWidget);
      expect(find.text('#fun #weekend #split'), findsNothing);
      // Title untouched — present and not ellipsis-forced (it had room).
      expect(find.text('Groceries'), findsOneWidget);
    });
  });

  group('search reveals a hidden note', () {
    testWidgets('a matched note opens even with the toggle off, and closes '
        'when the search clears', (tester) async {
      final off = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'));
      final matched = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          searchQuery: foldSearch('bakery'));
      final unmatched = await _pump(tester, _store(),
          _expense(note: 'Bakery & fruit'),
          searchQuery: foldSearch('zzz'));

      expect(matched, greaterThan(off + 6)); // note revealed
      expect(unmatched, closeTo(off, 1)); // non-match stays closed
    });
  });

  group('account label', () {
    testWidgets('shows on the Ledger, absent on an account-detail perspective',
        (tester) async {
      await _pump(tester, _store(), _expense());
      expect(find.text('Main Checking'), findsOneWidget);

      await _pump(tester, _store(), _expense(),
          perspective: 'a1', runningBalance: 880);
      expect(find.text('Main Checking'), findsNothing);
    });
  });

  testWidgets('no overflow at 130% text scale', (tester) async {
    await _pump(tester, _store(),
        _expense(note: 'Bakery & fruit', tags: const ['side']),
        showDescription: true, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
