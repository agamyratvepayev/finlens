import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/amount_override_sheet.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/change_row.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/detail_row.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../core/utils/date_range.dart';
import '../balance/same_transactions_screen.dart';
import '../insight/category_detail_screen.dart';
import 'budget_actions.dart';
import 'edit_budget_screen.dart';

/// Spec 5.6 — the screen a budget card opens on a tap: "where did this $560
/// go?", the recurring question, not "change the limit", the rare one. Editing
/// the limit moves into the ••• menu here.
///
/// **The boundary with [CategoryDetailScreen] (spec §7):** this screen answers
/// "how did I do against the limit?" — it is month-locked, has a shared limit
/// line, and is meaningful only for budgeted expenses. The category detail
/// answers "how much did I spend each period?" — it follows Insight's window
/// (six weeks for a week window), works for income categories, and has no
/// reference line. The `6-month spending history ›` row bridges to it; the two
/// never disagree, because `spentInCategory` delegates to the same
/// `spentInCategoryWindow` the category detail reads.
class BudgetDetailScreen extends StatelessWidget {
  const BudgetDetailScreen({
    super.key,
    required this.categoryId,
    required this.month,
  });

  final String categoryId;

  /// The month the Planner was showing when the card was tapped — every figure
  /// on this screen is scoped to it.
  final DateTime month;

  /// Past months are neutral: [Category.monthlyBudget] has no history, so
  /// colouring an earlier month against today's limit would judge a limit that
  /// never existed then (spec 5.6).
  static const _pastMonth = Color(0xFF55555A);

