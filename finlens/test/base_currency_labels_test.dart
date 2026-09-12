import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/planner/mark_paid_sheet.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/base_currency_labels_test.dart
//
// Task 19 + Task 21: money()/moneyCompact()/AmountText and the six on-screen
// currency labels that supplied a literal 'USD' now follow the store's base
// currency (or the relevant account/transaction currency). With the base = USD
// every one of these is byte-identical to before (the §4 regression), so the
// tests deliberately use a TMT base — where a stray dollar would show.

AppStore _store({
  List<Category> categories = const [],
  List<Task> tasks = const [],
  String currency = 'TMT',
}) =>
    AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'Main',
          group: AccountGroup.spendable,
          currency: currency,
          startingBalance: 0,
        ),
      ],
      categories: categories,
      txns: const [],
      goals: const [],
      tasks: tasks,
    );

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  // The formatter base is process-global; leave it as the code's own floor so a
  // test that set it to TMT cannot leak into a neighbour.
  tearDown(() => setFormatterBaseCurrency('USD'));

  group('Task 19 — money()/moneyCompact() default to the base', () {
    test('an omitted currency follows the module base; an explicit one wins',
        () {
      // Baseline (this is exactly the pre-Task-19 behaviour, kept as a guard):
      // with the base at USD, a bare money() is a dollar figure.
      setFormatterBaseCurrency('USD');
      expect(money(500), money(500, currency: 'USD'));
      expect(moneyCompact(12000), moneyCompact(12000, currency: 'USD'));

      // Move the base to TMT: a bare money() now follows it. Before Task 19 this
      // expectation FAILED — money(500) was '\$500', not the TMT form.
      setFormatterBaseCurrency('TMT');
      expect(money(500), money(500, currency: 'TMT'));
      expect(moneyCompact(12000), moneyCompact(12000, currency: 'TMT'));

      // An explicit argument is untouched by the base.
      expect(money(500, currency: 'USD'), money(500, currency: 'USD'));
      expect(money(500, currency: 'USD'), isNot(money(500)));
    });
  });

  group('Task 21 — AmountText', () {
    testWidgets('with no currency renders in the base', (tester) async {
      final store = _store();
      expect(store.baseCurrency, 'TMT');
      await tester.pumpWidget(
          _host(store, const Scaffold(body: Center(child: AmountText(1234)))));
      await tester.pumpAndSettle();

      expect(find.text(money(1234, currency: 'TMT')), findsOneWidget);
      expect(find.text(money(1234, currency: 'USD')), findsNothing);
    });

    testWidgets('with an explicit currency ignores the base', (tester) async {
      final store = _store();
      await tester.pumpWidget(_host(
          store,
          const Scaffold(
              body: Center(child: AmountText(1234, currency: 'USD')))));
      await tester.pumpAndSettle();

      expect(find.text(money(1234, currency: 'USD')), findsOneWidget);
    });
  });

  group('Task 21 — the budget limit row', () {
    testWidgets('its currency marker follows the base, never a dollar',
        (tester) async {
      final store = _store(categories: []);
      final cat = store.addCategory(
        name: 'Groceries',
        type: CategoryType.expense,
        icon: Icons.circle,
        color: const Color(0xFF34C759),
        monthlyBudget: 500,
      );
      await tester.pumpWidget(_host(store, EditBudgetScreen(categoryId: cat.id)));
      await tester.pumpAndSettle();

      // The trailing marker names the base (TMT → "m"); no dollar marker
      // survives anywhere on the screen.
      expect(find.text(currencySymbol('TMT')), findsWidgets);
      expect(find.text(currencySymbol('USD')), findsNothing); // a bare '$'
    });
  });

  group('Task 21 — the task editor', () {
    testWidgets('the amount marker falls back to the base with no account',
        (tester) async {
      final task = Task(
        id: 't1',
        title: 'Rent',
        linkedAccountId: '', // no account chosen yet
        expectedAmount: 0,
        dueDate: AppStore.today,
        icon: Icons.home_rounded,
      );
      final store = _store(tasks: [task]);
      await tester.pumpWidget(_host(store, const EditTaskScreen(taskId: 't1')));
      await tester.pumpAndSettle();

      expect(find.text(currencySymbol('TMT')), findsWidgets);
      expect(find.text(currencySymbol('USD')), findsNothing);
    });
  });

  group('Task 21 — the mark-paid sheet', () {
    testWidgets('the amount falls back to the base when the account is gone',
        (tester) async {
      final task = Task(
        id: 't1',
        title: 'Rent',
        linkedAccountId: 'gone', // resolves to null → base fallback
        expectedAmount: 0,
        dueDate: AppStore.today,
        icon: Icons.home_rounded,
      );
      final store = _store(tasks: [task]);
      await tester.pumpWidget(_host(
        store,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showMarkPaidSheet(context, task: task),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The hero renders the amount in the base (TMT → an "m…" figure); a
      // dollar figure would mean the old `?? 'USD'` fallback survived.
      expect(find.text(money(0, currency: 'TMT')), findsOneWidget);
      expect(find.text(money(0, currency: 'USD')), findsNothing);
    });
  });

  group('Task 21 — Quick Add records the account/base currency, not USD', () {
    testWidgets('a saved expense with a pre-fixed account is stored in its '
        'currency, never a hard-coded dollar', (tester) async {
      final store = _store(
        categories: [
          Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759),
          ),
        ],
      );
      expect(store.baseCurrency, 'TMT');

      // Account Detail's "Add expense" opens Quick Add with the account (and
      // here the category) pre-fixed, so Save needs no pickers — the exact path
      // where the picker never ran and `_currency` used to stay 'USD'.
      await tester.pumpWidget(_host(
        store,
        const QuickAddScreen(
          initialType: QuickAddType.expense,
          fixedFromAccountId: 'a1', // the TMT account
          fixedToAccountId: 'g', // (ab)used to pre-fill the category ref
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.txns.single.currency, 'TMT');
      expect(store.txns.single.currency, isNot('USD'));
    });
  });
}
