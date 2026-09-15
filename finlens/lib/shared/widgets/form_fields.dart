import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.opensSheet = false,
    this.enabled = true,
    this.locked = false,
    this.labelBadge,
  });

  final IconData? icon;
  final String label;

  /// An optional tag rendered immediately after the label, outside its flexible
  /// box so it never truncates (the currency picker's `CUSTOM` marker). Null for
  /// every other row.
  final Widget? labelBadge;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Which chevron [showChevron] draws — a disclosure direction, not decoration.
  /// `false` (the default, so an unclassified row never silently flips) renders
  /// the rightward `chevron_right` that says "tapping pushes a screen". `true`
  /// renders the downward `keyboard_arrow_down` that says "tapping discloses a
  /// bottom sheet in place", matching the Balance `Today` chip and the amount
  /// hero's currency chip. Chevron position, size and colour are unchanged.
  final bool opensSheet;
  final bool enabled;

  /// Read-only fields render a padlock and explain themselves in [subtitle]
  /// (spec 1.5 starting balance, 2.3 transaction type, 5.4 category).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final dim = !enabled || locked;
    // A subtitle is the only child that can be a sentence. When one is present
    // the row tightens the air inside its line boxes (§5b) and caps the sentence
    // at two lines (§5a); a single-line row keeps today's metrics byte-for-byte.
    final hasSub = subtitle != null;
    return InkWell(
      onTap: enabled && !locked ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: hasSub ? 9 : Insets.md,
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
                            // Tighten the label's line box only when a subtitle
                            // sits under it; `null` keeps AppText.body's 1.35 for
                            // a lone label, so single-line rows do not move (§5b).
                            height: hasSub ? 1.2 : null,
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
                      ?labelBadge,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            if (trailing != null)
              trailing!
            else if (value != null)
              // Expanded, not Flexible. Both slots carry flex 1, so a *loose*
              // fit let the value shrink-wrap and land immediately after the
              // label's half of the row — at the card's midpoint — with
              // `textAlign: right` aligning inside a box already the width of
              // its own text, i.e. doing nothing. A tight fit gives the value
              // the rest of the row to align against, so it reaches the right
              // edge like every other value on the card. The ellipsis budget is
              // unchanged: loose and tight cap the value at the same half-width.
              Expanded(
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
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  opensSheet
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.chevron_right_rounded,
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
    this.focusNode,
  });

  final IconData? icon;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final Widget? trailing;

  /// Optional external focus node. Null (every existing caller) keeps the
  /// TextField's own internal node — so those screens are byte-identical.
  final FocusNode? focusNode;

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
                  focusNode: focusNode,
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

