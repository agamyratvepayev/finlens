import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/theme/app_theme.dart';

/// The three widths the Add Transaction screen is signed off against. The
/// smallest is below any simulator the current iOS runtime can create, which
/// is why this lives in a test rather than in a manual pass.
const _sizes = <String, Size>{
  '390x844': Size(390, 844),
  '360x640': Size(360, 640),
  '320x568': Size(320, 568),
};

Widget _app(AppStore store, QuickAddType type) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: QuickAddScreen(initialType: type),
      ),
    );

void main() {
  for (final entry in _sizes.entries) {
    for (final type in QuickAddType.values) {
      testWidgets('${type.name} lays out with no overflow at ${entry.key}',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(buildSeedStore(), type));
        await tester.pump(const Duration(milliseconds: 350));

        // A RenderFlex overflow is reported as a thrown FlutterError rather
        // than a failed matcher, so asserting on the exception is the check.
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Task 007 — the New-task amount types in place on the docked keypad, so the
  // task form must also survive the keypad being open, at both text scales.
  for (final entry in _sizes.entries) {
    for (final textScale in const [1.0, 1.3]) {
      testWidgets(
          'newTask amount + keypad lays out with no overflow at ${entry.key} @${textScale}x',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(_app(buildSeedStore(), QuickAddType.newTask));
        await tester.pump(const Duration(milliseconds: 350));

        // Closed keypad — the baseline the values-loop already covers, re-checked
        // here under the raised text scale.
        expect(tester.takeException(), isNull);

        // Open the keypad by focusing the amount row, then a full number.
        await tester.tap(find.text('Amount'));
        await tester.pump(const Duration(milliseconds: 350));
        for (final k in ['1', '2', '3', '4', '5', '6']) {
          await tester.tap(find.text(k));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Save states name the first unmet requirement', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), QuickAddType.expense));
    await tester.pump(const Duration(milliseconds: 350));

    // Cold start: nothing entered yet.
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.text('Save expense'), findsNothing);

    // Amount satisfied -> the account becomes the blocker.
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Choose an account'), findsOneWidget);
  });

  testWidgets('every field value ends on one right edge', (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), QuickAddType.expense));
    await tester.pump(const Duration(milliseconds: 350));

    double rightEdgeOf(String text) {
      final f = find.text(text);
      expect(f, findsOneWidget, reason: '"\$text" should be on screen');
      final box = tester.getRect(f);
      return box.right;
    }

    // The ruler test: the values share one x, whatever their length. The Note
    // row is deliberately exempt — it drops its label and left-aligns the note
    // across the full width (see quick_add_note_test.dart), so it neither shares
    // this right edge nor carries a label.
    final edges = [
      rightEdgeOf('Choose account'),
      rightEdgeOf('Choose category'),
      rightEdgeOf('None'),
    ];
    for (final e in edges) {
      expect(e, closeTo(edges.first, 0.5));
    }

    // And the labels all start at one x, unmoved by the value beside them.
    final labelLefts = [
      tester.getRect(find.text('From')).left,
      tester.getRect(find.text('To')).left,
      tester.getRect(find.text('Tag')).left,
    ];
    for (final l in labelLefts) {
      expect(l, closeTo(labelLefts.first, 0.5));
    }
  });

  test('relative dates name only the three nearest days', () {
    final now = DateTime(2026, 8, 15, 9, 0);
    String at(DateTime d) => dateTimeLabel(d, AppLocalizationsEn(), now: now);

    expect(at(DateTime(2026, 8, 15, 14, 32)), 'Today, 14:32');
    expect(at(DateTime(2026, 8, 14, 14, 32)), 'Yesterday, 14:32');
    expect(at(DateTime(2026, 8, 16, 9, 0)), 'Tomorrow, 09:00');
    // Two days out is past the point where a name beats the date.
    expect(at(DateTime(2026, 8, 9, 14, 32)), '9 Aug, 14:32');
    expect(at(DateTime(2025, 8, 9, 14, 32)), '9 Aug 2025, 14:32');
  });

  testWidgets('amount zero state is dimmed, typed digits are not',
      (tester) async {
    tester.view.physicalSize = _sizes['390x844']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), QuickAddType.expense));
    await tester.pump(const Duration(milliseconds: 350));

    // The amount is a Text.rich so the placeholder and the blinking caret
    // (a WidgetSpan) can be separate spans — so match on a substring. Task 008
    // §2: the empty state shows only `$0`, never a padded `.00`; USD keeps its
    // symbol on the number (§1).
    expect(
      find.textContaining(r'$0', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('0.00', findRichText: true),
      findsNothing,
      reason: 'no decimals appear before the digits that fill them',
    );
  });
}
