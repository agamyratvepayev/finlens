import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/repeat_labels.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/planner/task_detail_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/shared/widgets/screen_header.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task063_edit_scheduled_item_test.dart
//
// Task 063 — the note survives, rows say what they hold, and a receivable is
// an earning. `today` is pinned to 2026-08-09.

final _today = DateTime(2026, 8, 9, 14, 32);

AppStore _store({List<Task> tasks = const []}) => AppStore(
      clock: Clock.fixed(_today),
      accounts: [
        Account(
            id: 'a1',
            name: 'Halkbank Main Account',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 1000),
        Account(
            id: 'a2',
            name: 'Savings',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 500),
        Account(
            id: 'rhk',
            name: 'Rowshen HK',
            group: AccountGroup.receivables,
            currency: 'USD',
            startingBalance: 0),
        Account(
            id: 'card',
            name: 'Visa Card',
            group: AccountGroup.creditCards,
            currency: 'USD',
            startingBalance: -100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.local_grocery_store_rounded,
            color: const Color(0xFF34C759)),
        Category(
            id: 'sal',
            name: 'Salary',
            type: CategoryType.income,
            icon: Icons.payments_rounded,
            color: const Color(0xFF30D158)),
      ],
      txns: const [],
      goals: const [],
      tasks: tasks,
    );

Task _task(
  String id, {
  double amount = -50,
  String account = 'a1',
  DateTime? due,
  String? note,
  String? categoryId,
  RepeatFrequency repeats = RepeatFrequency.none,
  Set<int> daysOfMonth = const {},
  DateTime? endDate,
  int? endCount,
}) =>
    Task(
      id: id,
      title: id,
      linkedAccountId: account,
      expectedAmount: amount,
      dueDate: due ?? DateTime(2026, 8, 20),
      icon: Icons.receipt_long_rounded,
      note: note,
      categoryId: categoryId,
      repeats: repeats,
      daysOfMonth: daysOfMonth,
      repeatEndDate: endDate,
      repeatEndCount: endCount,
    );

final _navKey = GlobalKey<NavigatorState>();

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        navigatorKey: _navKey,
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    );

Future<void> _push(WidgetTester tester, Widget screen) async {
  _navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

Finder _rowOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FormRow)).first;

