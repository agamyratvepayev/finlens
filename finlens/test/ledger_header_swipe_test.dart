import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';
import 'package:finlens/core/data/seed_data.dart';

// Month navigation by swipe (spec §2): a horizontal drag on the header zone
// steps the month through the same store.period path the sheet uses; the same
// drag on the transaction list does not.

Future<void> _pump(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const LedgerScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a horizontal drag on the header steps the month forward',
      (tester) async {
    final store = buildSeedStore();
    expect(store.period.month, 8); // August 2026

    await _pump(tester, store);
    // The ratio bar lives only in the header zone.
    await tester.drag(find.byType(ProgressBar), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(store.period.month, 9); // → September
  });

  testWidgets('a rightward drag on the header steps the month back',
      (tester) async {
    final store = buildSeedStore();
    await _pump(tester, store);

    await tester.drag(find.byType(ProgressBar), const Offset(160, 0));
    await tester.pumpAndSettle();

    expect(store.period.month, 7); // → July
  });

  testWidgets('a horizontal drag on the transaction list does not change month',
      (tester) async {
    final store = buildSeedStore();
    await _pump(tester, store);

    await tester.drag(find.byType(TxnRow).first, const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(store.period.month, 8); // unchanged — the list keeps its own gesture
  });
}
