import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
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
import 'goal_detail_screen.dart';
import 'goal_presentation.dart';
import 'schedule_horizon.dart';
import 'schedule_tab.dart';
import 'widgets/month_picker_sheet.dart';

/// Spec 5 вЂ” the forward-looking module. Three tabs, each answering its own
/// question in its own summary header (spec 6.2, "Tek Г¶zet kuralД±").
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _tab = 0;

  /// Planner's own month вЂ” never `store.period`. Stepping it leaves Ledger and
  /// Insight untouched (spec 5.1: Planner stops driving the global period).
  late DateTime _month =
      DateTime(AppStore.today.year, AppStore.today.month);

  /// Schedule's own forward horizon (В§1). Its own state вЂ” it never reads or
  /// writes `_month`, `store.period` or anything global.
  ScheduleHorizon _horizon = ScheduleHorizon.fallback;

  void _stepTab(int delta) =>
      setState(() => _tab = (_tab + delta + 3) % 3);

  Future<void> _openHorizonSheet(BuildContext context) async {
    final today = AppStore.today;
    final store = StoreScope.read(context);
    final counts = store.horizonCounts([
      for (final p in ScheduleHorizon.presetOrder)
        ScheduleHorizon.rangeOf(p, today),
    ]);
    final picked = await showScheduleHorizonSheet(
      context,
      current: _horizon,
      counts: counts,
      hasOverdue: store.overdueTasks.isNotEmpty,
      today: today,
    );
    if (picked != null) setState(() => _horizon = picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Row 1 вЂ” the period is the title. Budgets shows the month control;
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
                : _tab == 2
                    ? ScheduleControl(
                        horizon: _horizon,
                        onTap: () => _openHorizonSheet(context),
                      )
                    : const SizedBox.shrink(),
            onAdd: () {
              // Goals use their own full-screen form (the WATCHING picker and
              // targetв†”date pair don't fit the numeric-hero sheet); the other
              // types stay on Quick Add.
              if (_tab == 1) {
                openGoalEditor(context);
                return;
              }
              showQuickAdd(
                context,
                type: _tab == 2
                    ? QuickAddType.newTask
                    : QuickAddType.expense,
              );
            },
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.more_horiz_rounded, size: 22),
              color: AppColors.textPrimary,
              // Spec 5.8 вЂ” Archive lives behind the вЂўвЂўвЂў menu, never a tab.
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              ),
            ),
          ),
          // Row 2 вЂ” a segmented control, above the summary (spec В§1). Margin 14
          // each side (not the 20 gutter) per the container spec.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, Insets.md),
            child: _SegmentedTabs(
              labels: [l.plTabBudgets, l.plTabGoals, l.plTabSchedule],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          // Row 3 + content вЂ” swipe anywhere below the tabs to change tab.
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
        // No summary block above the Goals sections (В§2): goals of mixed
        // direction have no meaningful sum, and a "1 needs attention" count is
        // answered by the first card. The cards are sections в†’ cards, nothing
        // else.
        1 => const SizedBox.shrink(),
        2 => ScheduleSummary(store: store, horizon: _horizon),
        _ => _BudgetSummary(store: store, month: _month),
      };

  Widget _content(AppStore store) => switch (_tab) {
        1 => _GoalsTab(store: store),
        2 => ScheduleTab(
            store: store,
            horizon: _horizon,
            onHorizonChange: (h) => setState(() => _horizon = h),
          ),
        _ => _BudgetsTab(store: store, month: _month),
      };
}

/// Row 1's month control on the Budgets tab вЂ” a title-weight `August 2026 вЊ„`
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

