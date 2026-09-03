import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/split_sheet_widget_test.dart
//
// The redesigned split sheet (spec §4–§8): a single opening line with the
// transaction's category and a blank amount; Cancel in the header and Done the
// only commit; a status line that shows at most one thing and nothing when the
// split is valid; a missing category flagged in the row, not the status line.

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store() => AppStore(
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

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _portrait(WidgetTester tester) => _size(tester, 390, 844);

/// Pumps a host with an "open" button that shows the split sheet with [initial]
/// lines. Leaves the split sheet on screen, settled.
Future<void> _openSheet(
  WidgetTester tester, {
  required double total,
  required List<SplitLine> initial,
  Locale? locale,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
              textScaler: TextScaler.linear(textScale)),
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

SplitLine _line(String cat, double amt) =>
    SplitLine(categoryId: cat, amount: amt);

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

FilledButton _doneButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));

void main() {
  group('the frame: one commit, one opening line (§4/§5)', () {
    testWidgets('opens with one line, the category, and a blank amount',
        (tester) async {
      _portrait(tester);
      // The caller seeds the sheet with the transaction's own category.
      await _openSheet(tester, total: 1200, initial: [SplitLine(categoryId: 'c1')]);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget); // blank, placeholder colour
      expect(_textColor(tester, r'$0.00'), AppColors.textTertiary);
      // Regression: the old bottom commit is gone.
      expect(find.text('Apply split'), findsNothing);
    });

    testWidgets('the header holds Cancel; the only Done is the bottom button',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester, total: 1200, initial: [SplitLine(categoryId: 'c1')]);

      expect(find.text('Cancel'), findsOneWidget);
      // Exactly one 'Done' — the primary button — and no header 'Done'.
      expect(find.text('Done'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    });

    testWidgets('one line, amount assigned → "Add another line"; Done disabled',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester, total: 200, initial: [_line('c1', 200)]);
      expect(find.text('Add another line to split.'), findsOneWidget);
      expect(_doneButton(tester).onPressed, isNull);
    });
  });

  group('the status line shows at most one thing (§8)', () {
    testWidgets('a zero remainder renders no status figure', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 80)]);
      expect(find.text('Left to assign'), findsNothing);
      expect(find.text('Over the total by'), findsNothing);
      expect(find.text('Add another line to split.'), findsNothing);
    });

    testWidgets('assigned < total → amber "Left to assign" with the figure',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 30)]);
      expect(find.text('Left to assign'), findsOneWidget);
      expect(find.text(r'$50'), findsOneWidget); // status figure, no cents
      expect(_textColor(tester, 'Left to assign'), AppColors.warning);
      expect(_textColor(tester, r'$50'), AppColors.warning);
    });

    testWidgets('assigned > total → red "Over the total by"; offenders red',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 150), _line('c2', 100)]);
      expect(find.text('Over the total by'), findsOneWidget);
      expect(find.text('Left to assign'), findsNothing);
      expect(_textColor(tester, 'Over the total by'), AppColors.negative);
      // The overage-carrying line amounts render red.
      expect(_textColor(tester, r'$150.00'), AppColors.negative);
      expect(_textColor(tester, r'$100.00'), AppColors.negative);
    });

    testWidgets('a line with an amount but no category: amber row, no status',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200,
          initial: [SplitLine(amount: 120), _line('c2', 80)]);
      // The row names the fault, in amber.
      expect(find.text('Choose a category'), findsOneWidget);
      expect(_textColor(tester, 'Choose a category'), AppColors.warning);
      // No status line at all (sum is exact) and Done is disabled.
      expect(find.text('Left to assign'), findsNothing);
      expect(find.text('Over the total by'), findsNothing);
      expect(find.text('Add another line to split.'), findsNothing);
      expect(_doneButton(tester).onPressed, isNull);
    });
  });

  group('the helpers (§6/§7)', () {
    testWidgets('Assign the rest fills the first blank line, not a new one',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200,
          initial: [_line('c1', 120), SplitLine(categoryId: 'c2')]);
      await tester.tap(find.text('Assign the rest'));
      await tester.pumpAndSettle();
      // The blank line took the $80 remainder; no third line was added.
      expect(find.text(r'$80.00'), findsOneWidget);
      expect(find.text('Household'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
    });

    testWidgets('Assign the rest with no blank line adds an uncategorised line',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 30)]);
      await tester.tap(find.text('Assign the rest'));
      await tester.pumpAndSettle();
      // A third line appeared, holding the $50 remainder, with no category.
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(3));
      expect(find.text('Choose a category'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget);
    });

    testWidgets('Assign the rest is inert at a zero remainder', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 80)]);
      await tester.tap(find.text('Assign the rest')); // disabled → no-op
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2)); // unchanged
      expect(find.text(r'$120.00'), findsOneWidget);
      expect(find.text(r'$80.00'), findsOneWidget);
    });

    testWidgets('Split evenly overwrites hand-typed amounts', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 300, initial: [_line('c1', 250), _line('c2', 10)]);
      await tester.tap(find.text('Split evenly'));
      await tester.pumpAndSettle();
      // 300 / 2 = 150.00 each — both prior amounts replaced.
      expect(find.text(r'$150.00'), findsNWidgets(2));
    });
  });

  group('Done gating and un-blocked typing (§8)', () {
    testWidgets('Done enables only when every rule holds', (tester) async {
      _portrait(tester);
      // Balanced, categorised, positive, exact → enabled.
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 80)]);
      expect(_doneButton(tester).onPressed, isNotNull);
    });

    testWidgets('Done disabled on an inexact sum', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 70)]);
      expect(_doneButton(tester).onPressed, isNull);
    });

    testWidgets('Done disabled when a line has a zero amount', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 120, initial: [_line('c1', 120), _line('c2', 0)]);
      expect(_doneButton(tester).onPressed, isNull);
    });

    testWidgets('typing an amount above the total is accepted, not swallowed',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 1200, initial: [_line('c1', 100), _line('c2', 50)]);
      await tester.tap(find.text(r'$100.00'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15000');
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(r'$15,000.00'), findsOneWidget);
      expect(find.text('Over the total by'), findsOneWidget);
      expect(_textColor(tester, r'$15,000.00'), AppColors.negative);
    });
  });

  group('removing lines (§5/§11)', () {
    testWidgets('the last remaining line cannot be removed', (tester) async {
      _portrait(tester);
      await _openSheet(tester, total: 200, initial: [SplitLine(categoryId: 'c1')]);
      final remove = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close_rounded));
      expect(remove.onPressed, isNull);
    });

    testWidgets('a line can be removed down to one', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 80)]);
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('the amount editor still survives dismissal (§2)', () {
    testWidgets('enter a value, tap Done — no crash, value applied',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 3000, initial: [_line('c1', 100), _line('c2', 50)]);
      await tester.tap(find.text(r'$100.00'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2000');
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(r'$2,000.00'), findsOneWidget);
    });

    testWidgets('dismiss by scrim — no crash, no change', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 3000, initial: [_line('c1', 100), _line('c2', 50)]);
      await tester.tap(find.text(r'$100.00'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tapAt(const Offset(200, 20)); // scrim above the sheet
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(r'$100.00'), findsOneWidget); // untouched
    });
  });

  group('layout holds under narrow width, scale and locale (§11)', () {
    for (final w in const [390.0, 360.0, 320.0]) {
      testWidgets('no overflow at ${w.toInt()}pt', (tester) async {
        _size(tester, w, 720);
        await _openSheet(tester,
            total: 200, initial: [_line('c1', 150), _line('c2', 30)]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow at 320pt · 130% scale', (tester) async {
      _size(tester, 320, 720);
      await _openSheet(tester,
          total: 200,
          initial: [_line('c1', 150), _line('c2', 30)],
          textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    for (final loc in const [Locale('tr'), Locale('ru')]) {
      testWidgets('no overflow at 320pt in ${loc.languageCode}',
          (tester) async {
        _size(tester, 320, 720);
        await _openSheet(tester,
            total: 200,
            initial: [_line('c1', 150), _line('c2', 300)], // over → longest label
            locale: loc);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
