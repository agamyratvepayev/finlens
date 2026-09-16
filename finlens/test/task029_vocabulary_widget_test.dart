import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/archive_screen.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 029 — the copy reaches the screen. `flutter test` hangs on the dev
// machine; run this file yourself:
//   flutter test test/task029_vocabulary_widget_test.dart

void main() {
  final navKey = GlobalKey<NavigatorState>();

  Widget host(AppStore store, {Widget? home, Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          navigatorKey: navKey,
          locale: locale,
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ?? const Scaffold(),
        ),
      );

  void sizeTo(WidgetTester t, double w, double h, {double scale = 1.0}) {
    t.view.physicalSize = Size(w, h);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  AppStore oneAccount() {
    final s = AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );
    s.addAccount(
      name: 'Cash',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    return s;
  }

  Future<void> openType(WidgetTester t, QuickAddType type, {Locale? locale}) async {
    await t.pumpWidget(host(oneAccount(), locale: locale));
    navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => QuickAddScreen(initialType: type)));
    await t.pumpAndSettle();
  }

  // ── the picker renders the seven rows, in order ───────────────────────────
  //
  // The last match of a label is its menu row (the pill, if it shares the word,
  // sits higher in the top bar), so max-y disambiguates without scoping.
  for (final entry in {
    'en': ['Expense', 'Income', 'Transfer', 'Rebalance', 'Budget', 'Goal', 'Schedule'],
    'tr': ['Gider', 'Gelir', 'Transfer', 'Yeniden dengele', 'Bütçe', 'Hedef', 'Takvim'],
  }.entries) {
    testWidgets('picker: seven rows in order (${entry.key})', (t) async {
      sizeTo(t, 390, 844);
      await openType(t, QuickAddType.expense, locale: Locale(entry.key));

      // Open the type menu from the nav bar chevron.
      await t.tap(find.descendant(
          of: find.byType(FormNavBar),
          matching: find.byIcon(Icons.keyboard_arrow_down_rounded)));
      await t.pumpAndSettle();

      double rowY(String label) {
        final hits = find.text(label);
        expect(hits, findsWidgets, reason: '"$label" missing from the picker');
        return t
            .getRect(hits.last) // the menu row sits below the top-bar pill
            .top;
      }

      final ys = [for (final label in entry.value) rowY(label)];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]),
            reason: '${entry.value[i]} must sit below ${entry.value[i - 1]}');
      }
    });
  }

  // ── the pill on the schedule form reads "Schedule" ────────────────────────
  testWidgets('pill: the schedule form type pill reads Schedule', (t) async {
    sizeTo(t, 390, 844);
    await openType(t, QuickAddType.newTask);
    expect(find.descendant(of: find.byType(TypePill), matching: find.text('Schedule')),
        findsOneWidget);
  });

  // ── the save button reads "Schedule it" ───────────────────────────────────
  testWidgets('save button: the schedule form reads Schedule it', (t) async {
    sizeTo(t, 390, 844);
    await openType(t, QuickAddType.newTask);
    expect(find.text('Schedule it'), findsOneWidget);
  });

  // ── saving a schedule item toasts "Schedule saved" ────────────────────────
  testWidgets('toast: saving a schedule item reads Schedule saved', (t) async {
    sizeTo(t, 390, 844);
    final store = oneAccount();
    await t.pumpWidget(host(store));
    navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const QuickAddScreen(initialType: QuickAddType.newTask)));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField).first, 'Buy milk');
    await t.tap(find.text('Schedule it'));
    await t.pumpAndSettle();

    expect(store.tasks, hasLength(1));
    expect(find.text('Schedule saved'), findsOneWidget);
  });

  // ── the editor title reads "Edit scheduled item"; no "task" text ──────────
  testWidgets('editor: title is Edit scheduled item, no task copy', (t) async {
    sizeTo(t, 390, 844);
    await t.pumpWidget(
        host(buildSeedStore(), home: const EditTaskScreen(taskId: 'k-gym')));
    await t.pump();

    expect(find.text('Edit scheduled item'), findsOneWidget);
    expect(find.textContaining('task'), findsNothing);
    expect(find.textContaining('Task'), findsNothing);
  });

  // ── an Archive row reads "Schedule · …", never "Task · …" ─────────────────
  testWidgets('archive: a paused item row reads Schedule ·', (t) async {
    t.view.physicalSize = const Size(1206, 2622);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    final store = oneAccount();
    final task = store.addTask(
      title: 'Rent',
      linkedAccountId: store.accounts.first.id,
      expectedAmount: -500,
      dueDate: DateTime(2026, 8, 9),
      icon: Icons.arrow_circle_up_rounded,
    );
    store.pauseTask(task);

    await t.pumpWidget(host(store, home: const ArchiveScreen()));
    await t.pumpAndSettle();

    expect(find.textContaining('Schedule ·'), findsWidgets);
    expect(find.textContaining('Task ·'), findsNothing);
  });

  // ── no overflow at 320pt, 100% and 130%, all four locales ─────────────────
  for (final code in ['en', 'ru', 'tk', 'tr']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('layout: picker at 320pt ×$scale in $code has no overflow',
          (t) async {
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        await openType(t, QuickAddType.expense, locale: Locale(code));
        await t.tap(find.descendant(
            of: find.byType(FormNavBar),
            matching: find.byIcon(Icons.keyboard_arrow_down_rounded)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('layout: editor at 320pt ×$scale in $code has no overflow',
          (t) async {
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        await t.pumpWidget(host(buildSeedStore(),
            home: const EditTaskScreen(taskId: 'k-gym'), locale: Locale(code)));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }
}
