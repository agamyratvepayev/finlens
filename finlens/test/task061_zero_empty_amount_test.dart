import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_task_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/transaction_repeat_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/features/quick_add/widgets/transfer_sections.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task061_zero_empty_amount_test.dart
//
// Task 061 — typing a number moves nothing:
//   Part A · an empty amount reads a dim 0 in its currency, never a sentence;
//   Part B · tapping Amount on the Schedule form scrolls only when needed;
//   Part C · Ends ▸ After raises the number keyboard on the first tap.

// ── Fixtures ─────────────────────────────────────────────────────────────────

AppStore _store({List<Task> tasks = const []}) {
  final store = AppStore(
    clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
    accounts: [
      Account(
          id: 'a1',
          name: 'Cash',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 100),
      Account(
          id: 'a2',
          name: 'Euros',
          group: AccountGroup.spendable,
          currency: 'EUR',
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
  store.setRate('EUR', 1.1);
  return store;
}

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
  await _settle(tester);
}

/// A numeric hero / focused amount row blinks its caret forever, so
/// pumpAndSettle can hang — fixed pumps only.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

/// The amount row's value glyph is the row's only `Text.rich`.
TextSpan _valueSpan(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(TxnAmountFieldRow),
    matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
  );
  return tester.widget<Text>(finder).textSpan! as TextSpan;
}

/// The value's text spans without the caret's WidgetSpan.
List<TextSpan> _textSpans(WidgetTester tester) =>
    _valueSpan(tester).children!.whereType<TextSpan>().toList();

void main() {
  // ── Part A · Schedule form ──────────────────────────────────────────────────

  testWidgets('Schedule form, empty & unfocused: dim 0 + chip, no sentence',
      (tester) async {
    await tester.pumpWidget(_host(_store()));
    await _push(
        tester, const QuickAddScreen(initialType: QuickAddType.newTask));

    expect(find.text('Enter amount'), findsNothing);
    expect(find.byType(CurrencyChip), findsOneWidget);

    final spans = _textSpans(tester);
    expect(_valueSpan(tester).toPlainText(), '0');
    expect(spans.single.style!.color, AppColors.textTertiary);
  });

  // ── Part A · §1c: an empty amount is neutral even with a direction set ─────

  Widget directRow({required String raw, required bool focused}) => MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TxnAmountFieldRow(
            icon: Icons.numbers_rounded,
            label: 'Amount',
            raw: raw,
            currency: 'TMT',
            focused: focused,
            onTap: () {},
            onCurrencyTap: () {},
            // An expense category has set a direction (task 030) —
            sign: '−',
            valueColor: AppColors.negative,
          ),
        ),
      );

  testWidgets('empty + direction: no −, neutral 0, in both focus states',
      (tester) async {
    for (final focused in [false, true]) {
      await tester.pumpWidget(directRow(raw: '', focused: focused));
      await tester.pump(const Duration(milliseconds: 100));

      final spans = _textSpans(tester);
      expect(spans.single.text, '0', reason: 'focused=$focused');
      expect(spans.single.style!.color, AppColors.textTertiary,
          reason: 'an unset amount has no direction yet (focused=$focused)');
      expect(
          _valueSpan(tester).toPlainText(includePlaceholders: false), '0',
          reason: 'no sign in the empty state (focused=$focused)');
    }
  });

  testWidgets('typed + direction: −50 in the direction colour (task 030 kept)',
      (tester) async {
    await tester.pumpWidget(directRow(raw: '50', focused: true));
    await tester.pump(const Duration(milliseconds: 100));

    final spans = _textSpans(tester);
    expect(spans.first.text, '−');
    expect(spans.first.style!.color, AppColors.negative);
    expect(spans[1].text, '50');
    expect(spans[1].style!.color, AppColors.negative);
    expect(find.byType(CurrencyChip), findsOneWidget);
  });

  // ── Part A · Edit task ──────────────────────────────────────────────────────

  testWidgets('Edit task: label Amount, # icon, empty shows 0 + chip',
      (tester) async {
    final task = Task(
      id: 't1',
      title: 'Rent',
      linkedAccountId: 'a1',
      expectedAmount: 0,
      dueDate: DateTime(2026, 8, 20),
      icon: Icons.home_rounded,
    );
    await tester.pumpWidget(_host(_store(tasks: [task])));
    await _push(tester, const EditTaskScreen(taskId: 't1'));

    expect(find.text('Expected amount'), findsNothing);
    expect(find.text('Amount'), findsOneWidget);
    final row =
        tester.widget<TxnAmountFieldRow>(find.byType(TxnAmountFieldRow));
    expect(row.icon, Icons.numbers_rounded);
    expect(find.byType(CurrencyChip), findsOneWidget);
    expect(_valueSpan(tester).toPlainText(), '0');
    expect(_textSpans(tester).single.style!.color, AppColors.textTertiary);
  });

  // ── Part A · Transfer fee ───────────────────────────────────────────────────

  testWidgets('Transfer fee: empty shows hint 0; the rate field has no hint',
      (tester) async {
    await tester.pumpWidget(_host(_store()));
    await _push(
        tester,
        const QuickAddScreen(
          initialType: QuickAddType.transfer,
          fixedFromAccountId: 'a1',
          fixedToAccountId: 'a2',
        ));

    await tester.tap(find.byType(TransferFeeButton));
    await _settle(tester);

    final fields = tester
        .widgetList<TextField>(find.descendant(
            of: find.byType(InRowNumberField),
            matching: find.byType(TextField)))
        .toList();
    expect(fields, hasLength(2), reason: 'the rate and the fee');
    final withHint =
        fields.where((f) => f.decoration?.hintText == '0').toList();
    expect(withHint, hasLength(1), reason: 'only the fee gets the 0 hint');
    expect(withHint.single.decoration?.hintStyle?.color,
        AppColors.textTertiary);
    final rate = fields.firstWhere((f) => f.decoration?.hintText == null);
    expect(rate.decoration?.hintText, isNull);

    // Typing replaces the hint's 0 with the figure.
    await tester.enterText(
        find.byWidget(withHint.single, skipOffstage: false), '5');
    await _settle(tester);
    expect(withHint.single.controller!.text, '5');

    // The fee row keeps its pinned 48pt, resting and focused.
    final feeRow = find.ancestor(
        of: find.byWidget(withHint.single),
        matching: find.byType(InRowNumberField));
    expect(tester.getSize(feeRow).height, 48.0);
  });

  // ── Part B · tapping Amount does not move a visible row ────────────────────

  testWidgets('Schedule form: focusing Amount leaves a visible row in place',
      (tester) async {
    // Small enough that the list is scrollable once the keypad is up, so a
    // centring ensureVisible would visibly move the row.
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_store()));
    await _push(
        tester, const QuickAddScreen(initialType: QuickAddType.newTask));

    final row = find.byType(TxnAmountFieldRow);
    final before = tester.getTopLeft(row).dy;

    await tester.tap(find.text('Amount'));
    await _settle(tester);

    expect(find.byType(NumericKeypad), findsOneWidget);
    // The focused outline swaps 3pt of padding for margin, so the row's box
    // holds its place; the list must not have scrolled (task 061 Part B).
    expect((tester.getTopLeft(row).dy - before).abs(), lessThan(1.0),
        reason: 'a visible amount row must not move when focused');
  });

  // ── Part C · Ends ▸ After: first tap raises the keyboard ───────────────────

  Future<void> openEnds(WidgetTester tester) async {
    await tester.pumpWidget(StoreScope(
      store: _store(),
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => showTxnRepeatSheet(
                  ctx,
                  current:
                      const TxnRepeatSelection(freq: RepeatFrequency.none),
                  date: DateTime(2026, 8, 9),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.text('Ends'));
    await tester.pumpAndSettle();
  }

  testWidgets('one tap on After focuses the count and opens the keyboard',
      (tester) async {
    await openEnds(tester);
    expect(find.byType(TextField), findsNothing,
        reason: 'Never is selected; the count field does not exist yet');

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue,
        reason: 'the first tap must land focus (task 061 Part C)');
    expect(tester.testTextInput.hasAnyClients, isTrue,
        reason: 'focus must open a text-input connection — the keyboard');
    expect(field.keyboardType, TextInputType.number);
  });

  testWidgets('one tap on the value ("12 times") works the same',
      (tester) async {
    await openEnds(tester);

    await tester.tap(find.text('12 times'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });
}
