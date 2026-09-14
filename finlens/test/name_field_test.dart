import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/more/edit_category_screen.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/planner/schedule_horizon.dart';
import 'package:finlens/features/planner/schedule_tab.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 004 — one name field, everywhere. `flutter test` hangs on the dev
// machine, so these are written, not run here; verify with `flutter analyze` and
// run the file yourself:  flutter test test/name_field_test.dart
//
// The six call sites: goal name, task title (edit), account name, category name,
// New account, New category, task title (create). Every one is a 48pt NameField:
// no caption, hint-as-label, focus border, built-in clear.

void main() {
  Widget wrap(AppStore store, Widget child, {double scale = 1.0}) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: child,
        ),
      );

  Widget sheetHost(AppStore store, void Function(BuildContext) onTap) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  void phone(WidgetTester tester, {double w = 390, double h = 844}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  AppStore accountStore() {
    final s = AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    s.addAccount(
      name: 'Main Checking',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    return s;
  }

  AppStore categoryStore() {
    final s = AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    s.addCategory(
      name: 'Groceries',
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF5E5CE6),
    );
    return s;
  }

  String firstAccountId(AppStore s) => s.accounts.first.id;
  String firstCategoryId(AppStore s) => s.categories.first.id;

  // The Container the NameField paints its surface + focus border on — the only
  // one inside a NameField carrying a border.
  BoxDecoration nameDecoration(WidgetTester tester, Finder scope) {
    final c = tester.widget<Container>(
      find
          .descendant(
            of: scope,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border != null),
          )
          .first,
    );
    return c.decoration as BoxDecoration;
  }

  // ── §7 · every screen renders a captionless NameField ──────────────────────

  testWidgets('goal editor: one NameField, no "Goal name" caption', (t) async {
    phone(t);
    await t.pumpWidget(wrap(AppStore.empty(), const EditGoalScreen()));
    expect(find.byType(NameField), findsOneWidget);
    expect(find.text('Goal name'), findsNothing);
    expect(t.getSize(find.byType(NameField)).height, closeTo(48, 0.5));
  });

  testWidgets('edit task: one NameField, no "Task title" caption', (t) async {
    phone(t);
    await t.pumpWidget(wrap(buildSeedStore(), const EditTaskScreen(taskId: 'k-gym')));
    await t.pump();
    expect(find.byType(NameField), findsOneWidget);
    expect(find.text('Task title'), findsNothing);
    expect(t.getSize(find.byType(NameField)).height, closeTo(48, 0.5));
  });

  testWidgets('account editor: one NameField, no "Account name"/"Name" caption',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();
    expect(find.byType(NameField), findsOneWidget);
    // "Name" (eaName) is now only a semantics label, never visible text.
    expect(find.text('Account name'), findsNothing);
    expect(t.getSize(find.byType(NameField)).height, closeTo(48, 0.5));
  });

  testWidgets('category editor: one NameField, no "Category name" caption',
      (t) async {
    final s = categoryStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditCategoryScreen(categoryId: firstCategoryId(s))));
    await t.pump();
    expect(find.byType(NameField), findsOneWidget);
    expect(find.text('Category name'), findsNothing);
    expect(t.getSize(find.byType(NameField)).height, closeTo(48, 0.5));
  });

  testWidgets('New account sheet: captionless NameField with a glyph tile',
      (t) async {
    phone(t);
    await t.pumpWidget(sheetHost(accountStore(), (ctx) => showNewAccountSheet(ctx)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(NameField), findsOneWidget);
    expect(find.byType(NameGlyphTile), findsOneWidget);
    expect(find.text('Account name'), findsNothing);
  });

  testWidgets('New category sheet: captionless NameField with a glyph tile',
      (t) async {
    phone(t);
    await t.pumpWidget(sheetHost(categoryStore(),
        (ctx) => showNewCategorySheet(ctx, type: CategoryType.expense)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(NameField), findsOneWidget);
    expect(find.byType(NameGlyphTile), findsOneWidget);
    expect(find.text('Category name'), findsNothing);
  });

  // ── §7 · the old caption survives as a semantics label ─────────────────────

  testWidgets('the name field keeps its old caption as a semantics label',
      (t) async {
    phone(t);
    await t.pumpWidget(wrap(AppStore.empty(), const EditGoalScreen()));
    // egGoalName = "Goal name" is invisible text but a real semantics label.
    expect(
      find.bySemanticsLabel('Goal name'),
      findsOneWidget,
      reason: 'a screen reader must still name the field',
    );
  });

  // ── §7 · the decorative pencil is gone from the editors, kept on the tile ──

  testWidgets('account editor renders no trailing pencil on the name row',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();
    // The edit_rounded pencil that used to decorate the row is gone. (The glyph
    // tile's badge — the only other edit_rounded — lives on the creation sheets.)
    expect(
      find.descendant(
          of: find.byType(NameField), matching: find.byIcon(Icons.edit_rounded)),
      findsNothing,
    );
  });

  testWidgets('category editor renders no trailing pencil on the name row',
      (t) async {
    final s = categoryStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditCategoryScreen(categoryId: firstCategoryId(s))));
    await t.pump();
    expect(
      find.descendant(
          of: find.byType(NameField), matching: find.byIcon(Icons.edit_rounded)),
      findsNothing,
    );
  });

  testWidgets('creation sheets keep the pencil badge on the glyph tile',
      (t) async {
    phone(t);
    await t.pumpWidget(sheetHost(accountStore(), (ctx) => showNewAccountSheet(ctx)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byType(NameGlyphTile),
          matching: find.byIcon(Icons.edit_rounded)),
      findsOneWidget,
    );
  });

  // ── §7 · tapping the row padding focuses; tapping the tile does not ─────────

  testWidgets('tapping the row padding (not the field) focuses the name',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();

    final editable = find.descendant(
        of: find.byType(NameField), matching: find.byType(EditableText));
    expect(t.widget<EditableText>(editable).focusNode.hasFocus, isFalse);

    // Tap the left inset — inside the row, outside the field and the glyph.
    final topLeft = t.getTopLeft(find.byType(NameField));
    await t.tapAt(topLeft + const Offset(3, 22));
    await t.pump();
    expect(t.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
  });

  testWidgets('tapping the glyph tile opens the icon picker without focusing',
      (t) async {
    final calls = <MethodCall>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput, (c) async {
      calls.add(c);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.textInput, null));

    phone(t);
    await t.pumpWidget(sheetHost(categoryStore(),
        (ctx) => showNewCategorySheet(ctx, type: CategoryType.expense)));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    calls.clear();
    await t.tap(find.byType(NameGlyphTile));
    await t.pumpAndSettle();

    // The icon grid is up (the category picker has no Icons/Emoji tab, so assert
    // the grid itself), and tapping the tile never raised the keyboard.
    expect(find.byType(GridView), findsWidgets);
    expect(calls.any((c) => c.method == 'TextInput.show'), isFalse,
        reason: 'the tile opens the picker, it does not raise the keyboard');
  });

  // ── §7 · the clear button ──────────────────────────────────────────────────

  testWidgets('clear is absent when empty, present once typed, keeps focus once cleared',
      (t) async {
    phone(t);
    await t.pumpWidget(wrap(AppStore.empty(), const EditGoalScreen()));

    expect(find.byIcon(Icons.close_rounded), findsNothing);

    final field = find.descendant(
        of: find.byType(NameField), matching: find.byType(TextField));
    await t.enterText(field, 'Holiday');
    await t.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pump();
    expect(t.widget<TextField>(field).controller!.text, isEmpty);
    final editable = t.widget<EditableText>(find.descendant(
        of: find.byType(NameField), matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('the goal editor has exactly one clear button', (t) async {
    phone(t);
    await t.pumpWidget(wrap(AppStore.empty(), const EditGoalScreen()));
    await t.enterText(
        find.descendant(
            of: find.byType(NameField), matching: find.byType(TextField)),
        'Something');
    await t.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('clearing an account name shows the example hint, not a blank row',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();

    await t.enterText(
        find.descendant(
            of: find.byType(NameField), matching: find.byType(TextField)),
        '');
    await t.pump();
    expect(find.text('e.g. Main Checking'), findsOneWidget);
  });

  // ── §7 · focus border and equal heights ────────────────────────────────────

  testWidgets('the accent border shows only when focused; height is unchanged',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();

    final scope = find.byType(NameField);
    final hUnfocused = t.getSize(scope).height;
    final borderUnfocused = nameDecoration(t, scope).border! as Border;
    expect(borderUnfocused.top.color, Colors.transparent);

    await t.tapAt(t.getTopLeft(scope) + const Offset(3, 22));
    await t.pump();

    final hFocused = t.getSize(scope).height;
    final borderFocused = nameDecoration(t, scope).border! as Border;
    expect(borderFocused.top.color, AppColors.accent);
    expect(hFocused, closeTo(hUnfocused, 0.01));
  });

  // ── §7 · name and the row below share one text-left edge ───────────────────

  testWidgets('account name text-left aligns with the Group row below it',
      (t) async {
    final s = accountStore();
    phone(t);
    await t.pumpWidget(wrap(s, EditAccountScreen(accountId: firstAccountId(s))));
    await t.pump();

    final nameLeft = t
        .getRect(find.descendant(
            of: find.byType(NameField), matching: find.byType(EditableText)))
        .left;
    final groupLabelLeft = t.getRect(find.text('Group')).left;
    expect(nameLeft, closeTo(groupLabelLeft, 1.5));
  });

  // ── §5 · the task glyph ────────────────────────────────────────────────────

  group('§5 · the create-task glyph', () {
    final navKey = GlobalKey<NavigatorState>();

    Widget taskHost(AppStore store) => StoreScope(
          store: store,
          child: MaterialApp(
            navigatorKey: navKey,
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(),
          ),
        );

    Future<void> openTask(WidgetTester t, AppStore store) async {
      phone(t);
      await t.pumpWidget(taskHost(store));
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const QuickAddScreen(initialType: QuickAddType.newTask)));
      await t.pumpAndSettle();
    }

    AppStore oneAccount() => AppStore(
          accounts: [
            Account(
                id: 'a1',
                name: 'Cash',
                group: AccountGroup.spendable,
                currency: 'USD',
                startingBalance: 100),
          ],
          categories: const [],
          txns: const [],
          goals: const [],
          tasks: const [],
        );

    testWidgets('opening New task focuses the title (§5b)', (t) async {
      await openTask(t, oneAccount());
      final editable = t.widget<EditableText>(find.descendant(
          of: find.byType(NameField), matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('an untouched task saves Icons.arrow_circle_up_rounded (§5a)',
        (t) async {
      final store = oneAccount();
      await openTask(t, store);
      await t.enterText(find.byType(TextField), 'Buy milk');
      await t.tap(find.text('Create task'));
      await t.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      expect(store.tasks.single.icon, Icons.arrow_circle_up_rounded);
    });

    testWidgets('picking a glyph changes what the task saves (§5a)', (t) async {
      final store = oneAccount();
      await openTask(t, store);

      // Tap the leading glyph (the default arrow) to open the icon picker.
      await t.tap(find.byIcon(Icons.arrow_circle_up_rounded));
      await t.pumpAndSettle();

      // Pick the first glyph in the grid and remember which it is.
      final firstGlyph = find
          .descendant(of: find.byType(GridView), matching: find.byType(Icon))
          .first;
      final chosen = t.widget<Icon>(firstGlyph).icon!;
      await t.tap(firstGlyph);
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Renew licence');
      await t.tap(find.text('Create task'));
      await t.pumpAndSettle();

      expect(store.tasks.single.icon, chosen);
    });

    testWidgets('an empty-title Save toasts and does not create a task (§5c)',
        (t) async {
      final store = oneAccount();
      await openTask(t, store);
      await t.tap(find.text('Create task'));
      await t.pump();
      expect(find.text('Name the task'), findsWidgets);
      expect(store.tasks, isEmpty);
    });
  });

  // ── §5a · the edit-task glyph is tappable and persists ─────────────────────

  testWidgets('edit task: the picked glyph persists through Save', (t) async {
    final store = buildSeedStore();
    phone(t);
    await t.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const EditTaskScreen(taskId: 'k-gym')),
        ),
      ),
    ));
    await t.pump();

    final before = store.taskById('k-gym')!.icon;
    // Tap the leading glyph in the title NameField.
    await t.tap(find.descendant(
        of: find.byType(NameField), matching: find.byIcon(before)));
    await t.pumpAndSettle();

    final firstGlyph = find
        .descendant(of: find.byType(GridView), matching: find.byType(Icon))
        .first;
    final chosen = t.widget<Icon>(firstGlyph).icon!;
    await t.tap(firstGlyph);
    await t.pumpAndSettle();

    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(store.taskById('k-gym')!.icon, chosen);
  });

  // ── §5a · the Schedule row renders the task's own glyph ────────────────────

  testWidgets('the Schedule row renders the task glyph', (t) async {
    final store = AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: [
        Task(
          id: 'k1',
          title: 'Water the plants',
          linkedAccountId: 'a1',
          expectedAmount: 0,
          dueDate: AppStore.today.add(const Duration(days: 2)),
          icon: Icons.local_florist_rounded,
        ),
      ],
    );
    phone(t);
    await t.pumpWidget(wrap(
      store,
      Scaffold(
        body: ScheduleTab(
          store: store,
          horizon: ScheduleHorizon.fallback,
          onHorizonChange: (_) {},
        ),
      ),
    ));
    await t.pump();
    expect(find.byIcon(Icons.local_florist_rounded), findsWidgets);
  });
}
