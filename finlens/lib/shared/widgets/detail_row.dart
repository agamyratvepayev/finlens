import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// One `LABEL value` line of a read-only detail block (spec §3). The caps label
/// is top-aligned so that when [value] wraps (a long note) the label stays
/// against the first line. [clampValue] ellipsises the value on one line (a long
/// account name), leaving [trailing] — e.g. a balance-after figure — its
/// intrinsic width.
///
/// Extracted verbatim from `SameTransactionsScreen._detailRow` so the detail
/// vocabulary (62pt caps column · 13.5pt value · optional trailing) is shared by
/// the transaction drilldown and the budget screen's in-place row, never forked.
class DetailRow extends StatelessWidget {
  const DetailRow(
    this.label,
    this.value, {
    super.key,
    this.trailing,
    this.valueColor,
    this.clampValue = false,
  });

  final String label;
  final String value;
  final String? trailing;
  final Color? valueColor;
  final bool clampValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              // Nudge the small caps down onto the value's first line rather
              // than floating at the very top of the taller value box.
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.57, // 0.06em @ 9.5pt
                  color: AppColors.detailLabel,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: clampValue ? 1 : null,
              overflow:
                  clampValue ? TextOverflow.ellipsis : TextOverflow.clip,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.3,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.sm),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
