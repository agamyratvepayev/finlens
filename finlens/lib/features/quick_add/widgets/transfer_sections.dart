import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'form_kit.dart';

/// The bespoke rows and cards of the Transfer form's EXCHANGE / FEE / SUMMARY
/// sections (Transfer-fee spec §2, §3, §5). Leaf widgets only — the section
/// composition (labels, cards, captions, and the button↔section swap) lives in
/// `quick_add_sheet.dart`, which owns the controllers and callbacks, the way
/// `split_summary_rows.dart` exposes only the split's child rows.
///
/// Every row is authored to the form's own metrics (`formScale`, `kRowPadding`,
/// `kIconColumn`, `kIconGap`) so it lines up pixel-for-pixel with the From/To
/// rows above it.

/// A value set in place, in its row — no boxed field. The number is the value
/// colour; the surrounding units are muted; focus draws a 1.5pt underline under
/// the number only. Shared by the rate row (units on both sides) and the fee
/// amount row (a trailing currency code).
///
/// The whole row is pinned to a fixed 48pt height so it is provably identical
/// resting and focused — the focus underline is painted inside the field and
/// changes no layout (spec §2, acceptance: "measured height is identical").
class InRowNumberField extends StatelessWidget {
  const InRowNumberField({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.numberColor,
    this.prefix,
    this.suffix,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// The typed number's colour: white for the rate, the negative red for the
  /// fee amount (spec §2 / §3.2).
  final Color numberColor;

  /// Muted text before the field (`1 USD = `) and after it (` EUR` / `USD`).
  final String? prefix;
  final String? suffix;

  /// Announced to a screen reader so the field reads its label and units, not a
  /// bare number (spec §6).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);

    final field = ConstrainedBox(
      // A floor so an empty field is still a tap target; IntrinsicWidth then
      // grows it with the digits.
      constraints: BoxConstraints(minWidth: 40 * s),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 15 * s * t,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: numberColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          cursorColor: AppColors.accent,
          decoration: const InputDecoration(
            isDense: true,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            // The underline sits under the number only, and only on focus.
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ),
    );

    final dim = TextStyle(
      fontSize: 15 * s * t,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.textTertiary,
    );

    return Semantics(
      // The row reads label + units as one node; the field stays editable.
      textField: true,
      label: semanticsLabel ?? label,
      child: SizedBox(
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
              // The label is the one thing that yields at 320pt; the units and
              // the field never do (spec §6).
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15 * s * t,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: kIconGap * s),
              if (prefix != null) Text(prefix!, style: dim),
              field,
              if (suffix != null) Text(suffix!, style: dim),
            ],
          ),
        ),
      ),
    );
  }
}

/// The FEE section's header: the `FEE` label and a right-aligned `Remove` that
/// clears the fee and restores the button (spec §3.2).
class TransferFeeHeader extends StatelessWidget {
  const TransferFeeHeader({
    super.key,
    required this.label,
    required this.removeLabel,
    required this.onRemove,
  });

  final String label;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Padding(
      // Matches FormSectionLabel's own padding so FEE sits on the same line as
      // REQUIRED / EXCHANGE / OPTIONAL.
      padding: EdgeInsets.fromLTRB(21 * s, 20 * s, kFormMargin, 7 * s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5 * s * t,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1 * 10.5 * s,
                height: 1.2,
                color: AppColors.formDim2,
              ),
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Text(
                removeLabel,
                style: TextStyle(
                  fontSize: 11.5 * s * t,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: AppColors.accentLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width button that stands where the FEE section will open (spec
/// §3.1): `#1C1C1E`, radius 12, a percent glyph and `Fee`, both in `#A5A3FF`.
/// Rendered whether or not the currencies differ.
class TransferFeeButton extends StatelessWidget {
  const TransferFeeButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(kFormMargin, 16 * s, kFormMargin, 0),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12 * s),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 11 * s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.percent_rounded, size: 14 * s, color: AppColors.accentLight),
                SizedBox(width: 7 * s),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * s * t,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.accentLight,
                    ),
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

/// A caption line beneath a card — the fee-booking sentence under the FEE card
/// (spec §3.2) and under the SUMMARY card (spec §5). 11.5pt, `#636366`.
class TransferCaption extends StatelessWidget {
  const TransferCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(21 * s, 7 * s, kFormMargin, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5 * s * t,
          height: 1.3,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// One line of the SUMMARY card (spec §5): a label (with an optional caption
/// beneath) and a right-aligned figure that never shrinks or wraps.
class TransferSummaryRow extends StatelessWidget {
  const TransferSummaryRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
      child: Semantics(
        // Label, caption and value announce as one node (spec §6).
        container: true,
        excludeSemantics: true,
        label: caption == null ? '$label, $value' : '$label, $caption, $value',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * s * t,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (caption != null) ...[
                    SizedBox(height: 2 * s),
                    Text(
                      caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11 * s * t,
                        height: 1.25,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: kIconGap * s),
            Text(
              value,
              style: TextStyle(
                fontSize: 14 * s * t,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The read-only SUMMARY card (spec §5): one step darker than the input cards
/// (`#161618`), rows split by a faint hairline, nothing editable. Wrapped as a
/// live region so a screen-reader user typing a rate hears the figures move.
class TransferSummaryCard extends StatelessWidget {
  const TransferSummaryCard({super.key, required this.rows});

  final List<TransferSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: EdgeInsets.fromLTRB(kFormMargin, 12 * s, kFormMargin, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12 * s),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}
