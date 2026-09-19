import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 045 — the currency unit is stated once, and spaced once.
//
// `flutter test` hangs on the dev machine, so this file is written, not run
// here. Verify with `flutter analyze` and run it yourself:
//   flutter test test/task045_currency_token_test.dart
//
// The rules under test (task 045 §1/§2):
//   §1  a chip beside the number already names the currency in words, so a token
//       that ALSO contains a letter (`m`, `TMT`, a code) drops — the unit is
//       stated once, by the chip. A glyph ($, €, ₽) is not a repetition of the
//       code, so it stays. With no chip the number always carries its token.
//   §2  spacing follows the token's CHARACTERS, not its kind: a glyph hugs, a
//       letter symbol or a code takes a (non-breaking) space. It is one rule —
//       CurrencyDef.tokenHugs — read by both money() and AmountEntry.split, so
//       the entry path can no longer print `2,000TMT` where money() prints
//       `2,000 TMT`.

// Six currencies spanning (glyph|letter|code) × (before|after). Registered as
// CUSTOM so money() routes through the metadata-driven _moneyCustom branch and
// can be compared against split token-for-token. Codes and symbols are chosen
// distinct so a stray token in the number is visible next to the chip's code.
const _fixtures = <CurrencyDef>[
  CurrencyDef(code: 'UD', name: 'Glyph before', symbol: r'$'),
  CurrencyDef(code: 'RB', name: 'Glyph after', symbol: '₽', symbolBefore: false),
  CurrencyDef(code: 'MM', name: 'Letter before', symbol: 'm'),
  CurrencyDef(code: 'TT', name: 'Letter after', symbol: 'TMT', symbolBefore: false),
  CurrencyDef(code: 'CB', name: 'Code before'),
  CurrencyDef(code: 'CA', name: 'Code after', symbolBefore: false),
];

const _nbsp = ' ';

