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
    required this.title,
    this.showBack = false,
    this.showEye = true,
    this.showAdd = true,
    this.onAdd,
    this.trailing,
    this.subtitle,
  });

  final String title;
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
              child: _CircleButton(
                icon: Icons.arrow_back_rounded,
                plain: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.title),
                ?subtitle,
              ],
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: Insets.sm)],
          if (showEye)
            _CircleButton(
              icon: store.masked
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              onTap: store.toggleMasked,
            ),
          if (showAdd) ...[
            const SizedBox(width: Insets.sm),
            _CircleButton(
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
    this.accent = false,
    this.plain = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;
  final bool plain;

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
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: accent ? 22 : 19,
            color: AppColors.textPrimary,
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

/// Underlined tab strip (Balance's All/Assets/Liabilities, Planner's 3 tabs).
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.trailing,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          _Tab(
            label: labels[i],
            selected: i == index,
            onTap: () => onChanged(i),
          ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: Insets.sm,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
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
