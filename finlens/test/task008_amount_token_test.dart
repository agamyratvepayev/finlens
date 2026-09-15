import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 008 — one currency token on the number, and no decimals you did not type.
//
// `flutter test` hangs on the dev machine, so this file is written, not run
// here. Verify with `flutter analyze` and run it yourself:
//   flutter test test/task008_amount_token_test.dart
//
// The rules (Task 008 §1/§2):
//   §1  a symbol currency keeps its symbol on the number, on its own side
//       ($2,000.50 / 2,000.50 ₽); a code-only currency shows nothing there when
//       a chip names it (2,000.50), and its code (spaced) when there is no chip
//       (BAM 2,000).
//   §2  the field shows only the digits typed — no '.00' padding, ever.

const _accent = Color(0xFFAA0000);
const _accentDim = Color(0xFF002200);

/// A hero at a fixed width, with a chip (onCurrencyTap set) unless [chip] false.
Widget _host({
  required String raw,
  required String currency,
  bool chip = true,
  bool focused = false,
}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: NumericHeroCard(
            label: 'Amount',
            raw: raw,
            currency: currency,
            accent: _accent,
            accentDim: _accentDim,
            focused: focused,
            onTap: () {},
            onCurrencyTap: chip ? () {} : null,
          ),
        ),
      ),
    );

String _heroPlain(WidgetTester tester, String needle) => tester
    .renderObject<RenderParagraph>(
        find.textContaining(needle, findRichText: true))
    .text
    .toPlainText();

double _heroFont(WidgetTester tester, String needle) {
  final span = tester
      .renderObject<RenderParagraph>(
          find.textContaining(needle, findRichText: true))
      .text as TextSpan;
  return span.children!.whereType<TextSpan>().first.style!.fontSize!;
}

