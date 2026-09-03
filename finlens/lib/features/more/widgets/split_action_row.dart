import 'package:flutter/material.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Two icon actions sharing one row — Back up | Restore. The sibling of
/// [SplitCountRow] for controls that *do* something rather than count something:
/// same [IntrinsicHeight] + stretch shell, same 0.5 pt separator inset 6 pt, same
/// per-cell [Semantics] so a screen reader reads two buttons, never one.
///
/// Differences from [SplitCountRow]: each cell carries a leading icon and neither
/// has a count or a chevron (these open a file picker and a sheet, not a screen).
/// Deliberately NOT a parameter on SplitCountRow — that widget's whole job is
/// counts, and a nullable count would blur it.
///
/// §2.1 — the two verbs must not ellipsise. When either label would overflow its
/// half at the current width and text scale (Russian "Восстановить", or Turkish
/// at 130 %), the row falls back to two stacked full-width rows for that render,
/// so a shortened word never loses letters.
class SplitActionRow extends StatelessWidget {
  const SplitActionRow({
    super.key,
    required this.leftIcon,
    required this.leftLabel,
    required this.onLeftTap,
    required this.rightIcon,
    required this.rightLabel,
    required this.onRightTap,
  });

  final IconData leftIcon;
  final String leftLabel;
  final VoidCallback onLeftTap;
  final IconData rightIcon;
  final String rightLabel;
  final VoidCallback onRightTap;

  /// Does [label] fit within [maxWidth] at the ambient text scale, on one line?
  static bool _fits(String label, double maxWidth, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: AppText.body.copyWith(fontSize: 14.5),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.width <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each cell is half the card minus the 0.5 pt separator; the label sits
        // inside the same icon-column metrics the other rows use.
        final cellWidth = (constraints.maxWidth - 0.5) / 2;
        final labelMax = cellWidth - Insets.md - 24 - 12 - Insets.md;
        final fits = _fits(leftLabel, labelMax, scaler) &&
            _fits(rightLabel, labelMax, scaler);

        if (!fits) {
          return Column(
            children: [
              _Cell(icon: leftIcon, label: leftLabel, onTap: onLeftTap),
              const RowDivider(indent: 48),
              _Cell(icon: rightIcon, label: rightLabel, onTap: onRightTap),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    _Cell(icon: leftIcon, label: leftLabel, onTap: onLeftTap),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 0.5,
                  child: ColoredBox(color: AppColors.divider),
                ),
              ),
              Expanded(
                child:
                    _Cell(icon: rightIcon, label: rightLabel, onTap: onRightTap),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Each cell is its own button so a screen reader reads two controls.
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        // One shared row height with every other More row (§3.1). minHeight,
        // not a fixed height, so the row still grows with the text at 130 %.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child:
                      Icon(icon, size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.body.copyWith(
                        fontSize: 14.5, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
