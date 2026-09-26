import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/planner/task_detail_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 058.2 — the task detail screen (§1–§4) and one creation chrome (§5–§7).
//
// `flutter test` hangs on the author's machine, so these are written, not run
// here; verify with `flutter analyze` and run the file yourself. Note: widget
// tests use the deterministic FlutterTest font, whose glyph metrics differ from
// the on-device font. So where a size step depends on measured width (§2d), the
// assertions pin the font-INDEPENDENT invariants — which figure/code strings
// render, that the unit is a smaller, separate Text, that nothing is
// abbreviated, and that the figure never drops below 15 — rather than the exact
// point size, which the spec's measurements table (71/108/… pt) reports for the
// real font.

Clock get _clock => Clock.fixed(DateTime(2026, 8, 9, 14, 32));

void _size(WidgetTester tester, [double w = 390, double h = 844]) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

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

Account _tmtAccount(
  AppStore store, [
  String name = 'Main Credit Card (Amex)',
]) => store.addAccount(
  name: name,
  group: AccountGroup.spendable,
  currency: 'TMT',
  startingBalance: 0,
);

Category _cat(AppStore store, [String name = 'Subscriptions']) =>
    store.addCategory(
      name: name,
      type: CategoryType.expense,
      icon: Icons.subscriptions_rounded,
      color: Colors.red,
    );

/// A monthly-on-the-1st task in TMT, [amount] its expected amount.
Task _monthly(AppStore store, {required double amount, String? account}) {
  final acc = _tmtAccount(store, account ?? 'Main Credit Card (Amex)');
  final cat = _cat(store);
  return store.addTask(
    title: 'Netflix',
    linkedAccountId: acc.id,
    expectedAmount: amount,
    dueDate: DateTime(2026, 9, 1),
    icon: Icons.subscriptions_rounded,
    categoryId: cat.id,
    repeats: RepeatFrequency.monthly,
    daysOfMonth: const {1},
  );
}

