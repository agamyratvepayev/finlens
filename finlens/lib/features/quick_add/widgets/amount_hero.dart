import 'package:flutter/material.dart';

import '../../../core/models/currency_def.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import 'form_kit.dart';

/// Editing rules for the raw amount string the keypad drives.
///
/// The amount is held as the literal characters the user pressed ("24",
/// "24.", "24.5") rather than a double, because the display has to tell typed
/// digits apart from decimals the user has not reached yet.
abstract final class AmountEntry {
  static const _maxWhole = 12;

  static String press(String raw, String key) {
    if (key == '.') {
      if (raw.contains('.')) return raw;
      return raw.isEmpty ? '0.' : '$raw.';
    }
    final dot = raw.indexOf('.');
    if (dot >= 0) {
      // Two decimal places is the most any supported currency needs.
      if (raw.length - dot - 1 >= 2) return raw;
      return '$raw$key';
    }
    if (raw.length >= _maxWhole) return raw;
    if (raw == '0') return key;
    return '$raw$key';
  }

  static String backspace(String raw) =>
      raw.isEmpty ? raw : raw.substring(0, raw.length - 1);

  static double value(String raw) =>
      raw.isEmpty ? 0 : (double.tryParse(raw) ?? 0);

  /// Seeds the field when an existing record is opened for editing.
  static String fromDouble(double v) {
    if (v == 0) return '';
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// The typed amount, with the currency's **symbol** in the position that
  /// currency defines — and nothing at all when it has none, because then the
  /// chip beside the field is already showing its code and repeating it here
  /// costs four characters on the tightest line in the app (§1).
  ///
  /// [hasChip] is false only where the field is rendered without a currency
  /// control; there a code-only currency still shows its code (spaced), since
  /// nothing else states the unit. A currency that has a symbol always shows
  /// the symbol, chip or no chip.
  ///
  /// `rest` is now only the empty field's placeholder `0` (painted dim). Once a
  /// digit is typed the whole number lives in `typed` and `rest` is empty — no
  /// decimal places appear before the digits that fill them (§2). The tuple
  /// shape is kept so the caret still sits between the two spans.
  static ({String typed, String rest}) split(
    String raw,
    String currency, {
    bool hasChip = true,
  }) {
    final def = currencyDef(currency);
    // The unit against the number: a symbol flush on its own side; nothing when
    // the currency is code-only and a chip already names it; otherwise the code,
    // spaced, so a bare number never lacks a unit.
    final String pre;
    final String post;
    if (def.tokenIsSymbol) {
      // A symbol sits flush against the number on both sides — the app's law
      // (CurrencyDef: `m9,850` / `9,850m`, and _moneyCustom). §1 says "flush"
      // too; its `2,000.50 ₼` example carries a stray space we do not follow.
      pre = def.symbolBefore ? def.symbol! : '';
      post = def.symbolBefore ? '' : def.symbol!;
    } else if (hasChip) {
      pre = '';
      post = '';
    } else {
      pre = '$currency ';
      post = '';
    }

    // Empty: the whole placeholder is the dim `rest` — `$0`, `0₼`, `0` (§1/§2).
    if (raw.isEmpty) return (typed: '', rest: '${pre}0$post');

    final dot = raw.indexOf('.');
    final whole = dot < 0 ? raw : raw.substring(0, dot);
    final decimals = dot < 0 ? '' : raw.substring(dot + 1);
    final grouped = _group(whole.isEmpty ? '0' : whole);

    // Only what was typed: a trailing dot and a lone decimal survive verbatim
    // (`2,000.`, `2,000.5`); nothing is padded to two places (§2).
    final body = dot < 0 ? grouped : '$grouped.$decimals';
    return (typed: '$pre$body$post', rest: '');
  }

  /// The typed/untyped split **without a currency token**, for rows that carry
  /// the unit in a chip beside the number.
  ///
  /// [split] prefixes the symbol and assumes two decimal places; this one does
  /// neither and takes the count from `currencyDef(currency).decimals`, so a JPY
  /// row pads nothing and a dinar row pads three.
  static ({String typed, String rest}) splitPlain(String raw, String currency) {
    final def = currencyDef(currency);
    final zeros = def.decimals > 0 ? '.${'0' * def.decimals}' : '';
    if (raw.isEmpty) return (typed: '', rest: '0$zeros');
    final dot = raw.indexOf('.');
    final wholeRaw = dot < 0 ? raw : raw.substring(0, dot);
    final whole = _group(wholeRaw.isEmpty ? '0' : wholeRaw);
    if (dot < 0) return (typed: whole, rest: zeros);
    final decs = raw.substring(dot + 1);
    final pad = def.decimals - decs.length;
    return (typed: '$whole.$decs', rest: pad > 0 ? '0' * pad : '');
  }
}

/// The hero card. No border, no tint, no coloured background — the number is
/// the only thing carrying the accent, so the card must not compete with the
/// list below it.
class NumericHeroCard extends StatelessWidget {
  const NumericHeroCard({
    super.key,
    required this.label,
    required this.raw,
    required this.currency,
    required this.accent,
    required this.accentDim,
    required this.focused,
    required this.onTap,
    this.onCurrencyTap,
    this.currencyLocked = false,
  });

