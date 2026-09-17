import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/currency_def.dart';
import 'package:finlens/core/utils/formatters.dart';

/// Unit tests for the one place an amount becomes display text with an explicit
/// [AmountKind] (spec §1/§2): magnitude renders unsigned, signed keeps a true
/// U+2212 minus when negative and never adds a plus; a trailing affix takes a
/// non-breaking U+00A0 space; zero is never negative.
void main() {
  setUp(() => setCustomCurrencies(const []));
  tearDown(() => setCustomCurrencies(const []));

  group('magnitude is unsigned, signed keeps its minus', () {
    test('leading symbol — USD', () {
      expect(formatAmount(2000, 'USD', kind: AmountKind.magnitude), r'$2,000');
      expect(formatAmount(-2000, 'USD', kind: AmountKind.magnitude), r'$2,000');
      expect(formatAmount(2000, 'USD', kind: AmountKind.signed), r'$2,000');
      expect(formatAmount(-2000, 'USD', kind: AmountKind.signed), '−\$2,000');
    });

    test('leading code — CHF (spaced with a non-breaking space)', () {
      expect(formatAmount(1500, 'CHF', kind: AmountKind.magnitude),
          'CHF 1,500');
      expect(formatAmount(-1500, 'CHF', kind: AmountKind.signed),
          '−CHF 1,500');
    });

    test('trailing code — custom symbolBefore:false (non-breaking space)', () {
      setCustomCurrencies(const [
        CurrencyDef(code: 'ZZZ', name: 'Z', symbolBefore: false, custom: true),
      ]);
      expect(formatAmount(1500, 'ZZZ', kind: AmountKind.magnitude),
          '1,500.00 ZZZ');
      expect(formatAmount(-1500, 'ZZZ', kind: AmountKind.signed),
          '−1,500.00 ZZZ');
    });

    test('zero-decimal headline — JPY', () {
      expect(formatAmount(2000, 'JPY', kind: AmountKind.magnitude), '¥2,000');
      expect(formatAmount(-2000.4, 'JPY', kind: AmountKind.signed), '−¥2,000');
    });

    test('two decimals kept on a small precise amount', () {
      expect(formatAmount(15.99, 'USD', kind: AmountKind.magnitude), r'$15.99');
      expect(formatAmount(-15.99, 'USD', kind: AmountKind.signed), '−\$15.99');
    });
  });

  group('zero is never negative', () {
    test('-0.0 and values rounding to zero render as \$0, never −\$0', () {
      expect(formatAmount(-0.0, 'USD', kind: AmountKind.signed), r'$0');
      expect(formatAmount(-0.004, 'USD', kind: AmountKind.signed), r'$0');
      expect(
          formatAmount(-0.004, 'USD',
              kind: AmountKind.signed, forceDecimals: true),
          r'$0.00');
    });

    test('the custom-currency path also never emits −0', () {
      setCustomCurrencies(const [
        CurrencyDef(code: 'ZZZ', name: 'Z', symbolBefore: false, custom: true),
      ]);
      expect(formatAmount(-0.004, 'ZZZ', kind: AmountKind.signed),
          '0.00 ZZZ');
    });
  });

  group('glyph identity — asserted by code unit, not by eye', () {
    test('the minus is U+2212, not an ASCII hyphen', () {
      final s = formatAmount(-5, 'USD', kind: AmountKind.signed);
      expect(s.codeUnitAt(0), 0x2212);
      expect(s.contains('-'), isFalse);
    });

    test('the affix space is U+00A0 (non-breaking), not an ordinary space', () {
      final s = formatAmount(1500, 'CHF', kind: AmountKind.magnitude);
      expect(s, 'CHF 1,500');
      expect(s.codeUnitAt(3), 0x00A0); // 'C','H','F', then the affix space
      expect(s.contains(' '), isFalse); // never an ordinary space
    });
  });

  group('a magnitude never contains a minus', () {
    test('for any sign of input, and every affix shape', () {
      for (final v in [0.0, -0.0, 5.0, -5.0, -1234.56, 1000000000.0, -1e9]) {
        for (final c in ['USD', 'CHF', 'JPY', 'EUR']) {
          expect(formatAmount(v, c, kind: AmountKind.magnitude).contains('−'),
              isFalse,
              reason: 'magnitude of $v in $c must be unsigned');
        }
      }
    });
  });
}