Future<void> _pumpAt(
  WidgetTester tester,
  Widget w, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: w,
  ));
  // Focused heroes blink forever; a couple of fixed frames, never settle.
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  // ── §1/§2 · the split, at the unit level ─────────────────────────────────

  group('AmountEntry.split — the token', () {
    ({String typed, String rest}) s(String raw, String cur, {bool chip = true}) =>
        AmountEntry.split(raw, cur, hasChip: chip);

    test('a symbol-before currency keeps its symbol beside a chip', () {
      final p = s('2000', 'USD');
      expect(p.typed, r'$2,000');
      expect(p.rest, isEmpty);
    });

    test('a code-only currency drops the token when a chip names it', () {
      final p = s('2000', 'BAM');
      expect(p.typed, '2,000');
      expect(p.rest, isEmpty);
    });

    test('a code-only currency keeps its code when there is no chip', () {
      final p = s('2000', 'BAM', chip: false);
      expect(p.typed, 'BAM 2,000');
      expect(p.rest, isEmpty);
    });

    test('a symbol-after currency renders the symbol flush on the right', () {
      // RUB is ₽ with symbolBefore: false. Flush, per the app's symbol law
      // (CurrencyDef: `9,850m`) — not the spaced form the §1 example shows.
      final p = s('2000.50', 'RUB');
      expect(p.typed, '2,000.50₽');
      expect(p.rest, isEmpty);
    });

    test('the five typing states show exactly what was typed (§2)', () {
      // Empty is the only state with a (dim) rest — the placeholder `$0`.
      expect(s('', 'USD'), (typed: '', rest: r'$0'));
      expect(s('2000', 'USD').typed, r'$2,000');
      expect(s('2000.', 'USD').typed, r'$2,000.');
      expect(s('2000.5', 'USD').typed, r'$2,000.5');
      expect(s('2000.50', 'USD').typed, r'$2,000.50');
      // None of them pad to two places.
      for (final raw in ['2000', '2000.', '2000.5']) {
        expect('${s(raw, 'USD').typed}${s(raw, 'USD').rest}',
            isNot(contains('.00')));
      }
    });

    test('the empty placeholder follows §1 across the three classes', () {
      expect(s('', 'USD').rest, r'$0'); // symbol before
      expect(s('', 'RUB').rest, '0₽'); // symbol after, flush
      expect(s('', 'BAM').rest, '0'); // code-only, chip
      expect(s('', 'BAM', chip: false).rest, 'BAM 0'); // code-only, no chip
    });
  });

  // ── the stored value did not move (§2 is display-only) ────────────────────

  test('AmountEntry.value is unchanged for every §2 state', () {
    expect(AmountEntry.value(''), 0);
    expect(AmountEntry.value('2000'), 2000.0);
    expect(AmountEntry.value('2000.'), 2000.0);
    expect(AmountEntry.value('2000.5'), 2000.5);
    expect(AmountEntry.value('2000.50'), 2000.5);
  });

  // ── the seed path agrees with typing (§2) ─────────────────────────────────

  test('an edited record seeds the field to the same string it types to', () {
    // fromDouble is the editing seam; split of its output must match §2.
    expect(AmountEntry.split(AmountEntry.fromDouble(2000.50), 'USD').typed,
        r'$2,000.50');
    expect(AmountEntry.split(AmountEntry.fromDouble(2000), 'USD').typed,
        r'$2,000');
  });

  // ── §2 · widget — no .00 until you type it ────────────────────────────────

  testWidgets('the hero shows no .00 until a dot then a digit are pressed',
      (tester) async {
    await _pumpAt(tester, _host(raw: '', currency: 'USD', focused: true));
    expect(_heroPlain(tester, r'$0'), isNot(contains('.00')));

    await _pumpAt(tester, _host(raw: '2000', currency: 'USD', focused: true));
    expect(_heroPlain(tester, '2,000'), isNot(contains('.')));

    await _pumpAt(tester, _host(raw: '2000.', currency: 'USD', focused: true));
    expect(_heroPlain(tester, '2,000.'), isNot(contains('.00')));

    await _pumpAt(tester, _host(raw: '2000.5', currency: 'USD', focused: true));
    final t = _heroPlain(tester, '2,000.5');
    expect(t, contains(r'$2,000.5'));
    expect(t, isNot(contains('2,000.50')));
  });

  // ── §2 · widget — an edited record ────────────────────────────────────────

  testWidgets('a seeded 2000.50 shows \$2,000.50; a seeded 2000 shows \$2,000',
      (tester) async {
    await _pumpAt(
        tester, _host(raw: AmountEntry.fromDouble(2000.50), currency: 'USD'));
    expect(_heroPlain(tester, '2,000.50'), contains(r'$2,000.50'));

    await _pumpAt(
        tester, _host(raw: AmountEntry.fromDouble(2000), currency: 'USD'));
    final t = _heroPlain(tester, '2,000');
    expect(t, contains(r'$2,000'));
    expect(t, isNot(contains('.00')));
  });

  // ── §1 · widget — the chip always reads the code ──────────────────────────

  testWidgets('the chip reads the code in all three currency classes',
      (tester) async {
    for (final c in ['USD', 'RUB', 'BAM']) {
      await _pumpAt(tester, _host(raw: '2000', currency: c));
      expect(
          find.descendant(
              of: find.byType(CurrencyChip), matching: find.text(c)),
          findsOneWidget,
          reason: 'the $c chip states its code');
    }
  });

  // ── §3 · widget — the glyph is no longer a dollar ─────────────────────────

  testWidgets('the leading glyph is never attach_money, in any currency',
      (tester) async {
    for (final c in ['USD', 'RUB', 'BAM']) {
      await _pumpAt(tester, _host(raw: '2000', currency: c));
      expect(find.byIcon(Icons.attach_money_rounded), findsNothing);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    }
  });

  // ── §1.2 · widget — semantics names the currency with no visible token ────

  testWidgets('the semantics value names the currency when the number carries '
      'no token (code-only)', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpAt(tester, _host(raw: '2000', currency: 'BAM'));

    // The bare number is `2,000` (no token), but the hero speaks its currency:
    // money(2000, 'BAM') == 'BAM 2,000'.
    expect(find.bySemanticsLabel(RegExp('BAM')), findsWidgets);
    handle.dispose();
  });

  // ── §4 · widget — a code-only currency fits at least as large ─────────────

  testWidgets('at 320×1.3 the code-only number fits at a font ≥ the symbol '
      'case (fewer glyphs on the tightest line)', (tester) async {
    const tight = Size(320, 568);
    // Twelve digits: wide enough to force the shrink ladder off its base.
    const raw = '999999999999';

    await _pumpAt(tester, _host(raw: raw, currency: 'USD'),
        size: tight, textScale: 1.3);
    final usd = _heroFont(tester, '999');

    await _pumpAt(tester, _host(raw: raw, currency: 'BAM'),
        size: tight, textScale: 1.3);
    final bam = _heroFont(tester, '999');

    // BAM shows no token; USD carries a '$'. The shorter string can only fit at
    // a font size at least as large — never smaller — than the longer one.
    expect(bam, greaterThanOrEqualTo(usd - 0.001),
        reason: 'the code-only amount is the least wide, so it fits best');
  });
}
