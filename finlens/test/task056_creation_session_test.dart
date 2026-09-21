import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/quick_add/creation_host.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 056 — one creation session. Switching type hides a form instead of
// destroying it, so every form keeps what was typed until the session closes
// (Save, Cancel or the system back gesture). `flutter test` hangs on the
// author's machine — these are written, not run here; verify with
// `flutter analyze` and run the files yourself.

Clock get _clock => Clock.fixed(DateTime(2026, 8, 9, 14, 32));

void _size(WidgetTester tester, [double w = 390, double h = 844]) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _host(AppStore store, {required Widget home}) => StoreScope(
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

/// A bare screen whose one button opens Quick Add — the real entry point, so a
/// creation session is what gets pushed.
Widget _launcher(
  AppStore store, {
  QuickAddType type = QuickAddType.expense,
  Txn? copyOf,
  Txn? editing,
}) =>
    _host(
      store,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showQuickAdd(context, type: type, copyOf: copyOf, editing: editing),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

/// Open the type menu from whichever form is on stage and pick [label].
Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(find.byType(TypePill));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Account _account(AppStore store, String name) => store.addAccount(
      name: name,
      group: AccountGroup.spendable,
      currency: store.baseCurrency,
      startingBalance: 100,
    );

Category _expenseCat(AppStore store, String name) => store.addCategory(
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: Colors.orange,
    );

void main() {
  // ── Schedule (filled) → Goal → Schedule keeps every field ──────────────────
  testWidgets('Schedule → Goal → Schedule keeps the title and the account',
      (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newTask));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(find.byType(EditGoalScreen), findsNothing);

    // Type a title, pick an account.
    await tester.enterText(find.byType(TextField).first, 'RHK Salary');
    await tester.pump();
    await tester.tap(find.text('Choose account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rowshen HK'));
    await tester.pumpAndSettle();
    expect(find.text('Rowshen HK'), findsOneWidget);

    // → Goal. The goal form is on stage; the Quick Add form is hidden.
    await _pick(tester, 'Goal');
    expect(find.byType(EditGoalScreen), findsOneWidget);
    expect(find.text('Target amount'), findsOneWidget);
    expect(find.byType(QuickAddScreen), findsNothing);

    // → Schedule. Everything is exactly as it was left.
    await _pick(tester, 'Schedule');
    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(find.byType(EditGoalScreen), findsNothing);
    expect(find.text('RHK Salary'), findsOneWidget);
    expect(find.text('Rowshen HK'), findsOneWidget);
  });

  // ── Goal (name typed) → Schedule → Goal keeps the name ─────────────────────
  testWidgets('Goal → Schedule → Goal keeps the goal name', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newGoal));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(EditGoalScreen), findsOneWidget);

    // The goal name is the first field.
    await tester.enterText(find.byType(TextField).first, 'New car');
    await tester.pump();

    await _pick(tester, 'Schedule');
    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(find.byType(EditGoalScreen), findsNothing);

    await _pick(tester, 'Goal');
    expect(find.byType(EditGoalScreen), findsOneWidget);
    expect(find.text('New car'), findsOneWidget);
  });

  // ── Expense (Groceries) → Income → Expense brings the category back ─────────
  testWidgets('Expense → Income → Expense restores category and account',
      (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final bank = _account(store, 'Bank Card');
    final groceries = _expenseCat(store, 'Groceries');
    final expense = store.addTxn(
      type: TxnType.expense,
      amount: 42,
      currency: store.baseCurrency,
      fromRef: bank.id,
      toRef: groceries.id,
      date: DateTime(2026, 8, 9),
    );

    await tester.pumpWidget(_launcher(store, copyOf: expense));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The copy pre-fills From (Bank Card) and To (Groceries).
    expect(find.text('Bank Card'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    await _pick(tester, 'Income');
    // On Income, Groceries (an expense category) no longer fits the From slot.
    expect(find.text('Groceries'), findsNothing);

    await _pick(tester, 'Expense');
    // Expense's own refs return.
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Bank Card'), findsOneWidget);
  });

  // ── Cancel on the goal form after a switch closes the whole session ─────────
  testWidgets('Cancel on the goal form closes the session; next + is empty',
      (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newTask));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'RHK Salary');
    await tester.pump();

    await _pick(tester, 'Goal');
    expect(find.byType(EditGoalScreen), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Nothing is left of the session.
    expect(find.byType(CreationHost), findsNothing);
    expect(find.byType(QuickAddScreen), findsNothing);
    expect(find.byType(EditGoalScreen), findsNothing);

    // A fresh session opens empty.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('What needs doing?'), findsOneWidget);
    expect(find.text('RHK Salary'), findsNothing);
  });

  // ── System back closes the whole session ───────────────────────────────────
  testWidgets('system back on the goal form closes the session', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newTask));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _pick(tester, 'Goal');
    expect(find.byType(EditGoalScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CreationHost), findsNothing);
  });

  // ── Save closes the session ────────────────────────────────────────────────
  testWidgets('saving the schedule entry closes the session', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newTask));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'RHK Salary');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(CreationHost), findsNothing);
    expect(store.tasks.any((t) => t.title == 'RHK Salary'), isTrue);
  });

  // ── Editing an existing entry is untouched (no session, locked pill) ────────
  testWidgets('editing pushes QuickAddScreen directly, no host, locked pill',
      (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final bank = _account(store, 'Bank Card');
    final groceries = _expenseCat(store, 'Groceries');
    final txn = store.addTxn(
      type: TxnType.expense,
      amount: 42,
      currency: store.baseCurrency,
      fromRef: bank.id,
      toRef: groceries.id,
      date: DateTime(2026, 8, 9),
    );

    await tester.pumpWidget(_launcher(store, editing: txn));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(find.byType(CreationHost), findsNothing);
    // The pill is locked — a padlock, not a chevron.
    expect(
      find.descendant(
          of: find.byType(TypePill), matching: find.byIcon(Icons.lock_rounded)),
      findsOneWidget,
    );
  });

  // ── A hidden form takes no focus ───────────────────────────────────────────
  testWidgets('after switching to Goal, the Quick Add title holds no focus',
      (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _account(store, 'Rowshen HK');

    await tester.pumpWidget(_launcher(store, type: QuickAddType.newTask));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'RHK Salary');
    await tester.pump();

    await _pick(tester, 'Goal');
    // The keyboard is closed and the hidden Quick Add title holds no focus: no
    // editable anywhere in the session reports focus while Goal is on stage.
    // (find.byType includes offstage widgets when skipOffstage is false, so this
    // reaches the hidden form's fields too.)
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText, skipOffstage: false))
          .any((e) => e.focusNode.hasFocus),
      isFalse,
    );
  });
}
