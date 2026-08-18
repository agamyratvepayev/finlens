import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

/// Spec §1 — the correctness fix: tapping a Balance drill-down transaction row
/// opens the read-only Same-transactions screen (via [LedgerTxnRow.onOpen]) and
/// never the editor. Verified at the row level so the guarantee does not depend
/// on the surrounding screen's chrome.
Account _acc(String id, String name) => Account(
  id: id,
  name: name,
  group: AccountGroup.spendable,
  currency: 'USD',
  startingBalance: 1000,
);

void main() {
  late AppStore store;
  setUp(() {
    store = AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
  });

  ScopedTxn addRow(LedgerScope scope) {
    final added = store.addTxn(
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c-cat',
      date: DateTime(2026, 8, 5),
    );
    final q = LedgerQuery(
      store: store,
      scope: scope,
      start: DateTime(2020),
      end: DateTime(2030),
    );
    return q.rows().firstWhere((r) => r.txn.id == added.id);
  }

  testWidgets('tapping a row invokes onOpen — never onEdit/onCopy/onDelete', (
    tester,
  ) async {
    const scope = AccountScope('a1');
    final row = addRow(scope);
    var opened = 0, edited = 0, copied = 0, deleted = 0;

    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LedgerTxnRow(
              row: row,
              scope: scope,
              onOpen: () => opened++,
              onEdit: () => edited++,
              onCopy: () => copied++,
              onDelete: () => deleted++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(LedgerTxnRow));
    await tester.pump();

    expect(opened, 1, reason: 'a tap opens the read-only screen');
    expect(edited, 0, reason: 'a tap must never open the editor');
    expect(copied, 0);
    expect(deleted, 0);
  });
}