/// The one name input (task 004).
///
/// A name is not one of a thing's attributes — it is the thing's title — so it
/// looks the same in all six places the app asks for one: a single line, no
/// caption (the hint *is* the label), and a leading glyph that either sits
/// there quietly, opens the icon picker, or (for the two task titles) is a
/// plain-but-tappable glyph in the icon column.
///
/// Its height is **not** a constant (§2): it takes [verticalPadding] from the
/// rows it sits beside, so it matches them at every text scale. In the editors
/// that is `Insets.md` — the same value `FormRow` uses — and [fixedHeight] stays
/// null, so the height is intrinsic and tracks its neighbours. Quick Add's
/// neighbour is a hard `48 * s` `TxnFieldRow`, and the creation sheets carry a
/// 44 pt glyph tile that must not float in a taller box, so those two hosts pass
/// [fixedHeight] instead.
///
/// This is deliberately **not** [TextFieldRow], which also draws amounts, limits
/// and notes, where the caption is the only thing that says what the value means.
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.controller,
    required this.hint,
    required this.semanticsLabel,
    this.focusNode,
    this.leadingIcon,
    this.leadingTile,
    this.onLeadingTap,
    this.leadingSemanticsLabel,
    this.autofocus = false,
    this.onChanged,
    this.surface,
    this.radius = 12,
    this.scale = 1.0,
    this.textScale = 1.0,
    this.horizontalPadding = Insets.md,
    this.verticalPadding = Insets.md,
    this.fixedHeight,
    this.iconColumn = 24.0,
    this.iconGap = 12.0,
  })  : assert(leadingIcon == null || leadingTile == null,
            'a quiet glyph or a tappable tile, never both'),
        assert(onLeadingTap == null || leadingIcon != null,
            'onLeadingTap makes the quiet glyph tappable — it needs one');

  final TextEditingController controller;

  /// Shown when empty. It carries the label's job, so it is always supplied —
  /// a cleared name field must not become a blank row.
  final String hint;

  /// What a screen reader calls this field, now that nothing prints it.
  final String semanticsLabel;

  final FocusNode? focusNode;

  /// The quiet leading glyph. Mutually exclusive with [leadingTile]. When
  /// [onLeadingTap] is supplied it becomes a plain-but-tappable glyph in the
  /// icon column (the two task titles: tapping it picks the task's icon).
  final IconData? leadingIcon;

  /// The tappable 36 pt glyph tile the creation sheets use. Build it with
  /// [NameGlyphTile] so the pencil badge cannot drift between the two sheets.
  final Widget? leadingTile;

  /// Makes [leadingIcon] its own tap target (icon-only, no square, no badge) —
  /// the create/edit task glyph, which previews the task's icon and opens the
  /// picker. Focus still arrives on a tap anywhere else in the row.
  final VoidCallback? onLeadingTap;

  /// A11y label for the tappable [leadingIcon] (e.g. "Icon").
  final String? leadingSemanticsLabel;

  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Null when the field is a row inside a card that already paints a surface.
  final Color? surface;

  final double radius;

  /// Quick Add scales its whole form with the screen width; the editors do not.
  /// Both hosts keep their own row metrics so the name lines up with the rows
  /// beside it — the *design* is identical, the grid it sits on is the host's.
  final double scale;
  final double textScale;
  final double horizontalPadding;

  /// Vertical padding around the single line, applied **only when the row is
  /// intrinsic** ([fixedHeight] null). Defaults to `Insets.md`, matching
  /// `FormRow`, so an editor name row is as tall as the value rows beside it.
  final double verticalPadding;

  /// When set, the row is exactly this tall and [verticalPadding] is ignored —
  /// the hosts whose neighbours are a fixed height (Quick Add's `48 * s`
  /// `TxnFieldRow`) or that carry the 44 pt glyph tile (the creation sheets).
  /// Null in the editors, where the height follows the neighbours' padding (§2).
  final double? fixedHeight;

  final double iconColumn;
  final double iconGap;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// Focuses the field and asks the platform for the keyboard directly:
  /// [FocusNode.requestFocus] is a no-op when the field already holds focus, so
  /// a keyboard dismissed by a drag would never return without this (the
  /// behaviour the creation sheets' old `_focusName` guaranteed).
  void _focus() {
    if (!_node.hasFocus) _node.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final t = widget.textScale;
    return ListenableBuilder(
      listenable: _node,
      // The whole row — padding included — focuses the field; the leading
      // tile/glyph and the clear button carry their own gestures inside it, so
      // they win their own taps (§7).
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus,
        child: Container(
          // Null in the editors: the row shrink-wraps its single line plus the
          // padding below, matching the value rows beside it (§2). Set in Quick
          // Add and the creation sheets, whose neighbours or glyph tile fix it.
          height: widget.fixedHeight,
          decoration: BoxDecoration(
            color: widget.surface,
            borderRadius: BorderRadius.circular(widget.radius * s),
            // Always one point, transparent when unfocused: the card cannot
            // change size when focus arrives.
            border: Border.all(
              width: 1,
              color: _node.hasFocus ? AppColors.accent : Colors.transparent,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding * s,
            // Intrinsic rows carry their own vertical padding; a fixed-height row
            // centres its line in the given box instead.
            vertical:
                widget.fixedHeight == null ? widget.verticalPadding * s : 0,
          ),
          child: Row(
            children: [
              ..._leading(s),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: widget.semanticsLabel,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _node,
                    autofocus: widget.autofocus,
                    onChanged: widget.onChanged,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: AppColors.accent,
                    style: TextStyle(
                      fontSize: 17 * s * t,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        fontSize: 17 * s * t,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : _clearButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _leading(double s) {
    if (widget.leadingTile != null) {
      return [widget.leadingTile!, SizedBox(width: widget.iconGap * s)];
    }
    if (widget.leadingIcon == null) return const [];
    Widget glyph = SizedBox(
      width: widget.iconColumn * s,
      child: Icon(widget.leadingIcon,
          size: 18 * s, color: AppColors.textSecondary),
    );
    if (widget.onLeadingTap != null) {
      // A plain glyph that is its own button — no coloured square, no badge — so
      // the row keeps the 48 pt line and the host's grid while the glyph opens
      // the icon picker.
      glyph = Semantics(
        button: true,
        label: widget.leadingSemanticsLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onLeadingTap,
          child: glyph,
        ),
      );
    }
    return [glyph, SizedBox(width: widget.iconGap * s)];
  }

  /// §0.4's clear button, unchanged in every number — a 22 pt `surfaceHigh`
  /// circle in a 44 pt hit area — clearing the controller and keeping focus. It
  /// is absent, not disabled, when empty, and takes width only when present.
  Widget _clearButton() {
    return SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.controller.clear();
          _node.requestFocus();
        },
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The leading tile of a creation sheet's name row (§1.1) — the thing's glyph,
/// tappable, in a 44×44 hit area, carrying a pencil badge so it reads as its own
/// button. One step smaller than the pre-task-004 sheet tile (40→36) so it fits
/// the 48 pt [NameField] row; the hit area stays 44 while the drawing shrinks.
class NameGlyphTile extends StatelessWidget {
  const NameGlyphTile({
    super.key,
    required this.color,
    required this.onTap,
    required this.semanticsLabel,
    this.icon,
    this.emoji,
    this.fallbackIcon = Icons.category_rounded,
  });

  final Color color;
  final VoidCallback onTap;
  final String semanticsLabel;

  /// The glyph — an [icon] OR an [emoji]; [fallbackIcon] shows when both are null.
  final IconData? icon;
  final String? emoji;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        color.withValues(alpha: 0.18), AppColors.surfaceAlt),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 18))
                      : Icon(icon ?? fallbackIcon, size: 18, color: color),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.sheetCard,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit_rounded,
                      size: 8, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
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
    this.dense = false,
  });

  final String text;
  final IconData icon;
  final Color color;
  final EdgeInsetsGeometry? margin;

  /// A one-line pointer, not a paragraph: tighter air around the same type.
  /// Only the Schedule overdue banner passes this; the default path is
  /// byte-identical to before. See §1 of the schedule-header spec.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ??
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: Insets.sm)
          : const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.md,
            ),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.12),
        borderRadius: BorderRadius.circular(dense ? 10 : Radii.md),
        border: Border.all(color: AppColors.tint(color, 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: dense ? 15 : 17, color: color),
          SizedBox(width: dense ? 7 : Insets.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: dense ? 1.15 : null,
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
    this.opensSheet = false,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  /// See [FormRow.opensSheet]. `false` (default) keeps today's `chevron_right`;
  /// `true` renders `keyboard_arrow_down` for a row whose tap raises a bottom
  /// sheet. Every current caller's confirmation is a bottom sheet
  /// ([showDestructiveConfirm] is a `showModalBottomSheet`), so they pass `true`.
  final bool opensSheet;

  @override
  Widget build(BuildContext context) {
    // Same two-line shape as [FormRow] (§5): tighten and cap only when the
    // subtitle is present; a lone red label keeps today's metrics byte-for-byte.
    final hasSub = subtitle != null;
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
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: hasSub ? 9 : Insets.md,
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
                        height: hasSub ? 1.2 : null,
                        color: AppColors.negative,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          fontSize: 11.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                opensSheet
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
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
