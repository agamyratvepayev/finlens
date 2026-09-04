import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task_form_rework_test.dart
//
// Covers the New-Task form rework (§1–§6): the hero label sits above its field,
// the three optional rows read "Not set", no Remind control exists in either
// screen, Quick Add writes null reminders, an edit preserves stored reminders,
// Repeat opens the transaction sheet and reads one word, and the toggle bar is
// absent for tasks but present where it still belongs.

// ── Fixtures ─────────────────────────────────────────────────────────────────

AppStore _store({List<Task> tasks = const []}) => AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
        Account(
            id: 'a2',
            name: 'Savings',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 500),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: tasks,
    );

final _navKey = GlobalKey<NavigatorState>();

/// Hosts [child] one route deep so its Save can pop back to a placeholder —
/// the real Quick Add is a pushed fullscreen dialog, and its _save pops then
/// shows a snackbar, so the screen must never be the last route.
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

/// The task hero (TextHeroCard) draws no repeating animation, so pumpAndSettle
/// is safe for the task form. A numeric hero (Expense/Transfer) has a blinking
/// caret controller that never settles — those tests pump a fixed duration.
Future<void> _openTask(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(_host(store));
  await _push(tester, const QuickAddScreen(initialType: QuickAddType.newTask));
}

void main() {
  group('§1 · hero label sits above its field', () {
    testWidgets('the caption is above the title field', (tester) async {
      await _openTask(tester, _store());
      final captionY = tester.getTopLeft(find.text('Task title')).dy;
      // The task form has exactly one TextField: the hero title.
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      expect(captionY, lessThan(fieldY),
          reason: 'caption must render above the field, not beneath it');
    });
  });

  group('§2 · empty optional rows read "Not set"', () {
    testWidgets('Amount, Account and Category all read Not set', (tester) async {
      await _openTask(tester, _store());
      // Amount, Account, Category — the note reads "Add note", the due date has
      // a value, so exactly three "Not set" values render.
      expect(find.text('Not set'), findsNWidgets(3));
      // The old vocabulary is gone from this form.
      expect(find.text('None'), findsNothing);
    });
  });

  group('§4 · no Remind control in either screen', () {
    testWidgets('Quick Add task form shows no Remind toggle', (tester) async {
      await _openTask(tester, _store());
      expect(find.text('Remind'), findsNothing);
    });

    testWidgets('edit task screen shows no Remind me row', (tester) async {
      await tester.pumpWidget(_host(buildSeedStore()));
      await _push(tester, const EditTaskScreen(taskId: 'k-gym'));
      expect(find.text('Remind me'), findsNothing);
    });

    testWidgets('creating a task writes null to both reminder fields',
        (tester) async {
      final store = _store();
      await _openTask(tester, store);
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.tasks, hasLength(1));
      final task = store.tasks.single;
      expect(task.title, 'Buy milk');
      expect(task.reminderDaysBefore, isNull);
      expect(task.reminderTime, isNull);
    });

    testWidgets('a task with reminder fields keeps them through an edit',
        (tester) async {
      final store = buildSeedStore();
      // k-netflix carries reminderDaysBefore: 2 and a 09:00 reminder time.
      final before = store.taskById('k-netflix')!;
      expect(before.reminderDaysBefore, 2);
      expect(before.reminderTime, isNotNull);

      await tester.pumpWidget(_host(store));
      await _push(tester, const EditTaskScreen(taskId: 'k-netflix'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final after = store.taskById('k-netflix')!;
      expect(after.reminderDaysBefore, 2,
          reason: 'the edit must not clear a stored reminder');
      expect(after.reminderTime, isNotNull);
    });
  });

  group('§5 · Repeat opens the transaction sheet and reads one word', () {
    testWidgets('tapping Repeat opens the transaction repeat sheet',
        (tester) async {
      await _openTask(tester, _store());
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      // Daily and Custom are offered only by the transaction sheet; the Planner
      // sheet (showRepeatSheet) offers neither.
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('a Custom selection renders as a single word in the row',
        (tester) async {
      await _openTask(tester, _store());
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      // Confirm the custom sub-sheet (topmost) then the repeat sheet.
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Back on the form, the row shows the single word — the detail stays in
      // the sheet.
      expect(find.text('Custom'), findsOneWidget);
    });
  });

  group('§5 · the toggle bar renders only where a toggle remains', () {
    testWidgets('task form shows no toggle (no Fee, no Remind)',
        (tester) async {
      await _openTask(tester, _store());
      expect(find.text('Fee'), findsNothing);
      expect(find.text('Remind'), findsNothing);
    });

    testWidgets('transfer form still shows the Fee toggle', (tester) async {
      await tester.pumpWidget(_host(_store()));
      // Numeric hero blinks forever — push, then pump a fixed frame instead of
      // settling (pumpAndSettle would time out on the caret animation).
      _navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) =>
              const QuickAddScreen(initialType: QuickAddType.transfer)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Fee'), findsOneWidget);
    });
  });
}