  final String label;
  final String raw;
  final String currency;
  final Color accent;
  final Color accentDim;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback? onCurrencyTap;

  /// The chip renders a padlock and does not open the picker — the currency is
  /// the account's property, not a choice (Rebalance §2a). A locked chip still
  /// counts as a chip, so the number below it drops its currency token.
  final bool currencyLocked;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    // Widths are measured under the same scaler a `Text` paints with, so what
    // fits is what renders — no double counting, no guessing from `t`.
    final scaler = MediaQuery.textScalerOf(context);

    // A chip is shown when the currency is tappable, or locked (Rebalance §2a).
    final showChip = onCurrencyTap != null || currencyLocked;
    final chip = !showChip
        ? null
        : CurrencyChip(
            currency: currency,
            onTap: onCurrencyTap ?? () {},
            locked: currencyLocked,
          );

    // The number carries its currency's symbol when it has one, either side
    // (§1); a code-only currency shows nothing here because the chip beside it
    // already names the unit. With no chip the number carries the code instead.
    final hasChip = chip != null;

    // The whole amount string, caret aside — the caret is a fixed-width column
    // between the typed part and the dimmed remainder, so add it as a constant.
    final parts = AmountEntry.split(raw, currency, hasChip: hasChip);
    final amountText = '${parts.typed}${parts.rest}';
    final caretW = focused ? 2 + 2 * s : 0.0;
    double amountWidth(double size) =>
        _measureWidth(amountText, _amountStyle(size), scaler) + caretW;

    final baseSize = 17 * s * t;
    final floorSize = 15 * s * t;

