import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../ledger_scope.dart';

/// One 44px row carrying the date range, both direction totals, and the
/// direction filter.
///
/// The words IN and OUT are not shown — the arrow and the colour already state
/// direction, and in a single row those characters are the difference between
/// fitting and not. The arrows are direction glyphs, not signs: they survived
/// the change that stripped +/− from the amounts, and they are the chip's only
/// non-colour cue.
///
/// Order is load-bearing regardless: money-in is always the left figure and
/// money-out always the right, and neither slot collapses at zero.
class PeriodRow extends StatelessWidget {
  const PeriodRow({
    super.key,
    required this.range,
    required this.totalIn,
    required this.totalOut,
    required this.filter,
    required this.onStep,
    required this.onPickRange,
    required this.onFilter,
    this.highlighted = false,
  });

  final DateRange range;
  final double totalIn;
  final double totalOut;

  /// Tinted while the period sheet is open (spec §4).
  final bool highlighted;

  /// Null means unfiltered — neither figure active *is* All, so there is no
  /// separate All cell and no clear button.
  final FlowKind? filter;

  final ValueChanged<int> onStep;
  final VoidCallback onPickRange;
  final ValueChanged<FlowKind> onFilter;

  @override
  Widget build(BuildContext context) {
    final today = AppStore.today;
    // A ledger does not look forward.
    final canForward = range.end.isBefore(DateTime(today.year, today.month, today.day));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: highlighted
            ? Color.alphaBlend(
                AppColors.tint(AppColors.accent, 0.16), AppColors.fieldCard)
            : AppColors.fieldCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Expanded rather than a Spacer between the two groups: a Spacer is a
          // flex child, so it would split the free space with the label's own
          // Flexible and the label would start ellipsising while the row still
          // had room — and the unclaimed remainder would land after the figures,
          // which is the gap this is meant to close. Handing the navigation
          // group everything the figures do not need pins the figures to the
          // trailing edge and keeps truncation the last resort it should be.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Arrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => onStep(-1),
                ),
                Flexible(
                  child: Semantics(
                    button: true,
                    label: 'Period, ${range.label(today, AppLocalizations.of(context))}',
                    child: InkWell(
                      onTap: onPickRange,
                      borderRadius: BorderRadius.circular(7),
                      child: ConstrainedBox(
                        // The label is a tap target in its own right.
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  range.label(today, AppLocalizations.of(context)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              // Marks the label as tappable (opens the sheet).
                              const Text(
                                '▾',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1,
                                  color: AppColors.accentLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Arrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: canForward ? () => onStep(1) : null,
                ),
              ],
            ),
          ),
          // The pair travels as one unit, so the gap between the two figures is
          // set here and is unaffected by whatever the row does around it.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Figure(
                amount: totalIn,
                kind: FlowKind.inflow,
                active: filter == FlowKind.inflow,
                onTap: () => onFilter(FlowKind.inflow),
              ),
              const SizedBox(width: 4),
              _Figure(
                amount: totalOut,
                kind: FlowKind.outflow,
                active: filter == FlowKind.outflow,
                onTap: () => onFilter(FlowKind.outflow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          icon,
          size: 14,
          color: enabled
              ? AppColors.textSecondary
              : AppColors.stepperDisabled,
        ),
      ),
    );
  }
}

/// A direction total that doubles as the filter for that direction.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.amount,
    required this.kind,
    required this.active,
    required this.onTap,
  });

  final double amount;
  final FlowKind kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIn = kind == FlowKind.inflow;
    // The inactive figure keeps full contrast: filtering to one direction must
    // never hide the other.
    final colour = isIn
        ? AppColors.positive
        : (active ? AppColors.negative : AppColors.amountChildNeg);

    return Semantics(
      button: true,
      selected: active,
      label: '${isIn ? AppLocalizations.of(context).ldgMoneyIn : AppLocalizations.of(context).ldgMoneyOut}, '
          '${money(amount, signless: true, masked: StoreScope.of(context).masked)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? (isIn
                    ? AppColors.positive.withValues(alpha: 0.15)
                    : AppColors.negative.withValues(alpha: 0.14))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 11,
                  color: colour,
                ),
                const SizedBox(width: 5),
                // Full form ($6,100), never abbreviated and never shrunk — the
                // label truncates first, the figures hold their ground (spec 3b).
                Text(
                  money(amount,
                      signless: true, masked: StoreScope.of(context).masked),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: colour,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
