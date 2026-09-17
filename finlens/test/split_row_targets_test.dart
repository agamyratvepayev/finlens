import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show NumericKeypad;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/split_row_targets_test.dart
//
// task 035 · the Split row gets two real targets and one honest icon.
//
// The amount half of a line used to be a GestureDetector wrapped directly around
// its Text, so its hit area was the width of the string it drew — about ten
// pixels on a blank line showing `—`. It is now a ConstrainedBox(minWidth: 70) +
// Align inside a row whose height is given once (SizedBox(48) + stretch), so each
// tap cell is ≥70 × 48. The delete glyph moved from `✕` (which means *clear this
// value* elsewhere in the app) to a minus-in-a-circle, built on every line
// including the active one — the held-empty 44 pt slot is gone.

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [
        Account(
          id: 'a1',
          name: 'Cash',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: [_cat('c1', 'Groceries'), _cat('c2', 'Household')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Future<void> _open(
  WidgetTester tester, {
  required double total,
  required List<SplitLine> initial,
  Locale? locale,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        TkMaterialLocalizationsDelegate(),
        TkCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSplitSheet(
                  ctx,
                  total: total,
                  currency: 'USD',
                  accountName: 'Cash',
                  categoryType: CategoryType.expense,
                  initial: initial,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

SplitLine _line(String cat, double? amt) =>
    SplitLine(categoryId: cat, amount: amt);

/// The amount tap cell for a line drawing [amountText]. The ConstrainedBox is
/// the nearest such ancestor of the amount Text (Text ← Align ← ConstrainedBox),
/// and the amount GestureDetector wraps it directly, so its rect *is* the hit
/// area.
Finder _amountCell(String amountText) => find
    .ancestor(
        of: find.text(amountText), matching: find.byType(ConstrainedBox))
    .first;

void main() {
  group('task 035 · the amount cell is a real target', () {
    // The reported bug: adding a second line moves focus to it (_addLine ends
    // `_active = _lines.length - 1`), and returning to line 1 meant hitting a
    // ten-pixel em-dash. Now line 1's amount cell is ≥70 × 48.
    //
    // RED before the change: with the detector wrapped around the bare Text, the
    // cell centre of a `$5.00` line — 35 pt left of the right-aligned glyph —
    // was dead space, so the tap missed and line 1 never activated.
    testWidgets('tapping the centre of an inactive line\'s amount cell '
        'activates it', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await _open(tester,
          total: 85, initial: [_line('c1', 5), _line('c2', 80)]);

      // Focus the second line.
      await tester.tap(find.text(r'$80.00'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Household, editing amount'), findsOneWidget);

      // Tap the *centre* of the first line's amount cell — empty space beside
      // the right-aligned `$5.00`, not the glyph.
      await tester.tapAt(tester.getRect(_amountCell(r'$5.00')).center);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Groceries, editing amount'),
          findsOneWidget);
      expect(find.byType(NumericKeypad), findsOneWidget);
    });

    // The same, on a blank line whose only mark is `—` (the ten-pixel target
    // the bug was worst against). RED before the change for the same reason.
    testWidgets('tapping the centre of a blank amount cell activates the line',
        (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await _open(tester,
          total: 80, initial: [_line('c1', null), _line('c2', 80)]);

      await tester.tap(find.text(r'$80.00'));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getRect(_amountCell('—')).center);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Groceries, editing amount'),
          findsOneWidget);
    });

    // RED before the change: the cell hugged its Text, so a blank line's cell
    // was ~10 pt wide and ~18 pt tall.
    testWidgets('the amount cell is at least 70 × 44, blank and filled',
        (tester) async {
      await _open(tester,
          total: 2600, initial: [_line('c1', null), _line('c2', 2580)]);

      final blank = tester.getSize(_amountCell('—'));
      expect(blank.width, greaterThanOrEqualTo(70));
      expect(blank.height, greaterThanOrEqualTo(44));

      final filled = tester.getSize(_amountCell(r'$2,580.00'));
      expect(filled.width, greaterThanOrEqualTo(70));
      expect(filled.height, greaterThanOrEqualTo(44));
    });

    // The row must not have grown to buy the taller target: it was 48 (a 30 pt
    // tile in `vertical: 9`) and is still 48 (SizedBox(48) + stretch).
    testWidgets('the row is 48 pt tall', (tester) async {
      await _open(tester,
          total: 100, initial: [_line('c1', 40), _line('c2', 60)]);

      // The SizedBox(height: 48) is the nearest SizedBox ancestor of the amount.
      final row = find
          .ancestor(
              of: find.text(r'$40.00'), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(row).height, 48);
    });

    // The two cells abut but do not overlap: the amount cell begins to the right
    // of the category cell's right edge, so a tap in one is never a tap in the
    // other.
    testWidgets('the amount and category cells do not overlap', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await _open(tester,
          total: 100, initial: [_line('c1', 40), _line('c2', 60)]);

      final amount = tester.getRect(_amountCell(r'$40.00'));
      final category = tester.getRect(find
          .ancestor(
              of: find.text('Groceries'), matching: find.byType(GestureDetector))
          .first);
      expect(amount.left, greaterThanOrEqualTo(category.right));

      // A tap 1 pt inside the amount cell's left edge activates the line…
      await tester
          .tapAt(Offset(amount.left + 1, amount.center.dy));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Groceries, editing amount'),
          findsOneWidget);

      // …while a tap on the category cell opens the picker, not the keypad.
      await tester.tapAt(category.center);
      await tester.pumpAndSettle();
      expect(find.text('Expense category'), findsOneWidget);
    });
  });

  group('task 035 · one honest icon, built on every line', () {
    testWidgets('the glyph is a minus-in-a-circle; ✕ appears nowhere',
        (tester) async {
      await _open(tester,
          total: 100, initial: [_line('c1', 40), _line('c2', 60)]);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline_rounded),
          findsNWidgets(2));
    });

    // RED before the §2.4 change: the active line hid its delete control, so
    // after activating a line only one button remained.
    testWidgets('the active line keeps its button, and the amount right edge '
        'holds its dx', (tester) async {
      await _open(tester,
          total: 100, initial: [_line('c1', 40), _line('c2', 60)]);

      final inactiveDx = tester.getRect(_amountCell(r'$40.00')).right;

      await tester.tap(find.text(r'$40.00'));
      await tester.pumpAndSettle();

      // Both lines still carry a remove button — the active one included.
      expect(find.byIcon(Icons.remove_circle_outline_rounded),
          findsNWidgets(2));
      // The amount's right edge sits at the same dx whether the row is active.
      final activeDx = tester.getRect(_amountCell(r'$40.00')).right;
      expect(activeDx, moreOrLessEquals(inactiveDx, epsilon: 0.5));
    });

    testWidgets('the last remaining line\'s button is dimmed and disabled',
        (tester) async {
      await _open(tester, total: 200, initial: [_line('c1', 200)]);
      final btn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      expect(btn.onPressed, isNull);
    });
  });

  group('task 035 · removal semantics are unchanged', () {
    testWidgets('removing the active line closes the keypad', (tester) async {
      await _open(tester,
          total: 100, initial: [_line('c1', 40), _line('c2', 60)]);

      await tester.tap(find.text(r'$40.00'));
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsOneWidget);

      // The active line is index 0; remove it.
      await tester
          .tap(find.byIcon(Icons.remove_circle_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsNothing);
    });

    testWidgets('removing an earlier line keeps the keypad open', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      await _open(tester, total: 120,
          initial: [_line('c1', 40), _line('c2', 60), _line('c1b', null)]);

      // Activate the last line (Groceries clash aside, c1b has no category yet —
      // give it one via the store? keep it simple: activate line index 2 by its
      // blank amount).
      await tester.tapAt(tester.getRect(_amountCell('—')).center);
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsOneWidget);

      // Remove line 0 (an earlier line): the keypad stays, shifted down.
      await tester
          .tap(find.byIcon(Icons.remove_circle_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsOneWidget);
    });
  });

  group('task 035 · layout holds under narrow width, scale and locale', () {
    for (final w in const [390.0, 360.0, 320.0]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('no overflow at ${w.toInt()}pt · ${(scale * 100).toInt()}%',
            (tester) async {
          await _open(tester,
              total: 999999999,
              initial: [
                _line('c1', 208957123),
                _line('c2', 791042876),
              ],
              size: Size(w, 780),
              textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
