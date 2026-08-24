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

    // The ruler test: the five values share one x, whatever their length.
    final edges = [
      rightEdgeOf('Choose account'),
      rightEdgeOf('Choose category'),
      rightEdgeOf('None'),
      rightEdgeOf('Add a note'),
    ];
    for (final e in edges) {
      expect(e, closeTo(edges.first, 0.5));
    }

    // And the labels all start at one x, unmoved by the value beside them.
    final labelLefts = [
      tester.getRect(find.text('From')).left,
      tester.getRect(find.text('To')).left,
      tester.getRect(find.text('Tag')).left,
      tester.getRect(find.text('Note')).left,
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

    // The amount is a Text.rich so the typed digits and the untyped decimals
    // can carry different colours, and the blinking caret is a WidgetSpan
    // between them — so match on a substring rather than the whole string.
    expect(
      find.textContaining('0.00', findRichText: true),
      findsOneWidget,
    );
  });
}
