import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/widgets/amount_hero.dart';

// Task 043 §4 — decimals appear only once a decimal point is typed, and then
// the field completes to the currency's own width with dim zeros. The two
// splitters must agree digit-for-digit: [AmountEntry.split] (with the currency
// token) and [AmountEntry.splitPlain] (without).
//
// `flutter test` hangs on the author's machine — run this yourself:
//   flutter test test/task043_decimal_entry_test.dart

/// The number a split result renders — the currency token stripped, so `split`
/// (which prefixes `$`/`m`/`¥`) and `splitPlain` (which does not) can be
/// compared for equal digits.
String digitsOf(({String typed, String rest}) p) =>
    '${p.typed}${p.rest}'.replaceAll(RegExp(r'[^0-9.,]'), '');

void main() {
  const inputs = ['', '100000', '100000.', '100000.5', '100000.95'];

  // splitPlain has no token, so these are the exact tuples for every input.
  // TMT and USD are two-decimal; JPY is zero-decimal (a point never completes).
  const expected = <String, Map<String, ({String typed, String rest})>>{
    'USD': {
      '': (typed: '', rest: '0'),
      '100000': (typed: '100,000', rest: ''),
      '100000.': (typed: '100,000.', rest: '00'),
      '100000.5': (typed: '100,000.5', rest: '0'),
      '100000.95': (typed: '100,000.95', rest: ''),
    },
    'TMT': {
      '': (typed: '', rest: '0'),
      '100000': (typed: '100,000', rest: ''),
      '100000.': (typed: '100,000.', rest: '00'),
      '100000.5': (typed: '100,000.5', rest: '0'),
      '100000.95': (typed: '100,000.95', rest: ''),
    },
    'JPY': {
      '': (typed: '', rest: '0'),
      '100000': (typed: '100,000', rest: ''),
      '100000.': (typed: '100,000.', rest: ''),
      '100000.5': (typed: '100,000.5', rest: ''),
      '100000.95': (typed: '100,000.95', rest: ''),
    },
  };

  group('splitPlain: no point → no decimals; a point → completed field', () {
    for (final cur in expected.keys) {
      test(cur, () {
        for (final raw in inputs) {
          expect(AmountEntry.splitPlain(raw, cur), expected[cur]![raw],
              reason: 'splitPlain("$raw", $cur)');
        }
      });
    }
  });

  group('split and splitPlain agree digit-for-digit', () {
    for (final cur in expected.keys) {
      test(cur, () {
        for (final raw in inputs) {
          final sc = AmountEntry.split(raw, cur);
          final sp = AmountEntry.splitPlain(raw, cur);
          expect(digitsOf(sc), digitsOf(sp),
              reason: 'split vs splitPlain digits for "$raw" $cur');
          // USD/JPY carry their glyph *before* the number and TMT (a letter
          // symbol) drops its token entirely beside the default chip (task 045
          // §1); either way `post` is empty, so the dim rest is exactly the
          // completion, nothing more. A symbol-after currency would append its
          // token to `post` and this equality would not hold — none is used here.
          expect(sc.rest, sp.rest,
              reason: 'the dim rest is the completion only, for "$raw" $cur');
        }
      });
    }
  });

  test('a three-decimal currency completes to three; JPY completes to none', () {
    // BHD (Bahraini Dinar) is a three-decimal, code-only currency.
    expect(AmountEntry.splitPlain('100000.', 'BHD'),
        (typed: '100,000.', rest: '000'));
    expect(AmountEntry.splitPlain('100000.5', 'BHD'),
        (typed: '100,000.5', rest: '00'));
    expect(AmountEntry.splitPlain('100000.95', 'BHD'),
        (typed: '100,000.95', rest: '0'));
    // JPY pads nothing even after a point.
    expect(AmountEntry.splitPlain('100000.', 'JPY').rest, isEmpty);
  });

  test('an empty field is a bare dim 0, no decimals, in every currency', () {
    for (final cur in ['USD', 'TMT', 'JPY', 'BHD']) {
      expect(AmountEntry.splitPlain('', cur), (typed: '', rest: '0'));
    }
  });
}
