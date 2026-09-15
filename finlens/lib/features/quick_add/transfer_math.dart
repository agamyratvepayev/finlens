/// Pure arithmetic for the Transfer form's fee and exchange (Transfer-fee spec
/// §3 / §4 / §5). Kept out of the widget so the rules are unit-testable without
/// pumping a form, and so the form and its tests share one source of truth.
library;

import '../../core/utils/formatters.dart';

/// The amount the transfer record carries: the gross minus the fee (§4). The
/// fee is a separate expense; the transfer moves only the net.
double transferNet(double gross, double? fee) => gross - (fee ?? 0);

/// What the destination receives (§4.2): the fee is deducted first (in the
/// source currency) and the rest converted second, so a cross-currency transfer
/// arrives at `(gross − fee) × rate`, never `gross × rate`. Rounds through the
/// one currency-precision rule ([roundToCurrency]) and adds no second one.
double transferArriving({
  required double gross,
  double? fee,
  required bool cross,
  required double rate,
  required String toCurrency,
}) {
  final net = transferNet(gross, fee);
  return cross ? roundToCurrency(net * rate, toCurrency) : net;
}

/// The summary shows only when the two sides differ — a fee exists, or the
/// currencies do (§5). On a plain same-currency transfer with no fee the two
/// lines would print one number twice.
bool transferShowsSummary({double? fee, required bool cross}) =>
    (fee ?? 0) > 0 || cross;

/// A fee that eats the whole transfer is not a transfer (§3.3).
bool transferFeeValid(double gross, double? fee) =>
    fee == null || (fee >= 0 && fee < gross);

/// A non-zero fee must have a category, or it lands in no budget and no report
/// (§3.3); a zero or blank fee needs none.
bool transferFeeComplete(double? fee, String? categoryId) =>
    fee == null || fee == 0 || categoryId != null;

/// Which of the four caption shapes the `Arrives` row shows (§5). Returned as an
/// enum so the widget maps it to a localised string and the test can assert the
/// shape without a BuildContext.
enum ArrivesCaptionShape { none, fee, rate, feeAndRate }

ArrivesCaptionShape arrivesCaptionShape({double? fee, required bool cross}) {
  final hasFee = (fee ?? 0) > 0;
  if (hasFee && cross) return ArrivesCaptionShape.feeAndRate;
  if (hasFee) return ArrivesCaptionShape.fee;
  if (cross) return ArrivesCaptionShape.rate;
  return ArrivesCaptionShape.none;
}
