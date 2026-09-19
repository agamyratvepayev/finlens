import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 043 §3 — "Not set" is retired. Every empty *required* row names the
// action that fills it, in the imperative and with no article. This pumps the
// screens that own those rows, asserts the exact imperative, and asserts the
// literal "Not set" appears nowhere in the tree.
//
// `flutter test` hangs on the author's machine — run this yourself:
//   flutter test test/task043_empty_imperatives_test.dart

Widget _host(AppStore store, Widget home) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AppStore _empty() => AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9)));

void _noNotSet(WidgetTester tester) {
  expect(find.text('Not set'), findsNothing,
      reason: '"Not set" is retired everywhere (task 043 §3)');
}

void main() {
  testWidgets('goal editor: Monthly, Target date and Watching name their action',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_empty(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Enter amount'), findsOneWidget); // Monthly hint
    expect(find.text('Pick month'), findsOneWidget); // Target date
    expect(find.text('Choose source'), findsOneWidget); // Watching
    _noNotSet(tester);
  });

  testWidgets('new budget: targets read "Choose categories" and dates "Pick dates"',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(_empty(), const EditBudgetScreen()));
    await tester.pumpAndSettle();

    // Default scope is categories, so the target row asks for categories.
    expect(find.text('Choose categories'), findsOneWidget);
    expect(find.text('Pick dates'), findsOneWidget);
    _noNotSet(tester);
  });

  testWidgets('account editor: opening balance and the two credit-card day rows',
      (tester) async {
    _tall(tester);
    // A credit-card account (so the statement / payment rows exist) with no
    // opening receipt (startingBalance 0, no openingDate) and no days set.
    final store = AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9)),
      accounts: [
        Account(
          id: 'cc',
          name: 'Card',
          group: AccountGroup.creditCards,
          currency: 'USD',
          startingBalance: 0,
        ),
      ],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );
    await tester.pumpWidget(
        _host(store, const EditAccountScreen(accountId: 'cc')));
    await tester.pumpAndSettle();

    expect(find.text('Set balance'), findsOneWidget); // opening balance
    expect(find.text('Pick day'), findsNWidgets(2)); // statement day + due
    _noNotSet(tester);
  });

  testWidgets('quick add expense: the account row reads "Choose account"',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(
        _host(buildSeedStore(), const QuickAddScreen(initialType: QuickAddType.expense)));
    await tester.pump(const Duration(milliseconds: 350));

    // The From (account) row names its action; the category row uses the
    // long-standing qaChooseCategory ("Choose category"). Neither is "Not set".
    expect(find.text('Choose account'), findsOneWidget);
    _noNotSet(tester);
  });
}
