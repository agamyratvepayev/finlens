import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/more/category_management_screen.dart';
import 'package:finlens/features/more/more_screen.dart';
import 'package:finlens/features/more/tag_management_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';

void main() {
  Widget wrap(AppStore store, Widget child) => StoreScope(
        store: store,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('income categories are reachable in the management grid (§2)',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(buildSeedStore(), const CategoryManagementScreen()));
    await tester.pumpAndSettle();

    // The whole point of the rebuild: the old More row pinned the picker to
    // expense, so income categories were unreachable. Salary is an income one.
    expect(find.text('Salary'), findsOneWidget);
    // And an expense category renders too.
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('expense section truncates at 8 with a one-way +N more (§2.3)',
      (tester) async {
    phone(tester);
    final store = buildSeedStore();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final expenseCount =
        store.categoriesOfType(CategoryType.expense).length; // 11 on the seed
    expect(expenseCount, greaterThan(8));

    await tester.pumpWidget(wrap(store, const CategoryManagementScreen()));
    await tester.pumpAndSettle();

    final hidden = expenseCount - 8;
    expect(find.text(l.plusNMore(hidden)), findsOneWidget);

    // Tapping expands, and the link does not come back (one-way, §2.3).
    await tester.tap(find.text(l.plusNMore(hidden)));
    await tester.pumpAndSettle();
    expect(find.text(l.plusNMore(hidden)), findsNothing);
  });

  group('split row destinations (§1.3)', () {
    testWidgets('Categories half opens category management, not tags',
        (tester) async {
      phone(tester);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(wrap(buildSeedStore(), const MoreScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.moreCategories));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryManagementScreen), findsOneWidget);
      expect(find.byType(TagManagementScreen), findsNothing);
    });

    testWidgets('Tags half opens tag management', (tester) async {
      phone(tester);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(wrap(buildSeedStore(), const MoreScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.moreTags));
      await tester.pumpAndSettle();

      expect(find.byType(TagManagementScreen), findsOneWidget);
      expect(find.byType(CategoryManagementScreen), findsNothing);
    });
  });
}
