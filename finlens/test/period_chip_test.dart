import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/widgets/account_rows.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/ledger/widgets/period_row.dart';
import 'package:finlens/theme/app_theme.dart';

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(theme: AppTheme.dark, home: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('an account row is one whole-row tap target', (tester) async {
    final store = buildSeedStore();
    final acct = store.accounts.firstWhere((a) => a.name == 'Main Checking');
    var taps = 0;

    await tester.pumpWidget(_host(
      store,
      Scaffold(
        body: AccountRow(account: acct, balance: 100, onTap: () => taps++),
      ),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AccountRow));
    // The name side (left) and the amount side (right) hit the same target.
    await tester.tapAt(Offset(rect.left + 12, rect.center.dy));
    await tester.tapAt(Offset(rect.right - 12, rect.center.dy));
    expect(taps, 2);
  });

  testWidgets('‹ steps the cursor without opening the sheet; the label opens it',
      (tester) async {
    final store = buildSeedStore();
    final range = RangePreset.thisMonth.resolve(AppStore.today);
    var steps = 0;
    var picks = 0;

    await tester.pumpWidget(_host(
      store,
      Scaffold(
        body: PeriodRow(
          range: range,
          totalIn: 100,
          totalOut: 50,
          filter: null,
          onStep: (s) => steps += s,
          onPickRange: () => picks++,
          onFilter: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    expect(steps, -1);
    expect(picks, 0, reason: 'the arrow must not open the sheet');

    await tester.tap(find.text(range.label(AppStore.today, AppLocalizationsEn())));
    expect(picks, 1, reason: 'tapping the label opens the sheet');
  });

  testWidgets('the period sheet does not overflow at 320×568 and 130% scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    final acct = store.accounts.firstWhere((a) => a.name == 'Main Checking');

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: ScopedLedgerScreen(initialScope: AccountScope(acct.id)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester
        .tap(find.text(RangePreset.thisMonth.resolve(AppStore.today).label(AppStore.today, AppLocalizationsEn())));
    await tester.pumpAndSettle();

    // A RenderFlex overflow throws during layout; none may occur.
    expect(tester.takeException(), isNull);
    expect(find.text('Period'), findsOneWidget);
  });
}
