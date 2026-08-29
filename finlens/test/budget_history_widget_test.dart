import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/features/planner/goal_detail_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/change_row.dart';

/// Budget-detail CHANGES — the rendered section (spec §1/§4/§5). The seed's
/// Groceries budget predates the feature, so it exercises the empty state; a
/// hand-built category exercises the populated + narrow cases.
void main() {
  final aug = DateTime(2026, 8);

  Widget wrap(AppStore store, Widget child, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  void sizeScreen(WidgetTester tester, Size size, [double dpr = 3.0]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }

  Category storeWith(AppStore store, void Function(AppStore, Category) build) {
    final cat = store.addCategory(
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_cart_rounded,
      color: Colors.green,
      monthlyBudget: 3000,
    );
    build(store, cat);
    return cat;
  }

  AppStore freshStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  testWidgets('an empty history renders its muted line and the footnote',
      (tester) async {
    sizeScreen(tester, const Size(1206, 2622));
    final store = buildSeedStore(); // c-groceries budget predates the feature
    await tester.pumpWidget(wrap(
      store,
      BudgetDetailScreen(categoryId: 'c-groceries', month: aug),
    ));
    await tester.pump();

    expect(find.text('CHANGES'), findsOneWidget);
    expect(find.text('No changes recorded yet'), findsOneWidget);
    expect(find.textContaining('Changes are recorded from'), findsOneWidget);
  });

  testWidgets('a raised limit renders a Limit row with the trending_up glyph',
      (tester) async {
    sizeScreen(tester, const Size(1206, 2622));
    final store = freshStore();
    final cat = storeWith(store, (s, c) => s.updateBudget(c, monthlyBudget: 4000));

    await tester.pumpWidget(wrap(
      store,
      BudgetDetailScreen(categoryId: cat.id, month: aug),
    ));
    await tester.pump();

    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);
    // The amber flag is the budget glyph, not the goal's schedule glyph.
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
  });

  testWidgets('the goal CHANGES card still renders a Created ChangeRow after '
      'the extraction', (tester) async {
    sizeScreen(tester, const Size(1206, 2622));
    await tester.pumpWidget(wrap(
      buildSeedStore(),
      const GoalDetailScreen(goalId: 'g-house', backLabel: 'Goals'),
    ));
    await tester.pump();

    expect(find.text('CHANGES'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.byType(ChangeRow), findsWidgets);
  });

  testWidgets('a Limit row does not overflow at 320pt in Turkish',
      (tester) async {
    sizeScreen(tester, const Size(320, 700), 1.0);
    final store = freshStore();
    final cat = storeWith(store, (s, c) => s.updateBudget(c, monthlyBudget: 4000));

    await tester.pumpWidget(wrap(
      store,
      BudgetDetailScreen(categoryId: cat.id, month: aug),
      locale: const Locale('tr'),
    ));
    await tester.pump();

    // The value line "$3,000 → $4,000" is present and nothing overflowed.
    expect(find.byType(ChangeRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