/// Row 2 вЂ” the tab selector, a raised-chip segmented control (spec В§1). The
/// container sits **darker** than the page so the contrast lives between the
/// container and the chip, not the chip and the page; the active chip is a
/// neutral grey, never accent-tinted вЂ” six coloured budget bars sit directly
/// below and a purple selection would compete with them.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  static const _container = Color(0xFF141416);
  static const _activeSegment = Color(0xFF43434A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _container,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: i == index ? _activeSegment : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          i == index ? FontWeight.w600 : FontWeight.w400,
                      color: i == index
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// в”Ђв”Ђ 5.1 Budgets в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.store, required this.month});

  final AppStore store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = store.totalBudget;
    final hasBudget = budget > 0;
    final budgeted = store.budgetedSpend(month);
    // Hero and caption describe the budget and nothing else: left = budget в€’
    // budgeted spend; the percentage is budgeted / budget. Unbudgeted spend sits
    // outside the budget and is surfaced by _NoBudgetSection at the foot of the
    // tab, never here (spec В§2). Over budget the hero shows the *overage* with
    // the word "over", not a negative figure.
    final left = store.leftThisMonth(month);
    final over = hasBudget && left < 0;
    final ratio = hasBudget ? budgeted / budget : 0.0;
    final isCurrent = store.isCurrentMonth(month);
    final monthGone = store.monthProgressFor(month);

    // The hero bar colours by PACE, not the spent ratio (spec В§2): budgeted
    // spend sitting far past an even burn is a real signal. Over budget в†’ red;
    // ahead of pace в†’ amber; on or behind pace в†’ green.
    final barColor = over
        ? AppColors.negative
        : (ratio > monthGone ? AppColors.warning : AppColors.positive);

    // "left of $3,800" / "over $3,800" as one localized run so it masks with the
    // privacy eye and stays grammatical; the word carries the meaning the bare
    // figure can't (spec В§2).
    final budgetStr = money(budget, masked: store.masked);
    final phrase =
        over ? l.plOverAmount(budgetStr) : l.plLeftOfAmount(budgetStr);
    final phraseColor = over ? AppColors.negative : AppColors.textSecondary;

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
          // One line: figure В· inline label. No caps label row вЂ” the segmented
          // control above already says "Budgets" (spec В§2). The figure+phrase
          // scale together in a FittedBox so "left of $3,800" can never
          // truncate. The hero describes the budget alone вЂ” no unbudgeted note.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AmountText(
                  hasBudget ? (over ? -left : left) : 0,
                  style: AppText.hero.copyWith(fontSize: 32, height: 1.0),
                  color: over ? AppColors.negative : null,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  phrase,
                  style: AppText.caption.copyWith(color: phraseColor),
                ),
              ],
            ),
          ),
          // Fix the gap at the box, not the margin (spec В§2): a 32pt figure's
          // line box carries ~9px of empty descender space; height:1.0 above
          // removes it, and a 9px top margin lands the visual gap at 10вЂ“12px.
          const SizedBox(height: 9),
          // Solid fill = budgeted / budget. It clamps inside 100 %; over-budget
          // is announced by the figure and the word, not by the bar (spec В§2).
          ProgressBar(
            value: ratio,
            color: barColor,
            paceMarker: isCurrent ? monthGone : null,
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              // "76% spent В· day 9 of 31" вЂ” the percentage is budgeted spend
              // only, and the day count (the same clock as the pace marker) is
              // shorter and more actionable than a percentage of the month, so
              // it survives narrow widths and large text (spec В§2/В§4). Takes all
              // the space the legend leaves вЂ” Expanded, not Flexible + Spacer вЂ”
              // so it fills the row and never clips with room to spare.
              Expanded(
                child: Text(
                  isCurrent
                      ? '${l.plPctSpent(percent(ratio, decimals: 0))} В· '
                          '${l.plDayOfMonth(store.dayOfMonthFor(month), store.daysInMonthOf(month))}'
                      : l.plPctSpent(percent(ratio, decimals: 0)),
                  style: AppText.caption.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Pace marker legend вЂ” only the summary bar is labelled; a closed
              // or future month has no pace to keep, so it is hidden (spec В§2).
              // Sits flush right at its intrinsic width, on the same line.
              if (isCurrent) ...[
                const SizedBox(width: Insets.sm),
                Container(width: 2, height: 10, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text(l.plPace,
                    style: AppText.caption.copyWith(fontSize: 11.5)),
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
          // One card holding every budgeted category, split by the standard 1pt
          // rule (the pattern the Balance list and Ledger day cards use) вЂ” no
          // per-budget card, no inter-card gap (spec В§3). The divider indents
          // past the icon column (13 pad + 30 icon + 12 gap).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (i > 0) const RowDivider(indent: 55),
                    _BudgetRow(store: store, category: ordered[i], month: month),
                  ],
                ],
              ),
            ),
          ),
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
    final l = AppLocalizations.of(context);
    final spent = store.spentInCategory(category.id, month);
    final limit = category.effectiveLimit ?? 0;
    final ratio = limit <= 0 ? 0.0 : spent / limit;

    // <80% green, 80вЂ“100% amber, >100% red вЂ” against effectiveLimit, byte
    // identical thresholds to before (spec В§4). Colour states the fact; the
    // glyph names the one state geometry can't; the marker gives context.
    final over = ratio > 1;
    final warn = !over && ratio >= category.warnThreshold;
    final color = over
        ? AppColors.negative
        : (warn ? AppColors.warning : AppColors.positive);
    final isCurrent = store.isCurrentMonth(month);

    // One sentence per row for the screen reader (spec В§4): near-limit has no
    // glyph, only colour + bar length, so the state must survive in semantics.
    // Masked amounts make fragmented per-widget semantics unreadable, so the
    // whole row reads as a single composed label.
    final spentStr = money(spent, masked: store.masked);
    final limitStr = money(limit, masked: store.masked);
    final semantics = over
        ? l.plSemRowOver(category.name, spentStr, limitStr)
        : warn
            ? l.plSemRowNear(category.name, spentStr, limitStr)
            : l.plSemRowNormal(category.name, spentStr, limitStr);

    return Semantics(
      container: true,
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          // A tap opens the budget screen ("where did this go?"), never the
          // editor вЂ” a stray tap must not land on financial editing (spec В§6).
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) =>
                  BudgetDetailScreen(categoryId: category.id, month: month),
            ),
          ),
          // padding 9 / 13; the bar lives in the text column's second line, so
          // it costs no extra row height вЂ” 48pt of pitch, not 80 (spec В§3).
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
            child: Row(
              children: [
                IconTile(category.icon, color: category.color, size: 30),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: AppText.rowTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // The one glyph: a red triangle, only over budget.
                          // Near-limit's signal is the bar's length; it needs
                          // none, and a second glyph would clutter the list
                          // (spec В§4).
                          if (over)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: AppColors.negative,
                              ),
                            ),
                          const SizedBox(width: Insets.sm),
                          // $560 / $500 вЂ” the amount pair sits on the name line,
                          // freeing the second line for a full-width bar. Prints
                          // the effectiveLimit the maths uses, so a rollover row
                          // shows $742 / $1,080 and needs no caption (spec В§4b).
                          AmountText(spent, color: color),
                          Text(
                            ' / $limitStr',
                            style: AppText.amount.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // 4pt so the fill reads clear of the 2pt pace marker; the
                      // same unlabelled marker as the summary bar (spec В§3).
                      ProgressBar(
                        value: ratio,
                        color: color,
                        height: 4,
                        paceMarker:
                            isCurrent ? store.monthProgressFor(month) : null,
                      ),
                    ],
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

