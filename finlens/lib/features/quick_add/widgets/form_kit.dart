import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Everything on the transaction form is authored for a 390pt-wide screen and
/// scaled from there by one factor.
///
/// The clamp is the point: unclamped, a 320pt SE renders the form unreadably
/// small and a tablet renders it cartoonishly large. Tap targets, hairlines
/// and side margins deliberately opt out of this — see [kFormMargin].
double formScale(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w / 390).clamp(0.92, 1.10);
}

/// System text size, capped. Past ~1.3 the amount and the currency chip
/// collide; above the cap the chip wraps to its own line instead.
double formTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);

/// Flat at every width so the cards line up with the rest of the app.
const kFormMargin = 16.0;

/// Row padding, icon column and gap add up to where the hairline starts.
const kRowPadding = 15.0;
const kIconColumn = 22.0;
const kIconGap = 12.0;
const kSeparatorInset = 50.0;

/// A 48px row: icon, label, right-aligned value, chevron.
///
/// One widget for all five fields so the list rhythm cannot drift. Passing a
/// null [onTap] makes the row read-only (spec 5): the label dims, the chevron
/// disappears and there is no ripple — those two absences are what tell the
/// user tapping does nothing.
class TxnFieldRow extends StatelessWidget {
  const TxnFieldRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.emptyText,
    this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// null renders [emptyText] in the dim colour instead.
  final String? value;
  final String? emptyText;

  /// Overrides the filled-value colour (the Difference row's green/red).
  final Color? valueColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    final readOnly = onTap == null;
    final filled = value != null;
    final shown = value ?? emptyText ?? '';

    final row = SizedBox(
      height: 48 * s,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: kRowPadding * s),
        child: Row(
          children: [
            SizedBox(
              width: kIconColumn * s,
              child: Icon(icon, size: 18 * s, color: AppColors.formDim2),
            ),
            SizedBox(width: kIconGap * s),
            // The label yields only when the row genuinely cannot fit both
            // ("Starting amount" at 320pt); normally it takes its natural
            // width and the slack falls between the two columns.
            // Capped rather than Flexible: a second flex child would split the
            // free space with the value, and the value's right edge would then
            // move with the label's length — which is exactly the misalignment
            // this row is meant to avoid. The cap still stops a long label
            // ("Starting amount") overflowing a 320pt row.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 150 * s),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15 * s * t,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: readOnly
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: kIconGap * s),
            // Expanded, not Spacer + Flexible: the value fills the remaining
            // width and right-aligns inside it, which is what pins every value
            // to one x. A Spacer would split the slack with the value instead.
            Expanded(
              child: Text(
                shown,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15 * s * t,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: filled
                      ? (valueColor ?? AppColors.textPrimary)
                      : AppColors.formDim2,
                ),
              ),
            ),
            if (!readOnly) ...[
              SizedBox(width: 5 * s),
              Icon(
                Icons.chevron_right_rounded,
                size: 17 * s,
                color: AppColors.formChevron,
              ),
            ],
          ],
        ),
      ),
    );

    if (readOnly) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: row,
    );
  }
}

/// Card holding a run of [TxnFieldRow]s, with hairlines between them only —
/// never above the first or below the last.
class TxnCard extends StatelessWidget {
  const TxnCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kFormMargin),
      decoration: BoxDecoration(
        color: AppColors.fieldCard,
        borderRadius: BorderRadius.circular(14 * s),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: kSeparatorInset * s),
                // Hairlines stay at 0.5 logical px at every scale factor.
                child: const Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: AppColors.divider,
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// `REQUIRED` / `OPTIONAL` / `EXCHANGE`.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(21 * s, 20 * s, kFormMargin, 7 * s),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5 * s * formTextScale(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1 * 10.5 * s,
          height: 1.2,
          color: AppColors.formDim2,
        ),
      ),
    );
  }
}

/// A property of the transaction, not a link. The on-state has to be legible
/// without opening anything, which is why this is a tinted button rather than
/// a row that pushes a sheet.
class FormToggle {
  const FormToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.semanticValue,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onTap;

  /// A disabled toggle renders at 35% opacity and does not respond (e.g. Split
  /// before an amount is entered, spec §2).
  final bool enabled;

  /// Announced state/reason, e.g. "every month" or "unavailable until an amount
  /// is entered" (spec §4).
  final String? semanticValue;
}

