import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 11 — "the pale decimals never turn white".
//
// `flutter test` hangs on the dev machine, so this file is written, not run
// here. Verify with `flutter analyze` and run it yourself:
//   flutter test test/task11_amount_hero_colors_test.dart
//
// The rule (spec §0), for every amount the user types:
//   • nothing typed (raw empty)            → the whole placeholder is dim
//   • typing (focused, raw non-empty)      → typed bright, untyped padding dim
//   • done (unfocused, raw non-empty)      → everything bright, no dim part
//
// These drive `NumericHeroCard` directly with two sentinel colours so the
// bright accent and the dim accent are unmistakable in the rendered spans.

const _accent = Color(0xFFAA0000); // "bright"
const _accentDim = Color(0xFF002200); // "not typed yet"

Widget _host({required String raw, required bool focused}) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: NumericHeroCard(
            label: 'Amount',
            raw: raw,
            currency: 'USD',
            accent: _accent,
            accentDim: _accentDim,
            focused: focused,
            onTap: () {},
            onCurrencyTap: () {},
          ),
        ),
      ),
    );

/// The amount paragraph's child TextSpans (the caret is a WidgetSpan and is
/// skipped), paired with their colour.
List<({String text, Color? color})> _spans(WidgetTester tester, String needle) {
  final rp = tester.renderObject<RenderParagraph>(
      find.textContaining(needle, findRichText: true));
  final root = rp.text as TextSpan;
  return [
    for (final c in root.children ?? const <InlineSpan>[])
      if (c is TextSpan) (text: c.text ?? '', color: c.style?.color),
  ];
}

Future<void> _pumpFocused(WidgetTester tester, Widget w) async {
  // The caret blinks forever once focused, so pumpAndSettle never returns —
  // use a couple of fixed frames instead.
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('unfocused with a typed value carries NO dim span '
      '(the change this task exists to make)', (tester) async {
    // Before the fix the ".00" padding was painted accentDim whether focused or
    // not, so this assertion went red. After the fix a done amount is all
    // bright.
    await tester.pumpWidget(_host(raw: '1000', focused: false));
    await tester.pumpAndSettle();

    final colours = _spans(tester, '1,000').map((s) => s.color).toList();
    expect(colours, isNot(contains(_accentDim)),
        reason: 'a saved amount has no "not typed yet" pale part');
    expect(colours, contains(_accent));
  });

  testWidgets('focused with a typed value carries exactly one dim span, '
      'and it is the padding', (tester) async {
    await _pumpFocused(tester, _host(raw: '1000', focused: true));

    final spans = _spans(tester, '1,000');
    final dim = spans.where((s) => s.color == _accentDim).toList();
    expect(dim.length, 1, reason: 'only the untyped padding is dim while typing');
    expect(dim.single.text, '.00');
    // And the typed digits stay bright.
    expect(spans.where((s) => s.color == _accent).map((s) => s.text),
        contains(r'$1,000'));
  });

  testWidgets('a partial decimal dims only the untyped trailing zero',
      (tester) async {
    await _pumpFocused(tester, _host(raw: '1000.5', focused: true));

    final spans = _spans(tester, '1,000.5');
    final dim = spans.where((s) => s.color == _accentDim).toList();
    expect(dim.length, 1);
    expect(dim.single.text, '0', reason: 'the trailing pad zero is not typed yet');
  });

  testWidgets('an empty field is all dim — focused and unfocused alike',
      (tester) async {
    for (final focused in [false, true]) {
      if (focused) {
        await _pumpFocused(tester, _host(raw: '', focused: true));
      } else {
        await tester.pumpWidget(_host(raw: '', focused: false));
        await tester.pumpAndSettle();
      }

      final colours = _spans(tester, r'$0.00').map((s) => s.color).toList();
      expect(colours, isNotEmpty);
      expect(colours.every((c) => c == _accentDim), isTrue,
          reason: 'the placeholder is dim (focused=$focused)');
      expect(colours, isNot(contains(_accent)));
    }
  });
}
