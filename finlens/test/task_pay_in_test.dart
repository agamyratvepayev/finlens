import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/shared/widgets/screen_header.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 030 — a scheduled task can be money coming in.
///
/// `flutter test` hangs on the dev machine — written, not run there; verify with
/// `flutter analyze`. Run yourself:
///   flutter test test/task_pay_in_test.dart

const _minus = '−'; // the true minus money() uses, not a hyphen

Category _cat(String id, String name, CategoryType type) => Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.category_rounded,
      color: const Color(0xFF34C759),
    );

/// One account, one expense and (optionally) one income category.
AppStore _store({bool income = true}) => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [
        Account(
          id: 'a1',
          name: 'Checking',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: [
        _cat('c-groceries', 'Groceries', CategoryType.expense),
        if (income) _cat('c-salary', 'Salary', CategoryType.income),
      ],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, void Function(BuildContext) onTap) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Widget _taskApp(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: const QuickAddScreen(initialType: QuickAddType.newTask),
      ),
    );

Widget _scheduleApp(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Scaffold(
          body: ScheduleTab(
            store: store,
            horizon: const ScheduleHorizon.preset(SchedulePreset.next30),
            onHorizonChange: (_) {},
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 350));

/// The amount row's value glyph is a `Text.rich`; the label and chip are plain
/// `Text`. Picks the value span out of the row.
TextSpan _valueSpan(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(TxnAmountFieldRow),
    matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
  );
  return tester.widget<Text>(finder).textSpan! as TextSpan;
}

/// Fills the task form: title, then a category via the two-sided sheet (unless
/// [pickTab] is null), then a typed amount. Leaves the sheet closed.
Future<void> _fillTask(
  WidgetTester tester, {
  required String title,
  String? pickTab, // 'Expense' | 'Income' | null → no category
  required String? categoryName,
  required List<String> keys,
}) async {
  await tester.enterText(find.byType(TextField).first, title);
  await _settle(tester);

  if (pickTab != null && categoryName != null) {
    await tester.tap(find.text('Category'));
    await _settle(tester);
    await tester.tap(find.text(pickTab));
    await _settle(tester);
    await tester.tap(find.text(categoryName));
    await _settle(tester);
  }

  await tester.tap(find.text('Amount'));
  await _settle(tester);
  for (final k in keys) {
    await tester.tap(find.text(k));
    await tester.pump();
  }
}

