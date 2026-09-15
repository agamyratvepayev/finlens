import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/quick_add/transfer_math.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/transfer_fee_math_test.dart
//
// Pure arithmetic of the Transfer fee + exchange (Transfer-fee spec §3–§5):
// gross→net, deduct-then-convert, per-currency rounding, the summary-visibility
// rule, the caption shape, and the two fee validators.

void main() {
  group('transferNet', () {
    test('gross minus fee, treating null/0 as no fee', () {
      expect(transferNet(2000, 5), 1995);
      expect(transferNet(2000, null), 2000);
      expect(transferNet(2000, 0), 2000);
    });
  });

  group('transferArriving — deducted first, converted second (§4.2)', () {
    test('same currency, no fee → gross', () {
      expect(
        transferArriving(
            gross: 2000, fee: null, cross: false, rate: 1, toCurrency: 'USD'),
        2000,
      );
    });

    test('same currency, fee → net', () {
      expect(
        transferArriving(
            gross: 2000, fee: 5, cross: false, rate: 1, toCurrency: 'USD'),
        1995,
      );
    });

    test('cross currency with fee equals (gross − fee) × rate, NOT gross × rate',
        () {
      final arriving = transferArriving(
          gross: 2000, fee: 12, cross: true, rate: 0.9091, toCurrency: 'EUR');
      // (2000 − 12) × 0.9091 = 1807.2908 → 1807.29 at EUR's 2 dp.
      expect(arriving, closeTo(1807.29, 0.0001));
      // Must not be the naive 2000 × 0.9091 = 1818.20.
      expect(arriving,
          isNot(closeTo(roundToCurrency(2000 * 0.9091, 'EUR'), 0.0001)));
    });

    test('cross currency, no fee → gross × rate', () {
      expect(
        transferArriving(
            gross: 2000, fee: null, cross: true, rate: 0.9091, toCurrency: 'EUR'),
        closeTo(1818.20, 0.0001),
      );
    });
  });

  group('roundToCurrency — the one per-currency precision rule (§6)', () {
    test('2-decimal destination (EUR)', () {
      expect(roundToCurrency(1807.2908, 'EUR'), closeTo(1807.29, 0.00001));
    });
    test('0-decimal destination (JPY) rounds to a whole unit', () {
      expect(roundToCurrency(1807.2908, 'JPY'), 1807);
      expect(roundToCurrency(1807.9, 'JPY'), 1808);
    });
  });

  group('transferShowsSummary (§5)', () {
    test('same currency, no fee → false', () {
      expect(transferShowsSummary(fee: null, cross: false), isFalse);
      expect(transferShowsSummary(fee: 0, cross: false), isFalse);
    });
    test('fee only → true', () {
      expect(transferShowsSummary(fee: 5, cross: false), isTrue);
    });
    test('fx only → true', () {
      expect(transferShowsSummary(fee: null, cross: true), isTrue);
    });
    test('fee and fx → true', () {
      expect(transferShowsSummary(fee: 5, cross: true), isTrue);
    });
  });

  group('arrivesCaptionShape — the four shapes (§5)', () {
    test('none / fee / rate / feeAndRate', () {
      expect(arrivesCaptionShape(fee: null, cross: false),
          ArrivesCaptionShape.none);
      expect(
          arrivesCaptionShape(fee: 5, cross: false), ArrivesCaptionShape.fee);
      expect(
          arrivesCaptionShape(fee: null, cross: true), ArrivesCaptionShape.rate);
      expect(arrivesCaptionShape(fee: 5, cross: true),
          ArrivesCaptionShape.feeAndRate);
    });
  });

  group('transferFeeValid (§3.3)', () {
    test('0 ok, below gross ok, at/above gross bad, negative bad, null ok', () {
      expect(transferFeeValid(2000, 0), isTrue);
      expect(transferFeeValid(2000, 5), isTrue);
      expect(transferFeeValid(2000, 2000), isFalse);
      expect(transferFeeValid(2000, 2500), isFalse);
      expect(transferFeeValid(2000, -1), isFalse);
      expect(transferFeeValid(2000, null), isTrue);
    });
  });

  group('transferFeeComplete (§3.3)', () {
    test('a non-zero fee needs a category; a zero/blank one does not', () {
      expect(transferFeeComplete(null, null), isTrue);
      expect(transferFeeComplete(0, null), isTrue);
      expect(transferFeeComplete(5, null), isFalse);
      expect(transferFeeComplete(5, 'c-fee'), isTrue);
    });
  });
}
