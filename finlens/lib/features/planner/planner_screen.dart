import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_header.dart' show HorizontalSectionSwipe;
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/quick_add_sheet.dart';
import 'archive_screen.dart';
import 'budget_detail_screen.dart';
import 'edit_budget_screen.dart';
import 'edit_goal_screen.dart';
import 'edit_task_screen.dart';
import 'widgets/month_picker_sheet.dart';

/// Spec 5 — the forward-looking module. Three tabs, each answering its own
/// question in its own summary header (spec 6.2, "Tek özet kuralı").
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _tab = 0;

  /// Planner's own month — never `store.period`. Stepping it leaves Ledger and
  /// Insight untouched (spec 5.1: Planner stops driving the global period).
  late DateTime _month =
      DateTime(AppStore.today.year, AppStore.today.month);

  void _stepTab(int delta) =>
      setState(() => _tab = (_tab + delta + 3) % 3);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Row 1 — the period is the title. Budgets shows the month control;
          // Goals and Schedule have no scope to set, so the slot is empty.
          ScreenHeader(
            titleWidget: _tab == 0
                ? _MonthControl(
                    month: _month,
                    onTap: () => showPlannerMonthPicker(
                      context,
                      initial: _month,
                      onPick: (m) => setState(() => _month = m),
                    ),
                  )
                : const SizedBox.shrink(),
            onAdd: () => showQuickAdd(
              context,
              type: switch (_tab) {
                1 => QuickAddType.newGoal,
                2 => QuickAddType.newTask,
                _ => QuickAddType.expense,
              },
            ),
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.more_horiz_rounded, size: 22),
              color: AppColors.textPrimary,
              // Spec 5.8 — Archive lives behind the ••• menu, never a tab.
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
            ),
          ),
          // Row 2 — full-width tabs, now above the summary.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              0,
              Insets.gutter,
              Insets.md,
            ),
            child: UnderlineTabs(
              labels: [AppLocalizations.of(context).plTabBudgets, AppLocalizations.of(context).plTabGoals, AppLocalizations.of(context).plTabSchedule],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          // Row 3 + content — swipe anywhere below the tabs to change tab.
          Expanded(
            child: HorizontalSectionSwipe(
              onNext: () => _stepTab(1),
              onPrevious: () => _stepTab(-1),
              child: Column(
                children: [
                  _summary(store),
                  Expanded(child: _content(store)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(AppStore store) => switch (_tab) {
        1 => _GoalsSummary(store: store),
        2 => _ScheduleSummary(store: store),
        _ => _BudgetSummary(store: store, month: _month),
      };

  Widget _content(AppStore store) => switch (_tab) {
        1 => _GoalsTab(store: store),
        2 => _ScheduleTab(store: store),
        _ => _BudgetsTab(store: store, month: _month),
      };
}

/// Row 1's month control on the Budgets tab — a title-weight `August 2026 ⌄`
/// that opens the Planner month picker. Scales down rather than clipping so the
/// three controls beside it keep their size at 320 pt (spec 5.1).
class _MonthControl extends StatelessWidget {
  const _MonthControl({required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
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
                    monthYearLong(month, AppLocalizations.of(context)),
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
    );
  }
}

// ── 5.1 Budgets ─────────────────────────────────────────────────────────────

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.store, required this.month});

  final AppStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final budget = store.totalBudget;
    final hasBudget = budget > 0;
    final budgeted = store.budgetedSpend(month);
    final unbudgeted = store.unbudgetedSpend(month);
    final spent = budgeted + unbudgeted;
    // Left = budget − all spend (budgeted + unbudgeted). Negative keeps its
    // minus sign: that sign means "below zero", not "money out" (spec 5.2).
    final left = store.leftThisMonth(month);
    final ratio = hasBudget ? spent / budget : 0.0;
    final solidFrac = hasBudget ? budgeted / budget : 0.0;
    final hatchFrac = hasBudget ? unbudgeted / budget : 0.0;
    final isCurrent = store.isCurrentMonth(month);
    final showUnbudgeted = hasBudget && unbudgeted > 0;

    const noteStyle =
        TextStyle(fontSize: 11, color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context).plLeftThisMonth.toUpperCase(),
                  style: AppText.label),
              const Spacer(),
              // Neutral grey, never amber: spending outside a budget is a fact,
              // not a warning (spec 5.2).
              if (showUnbudgeted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(
                      unbudgeted,
                      style: noteStyle,
                      color: AppColors.textSecondary,
                    ),
                    Text(' ${AppLocalizations.of(context).plUnbudgeted}',
                        style: noteStyle),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    hasBudget ? left : 0,
                    style: AppText.hero.copyWith(fontSize: 32),
                    color:
                        (hasBudget && left < 0) ? AppColors.negative : null,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(' ${AppLocalizations.of(context).plOf} ', style: AppText.caption),
              AmountText(budget, style: AppText.caption),
              Text(' ${AppLocalizations.of(context).plBudgetWord}',
                  style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.md),
          // Solid = budgeted share; hatch = unbudgeted share, drawn right after
          // it. Both clamp inside 100 % (spec 5.2); over-budget is announced by
          // the figure going negative, not by the bar.
          ProgressBar(
            value: solidFrac,
            hatchValue: showUnbudgeted ? hatchFrac : null,
            color: ratio > 1
                ? AppColors.negative
                : (ratio > 0.8 ? AppColors.warning : AppColors.positive),
            paceMarker: isCurrent ? store.monthProgressFor(month) : null,
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                isCurrent
                    ? '${percent(ratio, decimals: 0)} spent · day '
                        '${store.dayOfMonthFor(month)} of '
                        '${store.daysInMonthOf(month)}'
                    : '${percent(ratio, decimals: 0)} spent',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              // Pace marker legend — only the summary bar is labelled; a closed
              // or future month has no pace to keep, so it is hidden (spec 5.2).
              if (isCurrent) ...[
                const Spacer(),
                Container(width: 2, height: 10, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).plPace, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetsTab extends StatelessWidget {
  const _BudgetsTab({required this.store, required this.month});

  final AppStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final budgets = store.budgetedCategories;
    final unbudgeted = store.unbudgetedSpendingCategories(month);

    if (budgets.isEmpty && unbudgeted.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.donut_small_rounded,
          title: AppLocalizations.of(context).plNoBudgetsYet,
          message: AppLocalizations.of(context).plNoBudgetsMsg,
        ),
      );
    }

    // Over-limit categories first, then the rest in their existing order.
    bool over(Category c) =>
        store.spentInCategory(c.id, month) > (c.effectiveLimit ?? 0);
    final ordered = [
      ...budgets.where(over),
      ...budgets.where((c) => !over(c)),
    ];

    final totalLabelStyle =
        AppText.label.copyWith(color: AppColors.textSecondary);

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        if (budgets.isNotEmpty) ...[
          SectionLabel(
            AppLocalizations.of(context).plBudgeted,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountText(store.budgetedSpend(month), style: totalLabelStyle),
                Text(' / ', style: totalLabelStyle),
                AmountText(store.totalBudget, style: totalLabelStyle),
              ],
            ),
          ),
          for (final c in ordered)
            _BudgetRow(store: store, category: c, month: month),
        ],
        if (unbudgeted.isNotEmpty)
          _NoBudgetSection(store: store, month: month, categories: unbudgeted),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.store,
    required this.category,
    required this.month,
  });

  final AppStore store;
  final Category category;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final spent = store.spentInCategory(category.id, month);
    final limit = category.effectiveLimit ?? 0;
    final ratio = limit <= 0 ? 0.0 : spent / limit;

    // Spec 5.1 — <80% green, 80–100% amber with ⚠, >100% red plus an
    // "$X over budget" line. The bar itself never exceeds 100%.
    final over = ratio > 1;
    final warn = !over && ratio >= category.warnThreshold;
    final color = over
        ? AppColors.negative
        : (warn ? AppColors.warning : AppColors.positive);
    final isCurrent = store.isCurrentMonth(month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          // Spec 5.6 — a tap opens the budget screen ("where did this go?"), not
          // the editor. A stray tap must not land on financial editing.
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) =>
                BudgetDetailScreen(categoryId: category.id, month: month),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              children: [
                Row(
                  children: [
                    IconTile(category.icon, color: category.color, size: 34),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              style: AppText.rowTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (warn)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: AppColors.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Row(
                      children: [
                        AmountText(spent, color: color),
                        Text(
                          ' / ${money(limit)}',
                          style: AppText.amount.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                // The same unlabelled pace marker as the summary bar — only the
                // summary is labelled (spec 5.1 §3).
                ProgressBar(
                  value: ratio,
                  color: color,
                  paceMarker:
                      isCurrent ? store.monthProgressFor(month) : null,
                ),
                if (over) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${money(spent - limit)} over budget',
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        color: AppColors.negative,
                      ),
                    ),
                  ),
                ],
                // Spec 5.1 §4 — the row already prints the effective limit
                // ($1,080), so the caption states the rollover, not a second
                // figure to double-count.
                if (category.budgetRollover && category.rolloverAmount > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'includes ${money(category.rolloverAmount)} rolled over',
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spec 5.1 §5 — expense categories with spending but no budget this month,
/// amount descending. Rendered only when non-empty: a category with nothing
/// spent has nothing uncovered.
class _NoBudgetSection extends StatelessWidget {
  const _NoBudgetSection({
    required this.store,
    required this.month,
    required this.categories,
  });

  final AppStore store;
  final DateTime month;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold(
      0.0,
      (sum, c) => sum + store.spentInCategory(c.id, month),
    );

    return Column(
      children: [
        SectionLabel(
          AppLocalizations.of(context).plNoBudgetSet,
          trailing: AmountText(
            total,
            style: AppText.label.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  _NoBudgetRow(
                    store: store,
                    category: categories[i],
                    month: month,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoBudgetRow extends StatelessWidget {
  const _NoBudgetRow({
    required this.store,
    required this.category,
    required this.month,
  });

  final AppStore store;
  final Category category;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Row(
        children: [
          IconTile(category.icon, color: category.color, size: 26),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              category.name,
              style: AppText.rowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Insets.sm),
          AmountText(store.spentInCategory(category.id, month)),
          const SizedBox(width: Insets.xs),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => EditBudgetScreen(categoryId: category.id),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentLight,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(AppLocalizations.of(context).plSet),
          ),
        ],
      ),
    );
  }
}

// ── 5.2 Goals ───────────────────────────────────────────────────────────────

class _GoalsSummary extends StatelessWidget {
  const _GoalsSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final saved = store.totalSaved;
    final target = store.totalGoalTarget;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).plSavedTowardGoals, style: AppText.label),
          const SizedBox(height: Insets.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    saved,
                    style: AppText.hero.copyWith(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(AppLocalizations.of(context).plOfTarget(money(target)),
                  style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.md),
          ProgressBar(
            value: target <= 0 ? 0 : saved / target,
            color: AppColors.goal,
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                '${store.goals.length} active goals',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              const Spacer(),
              Text(
                '${money(store.goalRemaining)} to go',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (store.goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.flag_rounded,
          title: AppLocalizations.of(context).plNoGoalsYet,
          message: AppLocalizations.of(context).plNoGoalsMsg,
          action: FilledButton.icon(
            onPressed: () =>
                showQuickAdd(context, type: QuickAddType.newGoal),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppLocalizations.of(context).plNewGoal),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        // Spec 5.2 — the three sections are derived from Goal.type, not from
        // three separate entities.
        for (final type in GoalType.values)
          if (store.goalsOfType(type).isNotEmpty) ...[
            SectionLabel(type.sectionTitle(AppLocalizations.of(context))),
            for (final g in store.goalsOfType(type))
              _GoalRow(store: store, goal: g),
          ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.store, required this.goal});

  final AppStore store;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final monthly = goal.monthlyNeeded;
    // Spec 5.2 — an unrealistic monthly requirement turns amber, an early
    // signal that the target date will not hold.
    final tooFast = monthly != null &&
        monthly > store.monthIncome(store.period) - store.monthExpense(store.period);

    final l = AppLocalizations.of(context);
    final subtitle = goal.isComplete
        ? l.plCompleteReady
        : goal.targetDate == null
            ? l.plNoTargetDate
            : '${monthYear(goal.targetDate!, l)} · ${money(monthly ?? 0)}${l.plMoNeeded}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => EditGoalScreen(goalId: goal.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              children: [
                Row(
                  children: [
                    IconTile(
                      goal.isComplete ? Icons.check_rounded : goal.icon,
                      color: goal.isComplete
                          ? AppColors.positive
                          : AppColors.goal,
                      size: 34,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: AppText.rowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppText.rowSubtitle.copyWith(
                              fontSize: 11.5,
                              color: tooFast
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Row(
                      children: [
                        AmountText(
                          goal.saved,
                          color: goal.isComplete ? AppColors.positive : null,
                        ),
                        Text(
                          ' / ${money(goal.targetAmount)}',
                          style: AppText.amount.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                ProgressBar(
                  value: goal.progress,
                  color: goal.isComplete ? AppColors.positive : AppColors.goal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 5.3 Schedule ────────────────────────────────────────────────────────────

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final overdue = store.overdueTasks;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).plComingIn,
                  style: AppText.body.copyWith(fontSize: 14),
                ),
              ),
              AmountText(
                store.comingIn,
                style: AppText.amountLarge,
                color: AppColors.positive,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).plGoingOut,
                  style: AppText.body.copyWith(fontSize: 14),
                ),
              ),
              AmountText(
                store.goingOut,
                style: AppText.amountLarge,
                color: AppColors.negative,
              ),
            ],
          ),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            NoticeBanner(
              margin: EdgeInsets.zero,
              color: AppColors.negative,
              icon: Icons.error_outline_rounded,
              text: AppLocalizations.of(context)
                  .plPaymentsOverdue(overdue.length, money(store.overdueAmount)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    // Spec 5.3 — one timeline ordered by date, never grouped by pay-in /
    // pay-out. Direction survives as icon colour and the ↻ recurring mark.
    final l = AppLocalizations.of(context);
    final sections = <(String, List<Task>)>[
      (l.schOverdue, store.overdueTasks),
      (l.schThisWeek, store.thisWeekTasks),
      (l.schLater, store.laterTasks),
    ].where((s) => s.$2.isNotEmpty).toList();

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.event_available_rounded,
          title: AppLocalizations.of(context).plNothingScheduled,
          message: AppLocalizations.of(context).plNothingSchedMsg,
          action: FilledButton.icon(
            onPressed: () =>
                showQuickAdd(context, type: QuickAddType.newTask),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppLocalizations.of(context).plNewTask),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        for (final (title, items) in sections) ...[
          SectionLabel(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const RowDivider(indent: Insets.md),
                    _TaskRow(store: store, task: items[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.store, required this.task});

  final AppStore store;
  final Task task;

  @override
  Widget build(BuildContext context) {
    final payOut = task.isPayOut;
    final color = payOut ? AppColors.negative : AppColors.positive;
    final days = task.daysUntilDue;
    final due = days < 0
        ? '${dayMonth(task.dueDate, AppLocalizations.of(context))} · ${dueLabel(days, AppLocalizations.of(context))}'
        : '${dayMonth(task.dueDate, AppLocalizations.of(context))}${task.isRecurring ? '' : ' · ${dueLabel(days, AppLocalizations.of(context))}'}';

    return InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => EditTaskScreen(taskId: task.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            IconTile(task.icon, color: color, size: 34),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppText.rowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          due,
                          style: AppText.rowSubtitle.copyWith(
                            fontSize: 11.5,
                            color: days < 0
                                ? AppColors.negative
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.isRecurring) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.repeat_rounded,
                          size: 11,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          task.repeats.label(AppLocalizations.of(context)).toLowerCase(),
                          style: AppText.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            AmountText(
              task.expectedAmount,
              showSign: true,
              color: color,
              forceDecimals: task.expectedAmount.abs() % 1 != 0,
            ),
            const SizedBox(width: Insets.md),
            // Spec 5.3 — the circle writes the real Ledger entry and closes
            // (or advances) the task.
            _MarkPaidButton(store: store, task: task),
          ],
        ),
      ),
    );
  }
}

class _MarkPaidButton extends StatelessWidget {
  const _MarkPaidButton({required this.store, required this.task});

  final AppStore store;
  final Task task;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        store.markTaskPaid(task);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${task.title} recorded in your Ledger'
              '${task.isRecurring ? ' · next ${dayMonth(task.dueDate, AppLocalizations.of(context))}' : ''}',
            ),
          ),
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceHigh, width: 1.5),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 15,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
