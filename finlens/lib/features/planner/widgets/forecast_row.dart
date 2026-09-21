import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/rate_missing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// The Planner's one forecast row (task 057 §3): a slim, one-line strip above
/// the segmented control, identical on all three tabs, reading
/// `30 Sep │ Spendable ≈ 130   Net worth ≈ 18,080   ›`. It carries no control
/// of its own — its [date] is the end of the period the header already names
/// (§4) — and no tap target: the chevron slot is reserved but empty until the
/// Forecast screen (task 058).
///
/// The row is **always one line** and the type **never shrinks**; it steps down
/// a fixed ladder (§3d) — compact figures, tighter gaps, then dropping the date
/// and the `≈` — measured at the real width and text scale.
class ForecastRow extends StatelessWidget {
  const ForecastRow({super.key, required this.store, required this.date});

  final AppStore store;

  /// The forecast's end date — the header period's end (§4). The window always
  /// starts today.
  final DateTime date;

  // Geometry (§3a).
  static const double _height = 36;
  static const double _leftPad = 12;
  static const double _rightPad = 8;
  static const double _chevronSlot = 22; // reserved, drawn empty (§3f)
  static const double _chevronLead = 8; // ≥8 before the chevron (§3f)
  static const double _dividerLead = 10; // 10 before the 1×16 rule (§3b)
  static const double _labelGap = 5; // label → value inside a part
  static const double _gapWide = 12; // ladder minimum gap
  static const double _gapTight = 6;

  static const TextStyle _dateStyle =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const TextStyle _labelStyle =
      TextStyle(fontSize: 12.5, color: AppColors.textSecondary);
  static const TextStyle _rateMissingStyle =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.warning);

  static TextStyle _valueStyle(bool negative) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: negative ? AppColors.warning : AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final masked = store.masked;
    final result = store.forecastTo(date);

    final spend = _Value.of(result.spendable, masked);
    final net = _Value.of(result.netWorth, masked);
    final dateStr = dayMonth(date, l);
    final spendLabel = l.accountGroupSpendable;
    final netLabel = l.insNetWorth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, Insets.md),
      child: Container(
        height: _height,
        padding: const EdgeInsets.only(left: _leftPad, right: _rightPad),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            double measure(String s, TextStyle st) {
              final tp = TextPainter(
                text: TextSpan(text: s, style: st),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              return tp.width;
            }

            final available = constraints.maxWidth;
            final dateW = measure(dateStr, _dateStyle);
            final spendLabelW = measure(spendLabel, _labelStyle);
            final netLabelW = measure(netLabel, _labelStyle);
            final l10n = l;

            double valueW(_Value v, bool compact, bool approx) {
              if (v.isNull) return measure(l10n.curRateMissing, _rateMissingStyle);
              final s =
                  (approx ? '≈ ' : '') + (compact ? v.compact : v.full);
              return measure(s, _valueStyle(v.negative));
            }

            // Does step [s] (1..6) fit on one line? "Content" reserves the
            // chevron slot and its 8pt lead (§3f); gaps are laid out evenly by
            // spaceBetween, so folding the lead into content keeps the equal gap
            // before the chevron ≥ 8 (§3c/§3f).
            bool fits(int s) {
              final compact = s >= 3;
              final showDate = s < 5;
              final approx = s < 6;
              final minGap = (s == 1 || s == 3) ? _gapWide : _gapTight;
              final dateBlock =
                  showDate ? dateW + _dividerLead + 1 : 0.0;
              final spendPart =
                  spendLabelW + _labelGap + valueW(spend, compact, approx);
              final netPart =
                  netLabelW + _labelGap + valueW(net, compact, approx);
              final partCount = showDate ? 4 : 3;
              final content = dateBlock +
                  spendPart +
                  netPart +
                  _chevronSlot +
                  _chevronLead;
              final gaps = partCount - 1;
              return content + gaps * minGap <= available;
            }

            var step = 6;
            for (var s = 1; s <= 6; s++) {
              if (fits(s)) {
                step = s;
                break;
              }
            }
            final overflow = !fits(6);

            final compact = step >= 3;
            final showDate = step < 5;
            final approx = step < 6;

            final spendPart = _valuePart(
                spendLabel, spend, compact, approx, masked, l10n,
                flexible: overflow);
            final netPart = _valuePart(
                netLabel, net, compact, approx, masked, l10n,
                flexible: overflow);
            final children = <Widget>[
              if (showDate) _dateBlock(dateStr),
              overflow ? Flexible(child: spendPart) : spendPart,
              overflow ? Flexible(child: netPart) : netPart,
              const SizedBox(width: _chevronSlot),
            ];

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            );
          },
        ),
      ),
    );
  }

  Widget _dateBlock(String dateStr) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateStr, style: _dateStyle, maxLines: 1),
          const SizedBox(width: _dividerLead),
          Container(width: 1, height: 16, color: AppColors.divider),
        ],
      );

  Widget _valuePart(String label, _Value v, bool compact, bool approx,
      bool masked, AppLocalizations l,
      {required bool flexible}) {
    // Announced in full — never the compact form (§3h).
    final spoken = v.isNull
        ? l.curRateMissing
        : (masked ? '••••' : money(v.raw!, withSymbol: false));

    final Widget valueWidget = v.isNull
        ? const RateMissingText(fontSize: 12.5)
        : Text(
            (approx ? '≈ ' : '') + (compact ? v.compact : v.full),
            style: _valueStyle(v.negative),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle, maxLines: 1),
        const SizedBox(width: _labelGap),
        // When the whole part is Flexible (overflow floor) the value ellipsises
        // rather than wrapping; otherwise it keeps its natural width (§3d).
        flexible ? Flexible(child: valueWidget) : valueWidget,
      ],
    );

    return Semantics(
      label: '$label, $spoken',
      child: ExcludeSemantics(child: row),
    );
  }
}

/// A forecast lens value ready to render: null (rate missing), or a signed
/// figure with its masked-aware full and compact strings (§3e).
class _Value {
  const _Value.rateMissing()
      : raw = null,
        isNull = true,
        negative = false,
        full = '',
        compact = '';

  const _Value.number(this.raw, this.negative, this.full, this.compact)
      : isNull = false;

  final double? raw;
  final bool isNull;
  final bool negative;
  final String full;
  final String compact;

  static _Value of(double? v, bool masked) {
    if (v == null) return const _Value.rateMissing();
    final negative = v < 0;
    final full = masked ? '••••' : money(v, withSymbol: false);
    final compact = masked ? '••••' : moneyCompact(v, withSymbol: false);
    return _Value.number(v, negative, full, compact);
  }
}
