import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Two independent tap targets sharing one row: a label, its live count, and a
/// chevron on each side of a hairline. Categories and Tags are the same kind of
/// thing — a label you attach to a transaction — and neither earns a row of its
/// own at this density. The pattern is the `insight-spec` §4 debt-state block:
/// two equal cells, one 0.5 pt vertical divider.
///
/// Deliberately not in shared/widgets: nothing else in the app splits a row
/// between two destinations, and a FormSection row that goes two places would
/// be a defect anywhere else.
class SplitCountRow extends StatelessWidget {
  const SplitCountRow({
    super.key,
    required this.leftLabel,
    required this.leftCount,
    required this.onLeftTap,
    required this.rightLabel,
    required this.rightCount,
    required this.onRightTap,
  });

  final String leftLabel;
  final int leftCount;
  final VoidCallback onLeftTap;
  final String rightLabel;
  final int rightCount;
  final VoidCallback onRightTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Cell(label: leftLabel, count: leftCount, onTap: onLeftTap),
          ),
          // 0.5 pt separator between cells, inset 6 pt so it reads as a divider
          // between two controls, not a border on the card.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 0.5,
              child: ColoredBox(color: AppColors.divider),
            ),
          ),
          Expanded(
            child: _Cell(label: rightLabel, count: rightCount, onTap: onRightTap),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Each cell is its own button so a screen reader reads the row as two
    // controls, never one.
    return Semantics(
      button: true,
      label: '$label $count',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            children: [
              // The label ellipsises under a narrow locale (RU КАТЕГОРИИ / ТЕГИ,
              // TK) — the count never shrinks, so a row that loses room loses
              // letters, not its figure.
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                // Tabular so 99 → 100 does not shift the two cells relative to
                // each other. AppText.amount is already tabular w600.
                style: AppText.amount,
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
