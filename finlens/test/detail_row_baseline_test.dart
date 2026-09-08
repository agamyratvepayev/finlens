import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/detail_row.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 10 — DetailRow baseline + column-edge geometry.
///
/// Baselines are computed from the widget rect plus the FlutterTest font's
/// deterministic metrics (ascent 0.75em, descent 0.25em; TextStyle.height
/// scales both proportionally, so the first-line baseline sits at
/// `rect.top + fontSize * height * 0.75`). Render-object
/// `getDistanceToBaseline` is debug-guarded outside layout, so the metric
/// formula is used instead of reading baselines off the render tree.
double _baselineOf(WidgetTester tester, String text,
        {required double fontSize, required double lineHeight}) =>
    tester.getRect(find.text(text)).top + fontSize * lineHeight * 0.75;

double _labelBaseline(WidgetTester t, String s) =>
    _baselineOf(t, s, fontSize: 9.5, lineHeight: 1.2);
double _valueBaseline(WidgetTester t, String s) =>
    _baselineOf(t, s, fontSize: 13.5, lineHeight: 1.3);
double _trailingBaseline(WidgetTester t, String s) =>
    _baselineOf(t, s, fontSize: 12, lineHeight: 1.3);

/// Global x of the right edge of the last glyph of [text] — where the label
/// actually ends, as opposed to where its 62pt box ends.
double _glyphRightEdge(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return paragraph.localToGlobal(Offset(boxes.last.right, 0)).dx;
}

Widget _host(Widget child, {double width = 390}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

void main() {
  // ── §6 test 1: label, value and trailing share one baseline ────────────────

  testWidgets('label, value and trailing sit on one alphabetic baseline',
      (tester) async {
    await tester.pumpWidget(_host(
      const DetailRow('when', '9 Aug 20:14', trailing: 'm200'),
    ));

    final label = _labelBaseline(tester, 'WHEN');
    final value = _valueBaseline(tester, '9 Aug 20:14');
    final trailing = _trailingBaseline(tester, 'm200');

    // Pre-fix (CrossAxisAlignment.start + top:2 nudge) these are three
    // different lines: 10.55 / 13.16 / 11.70 below the row top.
    expect(label, moreOrLessEquals(value, epsilon: 0.01));
    expect(trailing, moreOrLessEquals(value, epsilon: 0.01));
  });

  // ── §6 test 2: the column has an edge — labels end and values start
  //    on the same x regardless of label length ─────────────────────────────

  testWidgets('labels right-align to one edge; Insets.md separates the '
      'column from the value for every label length', (tester) async {
    await tester.pumpWidget(_host(
      const Column(
        children: [
          DetailRow('when', 'first value'),
          DetailRow('paid with', 'second value'),
        ],
      ),
    ));

    // Values start on one edge…
    final v1Left = tester.getRect(find.text('first value')).left;
    final v2Left = tester.getRect(find.text('second value')).left;
    expect(v1Left, moreOrLessEquals(v2Left, epsilon: 0.01));

    // …a real Insets.md gap after the 62pt label box (pre-fix this gap is 0)…
    final labelBoxRight = tester.getRect(find.text('WHEN')).right;
    expect(v1Left - labelBoxRight, moreOrLessEquals(Insets.md, epsilon: 0.01));

    // …and the labels themselves end on one edge (pre-fix they are
    // left-aligned, so a short and a long label end at different x).
    final shortEnd = _glyphRightEdge(tester, 'WHEN');
    final longEnd = _glyphRightEdge(tester, 'PAID WITH');
    expect(shortEnd, moreOrLessEquals(longEnd, epsilon: 1.0));
  });

  // ── §6 test 3: a wrapping value keeps the label on its first line ──────────

  testWidgets('a multi-line value baseline-aligns the label with its first '
      'line', (tester) async {
    const longNote = 'A note long enough to wrap across several lines at a '
        'narrow width so the value box is much taller than the label';
    await tester.pumpWidget(_host(
      const DetailRow('note', longNote),
      width: 280,
    ));

    // The value really did wrap.
    final valueRect = tester.getRect(find.text(longNote));
    expect(valueRect.height, greaterThan(13.5 * 1.3 * 1.5));

    // The label's baseline meets the value's *first-line* baseline.
    final label = _labelBaseline(tester, 'NOTE');
    final valueFirstLine = _valueBaseline(tester, longNote);
    expect(label, moreOrLessEquals(valueFirstLine, epsilon: 0.01));
  });
}