class FormToggleBar extends StatelessWidget {
  const FormToggleBar({super.key, required this.toggles});

  final List<FormToggle> toggles;

  @override
  Widget build(BuildContext context) {
    if (toggles.isEmpty) return const SizedBox.shrink();
    final s = formScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(kFormMargin, 16 * s, kFormMargin, 0),
      child: Row(
        children: [
          for (var i = 0; i < toggles.length; i++) ...[
            if (i > 0) SizedBox(width: 10 * s),
            Expanded(child: _ToggleButton(toggle: toggles[i])),
          ],
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.toggle});

  final FormToggle toggle;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final on = toggle.value;
    final button = Material(
      color: on
          ? AppColors.accent.withValues(alpha: 0.15)
          : AppColors.fieldCard,
      borderRadius: BorderRadius.circular(12 * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: toggle.enabled ? toggle.onTap : null,
        // Never scales below the 44pt minimum target.
        child: SizedBox(
          height: 44 * s < 44 ? 44 : 44 * s,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                toggle.icon,
                size: 14 * s,
                color: on
                    ? AppColors.toggleOnFg
                    : AppColors.toggleOffFg.withValues(alpha: 0.7),
              ),
              SizedBox(width: 7 * s),
              Flexible(
                child: Text(
                  toggle.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * s * formTextScale(context),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: on ? AppColors.toggleOnFg : AppColors.toggleOffFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: toggle.enabled,
      label: toggle.label,
      value: toggle.semanticValue,
      child: Opacity(opacity: toggle.enabled ? 1 : 0.35, child: button),
    );
  }
}

/// Explains what saving will actually do, with the figure emphasised.
/// Segments marked `strong` render white and heavier.
class HintStrip extends StatelessWidget {
  const HintStrip({super.key, required this.spans, required this.accent});

  final List<({String text, bool strong})> spans;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(kFormMargin, 10 * s, kFormMargin, 0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 11 * s),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(11 * s),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1 * s),
              // The one accent-coloured icon on the screen.
              child: Icon(
                Icons.info_outline_rounded,
                size: 15 * s,
                color: accent,
              ),
            ),
            SizedBox(width: 9 * s),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final span in spans)
                      TextSpan(
                        text: span.text,
                        style: TextStyle(
                          fontWeight:
                              span.strong ? FontWeight.w600 : FontWeight.w400,
                          color: span.strong
                              ? AppColors.textPrimary
                              : AppColors.hintText,
                        ),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12.5 * s * t,
                  height: 1.35,
                  color: AppColors.hintText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The pinned SaveBar was removed (spec §3): the nav bar's Save is the only
// commit, and it names/flashes the missing field on an incomplete tap.

/// Nav bar: Cancel / type pill / Save.
///
/// Save appears here *and* pinned at the bottom. The bottom button is the one
/// that explains itself when disabled; this one is the conventional
/// top-right commit for anyone who reaches for it there.
class FormNavBar extends StatelessWidget {
  const FormNavBar({
    super.key,
    required this.typeName,
    required this.accent,
    required this.onCancel,
    required this.onTypeTap,
    required this.onSave,
    required this.canSave,
    this.locked = false,
  });

  final String typeName;
  final Color accent;
  final VoidCallback onCancel;
  final VoidCallback? onTypeTap;
  final VoidCallback onSave;
  final bool canSave;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return SizedBox(
      height: 50 * s,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15 * s * t,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: locked ? null : onTypeTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 13 * s,
                      vertical: 6 * s,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6 * s,
                          height: 6 * s,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 7 * s),
                        // Flexible so the pill yields instead of overflowing:
                        // the side slots are laid out first, and on a 320pt
                        // screen "New Goal" plus the dot and chevron wanted
                        // ~1px more than the centre had. The type name is the
                        // one thing here that can afford to ellipsise.
                        Flexible(
                          child: Text(
                            typeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14 * s * t,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 5 * s),
                        Icon(
                          locked
                              ? Icons.lock_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 9 * s,
                          color: AppColors.textPrimary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canSave ? onSave : null,
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 15 * s * t,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  // Purple in every type: the accent says what you are
                  // creating, purple says this is the action.
                  color: canSave
                      ? AppColors.accent
                      : AppColors.saveDisabledFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