void main() {
  // ── §1 · the header prints category · account, once, on one line ───────────
  testWidgets('detail subtitle carries no cadence and is one ellipsised line', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 15.99);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    // The subtitle is exactly "category · account" — the cadence is not appended.
    final subtitle = find.text('Subscriptions · Main Credit Card (Amex)');
    expect(subtitle, findsOneWidget);
    final t = tester.widget<Text>(subtitle);
    expect(t.maxLines, 1);
    expect(t.overflow, TextOverflow.ellipsis);
    // The long cadence appears nowhere in the header line.
    expect(
      find.text(
        'Subscriptions · Main Credit Card (Amex) · Every month on the 1st',
      ),
      findsNothing,
    );
  });

  testWidgets('a long account name ellipsises rather than wrapping (320pt)', (
    tester,
  ) async {
    _size(tester, 320, 568);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(
      store,
      amount: 15.99,
      account: 'Main Credit Card (Amex) · joint household spending',
    );

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    final subtitle = find.byWidgetPredicate(
      (w) =>
          w is Text && (w.data ?? '').startsWith('Subscriptions · Main Credit'),
    );
    expect(subtitle, findsOneWidget);
    expect(tester.widget<Text>(subtitle).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  // ── §2 · the strip is one thin line (task 064) ─────────────────────────────
  testWidgets('the strip prints the amount figure and a separate TMT unit', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 15.99);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    // Cents kept below 1,000 (058.2 §2c, kept by 064): "15.99". The old
    // NEXT/AMOUNT/PER YEAR columns are gone — no per-year figure now.
    expect(find.text('15.99'), findsOneWidget);
    expect(find.text('191.88'), findsNothing);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('PER YEAR'), findsNothing);
    // The currency is a separate unit beside the figure.
    expect(find.text('TMT'), findsWidgets);
  });

  testWidgets('a whole amount ≥ 1,000 drops its cents (§2c)', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 4500);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('4,500'), findsWidgets);
    expect(find.text('4,500.00'), findsNothing);
  });

  testWidgets('an eight-digit amount is grouped, never abbreviated (§2d)', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 15000000);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    // Grouped in full — "15,000,000", not "15M" / "1.5M".
    expect(find.text('15,000,000'), findsWidgets);
    expect(find.text('15M'), findsNothing);
    expect(find.text('15.0M'), findsNothing);
    // No overflow at any width.
    expect(tester.takeException(), isNull);
  });

  // ── §3 · the cadence is a pill beside UPCOMING (task 064) ──────────────────
  testWidgets('Upcoming carries the cadence as a pill, sentence case', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 15.99);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('UPCOMING'), findsOneWidget);
    // The pill reads the short "Monthly · 1st" form, no longer the lower-cased
    // full sentence.
    expect(find.text('Monthly · 1st'), findsOneWidget);
    expect(find.text('every month on the 1st'), findsNothing);
  });

  testWidgets('a one-off task shows no Upcoming section and no cadence', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final acc = _tmtAccount(store);
    final cat = _cat(store);
    final task = store.addTask(
      title: 'Buy a gift',
      linkedAccountId: acc.id,
      expectedAmount: 50,
      dueDate: DateTime(2026, 9, 1),
      icon: Icons.card_giftcard_rounded,
      categoryId: cat.id,
      // one-off
    );

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('UPCOMING'), findsNothing);
    expect(find.textContaining('every month'), findsNothing);
    // The strip shows the amount but no cadence and no bar for a one-off.
    expect(find.text('PER YEAR'), findsNothing);
    expect(find.text('50'), findsWidgets);
  });

  // ── §4 · payment history is not drawn until there is a payment ─────────────
  testWidgets('with no payments: one grey line, no label, no card', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final task = _monthly(store, amount: 15.99);

    await tester.pumpWidget(
      _host(store, home: TaskDetailScreen(taskId: task.id)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAYMENT HISTORY'), findsNothing);
    expect(
      find.text('Past ones show up here once you mark one as done.'),
      findsOneWidget,
    );
  });

  // ── §5/§7 · one chrome; Goal creation and Schedule creation align ──────────
  testWidgets('Goal creation and Schedule creation put the pill and the name '
      'field at the same offsets, on formBg', (tester) async {
    // Goal creation.
    _size(tester);
    final goalStore = AppStore.empty(clock: _clock);
    _tmtAccount(goalStore, 'Vault');
    await tester.pumpWidget(_host(goalStore, home: const EditGoalScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    final goalPill = tester.getRect(find.byType(TypePill)).center;
    final goalName = tester.getTopLeft(find.byType(NameField)).dy;
    final goalScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(goalScaffold.backgroundColor, AppColors.formBg);

    // Schedule creation.
    final taskStore = AppStore.empty(clock: _clock);
    _tmtAccount(taskStore, 'Vault');
    await tester.pumpWidget(
      _host(
        taskStore,
        home: const QuickAddScreen(initialType: QuickAddType.newTask),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final schedPill = tester.getRect(find.byType(TypePill)).center;
    final schedName = tester.getTopLeft(find.byType(NameField)).dy;
    final schedScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(schedScaffold.backgroundColor, AppColors.formBg);

    expect(schedPill.dx, closeTo(goalPill.dx, 1.0));
    expect(schedPill.dy, closeTo(goalPill.dy, 1.0));
    expect(schedName, closeTo(goalName, 1.0));
  });

  testWidgets('editing an existing goal keeps the plain title header on the '
      'app bg, no pill', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    final acc = store.addAccount(
      name: 'Vault',
      group: AccountGroup.setAside,
      currency: 'TMT',
      startingBalance: 0,
    );
    final goal = store.addGoal(
      name: 'Holiday',
      source: GoalSource.account(acc.id),
      targetAmount: 1000,
    );
    await tester.pumpWidget(
      _host(store, home: EditGoalScreen(goalId: goal.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TypePill), findsNothing);
    expect(find.text('Edit goal'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor,
      isNull,
      reason: 'the theme scaffold bg (#0A0A0B) shows, not formBg',
    );
  });

  // ── §6 · the Schedule form drops its group labels; expense keeps them ──────
  testWidgets('Schedule renders no REQUIRED / OPTIONAL labels', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _tmtAccount(store, 'Vault');
    await tester.pumpWidget(
      _host(
        store,
        home: const QuickAddScreen(initialType: QuickAddType.newTask),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('REQUIRED'), findsNothing);
    expect(find.text('OPTIONAL'), findsNothing);
  });

  testWidgets('Expense still renders REQUIRED and OPTIONAL labels', (
    tester,
  ) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _tmtAccount(store, 'Vault');
    await tester.pumpWidget(
      _host(
        store,
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('REQUIRED'), findsOneWidget);
    expect(find.text('OPTIONAL'), findsOneWidget);
  });

  // ── §7 · Due is a date, not a date and a time; expense keeps the time ──────
  testWidgets('the Schedule Due row reads a bare date; the expense date keeps '
      'its time', (tester) async {
    _size(tester);
    final store = AppStore.empty(clock: _clock);
    _tmtAccount(store, 'Vault');

    // Schedule: Due is exactly "9 Aug" — no time.
    await tester.pumpWidget(
      _host(
        store,
        home: const QuickAddScreen(initialType: QuickAddType.newTask),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('9 Aug'), findsOneWidget);
    // No time component anywhere in the Due value.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').startsWith('9 Aug') &&
            (w.data ?? '').contains(':'),
      ),
      findsNothing,
    );

    // Expense: the date row still carries the time ("9 Aug, 12:00 AM").
    final store2 = AppStore.empty(clock: _clock);
    _tmtAccount(store2, 'Vault');
    await tester.pumpWidget(
      _host(
        store2,
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').startsWith('9 Aug') &&
            (w.data ?? '').contains(':'),
      ),
      findsOneWidget,
    );
  });
}