void main() {
  setUp(() => setCustomCurrencies(_fixtures));
  // Clear the registry so a registered fixture never leaks into another file.
  tearDown(() => setCustomCurrencies(const []));

  ({String typed, String rest}) s(String raw, String code, {bool chip = true}) =>
      AmountEntry.split(raw, code, hasChip: chip);

  // ── §1 · the token, at the unit level ────────────────────────────────────

  group('AmountEntry.split — the unit is stated once', () {
    // (code, hasChip) → the exact typed span for a whole `2000`.
    const cases = <(String, bool), String>{
      // A chip beside the number: a letter token or a code drops; a glyph stays.
      ('UD', true): r'$2,000', // glyph before — stays
      ('RB', true): '2,000₽', // glyph after — stays
      ('MM', true): '2,000', // letter before — dropped
      ('TT', true): '2,000', // letter after — dropped
      ('CB', true): '2,000', // code before — dropped
      ('CA', true): '2,000', // code after — dropped
      // No chip: the number always carries its token, spaced by the letter rule.
      ('UD', false): r'$2,000',
      ('RB', false): '2,000₽',
      ('MM', false): 'm${_nbsp}2,000',
      ('TT', false): '2,000${_nbsp}TMT',
      ('CB', false): 'CB${_nbsp}2,000',
      ('CA', false): '2,000${_nbsp}CA',
    };

    cases.forEach((key, expected) {
      final (code, chip) = key;
      test('$code, chip=$chip → "$expected"', () {
        final p = s('2000', code, chip: chip);
        expect(p.typed, expected);
        expect(p.rest, isEmpty);
      });
    });
  });

  // ── §2 · split and money() agree on the token and the gap ─────────────────

  test('split and money() carry the same token, side and gap', () {
    for (final def in _fixtures) {
      // The affix money() prints and split (no chip, so a token is guaranteed)
      // must print too: token+gap before the number, or gap+token after it.
      final gap = def.tokenHugs ? '' : _nbsp;
      final m = money(2000, currency: def.code);
      final split = s('2000', def.code, chip: false).typed;

      if (def.symbolBefore) {
        final prefix = '${def.token}$gap';
        expect(m, startsWith(prefix),
            reason: 'money(${def.code}) leads with "$prefix"');
        expect(split, startsWith(prefix),
            reason: 'split(${def.code}) leads with "$prefix"');
      } else {
        final suffix = '$gap${def.token}';
        expect(m, endsWith(suffix),
            reason: 'money(${def.code}) ends with "$suffix"');
        expect(split, endsWith(suffix),
            reason: 'split(${def.code}) ends with "$suffix"');
      }

      // And where a chip DOES leave a token on the number (a glyph), that token
      // matches too; where it does not (a letter/code), the number is bare.
      final chipped = s('2000', def.code, chip: true).typed;
      if (def.tokenHugs) {
        expect(chipped, split,
            reason: 'a glyph survives the chip and matches the chipless form');
      } else {
        expect(chipped, '2,000',
            reason: 'a letter/code token drops beside a chip');
      }
    }
  });

  // ── §1 · the empty placeholder carries the same token on the same rule ────

  test('the empty placeholder attaches the token by the same rule', () {
    // No chip: the dim `rest` is the whole placeholder, token and all.
    expect(s('', 'UD', chip: false).rest, r'$0');
    expect(s('', 'MM', chip: false).rest, 'm${_nbsp}0');
    expect(s('', 'CB', chip: false).rest, 'CB${_nbsp}0');
    expect(s('', 'RB', chip: false).rest, '0₽');
    expect(s('', 'TT', chip: false).rest, '0${_nbsp}TMT');
    expect(s('', 'CA', chip: false).rest, '0${_nbsp}CA');

    // A chip present: a glyph stays on the `0`, a letter/code leaves a bare `0`.
    expect(s('', 'UD').rest, r'$0');
    expect(s('', 'RB').rest, '0₽');
    for (final code in ['MM', 'TT', 'CB', 'CA']) {
      expect(s('', code).rest, '0', reason: '$code drops its token beside a chip');
    }
  });

  // ── task 043 §4 · the decimal rule is intact under the token change ────────

  test('decimals still follow task 043 §4', () {
    // No point → no decimals; a point → completed to the currency width, the
    // completion in the dim `rest`. USD-like two-decimal currency, glyph before.
    expect(s('100000', 'UD'), (typed: r'$100,000', rest: ''));
    expect(s('100000.', 'UD'), (typed: r'$100,000.', rest: '00'));
    expect(s('100000.5', 'UD'), (typed: r'$100,000.5', rest: '0'));
    expect(s('100000.95', 'UD'), (typed: r'$100,000.95', rest: ''));

    // A trailing token joins the dim run rather than being stranded bright.
    expect(s('100000.5', 'TT', chip: false),
        (typed: '100,000.5', rest: '0${_nbsp}TMT'));
  });

  // ── §1 · widget — the word appears once on the row, not twice ──────────────

  testWidgets('a letter-symbol currency states its unit once on the amount row',
      (tester) async {
    // The manat overridden to symbol `TMT`, placed after the number — the exact
    // defect. The chip names the code `TMT`; the number must NOT repeat it.
    setCustomCurrencies(const [
      CurrencyDef(
          code: 'TMT',
          name: 'Manat',
          symbol: 'TMT',
          symbolBefore: false,
          custom: true),
    ]);
    addTearDown(() => setCustomCurrencies(const []));

    await _pumpHero(tester, raw: '2000', currency: 'TMT');

    // Count 'TMT' across every rendered paragraph in the hero (chip included).
    // Before the fix: 2 (the chip's code + the number's glued symbol `2,000TMT`).
    // After: exactly 1 — the chip.
    final n = _countInHero(tester, 'TMT');
    expect(n, 1, reason: 'the unit is printed once on the row, by the chip');

    // The number itself carries no `TMT`.
    final amount = _amountText(tester);
    expect(amount, isNot(contains('TMT')));
    expect(amount, contains('2,000'));
  });

  // ── regression · splitPlain never attaches a token, for any currency ──────

  test('splitPlain returns a bare number for every currency', () {
    for (final code in [...(_fixtures.map((d) => d.code)), 'USD', 'JPY', 'BHD']) {
      expect(AmountEntry.splitPlain('2000', code), (typed: '2,000', rest: ''),
          reason: 'splitPlain($code) carries no token');
      expect(AmountEntry.splitPlain('', code), (typed: '', rest: '0'),
          reason: 'splitPlain($code) empty placeholder is a bare 0');
    }
  });
}

// ── helpers ─────────────────────────────────────────────────────────────────

const _accent = Color(0xFFAA0000);
const _accentDim = Color(0xFF002200);

Future<void> _pumpHero(
  WidgetTester tester, {
  required String raw,
  required String currency,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: NumericHeroCard(
          label: 'Amount',
          raw: raw,
          currency: currency,
          accent: _accent,
          accentDim: _accentDim,
          focused: false,
          onTap: () {},
          onCurrencyTap: () {}, // a chip is shown
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Occurrences of [needle] across every RichText (Text and Text.rich both
/// render as RichText) inside the hero — the chip and the number together.
int _countInHero(WidgetTester tester, String needle) {
  var n = 0;
  for (final e in find
      .descendant(
          of: find.byType(NumericHeroCard), matching: find.byType(RichText))
      .evaluate()) {
    final rt = e.widget as RichText;
    n += needle.allMatches(rt.text.toPlainText()).length;
  }
  return n;
}

/// The amount paragraph's flattened text (the one carrying the grouped digits).
String _amountText(WidgetTester tester) => (tester
        .renderObject<RenderParagraph>(
            find.textContaining('2,000', findRichText: true))
        .text)
    .toPlainText();
