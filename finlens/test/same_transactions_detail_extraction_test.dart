import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/detail_row.dart';
import 'package:finlens/theme/app_theme.dart';

/// Guards the DetailRow extraction (spec §3): SameTransactionsScreen's detail
/// card must render identically after its private `_detailRow` moved out into
/// the shared [DetailRow]. The card now *is* DetailRow instances, and the
/// NOTE·WHEN·PAID WITH·TAGS labels and values are byte-for-byte what they were.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the detail card is built from DetailRow and renders the same '
      'four labels/values', (tester) async {
    final store = AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'Main Checking',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: [
        Category(
          id: 'c1',
          name: 'Eating out',
          type: CategoryType.expense,
          icon: Icons.restaurant_rounded,
          color: const Color(0xFF30D158),
        ),
      ],
      txns: [
        Txn(
          id: 'e1',
          type: TxnType.expense,
          amount: 200,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'c1',
          date: DateTime(2026, 8, 9, 8, 12),
          note: 'Team lunch',
          tagIds: ['fun', 'work'],
        ),
      ],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: const SameTransactionsScreen(originTxnId: 'e1'),
      ),
    ));
    await tester.pumpAndSettle();

    // Four rows: NOTE, WHEN, PAID WITH, TAGS — all now DetailRow.
    expect(find.byType(DetailRow), findsNWidgets(4));
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('WHEN'), findsOneWidget);
    expect(find.textContaining('08:12'), findsOneWidget);
    expect(find.text('PAID WITH'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('#fun #work'), findsOneWidget);
  });
}
