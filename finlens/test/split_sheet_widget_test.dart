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

void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 @3x
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a host with an "open" button that shows the split sheet with [initial]
/// lines. Leaves the split sheet on screen, settled.
Future<void> _openSheet(
  WidgetTester tester, {
  required double total,
  required List<SplitLine> initial,
}) async {
  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => Scaffold(
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
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The colour of the remaining-row figure — the single Text inside the
/// live-region Semantics node.
Color _remainingColor(WidgetTester tester) {
  final figure = find.descendant(
    of: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(figure).style!.color!;
}

SplitLine _line(String cat, double amt) =>
    SplitLine(categoryId: cat, amount: amt);

void main() {
  group('the amount editor no longer crashes on dismissal (§1)', () {
    // The crash is value-independent: the disposal race fires on dismissal at
    // any amount. Proven across the small/boundary/large values the bug report
    // singled out — 5, 2000, 2001 — none of which is special here.
    for (final entry in const {5: r'$5', 2000: r'$2,000', 2001: r'$2,001'}
        .entries) {
      testWidgets('enter ${entry.key} and tap Done — no crash, value applied',
          (tester) async {
        _portrait(tester);
        await _openSheet(tester,
            total: 3000, initial: [_line('c1', 100), _line('c2', 50)]);

        await tester.tap(find.text(r'$100'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '${entry.key}');
        await tester.tap(find.widgetWithText(FilledButton, 'Done'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(entry.value), findsOneWidget); // line updated
      });
    }

    testWidgets('submit with the keyboard — no crash, value applied',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 3000, initial: [_line('c1', 100), _line('c2', 50)]);

      await tester.tap(find.text(r'$100'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '2000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(r'$2,000'), findsOneWidget);
    });

    testWidgets('dismiss the editor by tapping the scrim — no crash, no change',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 3000, initial: [_line('c1', 100), _line('c2', 50)]);

      await tester.tap(find.text(r'$100'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget); // editor open

      await tester.tapAt(const Offset(200, 20)); // scrim, above the sheet
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing); // editor gone
      expect(find.text(r'$100'), findsOneWidget); // line untouched
    });
  });

  group('the remaining row names its state (§2)', () {
    testWidgets('under-allocated: "Remaining", signed, textSecondary',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 30)]);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Over by'), findsNothing);
      expect(find.text(r'+$50'), findsOneWidget);
      expect(_remainingColor(tester), AppColors.textSecondary);
    });

    testWidgets('balanced: "Remaining", \$0, positive', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 120), _line('c2', 80)]);
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text(r'$0'), findsOneWidget);
      expect(_remainingColor(tester), AppColors.positive);
    });

    testWidgets('over-allocated: "Over by", unsigned, negative',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 150), _line('c2', 100)]);
      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('Remaining'), findsNothing);
      expect(find.text(r'$50'), findsOneWidget); // unsigned, no minus
      expect(find.text(r'-$50'), findsNothing);
      expect(_remainingColor(tester), AppColors.negative);
    });

    testWidgets('the ε boundary: just inside reads positive, just outside not',
        (tester) async {
      _portrait(tester);
      // remaining = +0.004 < kMoneyEpsilon → treated as balanced (positive).
      await _openSheet(tester,
          total: 200.004, initial: [_line('c1', 100), _line('c2', 100)]);
      expect(_remainingColor(tester), AppColors.positive);

      // remaining = +0.02 > kMoneyEpsilon → under-allocated (textSecondary).
      await _openSheet(tester,
          total: 200.02, initial: [_line('c1', 100), _line('c2', 100)]);
      expect(_remainingColor(tester), AppColors.textSecondary);

      // remaining = -0.02 < -kMoneyEpsilon → over-allocated (negative).
      await _openSheet(tester,
          total: 199.98, initial: [_line('c1', 100), _line('c2', 100)]);
      expect(_remainingColor(tester), AppColors.negative);
    });

    testWidgets('the live region announces the word, not just the number',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 150), _line('c2', 100)]);
      // Semantics label carries "Over by $50" so a screen reader hears it.
      expect(find.bySemanticsLabel(r'Over by $50'), findsOneWidget);
    });
  });

  group('an over-total line is marked, others are not (§2)', () {
    testWidgets('the line that alone exceeds the total renders negative',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 2000, initial: [_line('c1', 2500), _line('c2', 100)]);
      // The offending line is red; the innocent one stays white.
      expect(tester.widget<Text>(find.text(r'$2,500')).style!.color,
          AppColors.negative);
      expect(tester.widget<Text>(find.text(r'$100')).style!.color,
          Colors.white);
    });

    testWidgets('a line equal to the total is not marked', (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 2000, initial: [_line('c1', 2000), _line('c2', 100)]);
      expect(tester.widget<Text>(find.text(r'$2,000')).style!.color,
          Colors.white);
    });

    testWidgets('lines that only together exceed the total are not marked',
        (tester) async {
      _portrait(tester);
      await _openSheet(tester,
          total: 200, initial: [_line('c1', 150), _line('c2', 150)]);
      // Over by $100 overall, but no single line exceeds $200 → none red.
      for (final t in tester.widgetList<Text>(find.text(r'$150'))) {
        expect(t.style!.color, Colors.white);
      }
      expect(find.text('Over by'), findsOneWidget);
    });
  });
}
