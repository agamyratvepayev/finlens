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
    this.currency,
    this.style,
    this.color,
    this.showSign = false,
    this.forceDecimals = false,
    this.maskable = true,
    this.signless = false,
    this.isLiability = false,
  });

  /// A balance. Unsigned while its sign agrees with its account's kind, signed
  /// the moment it contradicts it (task 011).
  ///
  /// The old rule was "never signed — colour carries asset vs liability". Colour
  /// carries the account's *kind*; it never carried the figure's *sign*, and it
  /// has no shade for an asset that has gone below zero. Such a row printed the
  /// same pixels as one holding the same amount in credit.
  ///
  /// [isLiability] defaults to false, which is also the safe default: an
  /// asset-side figure — an asset account, an asset group, net worth, a goal
  /// balance — shows its minus when it has one. Only the call sites that render
  /// something owed pass true, and those already compute the flag for their
  /// colour.
  const AmountText.balance(
    this.value, {
    super.key,
    this.currency,
    this.style,
    this.color,
    this.forceDecimals = false,
    this.maskable = true,
    this.isLiability = false,
  })  : showSign = false,
        signless = true;

  final double value;

  /// The currency to render in. When null (the default), the amount renders in
  /// the store's base currency — most on-screen figures are base-currency
  /// aggregates, so the base is the right default rather than a fixed dollar.
  /// Callers pass an explicit code for an account- or transaction-scoped amount.
  final String? currency;
  final TextStyle? style;
  final Color? color;
  final bool showSign;
  final bool forceDecimals;
  final bool maskable;
  final bool signless;

  /// Whether [value] is a liability-side figure — something owed. Defaults to
  /// false (asset-side). Only meaningful when [signless] is set (the `.balance`
  /// constructor): it decides which sign agrees with the account's kind. The
  /// default constructor never sets [signless], so this has no effect there.
  final bool isLiability;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final masked = maskable && store.masked;
    // The sign is redundant exactly while it agrees with the kind: a positive
    // asset, a negative liability. Otherwise it is the only thing that says the
    // balance is not what the account is for.
    final contradicts = isLiability ? value > 0 : value < 0;
    final signlessNow = signless && !contradicts;
    // A negative value already prints its − once signless is off; showSign is
    // needed only to force a + on a liability that has gone into credit.
    final showSignNow = showSign || (contradicts && isLiability);
    return Text(
      money(
        value,
        currency: currency ?? store.baseCurrency,
        showSign: showSignNow,
        forceDecimals: forceDecimals,
        masked: masked,
        signless: signlessNow,
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
