import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// NOTE: measured heights are intrinsic (padding + content), so they vary a
// point or two with font metrics; assertions use tolerances. On-device Turkish
// descender clearance at 1.2 line-height still needs a visual check.

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

Txn _expense(String id,
        {String note = '', List<String> tags = const []}) =>
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

Txn _transfer(String id, {String note = ''}) => Txn(
      id: id,
      type: TxnType.transfer,
      amount: 500,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'a2',
      date: DateTime(2026, 8, 5),
      note: note,
    );

void main() {
  late AppStore store;
  setUp(() {
    store = AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Cash Wallet')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
  });

  ScopedTxn rowFor(Txn spec, LedgerScope scope) {
    final added = store.addTxn(
      type: spec.type,
      amount: spec.amount,
      currency: spec.currency,
      fromRef: spec.fromRef,
      toRef: spec.toRef,
      date: spec.date,
      note: spec.note,
      tags: spec.tags,
    );
    final q = LedgerQuery(
        store: store, scope: scope, start: DateTime(2020), end: DateTime(2030));
    return q.rows().firstWhere((r) => r.txn.id == added.id);
  }

  Future<double> pumpRow(
      WidgetTester tester, ScopedTxn row, LedgerScope scope,
      {double width = 360, double textScale = 1.0}) async {
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
                child: LedgerTxnRow(
                  row: row,
                  scope: scope,
                  onOpen: () {},
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
    return tester.getSize(find.byType(LedgerTxnRow)).height;
  }

  group('heights', () {
    testWidgets('description + meta line ≈ 66; without meta ≈ 52',
        (tester) async {
      // Group scope: the account name shows -> meta line present.
      final withMeta =
          await pumpRow(tester, rowFor(_expense('e1', note: 'Bakery & fruit'),
              const GroupScope(AccountGroup.spendable)),
              const GroupScope(AccountGroup.spendable));
      expect(withMeta, closeTo(66, 5));

      // Account scope: account implied -> no meta line, description only.
      final noMeta = await pumpRow(
          tester,
          rowFor(_expense('e2', note: 'Bakery & fruit'),
              const AccountScope('a1')),
          const AccountScope('a1'));
      expect(noMeta, closeTo(52, 5));
    });

    testWidgets('title only (no description, no meta) clamps to 44',
        (tester) async {
      final h = await pumpRow(tester,
          rowFor(_expense('e3'), const AccountScope('a1')),
          const AccountScope('a1'));
      expect(h, closeTo(44, 1.5));
      expect(h, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('account name shows in group scope, absent in account scope',
      (tester) async {
    await pumpRow(tester,
        rowFor(_expense('g1'), const GroupScope(AccountGroup.spendable)),
        const GroupScope(AccountGroup.spendable));
    expect(find.text('Main Checking'), findsOneWidget); // meta line

    await pumpRow(
        tester, rowFor(_expense('g2'), const AccountScope('a1')),
        const AccountScope('a1'));
    expect(find.text('Main Checking'), findsNothing);
  });

  testWidgets('with no description the balance sits on the amount line',
      (tester) async {
    final row = rowFor(_expense('n1'), const AccountScope('a1'));
    await pumpRow(tester, row, const AccountScope('a1'));

    // Amount and running balance render on the same line (same dy).
    final amountDy = tester.getCenter(find.text(r'$120')).dy;
    final balanceFinder = find.byWidgetPredicate((w) =>
        w is Text && (w.data ?? '').startsWith(r'$') && w.data != r'$120');
    expect(balanceFinder, findsWidgets);
    final balanceDy = tester.getCenter(balanceFinder.first).dy;
    expect((amountDy - balanceDy).abs(), lessThan(2.0));
  });

  testWidgets('a transfer without a tag renders no meta line',
      (tester) async {
    final h = await pumpRow(
        tester,
        rowFor(_transfer('t1', note: 'Partial payment before statement'),
            const GroupScope(AccountGroup.spendable)),
        const GroupScope(AccountGroup.spendable));
    // Title + description, no meta -> ~52, not ~66.
    expect(h, lessThan(60));
  });

  testWidgets('a long account name ellipsizes while the tag stays',
      (tester) async {
    store = AppStore(
      accounts: [
        _acc('a1', 'An extremely long account name that will not fit'),
        _acc('a2', 'Cash Wallet'),
      ],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
    final row = rowFor(_expense('l1', tags: const ['side']),
        const GroupScope(AccountGroup.spendable));
    await pumpRow(tester, row, const GroupScope(AccountGroup.spendable),
        width: 220);

    expect(find.text('side'), findsOneWidget); // tag stays visible
    final acct = tester.widget<Text>(
        find.text('An extremely long account name that will not fit'));
    expect(acct.overflow, TextOverflow.ellipsis);
  });

  testWidgets('no overflow at 130% text scale', (tester) async {
    await pumpRow(
      tester,
      rowFor(_expense('s1', note: 'Bakery & fruit', tags: const ['side']),
          const GroupScope(AccountGroup.spendable)),
      const GroupScope(AccountGroup.spendable),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
