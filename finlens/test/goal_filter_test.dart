import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/widgets/goal_scope_sheet.dart';
import 'package:finlens/l10n/app_localizations_en.dart';

/// The Goals-tab header filter (Planner §1). Store-level: the three counts, the
/// filtered getters, and the scope-control label for each of the five §1.1
/// cases. Sorting is asserted unchanged; the filter only removes rows.
void main() {
  final created = DateTime(2026, 1, 1);

  Account account(String id, AccountGroup group, double start) => Account(
        id: id,
        name: id,
        group: group,
        currency: 'USD',
        startingBalance: start,
      );

  // No target date → never "behind", so an available source is always on track;
  // an unavailable (archived) source always needs attention. Two clean levers.
  Goal goal(String id, String accId, double target) => Goal(
        id: id,
        name: id,
        source: GoalSource.account(accId),
        targetAmount: target,
        createdAt: created,
      );

  AppStore storeWith({
    List<Account> accounts = const [],
    List<Goal> goals = const [],
  }) =>
      AppStore(
        accounts: accounts,
        categories: const [],
        txns: const [],
        goals: goals,
        tasks: const [],
      );

  // ── goalFilterCounts ────────────────────────────────────────────────────────

  group('goalFilterCounts', () {
    test('splits five goals, an archived source counting as needs-attention',
        () {
      final accs = [
        for (final id in ['a1', 'a2', 'a3', 'gone1', 'gone2'])
          account(id, AccountGroup.spendable, 0),
      ];
      final store = storeWith(
        accounts: accs,
        goals: [
          goal('g1', 'a1', 1000),
          goal('g2', 'a2', 1000),
          goal('g3', 'a3', 1000),
          goal('g4', 'gone1', 1000),
          goal('g5', 'gone2', 1000),
        ],
      );
      // Archive two sources — the goals stay, but sourceAvailable flips false.
      accs[3].archived = true;
      accs[4].archived = true;

      final c = store.goalFilterCounts();
      expect(c.all, 5);
      expect(c.needsAttention, 2);
      expect(c.onTrack, 3);
      // The invariant the sheet relies on.
      expect(c.needsAttention + c.onTrack, c.all);
    });

    test('an empty goal list counts zero on every bucket', () {
      final c = storeWith().goalFilterCounts();
      expect(c.all, 0);
      expect(c.needsAttention, 0);
      expect(c.onTrack, 0);
    });
  });

  // ── sortedGoalsInSection(filter:) ─────────────────────────────────────────────

  group('sortedGoalsInSection under a filter', () {
    test('removes non-matching goals, order of the rest unchanged', () {
      final accs = [
        account('a1', AccountGroup.spendable, 0),
        account('a2', AccountGroup.spendable, 0),
        account('gone', AccountGroup.spendable, 0),
      ];
      final store = storeWith(
        accounts: accs,
        goals: [
          goal('on1', 'a1', 1000),
          goal('on2', 'a2', 1000),
          goal('attn', 'gone', 1000),
        ],
      );
      accs[2].archived = true; // 'attn' now needs attention

      final unfiltered = store.sortedGoalsInSection(GoalSection.saving);
      // Needs-attention sorts first, so 'attn' leads the unfiltered list.
      expect(unfiltered.first.id, 'attn');

      // On-track filter = unfiltered minus the attention goals, same order.
      final onTrack = store.sortedGoalsInSection(GoalSection.saving,
          filter: GoalFilter.onTrack);
      final expected = unfiltered
          .where((g) => !store.goalMetrics(g).needsAttention)
          .map((g) => g.id)
          .toList();
      expect(onTrack.map((g) => g.id).toList(), expected);

      // Needs-attention filter keeps only 'attn'.
      final needs = store.sortedGoalsInSection(GoalSection.saving,
          filter: GoalFilter.needsAttention);
      expect(needs.map((g) => g.id).toList(), ['attn']);
    });
  });

  // ── goalSectionSums(filter:) ──────────────────────────────────────────────────

  group('goalSectionSums under a filter', () {
    test('sums only the matching goals', () {
      final accs = [
        account('a1', AccountGroup.spendable, 500), // on-track goal's balance
        account('gone', AccountGroup.spendable, 800), // attention goal's balance
      ];
      final store = storeWith(
        accounts: accs,
        goals: [
          goal('on', 'a1', 1000),
          goal('attn', 'gone', 2000),
        ],
      );
      accs[1].archived = true;

      final all = store.goalSectionSums(GoalSection.saving);
      expect(all.current, 1300);
      expect(all.target, 3000);

      final onTrack =
          store.goalSectionSums(GoalSection.saving, filter: GoalFilter.onTrack);
      expect(onTrack.current, 500);
      expect(onTrack.target, 1000);

      final needs = store.goalSectionSums(GoalSection.saving,
          filter: GoalFilter.needsAttention);
      expect(needs.current, 800);
      expect(needs.target, 2000);
    });
  });

  // ── activeGoalSections(filter:) ───────────────────────────────────────────────

  group('activeGoalSections under a filter', () {
    test('drops a section whose goals all filter out', () {
      final accs = [
        account('sav', AccountGroup.spendable, 0), // SAVING, on track
        account('card', AccountGroup.creditCards, 0), // PAYING OFF, archived
      ];
      final store = storeWith(
        accounts: accs,
        goals: [
          goal('gs', 'sav', 1000),
          goal('gp', 'card', 0),
        ],
      );
      accs[1].archived = true; // 'gp' needs attention, section still payingOff

      expect(store.activeGoalSections(),
          [GoalSection.saving, GoalSection.payingOff]);
      expect(
          store.activeGoalSections(filter: GoalFilter.onTrack),
          [GoalSection.saving]);
      expect(
          store.activeGoalSections(filter: GoalFilter.needsAttention),
          [GoalSection.payingOff]);
    });
  });

  // ── goalScopeLabel — the five §1.1 cases ──────────────────────────────────────

  group('goalScopeLabel', () {
    final l = AppLocalizationsEn();

    test('all filter, some need attention', () {
      expect(
        goalScopeLabel(
            l, GoalFilter.all, (all: 5, needsAttention: 3, onTrack: 2)),
        '5 goals · 3 need attention',
      );
    });

    test('all filter, none need attention', () {
      expect(
        goalScopeLabel(
            l, GoalFilter.all, (all: 4, needsAttention: 0, onTrack: 4)),
        '4 goals · all on track',
      );
    });

    test('all filter, exactly one goal — singular, no count on the clause', () {
      expect(
        goalScopeLabel(
            l, GoalFilter.all, (all: 1, needsAttention: 1, onTrack: 0)),
        '1 goal · needs attention',
      );
      expect(
        goalScopeLabel(
            l, GoalFilter.all, (all: 1, needsAttention: 0, onTrack: 1)),
        '1 goal · on track',
      );
    });

    test('needs-attention filter reads m of n', () {
      expect(
        goalScopeLabel(l, GoalFilter.needsAttention,
            (all: 5, needsAttention: 3, onTrack: 2)),
        'Needs attention · 3 of 5',
      );
    });

    test('on-track filter reads k of n', () {
      expect(
        goalScopeLabel(
            l, GoalFilter.onTrack, (all: 5, needsAttention: 3, onTrack: 2)),
        'On track · 2 of 5',
      );
    });
  });
}
