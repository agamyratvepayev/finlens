import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/quick_add_sheet.dart';
import 'archive_screen.dart';
import 'edit_budget_screen.dart';
import 'edit_goal_screen.dart';
import 'edit_task_screen.dart';

/// Spec 5 — the forward-looking module. Three tabs, each answering its own
/// question in its own summary header (spec 6.2, "Tek özet kuralı").
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            title: 'Planner',
            onAdd: () => showQuickAdd(
              context,
              type: switch (_tab) {
                1 => QuickAddType.newGoal,
                2 => QuickAddType.newTask,
                _ => QuickAddType.expense,
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 22),
              color: AppColors.textPrimary,
              // Spec 5.8 — Archive lives behind the ••• menu, never a tab.
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
            ),
          ),
          _monthBar(store),
          _summary(store),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: UnderlineTabs(
              labels: const ['Budgets', 'Goals', 'Schedule'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              1 => _GoalsTab(store: store),
              2 => _ScheduleTab(store: store),
              _ => _BudgetsTab(store: store),
            },
          ),
        ],
      ),
    );
  }

  Widget _monthBar(AppStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: Row(
        children: [
          Text(
            monthYearLong(store.period),
            style: AppText.rowTitle.copyWith(fontSize: 15),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => store.shiftPeriod(-1),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => store.shiftPeriod(1),
          ),
        ],
      ),
    );
  }

  Widget _summary(AppStore store) => switch (_tab) {
        1 => _GoalsSummary(store: store),
        2 => _ScheduleSummary(store: store),
        _ => _BudgetSummary(store: store),
      };
}

// ── 5.1 Budgets ─────────────────────────────────────────────────────────────

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final left = store.leftToSpend;
    final spent = store.totalSpentAgainstBudget;
    final budget = store.totalBudget;
    final ratio = budget <= 0 ? 0.0 : spent / budget;
    final overspend = store.projectedOverspend;

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
          Text('Left to spend', style: AppText.label),
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
                    left,
                    style: AppText.hero.copyWith(fontSize: 32),
                    color: left < 0 ? AppColors.negative : null,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text('of ${money(budget)} budget', style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.md),
          // Spec 5.1 — the pace marker is what turns a percentage into a
          // judgement: fill to the right of the line means overspending.
          ProgressBar(
            value: ratio,
            color: ratio > 1
                ? AppColors.negative
                : (ratio > 0.8 ? AppColors.warning : AppColors.positive),
            paceMarker: store.monthProgress,
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                '${percent(ratio)} spent · day ${store.dayOfMonth} of '
                '${store.daysInPeriod}',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              const Spacer(),
              Container(width: 2, height: 10, color: AppColors.textPrimary),
              const SizedBox(width: 5),
              Text(
                'where you should be',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          if (overspend > 0) ...[
            const SizedBox(height: Insets.md),
            NoticeBanner(
              margin: EdgeInsets.zero,
              text: 'At this pace you\'ll overspend by ${money(overspend)} '
                  'this month.',
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetsTab extends StatelessWidget {
  const _BudgetsTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final budgets = store.budgetedCategories;

    if (budgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.donut_small_rounded,
          title: 'No budgets yet',
          message:
              'Give a category a monthly limit and it will show up here.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        SectionLabel(
          'Expense budgets',
          trailing: Text(
            '${money(store.totalSpentAgainstBudget)} / '
            '${money(store.totalBudget)}',
            style: AppText.label.copyWith(color: AppColors.textSecondary),
          ),
        ),
        for (final c in budgets)
          _BudgetRow(store: store, category: c),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.store, required this.category});

  final AppStore store;
  final Category category;

  @override
  Widget build(BuildContext context) {
    final spent = store.spentInCategory(category.id, store.period);
    final limit = category.effectiveLimit ?? 0;
    final ratio = limit <= 0 ? 0.0 : spent / limit;

    // Spec 5.1 — <80% green, 80–100% amber with ⚠, >100% red plus an
    // "$X over budget" line. The bar itself never exceeds 100%.
    final over = ratio > 1;
    final warn = !over && ratio >= category.warnThreshold;
    final color = over
        ? AppColors.negative
        : (warn ? AppColors.warning : AppColors.positive);

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
              builder: (_) => EditBudgetScreen(categoryId: category.id),
            ),
          ),
          // Spec 5.1 — long-press opens this category's entries in the Ledger.
          onLongPress: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${category.name}: '
                    '${store.txnCountForCategory(category.id)} entries'),
              ),
            );
          },
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
                ProgressBar(value: ratio, color: color),
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
                if (category.budgetRollover && category.rolloverAmount > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${money(category.rolloverAmount)} rolled over',
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
          Text('Saved toward goals', style: AppText.label),
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
              Text('of ${money(target)} target', style: AppText.caption),
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
          title: 'No goals yet',
          message: 'Set a target and FinLens works out the monthly pace.',
          action: FilledButton.icon(
            onPressed: () =>
                showQuickAdd(context, type: QuickAddType.newGoal),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New goal'),
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
            SectionLabel(type.sectionTitle),
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

    final subtitle = goal.isComplete
        ? 'Complete · ready to archive'
        : goal.targetDate == null
            ? 'No target date set'
            : '${monthYear(goal.targetDate!)} · ${money(monthly ?? 0)}/mo needed';

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
                  'Coming in',
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
                  'Going out',
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
              text: '${overdue.length} payment'
                  '${overdue.length == 1 ? '' : 's'} overdue · '
                  '${money(store.overdueAmount)}',
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
    final sections = <(String, List<Task>)>[
      ('Overdue', store.overdueTasks),
      ('This week', store.thisWeekTasks),
      ('Later this month', store.laterTasks),
    ].where((s) => s.$2.isNotEmpty).toList();

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.event_available_rounded,
          title: 'Nothing scheduled',
          message: 'Bills, salaries and subscriptions you plan will land here.',
          action: FilledButton.icon(
            onPressed: () =>
                showQuickAdd(context, type: QuickAddType.newTask),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New task'),
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
        ? '${dayMonth(task.dueDate)} · ${dueLabel(days)}'
        : '${dayMonth(task.dueDate)}${task.isRecurring ? '' : ' · ${dueLabel(days)}'}';

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
                          task.repeats.label.toLowerCase(),
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
              '${task.isRecurring ? ' · next ${dayMonth(task.dueDate)}' : ''}',
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
