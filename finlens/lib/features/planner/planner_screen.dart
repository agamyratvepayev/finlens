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
import 'widgets/goal_scope_sheet.dart';
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

  /// Goals' own header filter (§1). Sits beside `_month`: it is Goals' alone,
  /// survives a tab switch within the session, resets on relaunch (no
  /// persistence), and never touches `_month`, `store.period` or any other tab.
  GoalFilter _goalFilter = GoalFilter.all;

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

  Future<void> _openGoalScopeSheet(BuildContext context) async {
    final picked = await showGoalScopeSheet(
      context,
      current: _goalFilter,
      counts: StoreScope.read(context).goalFilterCounts(),
    );
    if (picked != null) setState(() => _goalFilter = picked);
  }

  /// Budgets is empty when there is nothing to cap and nothing uncovered — the
  /// exact test `_BudgetsTab` uses for its own empty branch (§1/§5), so the month
  /// control and the panel below it derive from one condition and cannot disagree
  /// (a month above a "no budgets" panel is exactly that disagreement).
  bool _budgetsEmpty(AppStore store) =>
      store.budgetedCategories.isEmpty &&
      store.unbudgetedSpendingCategories(_month).isEmpty;

  /// Row 1's leading control per tab. Budgets shows the month; Schedule shows
  /// the horizon; Goals shows the filter scope. Each slot collapses to empty when
  /// its own tab is empty (§1/§5) — a control that could only step from one empty
  /// view to another is not drawn.
  Widget _titleWidget(BuildContext context, AppStore store) => switch (_tab) {
        // Hidden with no budgeted and no unbudgeted-spending categories. A month
        // with spending but no budgets keeps the control — the NO BUDGET SET panel
        // renders and stepping the month is meaningful.
        0 => _budgetsEmpty(store)
            ? const SizedBox.shrink()
            : _MonthControl(
                month: _month,
                onTap: () => showPlannerMonthPicker(
                  context,
                  initial: _month,
                  onPick: (m) => setState(() => _month = m),
                ),
              ),
        // Hidden only with no tasks at all — the same test `_emptyState` fires on
        // (`openTasks.isEmpty`). Tasks that all fall past the horizon keep the
        // control: it is how `_nothingDue`'s own "next 3 months" link reaches them.
        2 => store.openTasks.isEmpty
            ? const SizedBox.shrink()
            : ScheduleControl(
                horizon: _horizon,
                onTap: () => _openHorizonSheet(context),
              ),
        _ => store.goals.isEmpty
            ? const SizedBox.shrink()
            : GoalScopeControl(
                filter: _goalFilter,
                counts: store.goalFilterCounts(),
                onTap: () => _openGoalScopeSheet(context),
              ),
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Row 1 вЂ” the period is the title. Budgets shows the month control,
          // Schedule the horizon, Goals the filter scope; only an empty goal
          // list leaves the slot empty (§1).
          ScreenHeader(
            titleWidget: _titleWidget(context, store),
            onAdd: () {
              // Each tab's + creates that tab's own thing (§5). Goals use their
              // own full-screen form (the WATCHING picker and targetв†”date pair
              // don't fit the numeric-hero sheet); Budgets and Schedule route
              // through Quick Add, which intercepts newBudget into the
              // category-first budget flow. Budgets no longer falls through to
              // an expense form.
              if (_tab == 1) {
                openGoalEditor(context);
                return;
              }
              showQuickAdd(
                context,
                type: _tab == 2
                    ? QuickAddType.newTask
                    : QuickAddType.newBudget,
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
        1 => _GoalsTab(
            store: store,
            filter: _goalFilter,
            onShowAll: () => setState(() => _goalFilter = GoalFilter.all),
          ),
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
      final l = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 56),
        child: EmptyState(
          icon: Icons.donut_small_rounded,
          title: l.plNoBudgetsYet,
          message: l.plNoBudgetsMsg,
          // The way out, matching New goal and New task (§2): same shape, colour
          // and icon size. Routes through the category-first budget flow — Quick
          // Add intercepts newBudget before the sheet builds — so this button and
          // this tab's + do the same thing (§2.1).
          action: FilledButton.icon(
            onPressed: () =>
                showQuickAdd(context, type: QuickAddType.newBudget),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.plNewBudget),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
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
          // Each budgeted category is its own card (spec §1), the way the Goals
          // tab next door renders a goal — separate AppCards at radius 14, 8pt
          // apart, no dividers anywhere. A budget is a standing commitment with
          // its own limit, history and detail screen, so it gets a goal's
          // standing, not a ledger row's. Each _BudgetRow carries its own gutter
          // padding and the 8pt inter-card gap, so the ordered list drops in raw.
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

    return Padding(
      // Own gutter padding + the 8pt inter-card gap (spec §1), exactly the
      // goal card's outer margin so the two tabs share a rhythm.
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 8),
      child: Semantics(
        container: true,
        button: true,
        label: semantics,
        child: ExcludeSemantics(
          // AppCard is shared, so its 14pt radius (down from Radii.card) is
          // passed in here, matching a goal card; a fuller radius reads too
          // round on a one-row card.
          child: AppCard(
            radius: 14,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              // A tap opens the budget detail ("where did this go?"), never the
              // editor — a stray tap must not land on financial editing (spec §6).
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BudgetDetailScreen(categoryId: category.id, month: month),
                ),
              ),
              // 8 top / 11 bottom / 12 sides. The bottom is 11, not the goal
              // card's 8: its last element is a 3pt bar over 8pt of air, ours is
              // a line of text whose descenders reach its box floor, so it needs
              // the extra 3pt to sit level beside a goal card at 56.5 (spec §3).
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 11),
                child: Row(
                  children: [
                    IconTile(category.icon, color: category.color, size: 30),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Line one: name, then the over-budget glyph, then the
                          // spent figure right-aligned so the figures form a
                          // column down the list. Explicit 1.15 line height
                          // matches the name to the amount box (spec §3).
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: AppText.rowTitle.copyWith(height: 1.15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // The one glyph: a red triangle, only over budget.
                              // Near-limit's signal is the bar's length; it needs
                              // none, and a second glyph would clutter the list
                              // (spec §4).
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
                              // White, not tinted: green here would read as money
                              // in, and the bar below already carries the three
                              // states (spec §4). Prints the spent magnitude; the
                              // effectiveLimit sits under it on line two.
                              AmountText(
                                spent,
                                style: AppText.amount.copyWith(height: 1.15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // Line two: the bar takes the width, the limit sits
                          // right-aligned directly under the spent figure — no
                          // "/" or "of", the shared right edge carries the
                          // relation (spec §2). The bar loses the limit's width
                          // plus this 10pt gap and is fine: a fill is
                          // proportional to whatever track it gets.
                          Row(
                            children: [
                              Expanded(
                                // 4pt so the fill reads clear of the pace marker;
                                // the same unlabelled marker as the summary bar.
                                child: ProgressBar(
                                  value: ratio,
                                  color: color,
                                  height: 4,
                                  paceMarker: isCurrent
                                      ? store.monthProgressFor(month)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // The goal card's denominator style: 11.5pt in
                              // textTertiary, its 1.15 height sets the line-two
                              // box (13.2) the bar centres in.
                              Text(
                                limitStr,
                                style: AppText.rowSubtitle.copyWith(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
  const _GoalsTab({
    required this.store,
    required this.filter,
    required this.onShowAll,
  });

  final AppStore store;
  final GoalFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // The real "no goals yet" state is unchanged — it owns the New goal button
    // and the header slot is empty above it (§5). It is keyed on the whole goal
    // list, never the filtered one.
    if (store.goals.isEmpty) {
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

    final sections = store.activeGoalSections(filter: filter);

    // The filter matched nothing — the user fixed the last goal in this scope
    // (§3.3). Name the filter and offer a way back; never the EmptyState, which
    // would falsely claim the user has no goals and offer a New goal button.
    if (sections.isEmpty) {
      return _EmptyFilterState(filter: filter, onShowAll: onShowAll);
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
          for (final g in store.sortedGoalsInSection(section, filter: filter))
            _GoalCard(store: store, goal: g),
        ],
      ],
    );
  }

  /// Each header carries its own total, formatted per section вЂ” `$2,000 of
  /// $3,700`, `$3,877 left`, `$3,000 owed` (В§2). The sums recompute over the
  /// visible goals under [filter], so a header never carries an unfiltered total
  /// above a filtered card (§3.2).
  String _sectionTotal(AppLocalizations l, AppStore store, GoalSection s) {
    final sums = store.goalSectionSums(s, filter: filter);
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

/// The filter matched no goal (§3.3) — a filter the user reached by fixing the
/// last goal in scope. One muted line naming the filter and a `Show all ›` back
/// to the unfiltered list. Never the tab's EmptyState, which would claim the
/// user has no goals at all.
class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.filter, required this.onShowAll});

  final GoalFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final message = filter == GoalFilter.needsAttention
        ? l.plGoalNoneNeed
        : l.plGoalNoneOnTrack;
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.rowSubtitle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentLight,
              visualDensity: VisualDensity.compact,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.plGoalShowAll),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
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
    // The figure the current amount is measured against: the target for a goal
    // that climbs (saving, earning), the original amount for one that pays down
    // (paying off, waiting on). Switched on the section, never a label string --
    // the rule _rateVerb follows. Rendered signless: it is a magnitude paired
    // with the signless balance above, and m.start is negative for a liability.
    final whole = switch (m.section) {
      GoalSection.saving || GoalSection.earning => m.target,
      GoalSection.payingOff || GoalSection.waitingOn => m.start,
    };
    final currentStr = money(m.current, signless: true);
    final wholeStr = money(whole, signless: true);
    // Omit the second figure when it would just repeat the first -- a waiting-on
    // goal with nothing collected (current == start) or a reached/funded one
    // (current == target). Compare the rendered strings, not the doubles, so two
    // figures a cent apart never print as an identical pair.
    final showWhole = wholeStr != currentStr;

    final maskedCurrent = money(m.current, signless: true, masked: store.masked);
    // The pair keeps a spoken "of" for the screen reader: two bare figures in
    // sequence say nothing about their relation, unlike the stacked visual (5).
    // Masking mirrors the visual -- the current amount masks, the whole does not.
    final amountPair =
        showWhole ? l.goalAmountOf(maskedCurrent, wholeStr) : maskedCurrent;

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
                        // Two columns top-aligned to each other, the whole block
                        // still centred against the icon by the outer Row. Left:
                        // name over verdict. Right: current amount over the
                        // figure it is measured against, right-aligned so the
                        // digits line up under one another with no connector.
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: AppText.rowTitle
                                          .copyWith(height: 1.15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                              const SizedBox(width: Insets.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Explicit 1.15 line height so this line box
                                  // equals the name's (rowTitle also at 1.15) --
                                  // without it the second lines drift a point.
                                  AmountText.balance(
                                    m.current,
                                    style: AppText.amount
                                        .copyWith(height: 1.15),
                                    color: m.reached
                                        ? AppColors.positive
                                        : null,
                                  ),
                                  if (showWhole) ...[
                                    const SizedBox(height: 1),
                                    // The reference figure: dimmer than the
                                    // verdict (tertiary, not secondary) and the
                                    // verdict's exact metrics so line two of each
                                    // column sits level.
                                    Text(
                                      wholeStr,
                                      style: AppText.rowSubtitle.copyWith(
                                        fontSize: 11.5,
                                        height: 1.15,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ],
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
