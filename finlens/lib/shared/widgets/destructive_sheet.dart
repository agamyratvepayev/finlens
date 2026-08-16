import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Spec 2.4 / 5.5 / 6.2 — the standardised Destructive Confirmation.
///
/// The rule this component exists to enforce: a delete dialog never just asks
/// "are you sure?", it states in concrete figures what stays and what goes.
class ImpactLine {
  const ImpactLine.kept(this.text) : kept = true;
  const ImpactLine.lost(this.text) : kept = false;

  final String text;
  final bool kept;
}

Future<bool> showDestructiveConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required List<ImpactLine> impact,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Keep it',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              title,
              style: AppText.title.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              message,
              style: AppText.caption.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.xl),
            for (final line in impact)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      line.kept ? Icons.check_rounded : Icons.close_rounded,
                      size: 18,
                      color: line.kept
                          ? AppColors.positive
                          : AppColors.negative,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        line.text,
                        style: AppText.body.copyWith(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.negative,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                textStyle: AppText.button,
              ),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(46),
                textStyle: AppText.button,
              ),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
