import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';

// Task 24: the shipped TMT def drops its `m` symbol and moves its token (now the
// code) to *after* the number. USD — the regression guard — must stay byte-for-
// byte identical: `$` still leads, still flush.
//
// flutter test hangs on the author's machine — run this yourself:
//   flutter test test/task24_tmt_token_test.dart
//
// The NBSP that separates a code from its digits is built with fromCharCode so
// the expectation cannot be corrupted by an editor turning it into a plain space.
void main() {
  final nbsp = String.fromCharCode(0xA0);

  group('money() places the TMT code after the number', () {
    test('TMT reads "1,100 TMT"; USD is unchanged', () {
      // The headline swap. Run the TMT expectation before the fix and it fails
      // with `m1,100`; the catalog change alone would give `TMT 1,100` (token on
      // the wrong side). Both pieces together give this.
      expect(money(1100, currency: 'TMT'), '1,100${nbsp}TMT');
      expect(money(1100, currency: 'USD'), r'$1,100');
    });

    test('a negative TMT leads with the minus, before the number', () {
      expect(money(-1100, currency: 'TMT'), '−1,100${nbsp}TMT');
      // USD keeps the minus ahead of a flush symbol.
      expect(money(-1100, currency: 'USD'), r'−$1,100');
    });

    test('the legacy decimal rule is untouched by the token move', () {
      // No cents from 1,000 up; cents on a small, precise amount.
      expect(money(14500, currency: 'TMT'), '14,500${nbsp}TMT');
      expect(money(15.99, currency: 'TMT'), '15.99${nbsp}TMT');
    });

    test('masked TMT keeps the token on the right; masked USD is unchanged', () {
      final maskedTmt = money(1100, currency: 'TMT', masked: true);
      expect(maskedTmt.endsWith('${nbsp}TMT'), isTrue,
          reason: 'the code follows the mask, never "TMT ••••"');
      expect(maskedTmt.startsWith('TMT'), isFalse);

      // The mask body (the run of bullets) is whatever money() uses; a masked
      // USD is that same body with a flush `$` in front — exactly as before.
      final bullets = maskedTmt.split(nbsp).first;
      expect(money(1100, currency: 'USD', masked: true), '\$$bullets');
    });

    test('withSymbol: false is a bare number, no stray gap, either currency', () {
      expect(money(1100, currency: 'TMT', withSymbol: false), '1,100');
      expect(money(1100, currency: 'USD', withSymbol: false), '1,100');
    });
  });

  group('moneyCompact() follows the same placement', () {
    test('TMT is "8.4K TMT"; USD is "\$8.4K"', () {
      expect(moneyCompact(8400, currency: 'TMT'), '8.4K${nbsp}TMT');
      expect(moneyCompact(8400, currency: 'USD'), r'$8.4K');
    });
  });

  group('AmountEntry.split() honours the code position', () {
    test('no chip: the code sits after the digits', () {
      final parts = AmountEntry.split('2000', 'TMT', hasChip: false);
      expect(parts.typed, '2,000${nbsp}TMT');
    });

    test('with a chip: no token at all (the chip names the unit)', () {
      final parts = AmountEntry.split('2000', 'TMT', hasChip: true);
      expect(parts.typed, '2,000');
    });
  });
}
