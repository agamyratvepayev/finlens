import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/balance/balance_screen.dart';
import 'package:finlens/features/balance/widgets/account_rows.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/theme/app_theme.dart';

Widget _app(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: BalanceScreen()),
      ),
    );

void main() {
  testWidgets('group and child amounts keep one right edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pumpAndSettle();

    // Spendable is expanded on load, so a group amount and its child amounts
    // are both on screen. The amount is now the single value on the right (the
    // share moved into the subtitle), so it keeps the child column's right edge
    // with nothing to nudge it. Scoped to the rows — the section-header total
    // is a different column and legitimately ends elsewhere.
    double edgeOf(Finder rowType) => tester
        .getBottomRight(
          find
              .descendant(of: rowType, matching: find.byType(AmountText))
              .first,
        )
        .dx;

    final groupEdge = edgeOf(find.byType(GroupRow).first);
    final childEdge = edgeOf(find.byType(AccountRow).first);

    expect(
      childEdge,
      groupEdge,
      reason: 'group and child amounts share one right edge',
    );
    expect(groupEdge, 390 - 20);
  });

  testWidgets('group rows keep two zones; account rows are one whole-row target',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pumpAndSettle();

    // Group rows are unchanged — zone 1 carries the figures and the expanded
    // state; zone 2 is the ledger.
    expect(
      find.bySemanticsLabel(RegExp(r'^Spendable, 4 accounts, .*')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Spendable transactions'), findsOneWidget);
    handle.dispose();

    // Account rows were consolidated: the whole row (name included) now opens
    // the account's ledger — the name side no longer has a separate destination.
    await tester.tap(find.text('Main Checking'));
    await tester.pumpAndSettle();
    expect(find.byType(ScopedLedgerScreen), findsOneWidget);
  });

  testWidgets('tapping the amount side opens a route, the name side does not',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore()));
    await tester.pumpAndSettle();

    final rowRect = tester.getRect(find.text('Receivables'));

    // The name side toggles: Balance is still the visible route.
    await tester.tap(find.text('Receivables'));
    await tester.pumpAndSettle();
    expect(find.byType(ScopedLedgerScreen), findsNothing);

    // A tap in the empty gap just left of the number must still navigate —
    // that gap is deliberately part of the right zone.
    await tester.tapAt(Offset(390 - 28, rowRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(ScopedLedgerScreen), findsOneWidget);
  });
}
