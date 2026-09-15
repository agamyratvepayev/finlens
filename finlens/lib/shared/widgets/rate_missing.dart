import 'package:flutter/material.dart';

import '../../core/models/currency_def.dart';
import '../../features/quick_add/pickers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The word that replaces a silenced total (spec 021a §2c): `Rate missing`, in
/// [AppColors.warning], sized to sit in the slot the number would have had. It
/// takes the number's place — the surrounding card is never re-laid-out.
class RateMissingText extends StatelessWidget {
  const RateMissingText({
    super.key,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.align = TextAlign.start,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Text(
      l.curRateMissing,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: AppColors.warning,
      ),
    );
  }
}

/// The warning card shown beneath any card whose total was silenced (spec 021a
/// §4b): `⚠ BAM has no rate / Totals that include it are hidden`, with a
/// `Set rate` action that opens that currency's edit sheet directly — a warning
/// that cannot be acted on is worse than no warning. More than one currency
/// missing names the first and adds `+N`, never a list.
class RateMissingCard extends StatelessWidget {
  const RateMissingCard({super.key, required this.codes});

  /// In-use currency codes with no rate, first-named on the card.
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final first = codes.first;
    final extra = codes.length - 1;
    final title = extra > 0
        ? '${l.curNoRateFor(first)}  +$extra'
        : l.curNoRateFor(first);

    return Container(
      margin: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.warning, 0.14),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                        fontSize: 13.5, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(l.curTotalsHidden,
                    maxLines: 2,
                    style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () =>
                showEditCurrencySheet(context, currencyDef(first)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.curSetRate,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
