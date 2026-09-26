import 'package:flutter/material.dart';

import '../../core/models/currency_def.dart';
import '../../core/utils/arithmetic.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../features/quick_add/widgets/amount_hero.dart';

/// One magnitude typed on the app keypad with the expression operators, with a
/// "this one" / "this one and after" choice and a Reset back to the usual value.
///
/// Task 064 introduced this for a scheduled item's occurrence amount; task 067.2
/// reuses it for a budget period's limit. The two callers differ only in the
/// title, the anchor value, the currency and what Save/Reset do — so those are
/// parameters and the sheet itself is shared, unchanged in behaviour.
Future<void> showAmountOverrideSheet(
  BuildContext context, {
  required String title,
  required double initialMagnitude,
  required double usualMagnitude,
  required String currencyCode,
  required bool hasOverride,
  required String onlyLabel,
  required String andAfterLabel,
  required void Function(double magnitude, bool andAfter) onSave,
  required VoidCallback onReset,
  int? decimals,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AmountOverrideSheet(
      title: title,
      initialMagnitude: initialMagnitude,
      usualMagnitude: usualMagnitude,
      currencyCode: currencyCode,
      hasOverride: hasOverride,
      onlyLabel: onlyLabel,
      andAfterLabel: andAfterLabel,
      onSave: onSave,
      onReset: onReset,
      decimals: decimals ?? currencyDef(currencyCode).decimals,
    ),
  );
}

class _AmountOverrideSheet extends StatefulWidget {
  const _AmountOverrideSheet({
    required this.title,
    required this.initialMagnitude,
    required this.usualMagnitude,
    required this.currencyCode,
    required this.hasOverride,
    required this.onlyLabel,
    required this.andAfterLabel,
    required this.onSave,
    required this.onReset,
    required this.decimals,
  });

  final String title;
  final double initialMagnitude;
  final double usualMagnitude;
  final String currencyCode;
  final bool hasOverride;
  final String onlyLabel;
  final String andAfterLabel;
  final void Function(double magnitude, bool andAfter) onSave;
  final VoidCallback onReset;
  final int decimals;

  @override
  State<_AmountOverrideSheet> createState() => _AmountOverrideSheetState();
}

class _AmountOverrideSheetState extends State<_AmountOverrideSheet> {
  late Expression _expr =
      Expression.ofRaw(AmountEntry.fromDouble(widget.initialMagnitude.abs()));

  /// false = Only … (the default); true = … and after.
  bool _andAfter = false;

  int get _precision => widget.decimals;
  double? get _value => _expr.value(_precision);
  bool get _canSave => (_value ?? 0) > 0;

  void _save() {
    if (!_canSave) return;
    // Save resolves a pending expression silently, exactly like the editors.
    final v = _expr.evaluated(_precision).value(_precision);
    if (v == null || v <= 0) return;
    widget.onSave(v, _andAfter);
    Navigator.of(context).pop();
  }

  void _reset() {
    widget.onReset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final usual = money(widget.usualMagnitude.abs(),
        masked: false, withSymbol: false, signless: true);
    final pendingResult = _expr.hasOperator && _canSave ? _value : null;

    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── header: Cancel · the title · Save ───────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(l.actionCancel,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    InkWell(
                      onTap: _canSave ? _save : null,
                      child: Text(
                        l.actionSave,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _canSave
                              ? AppColors.accent
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── the amount, as typed (an expression stays an expression) ────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 14, Insets.gutter, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _expr.hasOperator
                            ? expressionDisplay(_expr)
                            : money(_value ?? 0,
                                masked: false,
                                signless: true,
                                withSymbol: false,
                                forceDecimals: (_value ?? 0) % 1 != 0),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.currencyCode,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              if (pendingResult != null)
                Center(
                  child: Text(
                    '= ${money(pendingResult, signless: true, withSymbol: false, forceDecimals: pendingResult % 1 != 0)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 2),
              // ── the anchor: the usual amount, and Reset when overridden ─────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.tdUsually('$usual ${widget.currencyCode}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textTertiary),
                  ),
                  if (widget.hasOverride) ...[
                    const Text(' · ',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textTertiary)),
                    InkWell(
                      onTap: _reset,
                      child: Text(
                        l.tdReset,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentLight),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Insets.lg),
              // ── Only this one, or this one and after ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.sheetCard,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _optionRow(widget.onlyLabel,
                          selected: !_andAfter,
                          onTap: () => setState(() => _andAfter = false)),
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.only(left: 44),
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      _optionRow(widget.andAfterLabel,
                          selected: _andAfter,
                          onTap: () => setState(() => _andAfter = true)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              NumericKeypad(
                onKey: (k) => setState(
                    () => _expr = _expr.pressDigit(k, maxDecimals: _precision)),
                onBackspace: () => setState(() => _expr = _expr.backspace()),
                onOperator: (op) =>
                    setState(() => _expr = _expr.pressOperator(op)),
                onEquals: () =>
                    setState(() => _expr = _expr.evaluated(_precision)),
                canResolve: _expr.canResolve(_precision),
              ),
              const SizedBox(height: Insets.md),
            ],
          ),
        ),
      ),
    );
  }

  /// One 48 pt radio row: a 20 pt ring, filled with a 10 pt dot when selected.
  Widget _optionRow(String label,
      {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 14.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
