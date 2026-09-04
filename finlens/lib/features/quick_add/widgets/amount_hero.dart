import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
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

  /// Splits the display into the part the user actually typed and the decimal
  /// remainder that is only there to hold the column.
  static ({String typed, String rest}) split(String raw, String currency) {
    final symbol = currencySymbol(currency);
    if (raw.isEmpty) return (typed: '', rest: '${symbol}0.00');

    final dot = raw.indexOf('.');
    final whole = dot < 0 ? raw : raw.substring(0, dot);
    final decimals = dot < 0 ? '' : raw.substring(dot + 1);
    final grouped = _group(whole.isEmpty ? '0' : whole);

    final typed = dot < 0
        ? '$symbol$grouped'
        : '$symbol$grouped.$decimals';
    final rest = dot < 0 ? '.00' : '0' * (2 - decimals.length);
    return (typed: typed, rest: rest);
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
  });

  final String label;
  final String raw;
  final String currency;
  final Color accent;
  final Color accentDim;
  final bool focused;
  final VoidCallback onTap;
  final VoidCallback? onCurrencyTap;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    // Widths are measured under the same scaler a `Text` paints with, so what
    // fits is what renders — no double counting, no guessing from `t`.
    final scaler = MediaQuery.textScalerOf(context);

    final chip = onCurrencyTap == null
        ? null
        : _CurrencyChip(currency: currency, onTap: onCurrencyTap!);

    // The whole amount string, caret aside — the caret is a fixed-width column
    // between the typed part and the dimmed remainder, so add it as a constant.
    final parts = AmountEntry.split(raw, currency);
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

                  final amount = _AmountText(
                    raw: raw,
                    currency: currency,
                    accent: accent,
                    accentDim: accentDim,
                    focused: focused,
                    fontSize: chosenSize,
                  );

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
                        Icons.attach_money_rounded,
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
  });

  final String raw;
  final String currency;
  final Color accent;
  final Color accentDim;
  final bool focused;

  /// Resolved by the card from the space actually available (§2/§3): 17·s·t
  /// when the number fits, shrinking to a 15·s·t floor when it does not.
  final double fontSize;

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
    final parts = AmountEntry.split(widget.raw, widget.currency);
    final size = widget.fontSize;

    final style = _amountStyle(size);

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
              style: style.copyWith(color: widget.accentDim),
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

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.currency, required this.onTap});

  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    return GestureDetector(
      onTap: onTap,
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
              Icons.keyboard_arrow_down_rounded,
              size: 8 * s,
              color: AppColors.chipText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// New Task's hero: same card, same position, but the title is text.
///
/// The layout differs on purpose — a task has no figure to right-align, so
/// the title reads as a heading with its field name captioned underneath.
class TextHeroCard extends StatelessWidget {
  const TextHeroCard({
    super.key,
    required this.caption,
    required this.placeholder,
    required this.controller,
    required this.focusNode,
  });

  final String caption;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final s = formScale(context);
    final t = formTextScale(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kFormMargin),
      decoration: BoxDecoration(
        color: AppColors.fieldCard,
        borderRadius: BorderRadius.circular(14 * s),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(15 * s, 14 * s, 15 * s, 15 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2 * s),
              child: SizedBox(
                width: kIconColumn * s,
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 18 * s,
                  color: AppColors.formDim2,
                ),
              ),
            ),
            SizedBox(width: kIconGap * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    cursorColor: AppColors.accent,
                    style: TextStyle(
                      fontSize: 17 * s * t,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: placeholder,
                      hintStyle: TextStyle(
                        fontSize: 17 * s * t,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                        color: AppColors.formDim2,
                      ),
                    ),
                  ),
                  SizedBox(height: 3 * s),
                  Text(
                    caption,
                    style: TextStyle(
                      fontSize: 12.5 * s * t,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                      color: AppColors.formDim2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