void main() {
  // ── §2 · the two-sided sheet ────────────────────────────────────────────────
  group('pickCategory · two-sided', () {
    testWidgets('two types raise a "Category" sheet with tabs, Expense active',
        (tester) async {
      final store = _store();
      await tester.pumpWidget(_host(
        store,
        (ctx) => pickCategory(ctx,
            type: CategoryType.expense,
            types: const [CategoryType.expense, CategoryType.income]),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      expect(find.text('Category'), findsOneWidget); // the sheet title
      expect(find.byType(SegmentedPicker<CategoryType>), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      // Expense opens first, so its category is shown and the income one is not.
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
    });

    testWidgets('switching to Income swaps the grid in place', (tester) async {
      final store = _store();
      await tester.pumpWidget(_host(
        store,
        (ctx) => pickCategory(ctx,
            type: CategoryType.expense,
            types: const [CategoryType.expense, CategoryType.income]),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.tap(find.text('Income'));
      await _settle(tester);

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
    });

    testWidgets('the Income tab with no categories shows the empty body '
        'and keeps + New', (tester) async {
      final store = _store(income: false);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(_host(
        store,
        (ctx) => pickCategory(ctx,
            type: CategoryType.expense,
            types: const [CategoryType.expense, CategoryType.income]),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.tap(find.text('Income'));
      await _settle(tester);

      // The tab strip stays; the empty body appears; + New is still in the header.
      expect(find.byType(SegmentedPicker<CategoryType>), findsOneWidget);
      expect(find.text(l.qaNoCategoriesYet), findsOneWidget);
      expect(find.text(l.qaNewShort), findsOneWidget);
    });

    testWidgets('+ New on the Income tab opens the new-income-category form',
        (tester) async {
      final store = _store();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(_host(
        store,
        (ctx) => pickCategory(ctx,
            type: CategoryType.expense,
            types: const [CategoryType.expense, CategoryType.income]),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.tap(find.text('Income'));
      await _settle(tester);
      await tester.tap(find.text(l.qaNewShort));
      await _settle(tester);

      // The create form the active (Income) tab raised.
      expect(find.text(l.qaNewIncomeCategory), findsOneWidget);
      expect(find.text(l.qaNewExpenseCategory), findsNothing);
    });
  });

  // ── §2 · single-type callers are unchanged ──────────────────────────────────
  group('pickCategory · single type unchanged', () {
    testWidgets('no types → per-type title and no tab strip', (tester) async {
      final store = _store();
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(_host(
        store,
        (ctx) => pickCategory(ctx, type: CategoryType.expense),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      expect(find.text(l.qaExpenseCategory), findsOneWidget);
      expect(find.byType(SegmentedPicker<CategoryType>), findsNothing);
    });
  });

  // ── §3 · the side that was picked is the sign ────────────────────────────────
  group('task save · sign follows the category', () {
    testWidgets('an income category saves expectedAmount > 0', (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'Rent from tenant',
          pickTab: 'Income',
          categoryName: 'Salary',
          keys: ['1', '2', '0', '0']);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final t = store.tasks.firstWhere((t) => t.title == 'Rent from tenant');
      expect(t.expectedAmount, 1200);
      expect(t.isPayOut, isFalse);
      expect(t.categoryId, 'c-salary');
    });

    testWidgets('an expense category saves expectedAmount < 0', (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'Water bill',
          pickTab: 'Expense',
          categoryName: 'Groceries',
          keys: ['6', '0']);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final t = store.tasks.firstWhere((t) => t.title == 'Water bill');
      expect(t.expectedAmount, -60);
      expect(t.isPayOut, isTrue);
    });

    testWidgets('no category saves expectedAmount < 0 (pay-out default)',
        (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'Call plumber',
          pickTab: null,
          categoryName: null,
          keys: ['4', '0']);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final t = store.tasks.firstWhere((t) => t.title == 'Call plumber');
      expect(t.expectedAmount, -40);
      expect(t.isPayOut, isTrue);
    });

    testWidgets('switching income → expense before saving flips the sign',
        (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      // Pick income first…
      await _fillTask(tester,
          title: 'Maybe income',
          pickTab: 'Income',
          categoryName: 'Salary',
          keys: ['9', '9']);
      // …then reopen and pick an expense category (the sheet reopens on Expense).
      await tester.tap(find.text('Category'));
      await _settle(tester);
      await tester.tap(find.text('Groceries'));
      await _settle(tester);

      await tester.tap(find.text('Save'));
      await _settle(tester);

      final t = store.tasks.firstWhere((t) => t.title == 'Maybe income');
      expect(t.expectedAmount, -99);
    });
  });

  // ── §3 · the Amount row shows the sign ───────────────────────────────────────
  group('task amount row · signed by direction', () {
    testWidgets('income → + and positive colour', (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'Salary',
          pickTab: 'Income',
          categoryName: 'Salary',
          keys: ['5', '0', '0']);

      final span = _valueSpan(tester);
      expect(span.toPlainText().startsWith('+'), isTrue);
      final first = span.children!.first as TextSpan;
      expect(first.text, '+');
      expect(first.style!.color, AppColors.positive);
    });

    testWidgets('expense → − and negative colour', (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'Rent',
          pickTab: 'Expense',
          categoryName: 'Groceries',
          keys: ['5', '0']);

      final span = _valueSpan(tester);
      expect(span.toPlainText().startsWith(_minus), isTrue);
      final first = span.children!.first as TextSpan;
      expect(first.text, _minus);
      expect(first.style!.color, AppColors.negative);
    });

    testWidgets('no category → neither sign, neutral colour', (tester) async {
      final store = _store();
      await tester.pumpWidget(_taskApp(store));
      await _settle(tester);

      await _fillTask(tester,
          title: 'No category',
          pickTab: null,
          categoryName: null,
          keys: ['5', '0']);

      final span = _valueSpan(tester);
      final plain = span.toPlainText();
      expect(plain.contains('+'), isFalse);
      expect(plain.contains(_minus), isFalse);
      final first = span.children!.first as TextSpan;
      expect(first.style!.color, AppColors.textPrimary);
    });
  });

  // ── §3 · a form pay-in renders identically to an edit-screen pay-in ──────────
  testWidgets('a form pay-in shows green on the Schedule, like an edit pay-in',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_taskApp(store));
    await _settle(tester);

    await _fillTask(tester,
        title: 'FormPayIn',
        pickTab: 'Income',
        categoryName: 'Salary',
        keys: ['1', '0', '0']);
    await tester.tap(find.text('Save'));
    await _settle(tester);

    // What EditTaskScreen produces for a pay-in: a positive expectedAmount.
    store.addTask(
      title: 'EditPayIn',
      linkedAccountId: 'a1',
      expectedAmount: 100,
      dueDate: store.today,
      icon: Icons.category_rounded,
      categoryId: 'c-salary',
    );

    await tester.pumpWidget(_scheduleApp(store));
    await tester.pump(const Duration(milliseconds: 300));

    Color amountColor(String title) {
      final finder = find.descendant(
        of: find.ancestor(
            of: find.text(title), matching: find.byType(InkWell)),
        matching: find.byType(AmountText),
      );
      return tester.widget<AmountText>(finder.first).color!;
    }

    expect(amountColor('FormPayIn'), AppColors.positive);
    expect(amountColor('EditPayIn'), AppColors.positive);
    expect(amountColor('FormPayIn'), amountColor('EditPayIn'));
  });
}
