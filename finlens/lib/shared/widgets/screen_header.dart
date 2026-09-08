import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The header shared by Balance, Assets, Liabilities, Ledger and Planner
/// (spec 1.2: "Header'daki + ve göz ikonu Balance ile birebir aynı, paylaşılan
/// component"). The eye toggles privacy mode; + opens Quick Add.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.showBack = false,
    this.showEye = true,
    this.showAdd = true,
    this.onAdd,
    this.trailing,
    this.subtitle,
  }) : assert(title != null || titleWidget != null);

  final String? title;

  /// Replaces the title in the leading (Expanded) slot. Planner uses it to put
  /// the month control there on Budgets and nothing on Goals/Schedule — row 1
  /// is the tab's scope control, so an empty slot is deliberate.
  final Widget? titleWidget;

  final bool showBack;
  final bool showEye;
  final bool showAdd;
  final VoidCallback? onAdd;

  /// Extra action placed before the eye — e.g. the ••• menu on Planner.
  final Widget? trailing;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      child: Row(
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: HeaderCircleButton(
                icon: Icons.arrow_back_rounded,
                plain: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          Expanded(
            child: titleWidget ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title!, style: AppText.title),
                    ?subtitle,
                  ],
                ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: Insets.sm)],
          if (showEye)
            HeaderCircleButton(
              icon: store.masked
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              onTap: store.toggleMasked,
            ),
          if (showAdd) ...[
            const SizedBox(width: Insets.sm),
            HeaderCircleButton(
              icon: Icons.add_rounded,
              accent: true,
              onTap: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

/// The circular header control: the `+`, the eye, the back arrow, the Ledger's
/// range-lens `×`. One declaration, because a user who switches tabs must find
/// the same button under the same thumb — three private copies drifted to 34pt
/// / 36pt and to two different gutters, and the `+` visibly jumped between
/// Balance, the Ledger and the Planner. 36pt is the reference: [ScreenHeader]
/// already carries it on the Planner, Archive, Categories, Tags, See-all and
/// Category-detail screens.
///
/// `plus_button_alignment_test.dart` pins the resulting rect across all five
/// screens; keep the geometry here and nowhere else.
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.accent = false,
    this.plain = false,
    this.tint,
  });

  /// The one diameter. Call sites that reserve the button's footprint measure
  /// it from here rather than repeating the literal.
  static const double diameter = 36;

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  /// Drops the filled pill, leaving the glyph on a transparent ground — the
  /// back arrow's rendering.
  final bool plain;

  /// Overrides the glyph colour (size/background/behaviour are unchanged). The
  /// Ledger lens's × uses it to echo the accent title it clears; eye and `+`
  /// leave it null and keep the default textPrimary glyph.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: plain
          ? Colors.transparent
          : (accent ? AppColors.accent : AppColors.surfaceAlt),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Icon(
            icon,
            size: accent ? 22 : 19,
            color: tint ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Uppercase section label with an optional total on the right
/// ("ASSETS … $216,900").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.lg,
            Insets.gutter,
            Insets.sm,
          ),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: AppText.label)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Segmented control used by New/Edit Goal's type picker (spec 3.6 / 5.6).
class SegmentedPicker<T> extends StatelessWidget {
  const SegmentedPicker({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: v == selected
                        ? AppColors.surfaceHigh
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.sm + 1),
                  ),
                  child: Text(
                    labelOf(v),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          v == selected ? FontWeight.w600 : FontWeight.w500,
                      color: v == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