  /// The shared limit line across the six-month rows (spec `#EBEBF5`).
  static const _limitLine = Color(0xFFEBEBF5);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final category = store.categoryById(categoryId);
    if (category == null) {
      // Removed while open — leave rather than show an empty shell.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final budget = store.monthlyBudgetForCategory(category.id);
    final monthlyBudget = budget?.limit ?? store.monthlyLimitOf(category) ?? 0;
    // The screen's month, not the global period (task 067.2 §1): a period's own
    // limit is read where the reader is looking.
    final effectiveLimit =
        budget == null ? 0.0 : store.budgetEffectiveLimit(budget, month);
    final spent = store.spentInCategory(category.id, month);
    final ratio = effectiveLimit <= 0 ? 0.0 : spent / effectiveLimit;
    final over = ratio > 1;
    final warn = !over && ratio >= store.warnThresholdOf(category);
    final color = over
        ? AppColors.negative
        : (warn ? AppColors.warning : AppColors.positive);
    final isCurrent = store.isCurrentMonth(month);
    final beforeCurrent = DateTime(month.year, month.month)
        .isBefore(DateTime(store.today.year, store.today.month));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _navBar(context, category),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _header(context, store, category, monthlyBudget, budget),
                  _thisMonth(
                    context,
                    store,
                    category,
                    budget: budget,
                    spent: spent,
                    ratio: ratio,
                    over: over,
                    effectiveLimit: effectiveLimit,
                    color: color,
                    isCurrent: isCurrent,
                    beforeCurrent: beforeCurrent,
                  ),
                  if (budget != null && !beforeCurrent)
                    _upcoming(context, store, category, budget),
                  if (budget != null && budget.note.isNotEmpty)
                    _note(context, budget.note),
                  _againstTheLimit(store, category, budget, monthlyBudget, color,
                      AppLocalizations.of(context)),
                  _spendingHistoryRow(context, AppLocalizations.of(context)),
                  _transactions(context, store, category),
                  _changes(context, store, category, budget),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens §4's sheet for [periodStart] of [budget], writing the period's own
  /// limit. Shared by the THIS MONTH card and every UPCOMING row.
  Future<void> _openPeriodSheet(
      BuildContext context, AppStore store, Budget budget, DateTime periodStart) {
    final l = AppLocalizations.of(context);
    final ps = DateTime(periodStart.year, periodStart.month, periodStart.day);
    final label = monthYearLong(ps, l);
    return showAmountOverrideSheet(
      context,
      title: label,
      initialMagnitude: store.budgetLimitFor(budget, ps),
      usualMagnitude: store.budgetUsualLimitFor(budget, ps),
      currencyCode: store.budgetCurrencyOf(budget),
      hasOverride: store.budgetLimitIsOwn(budget, ps),
      masked: store.masked,
      onlyLabel: l.tdOnlyThis(label),
      andAfterLabel: l.tdThisAndAfter(label),
      onSave: (magnitude, andAfter) =>
          store.setBudgetPeriodLimit(budget, ps, magnitude, andAfter: andAfter),
      onReset: () => store.resetBudgetPeriodLimit(budget, ps),
    );
  }

  // ── Bridge to the category detail (spec §7) ──────────────────────────────────

  Widget _spendingHistoryRow(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        child: InkWell(
          onTap: () {
            // Open the category detail on this budget's month, so its six-period
            // history is centred where the reader was looking (the category
            // detail follows Insight's window, spec §6.1/§7).
            final start = DateTime(month.year, month.month, 1);
            final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
            StoreScope.read(context).setInsightWindow(
                DateRange(start, end, preset: RangePreset.thisMonth));
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(categoryId: categoryId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.insSpendingHistory,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.accentLight)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.accentLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────

  Widget _navBar(BuildContext context, Category category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, 0),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left_rounded,
                      size: 20, color: AppColors.accentLight),
                  Text(
                    AppLocalizations.of(context).plTabBudgets,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.accentLight,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 22, color: AppColors.accentLight),
              onPressed: () => _showMenu(context, category),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, Category category) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.sm),
            ListTile(
              leading: const Icon(Icons.tune_rounded,
                  color: AppColors.textPrimary),
              title: Text(AppLocalizations.of(context).ebTitle, style: AppText.body),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => EditBudgetScreen(categoryId: category.id),
                  ),
                );
              },
            ),
            // Remove just the budget (spec §5) — the middle of the three in
            // severity: the editor changes the budget, this drops it, Archive
            // removes the category everywhere. The category and its transactions
            // are untouched; the budget goes to the Archive's REMOVED BUDGETS.
            // Same layout as its neighbours, only the colour differs (no divider,
            // caption or badge between the three).
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.negative),
              title: Text(AppLocalizations.of(context).bdRemoveBudget,
                  style: AppText.body.copyWith(color: AppColors.negative)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmRemoveBudget(context, category);
              },
            ),
            // Archive the category itself (§4) — the honest home for the action
            // in an app with no standalone category screen: the one per-category
            // ••• menu there is. Distinct from "Edit budget": archiving retires
            // the category from every picker and removes its budget as a
            // consequence, spelled out in the confirmation.
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.negative),
              title: Text(AppLocalizations.of(context).ctArchiveCategory,
                  style: AppText.body.copyWith(color: AppColors.negative)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmArchive(context, category);
              },
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  /// Spec §5 — remove the budget, leaving the category and its transactions
  /// intact. The removed budget appears in the Archive's REMOVED BUDGETS section.
  /// Uses the app's existing destructive-confirmation sheet.
  Future<void> _confirmRemoveBudget(
      BuildContext context, Category category) async {
    final store = StoreScope.read(context);
    final budget = store.monthlyBudgetForCategory(category.id);
    if (budget == null) return;
    // One remove path for both screens (task 067.3 §4c); the text and effect are
    // unchanged. This screen pops itself after the budget is gone.
    final removed = await confirmAndRemoveBudget(context, store, budget);
    if (removed && context.mounted) Navigator.of(context).pop();
  }

  /// §4 — archive the category. A scheduled item that books into it would keep
  /// writing real Ledger entries against an archived category, so archiving is
  /// blocked while one exists and the item is named (§6). Otherwise the impact
  /// is stated in concrete figures: history stays, the budget goes (recoverably),
  /// and it leaves every picker. Every figure masks with the privacy eye.
  Future<void> _confirmArchive(BuildContext context, Category category) async {
    final store = StoreScope.read(context);
    final l = AppLocalizations.of(context);

    final blocking = store.tasksUsingCategory(category.id);
    if (blocking.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          title: Text(l.ctBlockedTitle(category.name), style: AppText.rowTitle),
          content: Text(l.ctBlockedMsg(blocking.first.title),
              style: AppText.body.copyWith(fontSize: 13.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.accentLight),
              child: Text(l.actionClose),
            ),
          ],
        ),
      );
      return;
    }

    final count = store.txnCountForCategory(category.id);
    final budget = store.monthlyLimitOf(category);
    final ok = await showDestructiveConfirm(
      context,
      title: l.ctArchiveTitle(category.name),
      message: l.ctArchiveMsg,
      impact: [
        ImpactLine.kept(l.ctTxnStay(count)),
        ImpactLine.kept(l.ctPastMonths(category.name)),
        // Omitted entirely when the category has no budget (§4/§6).
        if (budget != null)
          ImpactLine.lost(
              l.ctBudgetRemoved(money(budget, masked: store.masked))),
        ImpactLine.lost(l.ctDisappearsPicker),
      ],
      confirmLabel: l.ctArchiveCategory,
    );
    if (!ok || !context.mounted) return;
    store.archiveCategory(category);
    // The category is now out of every picker and its budget removed; this
    // budget screen has nothing left to show, so return to Planner.
    Navigator.of(context).pop();
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, AppStore store, Category category,
      double monthlyBudget, Budget? budget) {
    final l = AppLocalizations.of(context);
    // A repeating budget with an end appends " · until {Jun 2027}" (§5b).
    final until = budget?.runsUntil;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.lg,
      ),
      child: Row(
        children: [
          IconTile(category.icon, color: category.color, size: 38),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: AppText.rowTitle.copyWith(fontSize: 19),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // The usual limit, not the effective one (spec 5.6).
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: AmountText(monthlyBudget,
                                style: AppText.rowSubtitle),
                          ),
                          TextSpan(text: ' ${l.bdAMonth}'),
                          if (until != null)
                            TextSpan(text: ' · ${l.bdUntil(monthYear(until, l))}'),
                        ]),
                        style: AppText.rowSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── This month ─────────────────────────────────────────────────────────────

  Widget _thisMonth(
    BuildContext context,
    AppStore store,
    Category category, {
    required Budget? budget,
    required double spent,
    required double ratio,
    required bool over,
    required double effectiveLimit,
    required Color color,
    required bool isCurrent,
    required bool beforeCurrent,
  }) {
    final l = AppLocalizations.of(context);
    // The limit run wears accentLight when this period carries its own (§5c).
    final isOwn = budget != null && store.budgetLimitIsOwn(budget, month);
    final limitStr = money(effectiveLimit, masked: store.masked);
    final caption = over
        ? l.bdOfOver(limitStr, money(spent - effectiveLimit, masked: store.masked))
        : l.bdOfLeft(limitStr, money(effectiveLimit - spent, masked: store.masked));

    // The tint rides on the card itself while the sheet is up (task 070 B7), not
    // a box behind it — an opaque AppCard would hide a box.
    Widget cardWith(bool tapped) => AppCard(
          color: tapped ? AppColors.tint(AppColors.accent, 0.14) : null,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AmountText(
                    spent,
                    style: AppText.hero.copyWith(fontSize: 27),
                    color: color,
                  ),
                  const SizedBox(width: Insets.sm),
                  Flexible(
                    child: _ownAwareCaption(caption, limitStr, isOwn),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ProgressBar(
                value: ratio,
                color: color,
                paceMarker: isCurrent ? store.monthProgressFor(month) : null,
                height: 3,
                markerWidth: 1.5,
                markerOverhang: 1.5,
              ),
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Text(
                    isCurrent
                        ? '${percent(ratio, decimals: 0)} · '
                            '${l.bdDayOfMonth(store.dayOfMonthFor(month), store.daysInMonthOf(month))}'
                        : percent(ratio, decimals: 0),
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                  if (isCurrent) ...[
                    const Spacer(),
                    Container(
                        width: 1.5, height: 9, color: AppColors.textPrimary),
                    const SizedBox(width: 5),
                    Text(l.plPace,
                        style: AppText.caption.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.rangeThisMonth.toUpperCase(), style: AppText.label),
          const SizedBox(height: Insets.sm),
          // Tapping opens §4's sheet for this period — unless the month on screen
          // is before the current one, whose limit is history (§5c).
          if (budget == null || beforeCurrent)
            cardWith(false)
          else
            _PeriodTap(
              onTap: () => _openPeriodSheet(
                  context, store, budget, store.budgetWindow(budget, month).start),
              builder: cardWith,
              radius: Radii.card,
            ),
        ],
      ),
    );
  }

  /// The THIS MONTH caption, with the limit run drawn in accentLight when the
  /// period carries its own limit — the sentence split around the formatted
  /// figure so locale word order is preserved (§5c).
  Widget _ownAwareCaption(String full, String limitStr, bool isOwn) {
    const base = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    if (!isOwn) {
      return Text(full, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final idx = full.indexOf(limitStr);
    if (idx < 0) {
      return Text(full, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: full.substring(0, idx)),
        TextSpan(
          text: limitStr,
          style: const TextStyle(
              color: AppColors.accentLight, fontWeight: FontWeight.w500),
        ),
        TextSpan(text: full.substring(idx + limitStr.length)),
      ]),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Upcoming (task 067.2 §5d) ────────────────────────────────────────────────

  /// The next three periods after the one on screen in which the budget runs,
  /// each opening §4's sheet. Absent on a past month, for a one-off, or when no
  /// such period exists (handled by the caller / an empty return here).
  Widget _upcoming(
      BuildContext context, AppStore store, Category category, Budget budget) {
    final l = AppLocalizations.of(context);
    if (!budget.repeats) return const SizedBox.shrink();

    final periods = <DateTime>[];
    for (var i = 1; periods.length < 3 && i <= 36; i++) {
      final m = DateTime(month.year, month.month + i, 1);
      final window = DateRange(
        DateTime(m.year, m.month, 1),
        DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999),
      );
      if (store.budgetRunsIn(budget, window)) {
        periods.add(store.budgetWindow(budget, m).start);
      } else if (budget.runsUntil != null &&
          window.start.isAfter(budget.runsUntil!)) {
        break; // past the end — no later period runs
      }
    }
    if (periods.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bdUpcoming, style: AppText.label),
          const SizedBox(height: Insets.sm),
          AppCard(
            padding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < periods.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 12),
                  _upcomingRow(context, store, budget, periods[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingRow(
      BuildContext context, AppStore store, Budget budget, DateTime periodStart) {
    final l = AppLocalizations.of(context);
    final isOwn = store.budgetLimitIsOwn(budget, periodStart);
    final limit = store.budgetLimitFor(budget, periodStart);
    final limitStr =
        money(limit, currency: store.budgetCurrencyOf(budget), masked: store.masked);
    return _PeriodTap(
      radius: 0,
      onTap: () => _openPeriodSheet(context, store, budget, periodStart),
      builder: (tapped) => Container(
        color: tapped ? AppColors.tint(AppColors.accent, 0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                monthYearLong(periodStart, l),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              limitStr,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isOwn ? FontWeight.w600 : FontWeight.w400,
                color: isOwn ? AppColors.accentLight : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: AppColors.textQuaternary),
          ],
        ),
      ),
    );
  }

  // ── Note (task 067.2 §5e) ────────────────────────────────────────────────────

  Widget _note(BuildContext context, String note) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).bdNote, style: AppText.label),
          const SizedBox(height: Insets.sm),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Text(
              note,
              style: AppText.body.copyWith(fontSize: 14.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ── Against the limit ──────────────────────────────────────────────────────

  Widget _againstTheLimit(
    AppStore store,
    Category category,
    Budget? budget,
    double monthlyBudget,
    Color selectedColor,
    AppLocalizations l,
  ) {
    // Six calendar months ending with the selected one, newest first.
    final months = [
      for (var i = 0; i < 6; i++) DateTime(month.year, month.month - i),
    ];
    final amounts = [
      for (final m in months) store.spentInCategory(category.id, m),
    ];
    // Whether the budget actually runs in each month (task 067.2 §5f): a month
    // before a later start, or after the end, shows spend with no limit line and
    // is excluded from the average and the over count.
    bool runsIn(DateTime m) {
      if (budget == null) return true;
      return store.budgetRunsIn(
        budget,
        DateRange(DateTime(m.year, m.month, 1),
            DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999)),
      );
    }

    double limitOf(DateTime m) =>
        budget == null ? monthlyBudget : store.budgetLimitFor(budget, m);

    final withSpending = amounts.where((a) => a > 0).length;
    // A rate from two points is noise — the same rule the frequency line follows
    // (spec 5.6).
    if (withSpending < 2) return const SizedBox.shrink();

    final highestSpend = amounts.fold(0.0, (m, a) => a > m ? a : m);
    var highestLimit = 0.0;
    for (var i = 0; i < months.length; i++) {
      if (runsIn(months[i])) {
        final li = limitOf(months[i]);
        if (li > highestLimit) highestLimit = li;
      }
    }
    final axisMax =
        (highestSpend > highestLimit ? highestSpend : highestLimit) * 1.15;

    // Average and over-count are measured over running months only (§5f).
    final runningSpent = [
      for (var i = 0; i < months.length; i++)
        if (runsIn(months[i]) && amounts[i] > 0) amounts[i],
    ];
    final average = runningSpent.isEmpty
        ? 0.0
        : runningSpent.fold(0.0, (s, a) => s + a) / runningSpent.length;
    var overLimitCount = 0;
    for (var i = 0; i < months.length; i++) {
      if (runsIn(months[i]) && amounts[i] > limitOf(months[i])) overLimitCount++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bdAgainstLimit, style: AppText.label),
          const SizedBox(height: Insets.sm),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _historyRow(
                    month: months[i],
                    amount: amounts[i],
                    fraction: axisMax <= 0 ? 0.0 : amounts[i] / axisMax,
                    // Each row against its own month's limit (§5f); a month the
                    // budget does not run in draws no line.
                    limitFraction: !runsIn(months[i]) || axisMax <= 0
                        ? null
                        : limitOf(months[i]) / axisMax,
                    color: i == 0 ? selectedColor : _pastMonth,
                    l: l,
                  ),
                ],
                if (withSpending >= 3) ...[
                  const SizedBox(height: Insets.md),
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.hairline),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l.bdAveraging(money(average.roundToDouble()),
                          money(monthlyBudget), '$overLimitCount'),
                      style: AppText.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow({
    required DateTime month,
    required double amount,
    required double fraction,
    required double? limitFraction,
    required Color color,
    required AppLocalizations l,
  }) {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              monthShort(month.month, l),
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: _HistoryBar(
              fraction: fraction,
              limitFraction: limitFraction,
              color: color,
              limitColor: _limitLine,
            ),
          ),
          const SizedBox(width: Insets.md),
          SizedBox(
            width: 66,
            child: Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                amount,
                style: AppText.amount.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: color == _pastMonth
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Transactions ───────────────────────────────────────────────────────────

  Widget _transactions(
    BuildContext context,
    AppStore store,
    Category category,
  ) {
    final txns = store
        .txnsInMonth(month)
        .where((t) => t.type == TxnType.expense && t.toRef == category.id)
        .toList();
    final shown = txns.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          '${monthShort(month.month, AppLocalizations.of(context)).toUpperCase()} · '
          '${AppLocalizations.of(context).countTransactions(txns.length)}',
        ),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.gutter,
              vertical: Insets.sm,
            ),
            child: Text(
              AppLocalizations.of(context).bdNothingSpent,
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const RowDivider(indent: Insets.md),
                    // Keyed by txn id so open/closed state stays with the
                    // transaction, not the position: adding/editing/deleting a
                    // txn elsewhere reorders this list, and without the key an
                    // open row would appear to jump onto a different one.
                    _TxnMiniRow(
                      key: ValueKey(shown[i].id),
                      category: category,
                      txn: shown[i],
                    ),
                  ],
                ],
              ),
            ),
          ),
        // Spec 5.6 — See all opens the full category history. LedgerKey is built
        // from a category + direction alone, so the newest month txn is a valid
        // origin for that key.
        if (txns.length > shown.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.gutter,
              0,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SameTransactionsScreen(
                    originTxnId: txns.first.id,
                    backLabel: category.name,
                    showAll: true,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  AppLocalizations.of(context).balSeeAll(txns.length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Changes (budget edit history) ──────────────────────────────────────────

  /// The record the goal screen has and a budget needs more: every limit,
  /// rollover, threshold and removal edit, in write order (newest last). A
  /// raised limit trails an amber `trending_up` — the one place a card turning
  /// green because the limit grew is told apart from one turning green because
  /// spending fell. Existing budgets start empty (no backfill); the footnote
  /// dates the record so its emptiness reads as new, not missing.
  Widget _changes(
      BuildContext context, AppStore store, Category category, Budget? budget) {
    final l = AppLocalizations.of(context);
    final monthly = budget == null || budget.period == BudgetPeriod.month;
    final history = store.budgetHistoryOf(category);
    final since =
        '${store.budgetHistorySince.day} ${monthLong(store.budgetHistorySince.month, l)} ${store.budgetHistorySince.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Insets.md),
        SectionLabel(l.goalChanges),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.md,
                    ),
                    child: Center(
                      child: Text(
                        l.bhEmpty,
                        style: AppText.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < history.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _changeRow(l, history[i], store.masked, monthly),
                      ],
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.sm,
            Insets.gutter,
            0,
          ),
          child: Text(
            l.bhSince(since),
            style: AppText.caption.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  ChangeRow _changeRow(
      AppLocalizations l, BudgetEdit e, bool masked, bool monthly) {
    final period = e.period;
    final periodLabel = period == null
        ? ''
        : (monthly ? monthYearLong(period, l) : dayMonthYear(period, l));
    final label = switch (e.field) {
      'created' => l.bhCreated,
      // Task 067.2 §3 — a period's own limit, and a from-this-period change.
      'periodLimit' => l.bhLimitFor(periodLabel),
      'limit' => period == null ? l.bhLimit : l.bhLimitFrom(periodLabel),
      'until' => l.bhEnds,
      'rollover' => l.bhRollover,
      'warn' => l.bhWarn,
      'removed' => l.bhRemoved,
      'restored' => l.bhRestored,
      _ => l.bhCategoryArchived,
    };
    final value = _changeValue(l, e, masked, monthly);
    // Screen reader: one sentence, the amber flag folded in as words rather than
    // read as a separate node. Money in the value honours the privacy eye.
    final spoken = value.replaceAll(' → ', ' ${l.bhA11yTo} ');
    final sentence = StringBuffer('${e.at.day}.${e.at.month}, $label');
    if (spoken.isNotEmpty) sentence.write(', $spoken');
    if (e.amber) sentence.write(', ${l.bhA11yIncreased}');
    return ChangeRow(
      date: '${e.at.day}.${e.at.month}',
      label: label,
      value: value,
      amber: e.amber,
      amberIcon: Icons.trending_up_rounded,
      semanticsLabel: sentence.toString(),
    );
  }

  /// Composes the display value from the record's language-neutral parts. The
  /// store never stores localised words (it holds no [AppLocalizations]): the
  /// rollover state rides in as an `on`/`off` token, resolved here.
  String _changeValue(
      AppLocalizations l, BudgetEdit e, bool masked, bool monthly) {
    switch (e.field) {
      case 'created':
        final amount = _mask(e.to, masked);
        return e.from == 'on'
            ? l.bhCreatedRolloverOn(amount)
            : l.bhCreatedRolloverOff(amount);
      case 'limit':
      case 'periodLimit':
        return '${_mask(e.from, masked)} → ${_mask(e.to, masked)}';
      case 'until':
        // from/to hold epoch-ms strings, or '' for no end (task 067.1 §1).
        return '${_untilSide(l, e.from, monthly)} → ${_untilSide(l, e.to, monthly)}';
      case 'rollover':
        return '${_rolloverWord(l, e.from)} → ${_rolloverWord(l, e.to)}';
      case 'warn':
        // Percentages are not money and do not mask.
        return '${e.from} → ${e.to}';
      case 'removed':
      case 'restored':
        return _mask(e.to, masked);
      default:
        // categoryArchived — a label with no value line.
        return '';
    }
  }

  String _rolloverWord(AppLocalizations l, String token) =>
      token == 'on' ? l.bhOn : l.bhOff;

  /// One side of an 'until' change (task 067.2 §3): a date (monthYear for a
  /// monthly budget, dayMonthYear otherwise), or "No end" for the empty token.
  String _untilSide(AppLocalizations l, String token, bool monthly) {
    if (token.isEmpty) return l.bgNoEnd;
    final ms = int.tryParse(token);
    if (ms == null) return token;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return monthly ? monthYear(d, l) : dayMonthYear(d, l);
  }

  /// Masks the money runs in an already-formatted string when the privacy eye is
  /// on, leaving separators and any trailing words ("· rollover off") intact.
  /// The base currency is `$` throughout the app, so the pattern is unambiguous.
  static final _moneyRe = RegExp(r'\$[\d,]+(?:\.\d+)?');
  String _mask(String s, bool masked) =>
      masked ? s.replaceAll(_moneyRe, r'$••••') : s;
}

/// A single history bar with a fill and, when the budget runs that month, the
/// month's own vertical limit line (task 067.2 §5f). 3 pt tall (was 10).
class _HistoryBar extends StatelessWidget {
  const _HistoryBar({
    required this.fraction,
    required this.limitFraction,
    required this.color,
    required this.limitColor,
  });

  final double fraction;

  /// Null for a month the budget does not run in — no line is drawn.
  final double? limitFraction;
  final Color color;
  final Color limitColor;

  @override
  Widget build(BuildContext context) {
    const height = 3.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final lf = limitFraction;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
              if (lf != null)
                Positioned(
                  // Snapped to a whole pixel so the 1.5 pt line stays crisp.
                  left: (width * lf.clamp(0.0, 1.0) - 0.75)
                      .clamp(0.0, width - 1.5)
                      .roundToDouble(),
                  top: -2,
                  bottom: -2,
                  child: Container(width: 1.5, color: limitColor),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A tappable region that tints [AppColors.accent] at 14 % while its sheet is up
/// (task 067.2 §D.2 / §5c). Kept local so [BudgetDetailScreen] stays stateless.
class _PeriodTap extends StatefulWidget {
  const _PeriodTap({
    required this.builder,
    required this.onTap,
    required this.radius,
  });

  final Widget Function(bool tapped) builder;
  final Future<void> Function() onTap;
  final double radius;

  @override
  State<_PeriodTap> createState() => _PeriodTapState();
}

class _PeriodTapState extends State<_PeriodTap> {
  bool _tapped = false;

  Future<void> _run() async {
    setState(() => _tapped = true);
    await widget.onTap();
    if (mounted) setState(() => _tapped = false);
  }

  @override
  Widget build(BuildContext context) {
    // The tint is applied by the builder — on the card's own surface for the
    // THIS MONTH card (task 070 B7), and on the row's background for an UPCOMING
    // row — so nothing is drawn behind an opaque card here.
    return InkWell(
      onTap: _run,
      borderRadius:
          widget.radius > 0 ? BorderRadius.circular(widget.radius) : null,
      child: widget.builder(_tapped),
    );
  }
}

/// Compact transaction row for the budget screen's preview list. Closed it is a
/// read-only summary (title · date · amount); a tap expands it in place to
/// reveal the three facts the closed row cannot — WHEN's time of day, PAID WITH
/// and its balance-after, and TAGS — and a second tap closes it. No navigation,
/// no sheet (spec §1/§2). The screen stays stateless; the open flag lives here,
/// so more than one row can be open at once (intended — five rows at most).
class _TxnMiniRow extends StatefulWidget {
  const _TxnMiniRow({super.key, required this.category, required this.txn});

  final Category category;
  final Txn txn;

  @override
  State<_TxnMiniRow> createState() => _TxnMiniRowState();
}

class _TxnMiniRowState extends State<_TxnMiniRow> {
  bool _open = false;

  /// The tile beside the title, and the gap after it: the detail block indents
  /// to the title's left edge by clearing exactly these (spec §2). Derived, not
  /// the hard-coded 54 — the outer [Insets.md] row padding supplies the rest.
  static const _tileSize = 30.0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final category = widget.category;
    final txn = widget.txn;
    final title = txn.note.isEmpty ? category.name : txn.note;

    return Semantics(
      button: true,
      expanded: _open,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(category.icon, color: category.color, size: _tileSize),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.rowTitle.copyWith(fontSize: 14),
                          // The note's clamp lifts on open: a long note becomes
                          // fully readable, with no NOTE row repeating it (§2).
                          maxLines: _open ? null : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(dayMonth(txn.date, AppLocalizations.of(context)),
                            style: AppText.rowSubtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  AmountText(txn.amountBase),
                ],
              ),
              // The app's one reveal motion — same 180ms easeOut / topLeft as
              // TxnRow._descriptionLine (spec §2).
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topLeft,
                child: _open
                    ? _details(context, store)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// WHEN · PAID WITH · TAGS, built from [DetailRow] and indented to the title's
  /// left edge. Insets.sm above; the row's own bottom padding sits below. No
  /// NOTE row (the title above already is the note) and no CATEGORY row (the
  /// screen is the category) (spec §2/§3).
  Widget _details(BuildContext context, AppStore store) {
    final l = AppLocalizations.of(context);
    final txn = widget.txn;
    final rows = <Widget>[
      // WHEN — always present; the time of day is the one fact the closed row
      // cannot show. Same composition as the drilldown's detail card.
      DetailRow(
        l.stDetailWhen,
        l.dateWithTime(dayMonthYear(txn.date, l), hhmm(txn.date)),
      ),
    ];

    // PAID WITH — this list is expense-only, so fromRef is always the payer.
    // Omitted when the account will not resolve (deleted). The trailing figure
    // is the account's balance right after this transaction, in its own
    // currency, masked with the privacy eye.
    final account = store.accountById(txn.fromRef);
    if (account != null) {
      rows.add(DetailRow(
        l.stDetailPaidWith,
        account.name,
        clampValue: true,
        trailing: money(
          store.runningBalanceAt(account.id, txn),
          currency: account.currency,
          masked: store.masked,
        ),
      ));
    }

    // TAGS — omitted when there are none.
    final names = store.tagNames(txn.tagIds);
    if (names.isNotEmpty) {
      rows.add(DetailRow(
        l.stDetailTags,
        names.map((t) => '#$t').join(' '),
        valueColor: AppColors.tagDot,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: Insets.sm,
        left: _tileSize + Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}
