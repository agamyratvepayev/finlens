import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart';
import 'package:finlens/features/balance/widgets/account_rows.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run this yourself:
//   flutter test test/balance_reorder_undo_test.dart
//
// A reorder shows the "Moved" undo bar; since the persist: false fix it must
// disappear on its own after the window instead of hanging on screen.

Account _acc(String id, String name, double bal) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: bal,
    );

AppStore _store() => AppStore(
      accounts: [
        _acc('a1', 'Alpha', 3000),
        _acc('a2', 'Bravo', 2000),
        _acc('a3', 'Charlie', 1000),
      ],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

Future<void> _pump(WidgetTester tester, AppStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: BalanceScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a reorder shows Moved, and the bar disappears after the window',
      (tester) async {
    final store = _store();
    await _pump(tester, store);

    // Spendable opens by default; its three rows are on screen.
    expect(find.byType(AccountRow), findsNWidgets(3));

    // Lift the top row (350ms hold) and drag it well past the others.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(AccountRow).first));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // The move committed and flipped the sort to Custom, so the labelled bar
    // appears.
    expect(find.textContaining('Moved'), findsOneWidget);

    // Left alone, it auto-dismisses.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Moved'), findsNothing);
  });
}
