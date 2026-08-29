import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// The three header-filter counts (`AppStore.goalFilterCounts`), shared by the
/// control's label and the sheet's row counts (Planner §1/§2).
typedef GoalScopeCounts = ({int all, int needsAttention, int onTrack});

/// The label the Goals-tab scope control states for [filter] given [counts]
/// (Planner §1.1). Every branch is a whole localized message with placeholders —
/// the only choice made in Dart is *which* message, never string-building — so
/// `1 goal` can never render as `1 goals`, and the plural rides on the ARB.
String goalScopeLabel(
  AppLocalizations l,
  GoalFilter filter,
  GoalScopeCounts counts,
) {
  switch (filter) {
    case GoalFilter.needsAttention:
      return l.plGoalScopeNeeds(counts.needsAttention, counts.all);
    case GoalFilter.onTrack:
      return l.plGoalScopeOnTrack(counts.onTrack, counts.all);
    case GoalFilter.all:
      // The single-goal row drops the count on the second clause ("1 goal ·
      // needs attention"), so it can never be built from the plural messages.
      if (counts.all == 1) {
        return counts.needsAttention == 1
            ? l.plGoalScopeOneAttention
            : l.plGoalScopeOneOnTrack;
      }
      return counts.needsAttention > 0
          ? l.plGoalScopeAllSome(counts.all, counts.needsAttention)
          : l.plGoalScopeAllNone(counts.all);
  }
}

// ── The scope control (Row 1's leading slot on Goals) ───────────────────────

/// Row 1's Goals-tab scope control — same shape and type as Budgets'
/// `_MonthControl` and Schedule's `ScheduleControl` (18 pt · w700 · −0.3 ·
/// `textPrimary`, `keyboard_arrow_down_rounded` at 20 pt in `textSecondary`,
/// `FittedBox(scaleDown)` so it never clips at 320 pt) (Planner §1). It always
/// states the active scope, so a filtered list can never look like a list that
/// lost its goals. It shows counts, never money — the privacy eye leaves it be.
class GoalScopeControl extends StatelessWidget {
  const GoalScopeControl({
    super.key,
    required this.filter,
    required this.counts,
    required this.onTap,
  });

  final GoalFilter filter;
  final GoalScopeCounts counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = goalScopeLabel(l, filter, counts);
    // Colour carries none of this control's meaning, but the count does — so the
    // active scope is spoken as the button's value (Planner §4).
    return Semantics(
      container: true,
      button: true,
      label: l.plGoalFilterButton,
      value: label,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── The STATUS sheet (Planner §2) ───────────────────────────────────────────

/// Opens the Goals-tab filter sheet — the same row-based pattern as the
/// Schedule horizon sheet (`AppColors.surface`, `Radii.sheet` top corners, a
/// 36 × 5 `sheetGrabber`, rows at `Insets.gutter`/13 padding, a `check_rounded`
/// in `accentLight` on the active row, a dimmed non-selectable 0-count row).
/// Returns the chosen filter, or null on dismiss.
Future<GoalFilter?> showGoalScopeSheet(
  BuildContext context, {
  required GoalFilter current,
  required GoalScopeCounts counts,
}) {
  return showModalBottomSheet<GoalFilter>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GoalScopeSheet(current: current, counts: counts),
  );
}

class _GoalScopeSheet extends StatelessWidget {
  const _GoalScopeSheet({required this.current, required this.counts});

  final GoalFilter current;
  final GoalScopeCounts counts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.md),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, 0, Insets.gutter, Insets.sm),
              child: Text(l.plGoalStatus, style: AppText.label),
            ),
            _row(context, GoalFilter.all, l.plGoalFilterAll, counts.all),
            _row(context, GoalFilter.needsAttention, l.plGoalFilterNeeds,
                counts.needsAttention),
            _row(context, GoalFilter.onTrack, l.plGoalFilterOnTrack,
                counts.onTrack),
            // The one place that tells a user where finished goals went — always
            // shown (Planner §2).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
              child: Text(
                l.plGoalArchiveNote,
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    GoalFilter filter,
    String label,
    int count,
  ) {
    final l = AppLocalizations.of(context);
    final active = filter == current;
    // A 0-count row is dimmed and not selectable — this is what makes the
    // empty-filter state unreachable from the sheet (Planner §2).
    final enabled = count > 0;
    // Needs attention burns amber above zero; All and On track are always
    // secondary. The count colour follows the fact, not the row's enabled state.
    final countColor = filter == GoalFilter.needsAttention
        ? (count > 0 ? AppColors.warning : AppColors.textSecondary)
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: l.plGoalRowA11y(label, count),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? () => Navigator.of(context).pop(filter) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.gutter, vertical: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: active
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: AppColors.accentLight)
                      : null,
                ),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.rowTitle.copyWith(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                Text('$count', style: AppText.amount.copyWith(color: countColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
