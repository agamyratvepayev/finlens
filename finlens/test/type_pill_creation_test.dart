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

  testWidgets('New goal screen renders a TypePill: "New goal", violet dot, '
      'chevron (not a padlock)', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    final pill = find.byType(TypePill);
    expect(pill, findsOneWidget);
    expect(find.descendant(of: pill, matching: find.text('New goal')),
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

  testWidgets('New budget screen renders a TypePill reading "New budget", not '
      '"Edit budget"', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgetedCategory(store);
    await tester.pumpWidget(
        _host(store, home: EditBudgetScreen(categoryId: cat.id)));

    final pill = find.byType(TypePill);
    expect(pill, findsOneWidget);
    expect(find.descendant(of: pill, matching: find.text('New budget')),
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

  testWidgets('Edit task shows a title and no pill', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(
        _host(buildSeedStore(), home: const EditTaskScreen(taskId: 'k-gym')));

    expect(find.byType(TypePill), findsNothing);
    expect(find.text('Edit task'), findsOneWidget);
  });

  // ── §6 · the pill opens the menu, marked on the current type ──────────────

  testWidgets('tapping the New goal pill opens the menu with the check on '
      '"New goal"', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();

    expect(find.text('What are you adding?'), findsOneWidget);
    // The current type — New goal — carries the check.
    final checkRow = find.ancestor(
      of: find.text('New goal'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: checkRow, matching: find.byIcon(Icons.check_rounded)),
      findsWidgets,
    );
  });

  testWidgets('tapping the New budget pill opens the menu with the check on '
      '"New budget"', (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    final cat = _unbudgetedCategory(store);
    await tester.pumpWidget(
        _host(store, home: EditBudgetScreen(categoryId: cat.id)));

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();

    expect(find.text('What are you adding?'), findsOneWidget);
    final checkRow = find.ancestor(
      of: find.text('New budget'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: checkRow, matching: find.byIcon(Icons.check_rounded)),
      findsWidgets,
    );
  });

  // ── §6 · switching type off a creation screen ─────────────────────────────

  testWidgets('from New goal, picking Expense pops the goal screen and lands on '
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

    // The goal screen is gone from the stack (not underneath), and the expense
    // form is what's on screen.
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsOneWidget);
    // Its pill reads the expense type.
    expect(find.descendant(of: find.byType(TypePill), matching: find.text('Expense')),
        findsOneWidget);
  });

  testWidgets('from New goal, picking New budget lands on the budget screen',
      (tester) async {
    _size(tester, 390, 844);
    final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
    _unbudgetedCategory(store);
    await tester.pumpWidget(_goalFlowHost(store));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New budget'));
    await tester.pumpAndSettle();

    // The goal screen is gone and the one-step budget screen is up in create
    // mode — no "Budget which category?" step any more (spec §4).
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(EditBudgetScreen), findsOneWidget);
    expect(find.text('New budget'), findsOneWidget);
    expect(find.text('Budget which category?'), findsNothing);
  });

  testWidgets('picking "New goal" on the New goal screen closes the sheet and '
      'leaves the screen mounted with fields untouched', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen()));

    // Type a name (first field is Goal name), then re-pick the current type.
    await tester.enterText(find.byType(TextField).first, 'Holiday');
    await tester.pump();

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();

    // The sheet closed; the screen is still here; the name is intact.
    expect(find.text('What are you adding?'), findsNothing);
    expect(find.byType(EditGoalScreen), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
  });

  testWidgets('a half-filled goal name is discarded silently when the type is '
      'switched — no confirmation dialog', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(_goalFlowHost(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Half typed');
    await tester.pump();

    await tester.tap(find.byType(TypePill));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    // No confirmation, no draft — the goal screen is simply gone.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.byType(QuickAddScreen), findsOneWidget);
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

  // ── §5 · header row height is unchanged by the pill ───────────────────────

  testWidgets('EditScaffold header row height is equal with and without a '
      'pill, across widths and text scales', (tester) async {
    Widget bare({required bool withPill, double textScale = 1.0}) => MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: EditScaffold(
            title: 'Edit goal',
            type: withPill ? QuickAddType.newGoal : null,
            onTypeTap: withPill ? () {} : null,
            children: const [],
          ),
        );

    double headerHeight(WidgetTester t) {
      // The outermost Row ancestor of "Cancel" is the header row itself
      // (nothing above it in the scaffold is a Row); any nearer Row would be an
      // internal one, so take the last.
      final row =
          find.ancestor(of: find.text('Cancel'), matching: find.byType(Row));
      return t.getSize(row.last).height;
    }

    for (final w in [390.0, 360.0, 320.0]) {
      for (final ts in [1.0, 1.3]) {
        _size(tester, w, 844);
        await tester.pumpWidget(bare(withPill: false, textScale: ts));
        final without = headerHeight(tester);
        await tester.pumpWidget(bare(withPill: true, textScale: ts));
        final with_ = headerHeight(tester);
        expect(with_, closeTo(without, 0.5),
            reason: 'pill must not move the header row at ${w}pt × $ts');
      }
    }
  });

  // ── §5 · 320pt, four locales, no overflow on either screen ────────────────

  testWidgets('no overflow at 320pt across en/ru/tk/tr on both creation screens',
      (tester) async {
    for (final code in ['en', 'ru', 'tk', 'tr']) {
      _size(tester, 320, 568);

      // New goal.
      await tester.pumpWidget(
          _host(AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32))), home: const EditGoalScreen(), locale: Locale(code)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'New goal overflow in $code');

      // New budget.
      final store = AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));
      final cat = _unbudgetedCategory(store);
      await tester.pumpWidget(_host(store,
          home: EditBudgetScreen(categoryId: cat.id), locale: Locale(code)));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'New budget overflow in $code');
    }
  });
}