void main() {
  // ── §1 · the note ────────────────────────────────────────────────────────────
  group('the note is kept', () {
    test('addTask stores a trimmed note; empty stores null', () {
      final store = _store();
      final a = store.addTask(
          title: 'A',
          linkedAccountId: 'a1',
          expectedAmount: -5,
          dueDate: _today,
          icon: Icons.circle,
          note: '  x  ');
      expect(a.note, 'x');
      final b = store.addTask(
          title: 'B',
          linkedAccountId: 'a1',
          expectedAmount: -5,
          dueDate: _today,
          icon: Icons.circle,
          note: '   ');
      expect(b.note, isNull);
    });

    testWidgets('Quick Add ▸ Schedule passes the note to the task',
        (tester) async {
      final store = _store();
      await tester.pumpWidget(_host(store));
      await _push(
          tester, const QuickAddScreen(initialType: QuickAddType.newTask));

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Rent'); // the title hero
      await tester.enterText(fields.last, 'pay before the 5th'); // Add note
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.note, 'pay before the 5th');
    });

    testWidgets(
        'a repeating expense keeps the note as a note; the category names '
        'the series', (tester) async {
      final store = _store();
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const QuickAddScreen(
            initialType: QuickAddType.expense,
            fixedFromAccountId: 'a1',
            fixedToAccountId: 'g',
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('5')); // amount on the keypad
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'RHK Earned - Mine');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.title, 'Groceries',
          reason: 'the note is never the series title (task 063 §1c)');
      expect(store.tasks.single.note, 'RHK Earned - Mine');
    });

    testWidgets('a repeating transfer with no category titles qaRecurring',
        (tester) async {
      final store = _store();
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const QuickAddScreen(
            initialType: QuickAddType.transfer,
            fixedFromAccountId: 'a1',
            fixedToAccountId: 'a2',
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('5'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.title, 'Recurring');
    });

    testWidgets('Edit shows a saved note stacked, and a change round-trips',
        (tester) async {
      final store =
          _store(tasks: [_task('t1', note: 'RHK Earned - Mine')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));

      // Stacked (§D.7): the label is a caption above the wrapping text.
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('RHK Earned - Mine'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField).last, 'RHK Earned - Updated');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.taskById('t1')!.note, 'RHK Earned - Updated');
    });
  });

  // ── §2 · the account row is one line ────────────────────────────────────────
  testWidgets('the account row is one 48pt line with the name as its value',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store(tasks: [_task('t1')]);
    await tester.pumpWidget(_host(store));
    await _push(tester, const EditTaskScreen(taskId: 't1'));

    final row = _rowOf('Paid from');
    expect(tester.getSize(row).height, 48);
    expect(
        find.descendant(
            of: row, matching: find.text('Halkbank Main Account')),
        findsOneWidget);
  });

  // ── §3 · Direction is dense; the Goal picker is untouched ───────────────────
  testWidgets('the Direction control is ≤ 31pt tall', (tester) async {
    final store = _store(tasks: [_task('t1')]);
    await tester.pumpWidget(_host(store));
    await _push(tester, const EditTaskScreen(taskId: 't1'));

    final picker = find.byType(SegmentedPicker<bool>);
    expect(picker, findsOneWidget);
    expect(tester.getSize(picker).height, lessThanOrEqualTo(31));
    expect(tester.getSize(_rowOf('Direction')).height, 48);
  });

  // ── §5 · Paid to ─────────────────────────────────────────────────────────────
  group('Paid to', () {
    testWidgets('empty reads Choose category; chosen shows tile and name',
        (tester) async {
      final store = _store(tasks: [_task('t1')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));
      expect(find.text('Choose category'), findsOneWidget);
      expect(find.text('Where "Mark as paid" books it'), findsNothing);

      final store2 = _store(tasks: [_task('t2', categoryId: 'g')]);
      await tester.pumpWidget(_host(store2));
      await _push(tester, const EditTaskScreen(taskId: 't2'));
      final row = _rowOf('Paid to');
      expect(find.descendant(of: row, matching: find.text('Groceries')),
          findsOneWidget);
      expect(
          find.descendant(
              of: row,
              matching: find.byIcon(Icons.local_grocery_store_rounded)),
          findsOneWidget);
    });

    testWidgets('the destination sheet opens full, groups render, search '
        'filters both', (tester) async {
      final store = _store(tasks: [_task('t1')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));

      await tester.tap(find.text('Choose category'));
      await tester.pumpAndSettle();

      // Titled after the row; both groups visible.
      expect(find.text('Paid to'), findsWidgets); // row + sheet title
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Visa Card'), findsOneWidget);
      expect(find.text('Transfer — no budget category'), findsOneWidget);

      // Search filters both groups by name.
      await tester.enterText(find.byType(TextField).last, 'visa');
      await tester.pumpAndSettle();
      expect(find.text('Visa Card'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('CATEGORY'), findsNothing,
          reason: 'a group label never renders over zero rows');
    });
  });

  // ── §6 · a late due date says so ─────────────────────────────────────────────
  testWidgets('a late due date reads … · 1 day late in red', (tester) async {
    final store = _store(tasks: [_task('t1', due: DateTime(2026, 8, 8))]);
    await tester.pumpWidget(_host(store));
    await _push(tester, const EditTaskScreen(taskId: 't1'));

    final late = find.text('8 Aug · 1 day late');
    expect(late, findsOneWidget);
    expect(tester.widget<Text>(late).style?.color, AppColors.negative);
  });

  // ── §7 · repeats: last day, and the end ─────────────────────────────────────
  group('repeats', () {
    test('monthly on 31 or the sentinel reads last day; 30 keeps its ordinal',
        () async {
      // A pure label check through the real localizations.
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
          repeatCadenceLabel(
              RepeatFrequency.monthly, const {}, const {31}, _today, l),
          'Every month on the last day');
      expect(
          repeatCadenceLabel(RepeatFrequency.monthly, const {},
              const {kLastDayOfMonth}, _today, l),
          'Every month on the last day');
      expect(
          repeatCadenceLabel(
              RepeatFrequency.monthly, const {}, const {30}, _today, l),
          contains('30th'));
    });

    testWidgets('an end count reads · 12 times after the preview',
        (tester) async {
      final store = _store(tasks: [
        _task('t1',
            repeats: RepeatFrequency.monthly, daysOfMonth: {31}, endCount: 12)
      ]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));

      expect(find.text('Repeats every month on the last day'), findsOneWidget);
      expect(find.textContaining('12 times', findRichText: true),
          findsOneWidget);
    });

    testWidgets('an end date reads · last {date}; no end reads nothing',
        (tester) async {
      final store = _store(tasks: [
        _task('e1',
            repeats: RepeatFrequency.monthly,
            daysOfMonth: {15},
            endDate: DateTime(2027, 3, 1)),
      ]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 'e1'));
      expect(find.textContaining('last 1 Mar 2027', findRichText: true),
          findsOneWidget);

      final store2 = _store(tasks: [
        _task('e2', repeats: RepeatFrequency.monthly, daysOfMonth: {15}),
      ]);
      await tester.pumpWidget(_host(store2));
      await _push(tester, const EditTaskScreen(taskId: 'e2'));
      expect(find.textContaining('times', findRichText: true), findsNothing);
      expect(find.textContaining('last ', findRichText: true), findsNothing);
    });
  });

  // ── §8 · a receivable is an earning ─────────────────────────────────────────
  group('receivables', () {
    testWidgets('no Direction, Owed by + caption, income categories',
        (tester) async {
      final store =
          _store(tasks: [_task('t1', amount: 20000, account: 'rhk')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));

      expect(find.text('Direction'), findsNothing);
      expect(find.text('Owed by'), findsOneWidget);
      expect(find.text('Adds to what they owe you'), findsOneWidget);
      expect(find.text('Paid to'), findsNothing);
      expect(find.text('Category'), findsOneWidget);

      // The category picker offers income categories only.
      await tester.tap(find.text('Choose category'));
      await tester.pumpAndSettle();
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
    });

    testWidgets('a stored pay-out on a receivable is forced to an earning',
        (tester) async {
      // The device bug: the user's earning was saved as a pay-out.
      final store =
          _store(tasks: [_task('t1', amount: -20000, account: 'rhk')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));

      expect(find.text('Direction'), findsNothing);
      expect(find.text('Owed by'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.taskById('t1')!.expectedAmount, greaterThan(0),
          reason: 'saving from receivable mode stores a pay-in');
    });

    testWidgets('switching the account away from a receivable restores '
        'Direction with pay-in selected', (tester) async {
      final store =
          _store(tasks: [_task('t1', amount: 20000, account: 'rhk')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 't1'));
      expect(find.text('Direction'), findsNothing);

      await tester.tap(find.text('Rowshen HK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Savings').last);
      await tester.pumpAndSettle();

      expect(find.text('Direction'), findsOneWidget);
      final picker = tester
          .widget<SegmentedPicker<bool>>(find.byType(SegmentedPicker<bool>));
      expect(picker.selected, isFalse, reason: 'pay-in stays selected');
    });

    testWidgets('Task detail reads Record earning with the owes-more line',
        (tester) async {
      final store =
          _store(tasks: [_task('t1', amount: 20000, account: 'rhk')]);
      await tester.pumpWidget(_host(store));
      await _push(tester, const TaskDetailScreen(taskId: 't1'));

      expect(find.text('Record earning'), findsOneWidget);
      expect(find.text('Mark as received'), findsNothing);
      expect(find.textContaining('Rowshen HK will owe you'), findsOneWidget);
    });

    test('recording books the income and the receivable balance rises', () {
      final store =
          _store(tasks: [_task('t1', amount: 20000, account: 'rhk')]);
      final before = store.balanceOf('rhk');
      store.markTaskPaid(store.taskById('t1')!,
          amount: 20000,
          date: DateTime(2026, 8, 9),
          fromAccountId: 'rhk',
          toRef: 'sal');
      expect(store.balanceOf('rhk'), before + 20000,
          reason: 'booking is untouched — an income into the receivable');
    });
  });
}
