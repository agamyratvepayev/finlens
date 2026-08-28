import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Money on screen. Honours privacy mode (spec 1.1) in one place so no screen
/// has to remember to mask.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.currency = 'USD',
    this.style,
    this.color,
    this.showSign = false,
    this.forceDecimals = false,
    this.maskable = true,
    this.signless = false,
  });

  /// A balance: never signed. Colour carries asset vs liability instead.
  const AmountText.balance(
    this.value, {
    super.key,
    this.currency = 'USD',
    this.style,
    this.color,
    this.forceDecimals = false,
    this.maskable = true,
  })  : showSign = false,
        signless = true;

  final double value;
  final String currency;
  final TextStyle? style;
  final Color? color;
  final bool showSign;
  final bool forceDecimals;
  final bool maskable;
  final bool signless;

  @override
  Widget build(BuildContext context) {
    final masked = maskable && StoreScope.of(context).masked;
    return Text(
      money(
        value,
        currency: currency,
        showSign: showSign,
        forceDecimals: forceDecimals,
        masked: masked,
        signless: signless,
      ),
      style: (style ?? AppText.amount).copyWith(color: color),
    );
  }
}

/// Spec 6.2 "Yön ≠ renk" — the arrow carries direction, the colour carries
/// good/bad. A shrinking debt is a green ▼; a shrinking asset is a red ▼.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.fraction,
    this.caption,
    this.isLiability = false,
    this.compact = false,
  });

  final double fraction;
  final String? caption;

  /// For liabilities, "up" is bad and "down" is good — inverted from assets.
  final bool isLiability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rising = fraction >= 0;
    final good = isLiability ? !rising : rising;
    final color = fraction == 0
        ? AppColors.textSecondary
        : (good ? AppColors.positive : AppColors.negative);

    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rising ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          size: compact ? 16 : 20,
          color: color,
        ),
        Text(
          signedPercent(fraction),
          style: AppText.delta.copyWith(
            color: color,
            fontSize: compact ? 11.5 : 13,
          ),
        ),
      ],
    );

    if (caption == null) return chip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        Text(caption!, style: AppText.caption.copyWith(fontSize: 10.5)),
      ],
    );
  }
}

/// Two-tone bar showing the liability share of assets (spec 1.1).
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.liabilityRatio, this.height = 7});

  final double liabilityRatio;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ratio = liabilityRatio.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          // Childless boxes collapse under the loose cross-axis constraints a
          // Row hands out by default — stretch makes them fill the height.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: ((1 - ratio) * 1000).round().clamp(1, 1000),
              child: const ColoredBox(color: AppColors.positive),
            ),
            Expanded(
              flex: (ratio * 1000).round().clamp(1, 1000),
              child: const ColoredBox(color: AppColors.negative),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-value progress bar used by budgets, goals and credit utilisation.
/// The fill is capped at 100% — overspend is told in words, not by overflow
/// (spec 5.1).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
    this.background,
    this.paceMarker,
    this.markerWidth = 2,
    this.markerOverhang = 3,
  });

  final double value;
  final Color color;
  final double height;
  final Color? background;

  /// Spec 5.1 — vertical line marking how much of the month has elapsed.
  final double? paceMarker;

  /// Pace-marker geometry. Defaults match the budget bars (2pt wide, 3pt of
  /// overhang each side); the goal card passes thinner values so the marker
  /// doesn't outweigh its 3pt track.
  final double markerWidth;
  final double markerOverhang;

  @override
  Widget build(BuildContext context) {
    final fill = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Positioned.fill rather than a bare child: a Stack passes loose
              // constraints, under which a childless Container has no size.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background ?? AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fill,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
              if (paceMarker != null)
                Positioned(
                  left: (width * paceMarker!.clamp(0.0, 1.0) - markerWidth / 2)
                      .clamp(0.0, width - markerWidth),
                  top: -markerOverhang,
                  bottom: -markerOverhang,
                  child:
                      Container(width: markerWidth, color: AppColors.textPrimary),
                ),
            ],
          ),
        );
      },
    );
  }
}