/// Spec В§5 вЂ” expense categories with spending but no budget this month, amount
/// descending. Rendered only when non-empty: a category with nothing spent has
/// nothing uncovered. Collapsed by default, so it is noticed afresh each month
/// (next month's uncovered categories differ). The header carries the count and
/// total; the tap reveals *which* categories and the `Set` action.
class _NoBudgetSection extends StatefulWidget {
  const _NoBudgetSection({
    required this.store,
    required this.month,
    required this.categories,
  });

  final AppStore store;
  final DateTime month;
  final List<Category> categories;

  @override
  State<_NoBudgetSection> createState() => _NoBudgetSectionState();
}

class _NoBudgetSectionState extends State<_NoBudgetSection> {
  // Never persisted (spec В§5): the section opens collapsed every time, and
  // switching tabs disposes it, so returning shows it collapsed again.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = widget.categories.fold(
      0.0,
      (sum, c) => sum + widget.store.spentInCategory(c.id, widget.month),
    );
    final headerStyle = AppText.label.copyWith(color: AppColors.textSecondary);

    return Column(
      children: [
        // Header row вЂ” like a SectionLabel but tappable, with a rotating
        // chevron and the count В· total. The count is information while the
        // rows are hidden (Balance shows "4 accounts" for the same reason);
        // redundant but harmless once expanded, so the header keeps its shape.
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.lg,
              Insets.gutter,
              Insets.sm,
            ),
            child: Row(
              children: [
                Text(l.plNoBudgetSet.toUpperCase(), style: AppText.label),
                const SizedBox(width: Insets.xs),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(l.plCategoriesCount(widget.categories.length),
                    style: headerStyle),
                Text(' В· ', style: headerStyle),
                AmountText(total, style: headerStyle),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < widget.categories.length; i++) ...[
                    if (i > 0) const RowDivider(indent: Insets.md),
                    _NoBudgetRow(
                      store: widget.store,
                      category: widget.categories[i],
                      month: widget.month,
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

// в”Ђв”Ђ 5.2 Goals, rebuilt on real balances (В§1/В§2) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
//
// Sections в†’ cards, nothing else. Each section is derived from a goal's source
// (SAVING / PAYING OFF / WAITING ON / EARNING), renders only when non-empty,
// and carries its own total on the right вЂ” no goal count, no summary block.

class _GoalsTab extends StatelessWidget {
  const _GoalsTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = store.activeGoalSections;

    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.flag_rounded,
          title: l.plNoGoalsYet,
          message: l.plNoGoalsMsg,
          action: FilledButton.icon(
            onPressed: () => openGoalEditor(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.plNewGoal),
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
        for (final section in sections) ...[
          SectionLabel(
            section.label(l),
            trailing: Text(
              _sectionTotal(l, store, section),
              style: AppText.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          for (final g in store.sortedGoalsInSection(section))
            _GoalCard(store: store, goal: g),
        ],
      ],
    );
  }

  /// Each header carries its own total, formatted per section вЂ” `$2,000 of
  /// $3,700`, `$3,877 left`, `$3,000 owed` (В§2).
  String _sectionTotal(AppLocalizations l, AppStore store, GoalSection s) {
    final sums = store.goalSectionSums(s);
    switch (s) {
      case GoalSection.saving:
      case GoalSection.earning:
        return l.goalOfTotal(money(sums.current), money(sums.target));
      case GoalSection.payingOff:
        return l.goalLeftTotal(money(sums.current.abs()));
      case GoalSection.waitingOn:
        return l.goalOwedTotal(money(sums.current));
    }
  }
}

/// A goal card: icon В· name (no verb) В· verdict В· `current/target` В· bar. The
/// name carries no verb вЂ” the section header already says PAYING OFF вЂ” which is
/// what keeps both lines from wrapping at 375 pt. Tapping opens the detail
/// screen; it is never an edit affordance (В§2).
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.store, required this.goal});

  final AppStore store;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = store.goalMetrics(goal);
    final verdict = goalVerdict(l, goal, m);

    // One composed sentence for the screen reader вЂ” name, the amount pair, then
    // the verdict (which now carries the section's verb). ExcludeSemantics on
    // the visual tree keeps the two amounts and two Texts from reading twice.
    final amountPair =
        '${money(m.current, signless: true, masked: store.masked)}'
        ' / ${money(m.target)}';

    return Padding(
      // Tighter bottom margin than a budget card (В§1): 8, not Insets.md.
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 8),
      child: Semantics(
        container: true,
        button: true,
        label: '${goal.name}, $amountPair, ${verdict.text}',
        child: ExcludeSemantics(
          // AppCard is shared, so its 14pt radius (down from Radii.card) is
          // passed in from here, never edited on the widget itself.
          child: AppCard(
            radius: 14,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GoalDetailScreen(goalId: goal.id, backLabel: l.plTabGoals),
                ),
              ),
              // 8 vertical В· 12 horizontal (В§1): the two text lines and the bar
              // set the height, the padding is what's tuned вЂ” no fixed height,
              // so the card grows intact at large text scale.
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconTile(
                          m.reached
                              ? Icons.check_rounded
                              : store.goalIcon(goal),
                          color:
                              m.reached ? AppColors.positive : AppColors.goal,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and amount share a baseline; the verdict
                              // sits alone on the line below (В§2).
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.name,
                                      style: AppText.rowTitle
                                          .copyWith(height: 1.15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: Insets.sm),
                                  AmountText.balance(
                                    m.current,
                                    color: m.reached
                                        ? AppColors.positive
                                        : null,
                                  ),
                                  Text(
                                    ' / ${money(m.target)}',
                                    style: AppText.amount.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                verdict.text,
                                style: AppText.rowSubtitle.copyWith(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  color: goalVerdictColor(
                                      m, verdict.attention),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // The goal card's 3pt track with a thinner pace marker
                    // (В§6); the budget bars keep the 2pt/3pt default.
                    ProgressBar(
                      value: m.progress,
                      color: goalBarColor(m),
                      paceMarker: goalPaceFraction(m),
                      height: 3,
                      markerWidth: 1.5,
                      markerOverhang: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
