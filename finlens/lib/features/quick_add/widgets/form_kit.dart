import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
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

/// The single row height every selectable row in the Repeat / Custom / Ends
/// sheets uses (transaction Repeat spec §8). One constant so the sheets cannot
/// drift row-to-row. The account-type, currency and tag sheets predate it and
/// are left unchanged for now — see the report.
const double kSheetRowHeight = 44.0;

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
    this.hideLabel = false,
    this.valueMaxLines = 1,
    this.semanticValue,
    this.iconColor,
    this.showChevron = true,
    this.opensSheet = false,
  });

  final IconData icon;
  final String label;

  /// Overrides the leading icon's colour. The Repeat row uses the accent when a
  /// repeat is set, so the form shows at a glance that the transaction recurs
  /// (transaction Repeat spec §3). Null keeps the default dim glyph.
  final Color? iconColor;

  /// null renders [emptyText] in the dim colour instead.
  final String? value;
  final String? emptyText;

  /// Overrides the filled-value colour (the Difference row's green/red).
  final Color? valueColor;

  final VoidCallback? onTap;

  /// The Note row drops its label so the note itself gets the full width
  /// (spec §3): the icon already says what the row is, and a label side-by-side
  /// would leave prose ~25 characters. Only the Note row sets this.
  final bool hideLabel;

  /// How many lines the value may occupy before it ellipsises. 1 everywhere but
  /// the Note row, which is allowed two (spec §3 — two is the ceiling).
  final int valueMaxLines;

  /// The value announced to a screen reader, in full and untruncated — the Note
  /// row's preview is clipped, but assistive tech must read the whole note
  /// (spec §5). Null falls back to the visible value.
  final String? semanticValue;

  /// The Note row is tappable but no longer opens anything — it focuses an
  /// inline field in place — so its chevron goes while the ripple stays
  /// (inline-note spec §1). Every other tappable row keeps the chevron.
  final bool showChevron;

  /// Which chevron to draw: `false` (default, so an unclassified row keeps
  /// today's glyph) renders the rightward `chevron_right` ("tapping pushes a
  /// screen"); `true` renders the downward `keyboard_arrow_down` ("tapping
  /// discloses a bottom sheet in place"). Every tappable Quick Add field opens
  /// a sheet, so its [FieldSpec] passes `true`. Size, colour and position are
  /// unchanged.
  final bool opensSheet;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    final readOnly = onTap == null;
    final filled = value != null;
    final shown = value ?? emptyText ?? '';

    // Note row: no label, note fills the width (left-aligned) across up to two
    // lines, and the row grows past 48px to fit the second line. Kept in this
    // one widget so it shares the icon column, gap and chevron metrics with its
    // Date/Tags siblings and the list rhythm cannot drift.
    if (hideLabel) {
      final noteRow = ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48 * s),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: kRowPadding * s,
            vertical: 15 * s,
          ),
          child: Row(
            children: [
              SizedBox(
                width: kIconColumn * s,
                child: Icon(icon,
                    size: 18 * s, color: iconColor ?? AppColors.formDim2),
              ),
              SizedBox(width: kIconGap * s),
              Expanded(
                child: Text(
                  shown,
                  maxLines: valueMaxLines,
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
              if (!readOnly && showChevron) ...[
                SizedBox(width: 5 * s),
                Icon(
                  opensSheet
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.chevron_right_rounded,
                  size: 17 * s,
                  color: AppColors.formChevron,
                ),
              ],
            ],
          ),
        ),
      );
      final tappable = readOnly
          ? noteRow
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14 * s),
              child: noteRow,
            );
      return Semantics(
        button: !readOnly,
        label: semanticValue ?? shown,
        excludeSemantics: true,
        child: tappable,
      );
    }

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
            if (!readOnly && showChevron) ...[
              SizedBox(width: 5 * s),
              Icon(
                opensSheet
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
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

/// The Note row's inline editor (inline-note spec §1–§2).
///
/// Unfocused it is exactly the old preview: [TxnFieldRow] with the label
/// hidden, newlines collapsed to spaces, at most two lines — minus the chevron,
/// because tapping no longer opens anything. Tapped, it swaps in a multi-line
/// [TextField] bound to the caller's controller, so what is typed is committed
/// as it is typed, like every other field on the form.
class TxnNoteFieldRow extends StatefulWidget {
  const TxnNoteFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.emptyText,
    required this.maxLength,
    required this.counterThreshold,
    this.onEditingStarted,
  });

  final IconData icon;

  /// Names the field to assistive tech only; visually the row has no label —
  /// the note takes the full width, as before.
  final String label;

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The unfocused row's dim text while the note is empty. Deliberately not
  /// carried into the TextField as a hint: tapping the row clears it, leaving
  /// the caret alone (inline-note spec §6).
  final String emptyText;

  /// Input stops at this cap ([MaxLengthEnforcement.enforced]); nothing
  /// already typed is discarded.
  final int maxLength;

  /// The `used / max` counter under the field stays hidden until this many
  /// characters remain — a permanent counter reads as a restriction.
  final int counterThreshold;

  /// Fires before focus is requested. The form closes its numeric keypad here
  /// so the keypad and the system keyboard are never open together (§2).
  final VoidCallback? onEditingStarted;

  @override
  State<TxnNoteFieldRow> createState() => _TxnNoteFieldRowState();
}

