import 'package:flutter/material.dart';

import '../../../core/models/currency_def.dart';
import '../../../core/utils/arithmetic.dart';
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

  static String press(String raw, String key) =>
      appendDigit(raw, key, maxDecimals: 2, maxWhole: _maxWhole);

  static String backspace(String raw) => backspaceDigit(raw);

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

  /// The typed amount, with the currency's token attached in the position that
  /// currency defines — or with no token at all, when a chip beside the field is
  /// already naming the unit in words (task 045 §1).
  ///
  /// Three questions, each answered in exactly one place:
  ///
  ///   - **Is there a token?** A chip names the currency in words, so a token
  ///     that also contains letters would state the unit twice — `2,000TMT` next
  ///     to a `TMT` chip, `m2,000` next to it. That token drops. A glyph (`$`,
  ///     `€`, `₽`) is not a repetition of the code, reads as part of the figure,
  ///     and stays. With no chip the number always carries its token, because
  ///     nothing else on the row states the unit.
  ///   - **Which side?** [CurrencyDef.symbolBefore] — the user's own Position
  ///     choice, for symbols and codes alike, the same field `money()` reads.
  ///   - **Flush or spaced?** [CurrencyDef.tokenHugs], the same getter `money()`
  ///     reads. This function used to decide it itself and printed `2,000TMT`
  ///     where `money()` printed `2,000 TMT` (task 045 §2).
  ///
  /// Decimals follow one rule, shared with [splitPlain] (task 043 §4): no
  /// decimal point typed means no decimals at all; a decimal point typed means
  /// the field is completed to the currency's own width with dim zeros.
  static ({String typed, String rest}) split(
    String raw,
    String currency, {
    bool hasChip = true,
  }) {
    final def = currencyDef(currency);

    // The unit against the number. `def.token` is the symbol when the currency
    // has one and the code otherwise, so a code-only currency's Position choice
    // is honoured here exactly as it is in money().
    final token = def.token;
    // A non-breaking space, exactly as money()/_moneyCustom uses (spec §3): the
    // number never wraps away from its unit, and the two paths print the same
    // gap byte-for-byte.
    final gap = def.tokenHugs ? '' : ' ';
    final String pre;
    final String post;
    if (hasChip && !def.tokenHugs) {
      // Said once, and the chip is what says it.
      pre = '';
      post = '';
    } else if (def.symbolBefore) {
      pre = '$token$gap';
      post = '';
    } else {
      pre = '';
      post = '$gap$token';
    }

    // Empty: the whole placeholder is the dim `rest` — `$0`, `0 TMT`, `0`. No
    // point has been typed, so there are no decimals to show (task 043 §4).
    if (raw.isEmpty) return (typed: '', rest: '${pre}0$post');

    final dot = raw.indexOf('.');
    final whole = dot < 0 ? raw : raw.substring(0, dot);
    final decimals = dot < 0 ? '' : raw.substring(dot + 1);
    final grouped = _group(whole.isEmpty ? '0' : whole);

    // A whole number stays whole: `100000` is `100,000`, never `100,000.00`.
    if (dot < 0) return (typed: '$pre$grouped$post', rest: '');

    // The point exists, so the decimal field exists and is completed to the
    // currency's width: `100,000.` → `100,000.` + dim `00`, `100,000.5` →
    // `100,000.5` + dim `0`, `100,000.95` → nothing dim.
    final pad = def.decimals - decimals.length;
    final padding = pad > 0 ? '0' * pad : '';
    if (padding.isEmpty) {
      return (typed: '$pre$grouped.$decimals$post', rest: '');
    }
    // A trailing token joins the dim run rather than being stranded bright on
    // the far side of it — the hero paints two spans, not three, and the empty
    // placeholder above already dims its token for the same reason. It returns
    // to full brightness the moment the number is complete.
    return (typed: '$pre$grouped.$decimals', rest: '$padding$post');
  }

  /// The typed/untyped split **without a currency token**, for rows that carry
  /// the unit in a chip beside the number.
  ///
  /// Same decimal rule as [split] — no point, no decimals; a point, a completed
  /// field — and the same `currencyDef(currency).decimals` width, so a JPY row
  /// pads nothing and a dinar row pads three. It differs from [split] in one
  /// thing only: no symbol or code is attached here.
  static ({String typed, String rest}) splitPlain(String raw, String currency) {
    final def = currencyDef(currency);
    if (raw.isEmpty) return (typed: '', rest: '0');
    final dot = raw.indexOf('.');
    final wholeRaw = dot < 0 ? raw : raw.substring(0, dot);
    final whole = _group(wholeRaw.isEmpty ? '0' : wholeRaw);
    if (dot < 0) return (typed: whole, rest: '');
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
    this.expression,
  });

  final String label;
  final String raw;
  final String currency;

  /// The full expression the keypad is building. When it carries an operator the
  /// card renders the expression (grouped operands, spaced operators, a
  /// horizontal scroll) instead of the single-number path; a plain number
  /// (`!hasOperator`) renders exactly as [raw] always did. Null keeps the legacy
  /// single-number behaviour untouched (callers that have not adopted it).
  final Expression? expression;
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

    // Whether a chip sits beside the number is the only thing this widget knows
    // that [AmountEntry.split] does not, so it is the only thing it passes. What
    // the number then shows — a glyph, a spaced token, or nothing — is split's
    // decision, taken the same way for every amount in the app (task 045 §1).
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

                  // An active expression (an operator is pending) renders as a
                  // horizontally-scrolling line at full size — it never shrinks,
                  // wraps or truncates (spec §7). The label keeps its full cap,
                  // the chip stays on the line beside it.
                  final expr = expression;
                  if (expr != null && expr.showsAsExpression) {
                    return Row(
                      children: [
                        SizedBox(
                          width: iconW,
                          child: Icon(
                            Icons.payments_rounded,
                            size: 18 * s,
                            color: focused ? accent : AppColors.formDim2,
                          ),
                        ),
                        SizedBox(width: gap),
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: Semantics(
                            label: spokenExpression(
                                expr, AppLocalizations.of(context)),
                            excludeSemantics: true,
                            child: _ExpressionText(
                              expression: expr,
                              accent: accent,
                              focused: focused,
                              fontSize: baseSize,
                            ),
                          ),
                        ),
                        if (chip != null) ...[
                          SizedBox(width: chipGap),
                          chip,
                        ],
                      ],
                    );
                  }

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

