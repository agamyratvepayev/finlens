import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// One row of a header overflow menu ([showHeaderMenu]), rendered *below* the
/// mask toggle and the divider. The screen's own secondary actions live here.
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

/// The corner `•••` menu shared by every screen whose eye moved off the header
/// (header-controls spec §2/§3).
///
/// Its first row is always the global `Mask all amounts` preference, drawn as a
/// switch because the eye button carried that state in its icon and it must not
/// be lost. Toggling it does **not** close the sheet, so the change is visible on
/// the screen behind. A hairline then separates that *preference* from the
/// screen's own [actions] — a preference and an action must not share a block.
///
/// Callers only reach this with at least one entry in [actions]: a menu that
/// would hold nothing but the mask toggle costs two taps for what was one, and
/// the spec (§5) says to keep the eye button on such screens instead.
Future<void> showHeaderMenu(
  BuildContext context, {
  required List<HeaderMenuAction> actions,
}) {
  final store = StoreScope.read(context);
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
          // Rebuilds on every notifyListeners so the switch reflects the live
          // preference — including the flip this row itself makes, which leaves
          // the sheet open.
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => _MaskToggleRow(
              value: store.masked,
              onChanged: (v) {
                if (v != store.masked) store.toggleMasked();
              },
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
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

/// The mask preference row. Shaped like [_HeaderMenuRow] but ends in the app's
/// switch (matching More › Preferences), and never pops the sheet.
class _MaskToggleRow extends StatelessWidget {
  const _MaskToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      toggled: value,
      label: l.moreMaskAmounts,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.gutter,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 20, color: AppColors.textPrimary),
              const SizedBox(width: Insets.md),
              Expanded(child: Text(l.moreMaskAmounts, style: AppText.rowTitle)),
              const SizedBox(width: Insets.sm),
              // FittedBox boxes the switch's layout to 40 × 24 so the row keeps
              // the shared menu-row height (a bare Switch is taller).
              SizedBox(
                width: 40,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceHigh,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
