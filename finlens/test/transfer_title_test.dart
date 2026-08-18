import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/shared/widgets/transfer_title.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 0,
    );

Txn _transfer(String from, String to, {String note = ''}) => Txn(
      id: 't1',
      type: TxnType.transfer,
      amount: 500,
      currency: 'USD',
      fromRef: from,
      toRef: to,
      date: DateTime(2026, 8, 5),
      note: note,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Main Credit Card')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)),
    );

void main() {
  group('title helper', () {
    test('returns "{from} → {to}" and contains no "Transfer"', () {
      final store = _store();
      final title = store.transferTitle(_transfer('a1', 'a2'));
      expect(title, 'Main Checking → Main Credit Card');
      expect(title.contains('Transfer'), isFalse);
    });

    test('a missing account falls back to "Deleted account"', () {
      final store = _store();
      final p = store.transferParties(_transfer('gone', 'a2'));
      expect(p.from, 'Deleted account');
      expect(p.to, 'Main Credit Card');
    });
  });

  group('TransferTitleText widget', () {
    testWidgets('both long names ellipsize and neither collapses to nothing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              child: TransferTitleText(
                from: 'A very long source account name',
                to: 'An even longer destination account name',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ));

      // Both names are laid out (their Text.data is the full string even when
      // visually clipped), and both texts ellipsize.
      final nameTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').trim() != '→')
          .toList();
      expect(nameTexts.length, 2);
      for (final t in nameTexts) {
        expect(t.overflow, TextOverflow.ellipsis);
        expect((t.data ?? '').isNotEmpty, isTrue);
      }
    });

    testWidgets('in an RTL locale the arrow points in reading direction (←)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TransferTitleText(
                from: 'A', to: 'B', style: const TextStyle(fontSize: 14)),
          ),
        ),
      ));
      expect(find.text(' ← '), findsOneWidget);
      expect(find.text(' → '), findsNothing);
    });
  });

  group('TxnRow transfer', () {
    testWidgets('shows source then "→ destination" on two lines, no "Transfer"',
        (tester) async {
      // Spec §2: the source names line 1, "→ {destination}" names line 2, the
      // word "Transfer" appears nowhere, and the note is deliberately dropped
      // to hold the row at two lines.
      await tester.pumpWidget(_host(
        _store(),
        TxnRow(
          txn: _transfer('a1', 'a2', note: 'Partial payment before statement'),
          onTap: () {},
          onEdit: () {},
          onCopy: () {},
          onDelete: () {},
        ),
      ));

      expect(find.text('Main Checking'), findsOneWidget); // line 1: source
      expect(find.text('→ Main Credit Card'), findsOneWidget); // line 2: dest
      expect(find.text('Transfer'), findsNothing);
      // The note is not shown on the Ledger transfer row.
      expect(find.text('Partial payment before statement'), findsNothing);
    });

    testWidgets('the amount is the neutral transfer colour — never red/green',
        (tester) async {
      await tester.pumpWidget(_host(
        _store(),
        TxnRow(
          txn: _transfer('a1', 'a2'),
          onTap: () {},
          onEdit: () {},
          onCopy: () {},
          onDelete: () {},
        ),
      ));

      // No one-line "{from} → {to}" title widget any more; the two account
      // lines carry the path, and the amount is neutral.
      expect(find.byType(TransferTitleText), findsNothing);
      final amount = tester.widget<Text>(find.text(r'$500'));
      expect(amount.style?.color, AppColors.transferAmount);
    });

    testWidgets('the row semantics name the type and both accounts',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        _store(),
        TxnRow(
          txn: _transfer('a1', 'a2'),
          onTap: () {},
          onEdit: () {},
          onCopy: () {},
          onDelete: () {},
        ),
      ));

      expect(
        find.bySemanticsLabel(
            RegExp(r'Transfer from Main Checking to Main Credit Card')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