/// The expression spoken as words for a screen reader — `569 plus 30`, not a
/// run of bare glyphs (spec §8). The operators use the localised keypad labels;
/// a resolved negative keeps its minus.
String spokenExpression(Expression e, AppLocalizations l) {
  String word(Op op) => switch (op) {
        Op.add => l.keypadPlus,
        Op.subtract => l.keypadMinus,
        Op.multiply => l.keypadMultiply,
        Op.divide => l.keypadDivide,
      };
  final nums = [...e.operands, if (e.pending.isNotEmpty) e.pending];
  final parts = <String>[];
  for (var i = 0; i < nums.length; i++) {
    parts.add(nums[i].startsWith('-') ? '−${nums[i].substring(1)}' : nums[i]);
    if (i < e.operators.length) parts.add(word(e.operators[i]));
  }
  return parts.join(' ');
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

/// Renders an active expression (`569 + 30`) on one line. The operands are
/// grouped like plain numbers and the operators spaced (spec §7); the whole line
/// scrolls horizontally when it outgrows the field, keeping the caret at the
/// right edge visible, and it never shrinks the font, wraps or truncates.
class _ExpressionText extends StatefulWidget {
  const _ExpressionText({
    required this.expression,
    required this.accent,
    required this.focused,
    required this.fontSize,
  });

  final Expression expression;
  final Color accent;
  final bool focused;
  final double fontSize;

  @override
  State<_ExpressionText> createState() => _ExpressionTextState();
}

class _ExpressionTextState extends State<_ExpressionText>
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
    final size = widget.fontSize;
    final style = _amountStyle(size).copyWith(color: widget.accent);
    // reverse:true pins the line to the right when it fits and keeps the caret
    // (its right end) visible when it overflows — a right-aligned scroll.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const ClampingScrollPhysics(),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: expressionDisplay(widget.expression), style: style),
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
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textAlign: TextAlign.right,
      ),
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
    this.showIndicator = true,
    this.semanticsHint,
  });

  final String currency;
  final VoidCallback onTap;

  /// A locked chip states the unit but cannot change it — a padlock stands
  /// where the chevron would, and the tap does nothing (Rebalance §2a). Its
  /// geometry is otherwise the chevron chip's exactly, so widths still match.
  final bool locked;

  /// The trailing glyph (task 066 §3). True → the chevron (or padlock when
  /// [locked]). False → no glyph at all: the app's plain currency chip, a
  /// label rather than a button, for a unit the user cannot change on this
  /// screen but that is not "locked" behind a padlock (the goal form). The
  /// [onTap] still fires — the goal uses it for its explanatory snackbar.
  final bool showIndicator;

  /// Appended to the semantics label after the currency (task 066 §3) — the
  /// goal passes "amounts follow the source's currency". Null keeps the
  /// default "{code} · currency".
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    // A button only when it can change (a chevron chip). Locked or indicator-
    // less, it is a label that still names the currency in words so a token-
    // less number is announced with its unit.
    final isButton = !locked && showIndicator;
    return Semantics(
      button: isButton,
      label:
          '$currency · ${semanticsHint ?? AppLocalizations.of(context).eaCurrency}',
      child: GestureDetector(
        onTap: (locked && showIndicator) ? null : onTap,
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
              if (showIndicator) ...[
                SizedBox(width: 2 * s),
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 8 * s,
                  color: AppColors.chipText.withValues(alpha: 0.5),
                ),
              ],
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
///
/// An empty amount is a neutral, dim `0` beside its currency chip (task 061):
/// a zero in a unit, never a sentence. The chip is always present, so typing
/// moves nothing but the digits.
class TxnAmountFieldRow extends StatefulWidget {
  const TxnAmountFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.raw,
    required this.currency,
    required this.focused,
    required this.onTap,
    required this.onCurrencyTap,
    this.sign = '',
    this.valueColor,
    this.expression,
  });

  final IconData icon;
  final String label;

  /// The literal characters typed, straight from the form's `_raw`.
  final String raw;

  /// The full keypad expression. An operator switches the row to expression
  /// mode (a scrolling `1,234 + 30`); a plain number renders [raw] unchanged.
  final Expression? expression;
  final String currency;

  /// A leading sign glyph shown before the figure once a direction is known
  /// (task 030 §3): '+' or '−'. Empty keeps the row unsigned, as every amount
  /// row was before. Never drawn in the empty state — an unset amount has no
  /// sign to carry — and the build enforces that (task 061): the empty `0`
  /// stays neutral even when [valueColor] is set.
  final String sign;

  /// The colour the figure (and its sign) take once a direction is known —
  /// positive for money in, negative for money out. Null keeps the neutral
  /// primary-text colour every other amount row uses.
  final Color? valueColor;

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
    final exprMode =
        widget.expression != null && widget.expression!.showsAsExpression;
    final filled = widget.raw.isNotEmpty || exprMode;
    // The chip is always present (task 061): it is the currency's place on the
    // row, exactly like the hero's, in every state — so typing into an empty
    // amount moves nothing but the digits.

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
    // one figure. An EMPTY amount is neutral (task 061): its `0` stays in the
    // dim ramp in every state, even when a category has set [valueColor] —
    // an unset amount has no direction yet.
    final restColor = !filled
        ? AppColors.textTertiary
        : widget.valueColor ??
            (focused ? AppColors.textTertiary : AppColors.textPrimary);

    final Widget value = exprMode
        ? _ExpressionText(
            expression: widget.expression!,
            accent: numColor,
            focused: focused,
            fontSize: 14.5 * s * t,
          )
        : Text.rich(
            TextSpan(children: [
              // The sign leads the figure (task 030 §3); never in the empty
              // state — an unset amount has no sign to carry (task 061).
              if (widget.sign.isNotEmpty && filled)
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

    final chip =
        CurrencyChip(currency: widget.currency, onTap: widget.onCurrencyTap);

    final icon = Icon(
      widget.icon,
      size: 18 * s,
      color: focused ? AppColors.accent : AppColors.formDim2,
    );

    final content = LayoutBuilder(
      builder: (context, c) {
        final labelW = _measure(widget.label, labelStyle, scaler);
        final shown =
            '${filled ? widget.sign : ''}${parts.typed}${parts.rest}';
        final valueW = _measure(shown, numStyle(AppColors.textPrimary), scaler) +
            (focused ? 4 : 0); // the caret column
        // padL(10) + code + gap(2) + chevron(8) + padR(10), all ·s — the
        // same arithmetic the hero uses, so the two chips measure alike. The
        // chip is always on the row (task 061), so it is always counted.
        final chipW = 10 * s +
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
        // breathing room between them. An expression always takes the one-line
        // path — its value scrolls horizontally rather than wrapping (spec §7).
        final oneLine = exprMode ||
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
              SizedBox(width: 6 * s),
              chip,
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
                      SizedBox(width: 6 * s),
                      chip,
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
      // An empty amount is announced as a zero in its currency through the
      // same money() path the filled state uses (task 061) — never a sentence.
      label: exprMode
          ? '${widget.label} '
              '${spokenExpression(widget.expression!, AppLocalizations.of(context))}'
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
///
/// An operator row (`+ − × ÷ =`) sits above the digit grid, always visible so
/// the arithmetic is discoverable (spec §2). The **digit grid below is
/// untouched** — same 8·s gaps, 12·s radius, 52·s keys. [onOperator] and
/// [onEquals] are optional so a field that has not adopted the expression model
/// simply gets an inert operator row; [canResolve] drives the `=` key's two
/// states (an accent fill when it resolves, otherwise the operator pill with a
/// grey glyph — spec §4).
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.onOperator,
    this.onEquals,
    this.canResolve = false,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// Fires with the operator pressed. Null leaves the row visible but inert.
  final ValueChanged<Op>? onOperator;

  /// Fires when `=` is pressed and [canResolve] is true.
  final VoidCallback? onEquals;

  /// Whether a pending expression can be resolved right now — the `=` key's
  /// enabled state and its only on-screen error report (spec §4).
  final bool canResolve;

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
            // The operator row. The buttons are deliberately shorter than the
            // digit keys (34·s visible) — a full key-row of height would push
            // the form off a small screen; the tap target is expanded to 44
            // instead, into the transparent space around the pill (spec §2.1).
            Row(
              children: [
                for (final op in Op.values) ...[
                  Expanded(
                    child: _OpKey(
                      glyph: op.glyph,
                      semanticsLabel: _opLabel(context, op),
                      onTap: onOperator == null ? null : () => onOperator!(op),
                    ),
                  ),
                  SizedBox(width: 8 * s),
                ],
                Expanded(
                  child: _EqualsKey(
                    enabled: canResolve,
                    onTap: canResolve ? onEquals : null,
                    label: _equalsLabel(context),
                  ),
                ),
              ],
            ),
            // The one gap the spec sets between the operator row and the grid.
            SizedBox(height: 6 * s),
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

  static String _opLabel(BuildContext context, Op op) {
    final l = AppLocalizations.of(context);
    return switch (op) {
      Op.add => l.keypadPlus,
      Op.subtract => l.keypadMinus,
      Op.multiply => l.keypadMultiply,
      Op.divide => l.keypadDivide,
    };
  }

  static String _equalsLabel(BuildContext context) =>
      AppLocalizations.of(context).keypadEquals;
}

/// An operator key (`+ − × ÷`). Visible height 34·s; the tap target is a 44·s
/// [SizedBox] with the pill centred inside it, so the hit area reaches 44
/// without the pill growing (spec §2.1 / §8).
class _OpKey extends StatefulWidget {
  const _OpKey({
    required this.glyph,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String glyph;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  State<_OpKey> createState() => _OpKeyState();
}

class _OpKeyState extends State<_OpKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final hit = 44 * s < 44 ? 44.0 : 44 * s;
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SizedBox(
          height: hit,
          child: Center(
            child: Container(
              height: 34 * s,
              decoration: BoxDecoration(
                color: _pressed ? AppColors.keyPressed : AppColors.sheetCard,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.glyph,
                style: TextStyle(
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  color: AppColors.accentLight,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The `=` key. Active it is an accent fill (tap to resolve); passive it wears
/// the same operator pill as `+ − × ÷` (sheetCard) with a grey glyph — five
/// equal keys, the glyph colour alone saying an expression is pending (spec §4).
/// Same 34·s visible / 44·s hit-target geometry as [_OpKey].
class _EqualsKey extends StatefulWidget {
  const _EqualsKey({
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final String label;

  @override
  State<_EqualsKey> createState() => _EqualsKeyState();
}

class _EqualsKeyState extends State<_EqualsKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final hit = 44 * s < 44 ? 44.0 : 44 * s;
    // Passive `=` wears the same pill as `+ − × ÷` (sheetCard), so the operator
    // row reads as five keys on every host — on a surfaceAlt sheet the old
    // surfaceAlt pill vanished into the body. The glyph is neutral grey, not the
    // operators' accentLight: grey says "nothing to resolve yet", the accent
    // fill says "tap to resolve".
    final bg = !widget.enabled
        ? AppColors.sheetCard
        : (_pressed ? AppColors.keyPressed : AppColors.accent);
    final fg =
        widget.enabled ? AppColors.textPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SizedBox(
          height: hit,
          child: Center(
            child: Container(
              height: 34 * s,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              alignment: Alignment.center,
              child: Text(
                '=',
                style: TextStyle(
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
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
