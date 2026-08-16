import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'app_card.dart';

/// Groups form rows into one rounded card with hairlines between them.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin ??
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const RowDivider(indent: 52),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The workhorse row: leading glyph, label, optional sub-label, and a trailing
/// value / chevron / control.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.enabled = true,
    this.locked = false,
  });

  final IconData? icon;
  final String label;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool enabled;

  /// Read-only fields render a padlock and explain themselves in [subtitle]
  /// (spec 1.5 starting balance, 2.3 transaction type, 5.4 category).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final dim = !enabled || locked;
    return InkWell(
      onTap: enabled && !locked ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 24,
                child: Icon(
                  icon,
                  size: 18,
                  color: dim ? AppColors.textTertiary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: Insets.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: AppText.body.copyWith(
                            fontSize: 14.5,
                            color: dim
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppText.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            if (trailing != null)
              trailing!
            else if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: AppText.amount.copyWith(
                    color: valueColor ??
                        (dim ? AppColors.textTertiary : AppColors.textPrimary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (showChevron)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// FormRow with a switch on the right.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceHigh,
      ),
    );
  }
}

/// Free-text row (names, notes) rendered inline inside a [FormSection].
class TextFieldRow extends StatelessWidget {
  const TextFieldRow({
    super.key,
    this.icon,
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.trailing,
  });

  final IconData? icon;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + 2,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 24,
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: Insets.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption.copyWith(fontSize: 11.5)),
                TextField(
                  controller: controller,
                  autofocus: autofocus,
                  style: AppText.body.copyWith(fontSize: 15),
                  cursorColor: AppColors.accentSoft,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(top: 2),
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Amber/red information banner used for warnings and projections.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.text,
    this.icon = Icons.warning_amber_rounded,
    this.color = AppColors.warning,
    this.margin,
  });

  final String text;
  final IconData icon;
  final Color color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.tint(color, 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral informational note ("This category will also appear in Planner…").
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + Insets.xs,
        0,
        Insets.gutter + Insets.xs,
        Insets.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final String text;
}

/// Red, full-width destructive action closing an edit form.
class DestructiveRow extends StatelessWidget {
  const DestructiveRow({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.body.copyWith(
                        fontSize: 14.5,
                        color: AppColors.negative,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: AppText.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