    // The chip never yields: it keeps its intrinsic width on one line, always,
    // and nothing upstream may compress it (§2). So its width is a fixed cost.
    double chipWidth = 0;
    if (chip != null) {
      final chipTextW = _measureWidth(
        currency,
        TextStyle(
          fontSize: 12.5 * s * t,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        scaler,
      );
      // padL(10) + text + gap(2) + chevron(8) + padR(10), all ·s.
      chipWidth = 10 * s + chipTextW + 2 * s + 8 * s + 10 * s;
    }

    // The label yields last (§2): capped at 150·s as before, and below the
    // floor it ellipsises, then disappears.
    final labelNaturalW = _measureWidth(
      label,
      TextStyle(
        fontSize: 15 * s * t,
        fontWeight: FontWeight.w400,
        height: 1.2,
      ),
      scaler,
    ).clamp(0.0, 150 * s);

    final iconW = kIconColumn * s;
    final gap = kIconGap * s;
    const chipGapBase = 10.0;
    final chipGap = chipGapBase * s;
    // A half-pixel of slack so a rounding error never clips the number.
    const eps = 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kFormMargin),
      decoration: BoxDecoration(
        color: AppColors.fieldCard,
        borderRadius: BorderRadius.circular(14 * s),
        border: focused
            ? Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14 * s),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: kRowPadding * s),
            child: ConstrainedBox(
              // A minHeight, never a fixed height: at large text scales the
              // number alone is taller than this, and the row must grow (§1).
              constraints: BoxConstraints(minHeight: 52 * s),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rowWidth = constraints.maxWidth;

                  // Everything on the amount's line except the label and the
                  // amount: the icon column, the two gaps, and the chip when it
                  // shares the line.
                  double fixed(bool chipOnLine) =>
                      iconW +
                      gap +
                      gap +
                      (chip != null && chipOnLine ? chipGap + chipWidth : 0);

                  final amountFloorW = amountWidth(floorSize);

                  // The one decision, taken from measurement, not from `t`: if
                  // the amount cannot fit on the line even at its floor with the
                  // label gone, the chip moves to its own line (§4).
                  final wrapChip = chip != null &&
                      amountFloorW > rowWidth - fixed(true) + eps;

                  // Budget the label and amount share on their line.
                  final budgetLA = rowWidth - fixed(!wrapChip);
                  final amountBudgetFull = budgetLA - labelNaturalW;

                  double chosenSize;
                  double labelMax;
                  if (amountWidth(baseSize) <= amountBudgetFull - eps) {
                    // Fits at full size with the whole label.
                    chosenSize = baseSize;
                    labelMax = 150 * s;
                  } else if (amountFloorW <= amountBudgetFull - eps) {
                    // Shrink the amount — but no further than the floor — keeping
                    // the whole label. Largest fitting size wins.
                    var size = floorSize;
                    const n = 16;
                    for (var i = 0; i <= n; i++) {
                      final cand = baseSize - (baseSize - floorSize) * i / n;
                      if (amountWidth(cand) <= amountBudgetFull - eps) {
                        size = cand;
                        break;
                      }
                    }
                    chosenSize = size;
                    labelMax = 150 * s;
                  } else {
                    // Amount pinned at the floor; the label yields the rest.
                    chosenSize = floorSize;
                    labelMax =
                        (budgetLA - amountFloorW - eps).clamp(0.0, 150 * s);
                  }

                  final Widget amountText = _AmountText(
                    raw: raw,
                    currency: currency,
                    accent: accent,
                    accentDim: accentDim,
                    focused: focused,
                    fontSize: chosenSize,
                    hasChip: hasChip,
                  );
                  // The number may now carry no visible token at all (a code-only
                  // currency), or only a bare symbol — neither names the currency
                  // in words. Whenever a chip is present, speak the amount with
                  // its currency and hide the bare digits beneath (§1.2); the chip
                  // itself also names the unit. A chipless number carries the code
                  // and needs no help.
                  final amount = hasChip
                      ? Semantics(
                          label:
                              money(AmountEntry.value(raw), currency: currency),
                          excludeSemantics: true,
                          child: amountText,
                        )
                      : amountText;

                  final labelWidget = labelMax < 1
                      // Below a legible width the label disappears entirely —
                      // the $ icon and the sheet's title already name the number.
                      ? const SizedBox.shrink()
                      : ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: labelMax),
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
                        );

                  final leading = [
                    SizedBox(
                      width: iconW,
                      child: Icon(
                        // Currency-neutral: the symbol now lives in the number,
                        // so the slot no longer claims a dollar (§3).
                        Icons.payments_rounded,
                        size: 18 * s,
                        color: focused ? accent : AppColors.formDim2,
                      ),
                    ),
                    SizedBox(width: gap),
                    labelWidget,
                    SizedBox(width: gap),
                  ];

                  if (wrapChip) {
                    // §4 — the chip drops to its own line; §2's order still holds
                    // on the line that remains (amount shrank first, label last).
                    return Row(
                      children: [
                        ...leading,
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(height: 8 * s),
                              amount,
                              // wrapChip is only ever true when a chip exists.
                              SizedBox(height: 6 * s),
                              chip,
                              SizedBox(height: 8 * s),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      ...leading,
                      // Fills the slack and right-aligns, so the amount and the
                      // chip read as one trailing group flush to the edge.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: amount,
                        ),
                      ),
                      if (chip != null) ...[
                        SizedBox(width: chipGap),
                        chip,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The amount's glyph style at a given [size]. Shared by [_AmountText] and the
/// measurement pass in [NumericHeroCard] so the width the card fits the number
/// into is the exact width the number paints at — letterSpacing rides on the
/// size, so it follows on its own.
TextStyle _amountStyle(double size) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.024 * size,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// One-line intrinsic width of [text] in [style], scaled exactly as a `Text`
/// under [scaler] would paint it. The card sizes the amount from real widths,
/// not a text-scale heuristic.
double _measureWidth(String text, TextStyle style, TextScaler scaler) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

class _AmountText extends StatefulWidget {
  const _AmountText({
    required this.raw,
    required this.currency,
    required this.accent,
    required this.accentDim,
    required this.focused,
    required this.fontSize,
    this.hasChip = true,
  });

  final String raw;
  final String currency;
  final Color accent;
  final Color accentDim;
  final bool focused;

  /// Resolved by the card from the space actually available (§2/§3): 17·s·t
  /// when the number fits, shrinking to a 15·s·t floor when it does not.
  final double fontSize;

  /// Matches the card's decision (§1): a code-only currency drops its token from
  /// the number when a chip beside it names the unit; a symbol currency keeps
  /// its symbol regardless.
  final bool hasChip;

  @override
  State<_AmountText> createState() => _AmountTextState();
}

class _AmountTextState extends State<_AmountText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final parts =
        AmountEntry.split(widget.raw, widget.currency, hasChip: widget.hasChip);
    final size = widget.fontSize;

    final style = _amountStyle(size);

    // The pale span is now only the empty field's placeholder `0`: no decimals
    // are shown before the digits that fill them (§2), so once anything is typed
    // `rest` is empty and the whole number is bright. An empty field is all
    // placeholder, so it stays dim whether focused or not.
    final restColor = widget.accentDim;

    return Text.rich(
      TextSpan(
        children: [
          if (parts.typed.isNotEmpty)
            TextSpan(
              text: parts.typed,
              style: style.copyWith(color: widget.accent),
            ),
          if (widget.focused)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AnimatedBuilder(
                animation: _blink,
                builder: (context, _) => Opacity(
                  opacity: _blink.value < 0.5 ? 1 : 0,
                  child: Container(
                    width: 2,
                    height: size * 1.05,
                    margin: EdgeInsets.symmetric(horizontal: 1 * s),
                    color: widget.accent,
                  ),
                ),
              ),
            ),
          if (parts.rest.isNotEmpty)
            TextSpan(
              text: parts.rest,
              style: style.copyWith(color: restColor),
            ),
        ],
      ),
      maxLines: 1,
      // Never ellipsised: the card has already sized the number to fit (§2), so
      // the reader always sees every digit they typed. Clip (not ellipsis) so a
      // sub-pixel rounding error trims a hair rather than swapping in a "…".
      overflow: TextOverflow.clip,
      textAlign: TextAlign.right,
    );
  }
}

