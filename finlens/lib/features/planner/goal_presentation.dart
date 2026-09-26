import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// Shared presentation for goals, rebuilt on real balances (§1). The Goals tab
/// card and the detail screen read the same verdict, pace marker and colours
/// from here so the two never disagree.
///
/// The verdict never quotes a monthly rate for a `WAITING ON` source: a
/// receivable is someone else's work, so there is no pace to keep (§1).
({String text, bool attention}) goalVerdict(
  AppLocalizations l,
  Goal goal,
  GoalMetrics m,
  DateTime today,
) {
  if (!m.sourceAvailable) {
    return (text: l.goalSourceUnavailable, attention: true);
  }

  if (m.reached) {
    if (m.targetDate != null) {
      final daysEarly = m.targetDate!.difference(today).inDays;
      if (daysEarly > 0) {
        return (text: l.goalReachedEarly(daysEarly), attention: false);
      }
    }
    return (text: l.goalReached, attention: false);
  }

  // WAITING ON — never a rate. "$X in" is what has been collected so far.
  if (m.section == GoalSection.waitingOn) {
    final collected = m.start - m.current;
    final tail = collected <= 0.005
        ? l.goalNothingYet
        : l.goalAmountIn(money(collected));
    if (m.targetDate == null) return (text: tail, attention: false);
    return (text: l.goalDueLine(dayMonth(m.targetDate!, l), tail), attention: false);
  }

  // No target date — the refill / funded case (§9). No pace, no rate. The
  // refill amount carries no fractional meaning, so it prints whole ($569).
  if (m.targetDate == null) {
    if (m.atTarget) return (text: l.goalFunded, attention: false);
    return (text: l.goalRefill(money(m.remaining, noDecimals: true)),
        attention: false);
  }

  // The rate reads in the goal's own period (task 066 §5c): the engine keeps
  // the monthly figure; the display converts and appends the period suffix. It
  // rounds *up*: paying the rounded-down figure lands short ($969.13 → $970).
  final rate =
      money(goalPaceRate(m.requiredRate ?? 0, goal.pace), roundUp: true);
  final per = l.goalPer(goal.pace.name);
  // Behind leads with the section's own verb ("pay" / "save" / "collect" /
  // "earn"), never a passive "needed" — the verb tells the user what to do.
  if (m.behind) {
    return (
      text: l.goalBehind(_rateVerb(l, m.section, rate, per)),
      attention: true
    );
  }

  final ahead =
      m.projectedEnd != null && m.projectedEnd!.isBefore(m.targetDate!);
  if (ahead) return (text: l.goalAhead(rate, per), attention: false);
  return (text: l.goalOnTrack(rate, per), attention: false);
}

/// A monthly rate converted to [pace]'s period (task 066 §5c). The verdict
/// engine computes monthly; every pace surface converts here so the two never
/// diverge.
double goalPaceRate(double monthly, GoalPace pace) => switch (pace) {
      GoalPace.day => monthly * 12 / 365,
      GoalPace.week => monthly * 12 / 52,
      GoalPace.month => monthly,
      GoalPace.quarter => monthly * 3,
      GoalPace.year => monthly * 12,
    };

/// The section's verb applied to a formatted period rate ("pay $970/mo"),
/// chosen from the goal's own section — never a string comparison on the label.
/// `waitingOn` never reaches this (it returns early with no rate), but it maps
/// to "collect" for completeness.
String _rateVerb(
        AppLocalizations l, GoalSection section, String rate, String per) =>
    switch (section) {
      GoalSection.saving => l.plGoalRateSave(rate, per),
      GoalSection.payingOff => l.plGoalRatePay(rate, per),
      GoalSection.waitingOn => l.plGoalRateCollect(rate, per),
      GoalSection.earning => l.plGoalRateEarn(rate, per),
    };

/// The verdict's colour: green when reached, amber when it needs attention,
/// muted otherwise. Colour states a fact; direction is carried elsewhere.
Color goalVerdictColor(GoalMetrics m, bool attention) {
  if (m.reached) return AppColors.positive;
  if (attention) return AppColors.warning;
  return AppColors.textSecondary;
}

/// The fill colour of a goal's progress bar.
Color goalBarColor(GoalMetrics m) =>
    m.reached ? AppColors.positive : AppColors.goal;

/// The pace marker fraction (elapsed / total of the goal's own span), or null
/// when there is no marker to draw — no target date, or a `WAITING ON` source
/// (§2). Unlabelled on the card.
double? goalPaceFraction(GoalMetrics m) {
  if (m.targetDate == null || m.section == GoalSection.waitingOn) return null;
  if (m.daysTotal <= 0) return null;
  return (m.daysElapsed / m.daysTotal).clamp(0.0, 1.0);
}