class _TxnNoteFieldRowState extends State<TxnNoteFieldRow> {
  /// True from the tap that starts editing until focus is lost. Kept apart from
  /// `focusNode.hasFocus` because the TextField only enters the tree on the
  /// tap's rebuild — focus cannot be requested until the frame after.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    // The counter and the unfocused preview both read the text live.
    widget.controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(TxnNoteFieldRow old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTextChange);
      widget.controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    // Losing focus — Cancel, the amount hero, a type switch — drops straight
    // back to the preview. What was typed is already in the controller.
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  void _startEditing() {
    widget.onEditingStarted?.call();
    setState(() => _editing = true);
    // The TextField enters the tree on this rebuild; focus must wait for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      final text = widget.controller.text.trim();
      return TxnFieldRow(
        icon: widget.icon,
        label: widget.label,
        hideLabel: true,
        valueMaxLines: 2,
        // A display rule only (§1): newlines collapse to spaces so the preview
        // stays clean; the controller keeps the real line breaks.
        value: text.isEmpty ? null : text.replaceAll('\n', ' '),
        emptyText: widget.emptyText,
        semanticValue: text.isEmpty ? widget.emptyText : text,
        showChevron: false,
        onTap: _startEditing,
      );
    }

    final s = formScale(context);
    final t = formTextScale(context);
    final used = widget.controller.text.characters.length;
    final showCounter = widget.maxLength - used <= widget.counterThreshold;
    return Container(
      // Focused: the accent outline, inset inside the card — the same
      // margin/padding swap the new-account form's numeric rows use, so the
      // text barely moves when the outline appears.
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.55),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: BoxConstraints(minHeight: 48 * s - 6),
      padding: EdgeInsets.symmetric(
        horizontal: kRowPadding * s - 3,
        vertical: 12 * s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kIconColumn * s,
            child: Padding(
              padding: EdgeInsets.only(top: 1 * s),
              child: Icon(widget.icon, size: 18 * s, color: AppColors.accent),
            ),
          ),
          SizedBox(width: kIconGap * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  // Grows with the text to four lines, then scrolls inside
                  // itself, so the row can never push the footer off screen
                  // (§1).
                  maxLines: 4,
                  maxLength: widget.maxLength,
                  // Stop input at the cap without discarding earlier text; a
                  // paste over the cap is accepted up to it, overflow dropped.
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  // The default counter is suppressed; one only appears near
                  // the limit, rendered beneath.
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  // Extra bottom room so the auto-scroll that keeps the caret
                  // above the keyboard also keeps the counter visible.
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
                  style: TextStyle(
                    fontSize: 15 * s * t,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                  cursorColor: AppColors.accent,
                  decoration: const InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                ),
                if (showCounter) ...[
                  SizedBox(height: 4 * s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '$used / ${widget.maxLength}',
                        style: TextStyle(
                          fontSize: 11 * s * t,
                          height: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

/// A transformation, not a property — one full-width action beneath the card.
/// Unlike [FormToggle] it holds no value; when disabled it states its reason on
/// a line beneath (transaction Repeat spec §7).
class FormActionSpec {
  const FormActionSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// Shown beneath the button and announced to the screen reader when
  /// [enabled] is false, e.g. "Enter an amount first."
  final String? disabledReason;
}

/// Renders a [FormActionSpec] full-width, with the disabled reason on its own
/// line beneath when the action is unavailable.
class FormAction extends StatelessWidget {
  const FormAction({super.key, required this.spec});

  final FormActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final on = spec.enabled;
    final button = Material(
      color: AppColors.fieldCard,
      borderRadius: BorderRadius.circular(12 * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: on ? spec.onTap : null,
        child: SizedBox(
          height: 44 * s < 44 ? 44 : 44 * s,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                spec.icon,
                size: 14 * s,
                color: AppColors.toggleOffFg.withValues(alpha: 0.7),
              ),
              SizedBox(width: 7 * s),
              Flexible(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * s * formTextScale(context),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: AppColors.toggleOffFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(kFormMargin, 16 * s, kFormMargin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            enabled: on,
            label: spec.label,
            // The reason travels with the button's semantics so a screen reader
            // hears why it is unavailable (spec §7 / §12).
            value: on ? null : spec.disabledReason,
            child: Opacity(opacity: on ? 1 : 0.35, child: button),
          ),
          if (!on && spec.disabledReason != null)
            Padding(
              padding: EdgeInsets.only(top: 7 * s, left: 2 * s),
              child: Text(
                spec.disabledReason!,
                style: TextStyle(
                  fontSize: 12 * s * formTextScale(context),
                  height: 1.3,
                  color: AppColors.formDim2,
                ),
              ),
            ),
        ],
      ),
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
                AppLocalizations.of(context).actionCancel,
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
                AppLocalizations.of(context).actionSave,
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
