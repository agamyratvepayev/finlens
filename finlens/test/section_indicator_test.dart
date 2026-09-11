import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/section_header.dart';
import 'package:finlens/theme/app_colors.dart';

// Task-14: the indicator is now `count` equal bars (14×6, radius 3), with the
// current section the only one in AppColors.accent and the rest in
// AppColors.textTertiary. Colour is the sole differentiator by design — the
// section name sits to the left.
void main() {
  Future<List<AnimatedContainer>> pumpBars(WidgetTester tester,
      {required int count, required int index}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SectionIndicator(
          label: 'NET WORTH',
          count: count,
          index: index,
          onAdvance: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200)); // settle AnimatedContainer
    return tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
  }

  testWidgets('renders `count` bars of equal size, one in accent',
      (tester) async {
    final bars = await pumpBars(tester, count: 3, index: 1);

    expect(bars.length, 3);

    Color? colorOf(AnimatedContainer c) => (c.decoration as BoxDecoration).color;
    final accentCount = bars.where((b) => colorOf(b) == AppColors.accent).length;
    final tertiaryCount =
        bars.where((b) => colorOf(b) == AppColors.textTertiary).length;

    expect(accentCount, 1, reason: 'exactly one bar marks the current section');
    expect(tertiaryCount, 2);

    // All bars share one geometry — only colour differs.
    for (final b in bars) {
      expect(b.constraints?.maxWidth ?? b.constraints?.minWidth, 14);
    }
  });

  testWidgets('the accent bar tracks the current index', (tester) async {
    final bars = await pumpBars(tester, count: 3, index: 2);
    Color? colorOf(AnimatedContainer c) => (c.decoration as BoxDecoration).color;
    expect(colorOf(bars[0]), AppColors.textTertiary);
    expect(colorOf(bars[1]), AppColors.textTertiary);
    expect(colorOf(bars[2]), AppColors.accent);
  });
}