/// The currency control: the code, a chevron, and a tap that opens the picker.
/// Shared by the numeric hero and [TxnAmountFieldRow] — one chip, two callers,
/// so a change to either shows up in both.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({
    super.key,
    required this.currency,
    required this.onTap,
    this.locked = false,
  });

  final String currency;
  final VoidCallback onTap;

  /// A locked chip states the unit but cannot change it — a padlock stands
  /// where the chevron would, and the tap does nothing (Rebalance §2a). Its
  /// geometry is otherwise the chevron chip's exactly, so widths still match.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return Semantics(
      // Locked, it is a label, not a button; either way it names the currency
      // in words so the token-less number is still announced with its unit.
      button: !locked,
      label: '$currency · ${AppLocalizations.of(context).eaCurrency}',
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8 * s),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency,
                style: TextStyle(
                  fontSize: 12.5 * s * formTextScale(context),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.chipText,
                ),
              ),
              SizedBox(width: 2 * s),
              Icon(
                locked
                    ? Icons.lock_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 8 * s,
                color: AppColors.chipText.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amount row typed in place (task 007).
///
/// Unfocused it is [TxnFieldRow]'s geometry exactly, minus the chevron —
/// tapping opens nothing, and those two absences are what say so. Focused, the
/// keypad docked at the form's foot writes here; the accent outline, the accent
/// icon and a blinking caret mark it three ways at once, so focus never rests
/// on colour alone.
class TxnAmountFieldRow extends StatefulWidget {
  const TxnAmountFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.raw,
    required this.currency,
    required this.emptyText,
    required this.focused,
    required this.onTap,
    required this.onCurrencyTap,
    this.sign = '',
    this.valueColor,
  });

  final IconData icon;
  final String label;

  /// The literal characters typed, straight from the form's `_raw`.
  final String raw;
  final String currency;

  /// A leading sign glyph shown before the figure once a direction is known
  /// (task 030 §3): '+' or '−'. Empty keeps the row unsigned, as every amount
  /// row was before. Never drawn in the empty state — an unset amount has no
  /// sign to carry.
  final String sign;

  /// The colour the figure (and its sign) take once a direction is known —
  /// positive for money in, negative for money out. Null keeps the neutral
  /// primary-text colour every other amount row uses.
  final Color? valueColor;

  /// Shown while [raw] is empty *and* the row is unfocused. The instant the row
  /// takes focus the dim `0.00` replaces it; the two never coexist.
  final String emptyText;

  /// True while the docked keypad writes to this row.
  final bool focused;

  final VoidCallback onTap;
  final VoidCallback onCurrencyTap;

  @override
  State<TxnAmountFieldRow> createState() => _TxnAmountFieldRowState();
}

