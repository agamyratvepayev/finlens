import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/planner/goal_presentation.dart';
import 'package:finlens/l10n/app_localizations_en.dart';

/// Planner goal-card verdict (§4/§5): the required rate rounds *up* and drops
/// cents, and the "Behind" line leads with the section's own verb.
void main() {
  final l = AppLocalizationsEn();

  // A dummy goal — goalVerdict reads everything off the metrics, never the goal.
  final goal = Goal(
    id: 'g',
    name: 'G',
    source: const GoalSource.account('a'),
    targetAmount: 1000,
    createdAt: DateTime(2026, 1, 1),
  );

  GoalMetrics behind(GoalSection section) => GoalMetrics(
        section: section,
        start: 0,
        current: 100,
        target: 1000,
        targetDate: DateTime(2026, 12, 1),
        progress: 0.1,
        reached: false,
        atTarget: false,
        sourceAvailable: true,
        monthsElapsed: 2,
        monthsRemaining: 4,
        requiredRate: 969.13,
        actualRate: 10,
        projectedEnd: null, // null + a date to miss → behind.
        daysElapsed: 60,
        daysTotal: 180,
      );

  // ── §5 · the required-rate formatter ────────────────────────────────────────

  group('money rounds a required rate up and never shows cents', () {
    test('rounds up, not to nearest — \$969.13 becomes \$970', () {
      expect(money(969.13, roundUp: true), r'$970');
    });

    test('a bare cent still rounds a whole dollar up', () {
      expect(money(969.01, roundUp: true), r'$970');
    });

    test('an already-whole figure is unchanged', () {
      expect(money(970, roundUp: true), r'$970');
      expect(money(500, roundUp: true), r'$500');
    });

    test('noDecimals drops cents to the nearest whole — \$569.00 → \$569', () {
      expect(money(569, noDecimals: true), r'$569');
      expect(money(569.40, noDecimals: true), r'$569');
      expect(money(569.60, noDecimals: true), r'$570');
    });

    test('the default formatter still keeps cents on small amounts', () {
      expect(money(15.99), r'$15.99');
    });
  });

  // ── §4 · each section maps to its own verb ──────────────────────────────────

  group('the Behind verdict uses the section verb', () {
    test('SAVING → save', () {
      expect(goalVerdict(l, goal, behind(GoalSection.saving)).text,
          r'Behind · save $970/mo');
    });

    test('PAYING OFF → pay', () {
      expect(goalVerdict(l, goal, behind(GoalSection.payingOff)).text,
          r'Behind · pay $970/mo');
    });

    test('EARNING → earn', () {
      expect(goalVerdict(l, goal, behind(GoalSection.earning)).text,
          r'Behind · earn $970/mo');
    });

    test('the four verb keys are distinct and grammatical', () {
      expect(l.plGoalRateSave(r'$970'), r'save $970/mo');
      expect(l.plGoalRatePay(r'$970'), r'pay $970/mo');
      expect(l.plGoalRateCollect(r'$970'), r'collect $970/mo');
      expect(l.plGoalRateEarn(r'$970'), r'earn $970/mo');
    });

    test('WAITING ON never quotes a rate — no verb, no "Behind"', () {
      final text = goalVerdict(l, goal, behind(GoalSection.waitingOn)).text;
      expect(text, isNot(contains('collect')));
      expect(text, isNot(startsWith('Behind')));
    });
  });
}
