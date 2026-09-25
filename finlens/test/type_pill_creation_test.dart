import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/planner/edit_scaffold.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// The type pill on the Goal and Budget CREATION screens (this change).
//
// `flutter test` hangs on the author's machine — these are written, not run
// here; verify with `flutter analyze` and run the files yourself.
//
// The rule: anything reachable *from* the type menu must itself be able to
// reopen it, so the two creation forms carry the pill; editing an existing
// record has nothing to switch to, so those screens keep the plain title.

Widget _host(AppStore store, {required Widget home, Locale? locale}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
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

/// A Scaffold whose one button opens the goal editor in *create* mode over a
/// real route, so popping the goal screen (a type switch) lands somewhere.
Widget _goalFlowHost(AppStore store, {Locale? locale}) => _host(
      store,
      locale: locale,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => openGoalEditor(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// An expense category that carries no budget — the only reachable way to land
/// on EditBudgetScreen in *create* mode.
Category _unbudgetedCategory(AppStore store) {
  return store.addCategory(
    name: 'FreshCatZZ',
    type: CategoryType.expense,
    icon: Icons.shopping_bag_rounded,
    color: Colors.orange,
  );
}

Goal _oneGoal(AppStore store) {
  final acc = store.addAccount(
    name: 'Vault',
    group: AccountGroup.setAside,
    currency: 'USD',
    startingBalance: 0,
  );
  return store.addGoal(
    name: 'Holiday',
    source: GoalSource.account(acc.id),
    targetAmount: 1000,
  );
}

void main() {
  // ── §6 · the creation screens render a pill ───────────────────────────────

  testWidgets('Goal screen renders a TypePill: "Goal", violet dot, '
      'chevron (not a padlock)', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    final pill = find.byType(TypePill);
    expect(pill, findsOneWidget);
    expect(find.descendant(of: pill, matching: find.text('Goal')),
        findsOneWidget);

    // The dot is the goal accent, #BF5AF2.
    expect(
      find.descendant(
        of: pill,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.goal &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      ),
      findsOneWidget,
    );

    // A menu, not a lock.
    expect(
        find.descendant(
            of: pill,
            matching: find.byIcon(Icons.keyboard_arrow_down_rounded)),
        findsOneWidget);
    expect(find.descendant(of: pill, matching: find.byIcon(Icons.lock_rounded)),
        findsNothing);
  });

  testWidgets('Budget screen renders a TypePill reading "Budget", not '
      '"Edit budget"', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgetedCategory(store);
    await tester.pumpWidget(
        _host(store, home: EditBudgetScreen(categoryId: cat.id)));

    final pill = find.byType(TypePill);
    expect(pill, findsOneWidget);
    expect(find.descendant(of: pill, matching: find.text('Budget')),
        findsOneWidget);
    // The old wording is gone from the header.
    expect(find.text('Edit budget'), findsNothing);

    // Cyan dot, #64D2FF.
    expect(
      find.descendant(
        of: pill,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.budget),
      ),
      findsOneWidget,
    );
  });

  // ── §6 · edit screens keep the plain title, no pill ───────────────────────

  testWidgets('Edit goal shows a centred title and no pill', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final goal = _oneGoal(store);
    await tester.pumpWidget(
        _host(store, home: EditGoalScreen(goalId: goal.id)));

    expect(find.byType(TypePill), findsNothing);
    expect(find.text('Edit goal'), findsOneWidget);
  });

  testWidgets('Edit budget (category already budgeted) shows a title, no pill',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgetedCategory(store);
    store.updateBudget(cat, monthlyBudget: 200);
    await tester.pumpWidget(
        _host(store, home: EditBudgetScreen(categoryId: cat.id)));

    expect(find.byType(TypePill), findsNothing);
    expect(find.text('Edit budget'), findsOneWidget);
  });

  testWidgets('Edit scheduled item shows a title and no pill', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(
        _host(buildSeedStore(), home: const EditTaskScreen(taskId: 'k-gym')));

    expect(find.byType(TypePill), findsNothing);
    // Task 029: the editor title is now "Edit scheduled item".
    expect(find.text('Edit scheduled item'), findsOneWidget);
  });

  // ── §6 · the pill opens the menu, marked on the current type ──────────────

  testWidgets('tapping the Goal pill opens the menu with the check on '
      '"Goal"', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();

    expect(find.text('What are you adding?'), findsOneWidget);
    // The current type — Goal — carries the check.
    final checkRow = find.ancestor(
      of: find.text('Goal'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: checkRow, matching: find.byIcon(Icons.check_rounded)),
      findsWidgets,
    );
  });

  testWidgets('tapping the Budget pill opens the menu with the check on '
      '"Budget"', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgetedCategory(store);
    await tester.pumpWidget(
        _host(store, home: EditBudgetScreen(categoryId: cat.id)));

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();

    expect(find.text('What are you adding?'), findsOneWidget);
    final checkRow = find.ancestor(
      of: find.text('Budget'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: checkRow, matching: find.byIcon(Icons.check_rounded)),
      findsWidgets,
    );
  });

  // ── §6 · switching type off a creation screen ─────────────────────────────

  testWidgets('from Goal, picking Expense hides the goal screen and shows '
      'QuickAddScreen (expense)', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_goalFlowHost(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(EditGoalScreen), findsOneWidget);

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    // Task 056: the goal screen is hidden (offstage, so absent to find.byType)
    // rather than popped, and the expense form is what's on screen.
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsOneWidget);
    // Its pill reads the expense type.
    expect(find.descendant(of: find.byType(TypePill), matching: find.text('Expense')),
        findsOneWidget);
  });

  testWidgets('from Goal, picking Budget shows the budget screen',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    _unbudgetedCategory(store);
    await tester.pumpWidget(_goalFlowHost(store));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    // The goal screen is gone and the one-step budget screen is up in create
    // mode — no "Budget which category?" step any more (spec §4).
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Budget which category?'), findsNothing);
  });

  testWidgets('picking "Goal" on the Goal screen closes the sheet and '
      'leaves the screen mounted with fields untouched', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    // Type a name (first field is Goal name), then re-pick the current type.
    await tester.enterText(find.byType(TextField).first, 'Holiday');
    await tester.pump();

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();

    // The sheet closed; the screen is still here; the name is intact.
    expect(find.text('What are you adding?'), findsNothing);
    expect(find.byType(EditGoalScreen), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
  });

  testWidgets('a half-filled goal name survives a switch away and back, and is '
      'gone after Cancel', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_goalFlowHost(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Half typed');
    await tester.pump();

    // Switching away never asks and never confirms (task 056 keeps input, so
    // there is nothing to discard).
    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsOneWidget);

    // Switching back shows the goal form with the name still there.
    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.byType(EditGoalScreen), findsOneWidget);
    expect(find.text('Half typed'), findsOneWidget);

    // Cancel closes the whole session; a fresh open is empty.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Half typed'), findsNothing);
  });

  // ── §6 · Quick Add's pill still lives inside FormNavBar ────────────────────

  testWidgets('FormNavBar still hosts the pill; it is horizontally centred at '
      '390×844', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(buildSeedStore(),
        home: const QuickAddScreen(initialType: QuickAddType.expense)));
    await tester.pump(const Duration(milliseconds: 350));

    final pill = find.descendant(
        of: find.byType(FormNavBar), matching: find.byType(TypePill));
    expect(pill, findsOneWidget);

    // The pill is centred in the 390pt-wide bar (the Expanded(Center(...)) slot).
    final r = tester.getRect(pill);
    expect(r.center.dx, closeTo(195, 1.0),
        reason: 'the pill sits at the nav bar centre');
    // And it is the short control the spec measures (~29pt), below the 44pt
    // tap target — a documented, deliberate gap.
    expect(r.height, lessThan(44));
  });

  // ── §5 (task 058.2) · creation and editing wear DIFFERENT chrome now ──────
  //
  // The old invariant — a pill must not change the EditScaffold header height —
  // is retired. Task 058.2 gives the creation session Quick Add's chrome: a
  // FormNavBar (50 pt) on the black formBg. Editing keeps the TextButton title
  // row on the app bg. The new invariant lives in
  // task058_2_detail_and_chrome_test.dart: Goal and Schedule creation match each
  // other. Here we only pin that the two chromes are the two chromes.

  testWidgets('creation (pill) wears the FormNavBar on formBg; editing wears '
      'the TextButton title row', (tester) async {
    Widget bare({required bool withPill}) => MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditScaffold(
            title: 'Edit goal',
            type: withPill ? QuickAddType.newGoal : null,
            onTypeTap: withPill ? () {} : null,
            hero: withPill
                ? const SizedBox(key: Key('goalHero'), height: 48)
                : null,
            children: const [],
          ),
        );

    _size(tester, 390, 844);

    // Creation: FormNavBar, black ground, no TextButton row.
    await tester.pumpWidget(bare(withPill: true));
    expect(find.byType(FormNavBar), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    expect(find.byKey(const Key('goalHero')), findsOneWidget);
    Scaffold scaffold = tester.widget(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.formBg);

    // Editing: the TextButton title row, no FormNavBar, app bg (theme default).
    await tester.pumpWidget(bare(withPill: false));
    expect(find.byType(FormNavBar), findsNothing);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.text('Edit goal'), findsOneWidget);
    scaffold = tester.widget(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull,
        reason: 'editing keeps the theme scaffold bg (#0A0A0B)');
  });

  // ── §5 · 320pt, four locales, no overflow on either screen ────────────────

  testWidgets('no overflow at 320pt across en/ru/tk/tr on both creation screens',
      (tester) async {
    for (final code in ['en', 'ru', 'tk', 'tr']) {
      _size(tester, 320, 568);

      // Goal.
      await tester.pumpWidget(
          _host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen(), locale: Locale(code)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Goal overflow in $code');

      // Budget.
      final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
      final cat = _unbudgetedCategory(store);
      await tester.pumpWidget(_host(store,
          home: EditBudgetScreen(categoryId: cat.id), locale: Locale(code)));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'Budget overflow in $code');
    }
  });
}