class _TxnAmountFieldRowState extends State<TxnAmountFieldRow>
    with SingleTickerProviderStateMixin {
  /// Caret blink, the same 1050 ms period the hero and the starting-balance row
  /// use. Runs only while focused, so an unfocused row costs no ticker.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void initState() {
    super.initState();
    if (widget.focused) _blink.repeat();
  }

  @override
  void didUpdateWidget(TxnAmountFieldRow old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) _blink.repeat();
    if (!widget.focused && old.focused) _blink.stop();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  static double _measure(String s, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    final scaler = MediaQuery.textScalerOf(context);

    final focused = widget.focused;
    final filled = widget.raw.isNotEmpty;
    // The chip is a property of an amount: absent until there is one, or until
    // the row is focused and there is about to be (§1).
    final showChip = focused || filled;
    final showEmpty = !filled && !focused;

    final labelStyle = TextStyle(
      fontSize: 14.5 * s * t,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.textPrimary,
    );
    // The value takes TxnFieldRow's style exactly — 14.5 pt w400 (task 042), not
    // the starting-balance row's 16 pt w600. Here the amount is one optional row
    // among five and must not outweigh Account, Category and Repeat beside it.
    TextStyle numStyle(Color c) => TextStyle(
          fontSize: 14.5 * s * t,
          fontWeight: FontWeight.w400,
          height: 1.2,
          color: c,
        );

    final parts = AmountEntry.splitPlain(widget.raw, widget.currency);
    // Task 030: once a direction is known the whole figure (sign, digits and
    // padding) takes the direction colour; otherwise the neutral ramp below.
    final numColor = widget.valueColor ?? AppColors.textPrimary;
    // Task 11: the typed digits are always bright; the untyped padding is dim
    // only while the keypad is still writing here (or the field is empty), and
    // joins the number at full brightness once the row is filled and unfocused.
    // Pale means "not typed yet", never "these are the decimals". A signed row
    // paints the padding in the direction colour too, so `+1,200.00` reads as
    // one figure.
    final restColor = widget.valueColor ??
        ((filled && !focused) ? AppColors.textPrimary : AppColors.textTertiary);

    final Widget value = showEmpty
        ? Text(
            widget.emptyText,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: numStyle(AppColors.formDim2),
          )
        : Text.rich(
            TextSpan(children: [
              // The sign leads the figure (task 030 §3); never in the empty
              // state, which this branch is not.
              if (widget.sign.isNotEmpty)
                TextSpan(text: widget.sign, style: numStyle(numColor)),
              if (parts.typed.isNotEmpty)
                TextSpan(text: parts.typed, style: numStyle(numColor)),
              if (focused)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: AnimatedBuilder(
                    animation: _blink,
                    builder: (context, _) => Opacity(
                      opacity: _blink.value < 0.5 ? 1 : 0,
                      child: Container(
                        width: 2,
                        height: 17 * s,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              if (parts.rest.isNotEmpty)
                TextSpan(text: parts.rest, style: numStyle(restColor)),
            ]),
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
          );

    final chip = showChip
        ? CurrencyChip(currency: widget.currency, onTap: widget.onCurrencyTap)
        : null;

    final icon = Icon(
      widget.icon,
      size: 18 * s,
      color: focused ? AppColors.accent : AppColors.formDim2,
    );

    final content = LayoutBuilder(
      builder: (context, c) {
        final labelW = _measure(widget.label, labelStyle, scaler);
        final shown = showEmpty
            ? widget.emptyText
            : '${widget.sign}${parts.typed}${parts.rest}';
        final valueW = _measure(shown, numStyle(AppColors.textPrimary), scaler) +
            (focused ? 4 : 0); // the caret column
        final chipW = chip == null
            ? 0.0
            // padL(10) + code + gap(2) + chevron(8) + padR(10), all ·s — the
            // same arithmetic the hero uses, so the two chips measure alike.
            : 10 * s +
                _measure(
                  widget.currency,
                  TextStyle(
                      fontSize: 12.5 * s * t,
                      fontWeight: FontWeight.w600,
                      height: 1.2),
                  scaler,
                ) +
                2 * s +
                8 * s +
                10 * s +
                6 * s; // the gap before it
        final iconW = kIconColumn * s;
        final gaps = kIconGap * s * 2;
        // One line only if the label and the amount unit both fit with a little
        // breathing room between them.
        final oneLine =
            iconW + gaps + labelW + 16 * s + valueW + chipW <= c.maxWidth;

        if (oneLine) {
          return Row(
            children: [
              SizedBox(width: iconW, child: icon),
              SizedBox(width: kIconGap * s),
              // Capped, not Flexible: a second flex child would split the free
              // space with the value and the value's right edge would move with
              // the label's length — the misalignment this row exists to avoid.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 150 * s),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              SizedBox(width: kIconGap * s),
              Expanded(child: value),
              if (chip != null) ...[SizedBox(width: 6 * s), chip],
            ],
          );
        }

        // Two-line fallback — label above, the amount below, right-aligned.
        // The number is never truncated and never shrunk, and the chip never
        // wraps on its own.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: iconW,
              child: Padding(padding: EdgeInsets.only(top: 1 * s), child: icon),
            ),
            SizedBox(width: kIconGap * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label, style: labelStyle),
                  SizedBox(height: 4 * s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: value),
                      if (chip != null) ...[SizedBox(width: 6 * s), chip],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    final body = Container(
      // Focused: the accent outline, inset inside the card. The margin/padding
      // swap keeps the content in place, so the text barely moves when the
      // outline appears — the same swap TxnNoteFieldRow and the starting
      // balance row use.
      margin: focused ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: focused
          ? BoxDecoration(
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.55),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      constraints: BoxConstraints(minHeight: focused ? 48 * s - 6 : 48 * s),
      padding: EdgeInsets.symmetric(
        horizontal: focused ? kRowPadding * s - 3 : kRowPadding * s,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      focused: focused,
      excludeSemantics: true,
      label: showEmpty
          ? '${widget.label} ${widget.emptyText}'
          : '${widget.label} '
              '${money(AmountEntry.value(widget.raw), currency: widget.currency)}',
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14 * s),
        child: body,
      ),
    );
  }
}

/// In-app keypad for the amount.
///
/// The amount is the field users touch first and the only numeric one, so it
/// gets a keypad rather than the system keyboard: no keyboard-height jump, a
/// full-size decimal key, and Save stays in thumb reach directly above it.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', 'back'],
  ];

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10 * s, 8 * s, 10 * s, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < _rows.length; r++) ...[
              if (r > 0) SizedBox(height: 8 * s),
              Row(
                children: [
                  for (var c = 0; c < _rows[r].length; c++) ...[
                    if (c > 0) SizedBox(width: 8 * s),
                    Expanded(
                      child: _Key(
                        value: _rows[r][c],
                        onKey: onKey,
                        onBackspace: onBackspace,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    required this.value,
    required this.onKey,
    required this.onBackspace,
  });

  final String value;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final isBack = widget.value == 'back';
    final isDot = widget.value == '.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () =>
          isBack ? widget.onBackspace() : widget.onKey(widget.value),
      child: Container(
        height: 52 * s < 44 ? 44 : 52 * s,
        decoration: BoxDecoration(
          color: _pressed ? AppColors.keyPressed : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12 * s),
        ),
        alignment: Alignment.center,
        child: isBack
            ? Icon(
                Icons.backspace_outlined,
                size: 22 * s,
                color: AppColors.textPrimary,
              )
            : Text(
                widget.value,
                style: TextStyle(
                  fontSize: (isDot ? 20 : 23) * s,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  color: isDot
                      ? AppColors.decimalKey
                      : AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }
}
