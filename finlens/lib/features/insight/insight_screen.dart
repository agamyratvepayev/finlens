import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';

/// Insight is named in the bottom navigation but has no screen spec in
/// v1.1. It is built here from the metrics the spec *does* define — left over
/// (2.1), spending by category (5.1) and goal performance (5.6/5.8) — so the
/// tab is honest rather than empty, and ready to be replaced when the module
/// is specified.
class InsightScreen extends StatelessWidget {
  const InsightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final income = store.monthIncome(store.period);
    final expense = store.monthExpense(store.period);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            title: l.insightTitle,
            onAdd: () => showQuickAdd(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    0,
                    Insets.gutter,
                    Insets.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${l.insightLeftOver} · ${monthYearLong(store.period, l)}',
                          style: AppText.label),
                      const SizedBox(height: Insets.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AmountText(
                          income - expense,
                          style: AppText.hero.copyWith(fontSize: 32),
                          color: income - expense < 0
                              ? AppColors.negative
                              : AppColors.positive,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        income <= 0
                            ? l.insightNoIncome
                            : l.insightKept(
                                percent(store.monthLeftOverFraction(store.period),
                                    decimals: 0),
                                money(income)),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                _spendingByCategory(store, l),
                _goalPerformance(store, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _spendingByCategory(AppStore store, AppLocalizations l) {
    final rows = <(Category, double)>[];
    for (final c in store.categoriesOfType(CategoryType.expense)) {
      final spent = store.spentInCategory(c.id, store.period);
      if (spent > 0) rows.add((c, spent));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    if (rows.isEmpty) return const SizedBox.shrink();
    final max = rows.first.$2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.insightWhereItWent),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              children: [
                for (final (category, spent) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconTile(
                              category.icon,
                              color: category.color,
                              size: 26,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Text(
                                category.name,
                                style: AppText.body.copyWith(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AmountText(spent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          value: max <= 0 ? 0 : spent / max,
                          color: category.color,
                          height: 5,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Spec 5.6 — "Mark as reached" writes completed_at and duration_months
  /// precisely so this section can exist.
  Widget _goalPerformance(AppStore store, AppLocalizations l) {
    final reached = store.archivedGoals
        .where((g) => g.status == GoalStatus.reached)
        .toList();
    final abandoned = store.archivedGoals
        .where((g) => g.status == GoalStatus.abandoned)
        .length;
    final finished = reached.length + abandoned;
    final rate = finished == 0 ? 0.0 : reached.length / finished;
    final avgMonths = reached.isEmpty
        ? 0
        : reached.fold(0, (sum, g) => sum + (g.durationMonths ?? 0)) ~/
            reached.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.insightGoalPerformance),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              children: [
                _Stat(
                  label: l.insightReached,
                  value: '${reached.length}',
                  color: AppColors.positive,
                ),
                _Stat(
                  label: l.insightSuccessRate,
                  value: finished == 0 ? '—' : percent(rate, decimals: 0),
                  color: AppColors.goal,
                ),
                _Stat(
                  label: l.insightAvgTime,
                  value: reached.isEmpty ? '—' : l.insightMonthsShort(avgMonths),
                  color: AppColors.info,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label),
          const SizedBox(height: Insets.xs),
          Text(
            value,
            style: AppText.amountLarge.copyWith(fontSize: 20, color: color),
          ),
        ],
      ),
    );
  }
}
