import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// One row of a header overflow menu ([showHeaderMenu]) — a screen's secondary
/// action (Filter on Insight/See-all, Archive on Planner).
class HeaderMenuAction {
  const HeaderMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;

  /// Runs after the sheet has closed.
  final VoidCallback onSelected;
  final bool danger;
}

/// The corner `•••` menu shared by every screen that folds a secondary action
/// off the header (header-controls spec §2/§3): Filter on Insight and See-all,
/// Archive on Planner.
///
/// It holds only the screen's own [actions]. Masking is **not** among them: it
/// is a single global preference set in More › Preferences (task 028), never a
/// per-screen control. Callers reach this with at least one entry in [actions].
Future<void> showHeaderMenu(
  BuildContext context, {
  required List<HeaderMenuAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Insets.sm),
          for (final a in actions)
            _HeaderMenuRow(
              action: a,
              onTap: () {
                Navigator.of(sheetContext).pop();
                a.onSelected();
              },
            ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    ),
  );
}

/// A plain action row — same anatomy as the detail-screen menus' `_MenuRow`.
class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.action, required this.onTap});

  final HeaderMenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = action.danger ? AppColors.negative : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            Icon(action.icon, size: 20, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label,
                      style: AppText.rowTitle.copyWith(color: color)),
                  if (action.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(action.subtitle!,
                        style: AppText.rowSubtitle.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
