import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/swipe_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/edit_budget_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'insight_filter.dart';

/// One screen for both directions and all entry points: Insight's income row,
/// Insight's expense row and Planner's `6-month spending history ›` row all push
/// *this*. Two category screens is how two figures for the same category start
/// disagreeing.
///
/// **The boundary with [EditBudgetScreen]/BudgetDetailScreen (spec §7):** this
/// screen answers "how much did I spend each period?" — it follows Insight's
/// window (six weeks for a week window), works for income categories, and has no
/// reference line. The budget screen answers "how did I do against the limit?"
/// — it is month-locked, has a shared limit line, and is meaningful only for
/// budgeted expenses.
///
/// Reads Insight's window from the store (spec §6.1); tapping a bar or swiping
/// the chart writes it back, so returning to the main screen shows the period
/// the reader ended on. Pushed on the root navigator, so it covers the nav.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final String categoryId;

  static const _periods = 6;
  static const _eps = 0.005;

  DateTime get _startOfToday =>
      DateTime(AppStore.today.year, AppStore.today.month, AppStore.today.day);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final category = store.categoryById(categoryId);

    if (category == null) {
      // Deleted category still referenced — never crash.
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(children: [
            ScreenHeader(title: '—', showBack: true, showAdd: false),
          ]),
        ),
      );
    }

    final window = store.insightWindow;
    final expense = category.type == CategoryType.expense;
    final today = _startOfToday;

    double valueOf(DateRange w) => expense
        ? store.spentInCategoryWindow(categoryId, w)
        : store.earnedInCategoryWindow(categoryId, w);

    // A window that contains today but has not ended is incomplete (spec §6.2).
    bool partialOf(DateRange w) =>
        w.start.isBefore(today) && w.end.isAfter(today);

    // Six periods ending with the current one, stepped by the window's unit.
    final windows = [
      for (var n = _periods - 1; n >= 0; n--) window.copyShifted(-n),
    ];
    final values = [for (final w in windows) valueOf(w)];
    final partial = [for (final w in windows) partialOf(w)];
    final hasData = [for (final v in values) v > _eps];

    // A partial period is excluded from the average and from `highest`
    // (spec §6.2): folding nine days in with three full months is a lie.
    final counted = [
      for (var i = 0; i < values.length; i++) hasData[i] && !partial[i]
    ];
    final withData = [
      for (var i = 0; i < values.length; i++)
        if (counted[i]) values[i]
    ];
    final periodsWithData = withData.length;
    // Under three periods with data: no average, no percentage — a claim built
    // on two points is a confident lie.
    final showTrend = periodsWithData >= 3;
    final average = withData.isEmpty
        ? 0.0
        : withData.reduce((a, b) => a + b) / withData.length;
    // Bars scale to the tallest of the six (the partial one included).
    final maxVal = values.fold(0.0, (m, v) => v > m ? v : m);

    var hiIndex = -1;
    for (var i = 0; i < values.length; i++) {
      if (counted[i] && (hiIndex < 0 || values[i] > values[hiIndex])) {
        hiIndex = i;
      }
    }

    final current = values.last;
    final currentPartial = partial.last;

    // The elapsed slice of the current window (start … today), for the hero
    // label, the axis label and the like-for-like comparison (spec §6.2/§6.3).
    final elapsedEnd = window.end.isAfter(today) ? today : window.end;
    final elapsedWindow = DateRange(window.start, elapsedEnd);
    final elapsedDays = elapsedWindow.days;

    // Hero label: the elapsed range while partial (`1–9 Aug`), otherwise the
    // window's name. This deliberately differs from the main screen, which keeps
    // the window's name — a comparison of six periods has to say what it is
    // comparing (spec §6.2).
    final heroLabel = currentPartial
        ? elapsedWindow.label(AppStore.today, l)
        : insightWindowLabel(window, l);

    final labels = [
      for (var i = 0; i < windows.length; i++)
        partial[i]
            ? '${monthShort(windows[i].end.month, l)} · ${l.insDaysShort(elapsedDays)}'
            : _barLabel(windows[i], l)
    ];

    // One spoken sentence per bar (spec §9); the visual value labels are
    // ExcludeSemantics inside the chart.
    final a11yLabels = [
      for (var i = 0; i < windows.length; i++)
        if (!hasData[i])
          l.insA11yChartColEmpty(_barLabel(windows[i], l))
        else if (partial[i])
          l.insA11yChartColPartial(
              monthLong(windows[i].end.month, l),
              money(values[i], masked: store.masked),
              l.insDaysCount(elapsedDays))
        else
          l.insA11yChartCol(
              _barLabel(windows[i], l), money(values[i], masked: store.masked))
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              titleWidget: Row(
                children: [
                  IconTile(category.icon, color: category.color, size: 28),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title.copyWith(fontSize: 20)),
                  ),
                ],
              ),
              showBack: true,
              showAdd: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.xxl),
                children: [
                  // Hero: this window's figure, with the elapsed/window label.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AmountText(current,
                              style: AppText.hero.copyWith(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(heroLabel,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textTertiary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _comparison(
                    context,
                    store,
                    l,
                    window: window,
                    current: current,
                    currentPartial: currentPartial,
                    elapsedDays: elapsedDays,
                    expense: expense,
                    showTrend: showTrend,
                    valueOf: valueOf,
                  ),
                  const SizedBox(height: Insets.md),

                  // The six-period column chart — swipe or tap to move the
                  // window (spec §6.5).
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      children: [
                        HorizontalSectionSwipe(
                          onNext: () => _step(context, 1),
                          onPrevious: () => _step(context, -1),
                          child: _ColumnChart(
                            labels: labels,
                            a11yLabels: a11yLabels,
                            values: values,
                            hasData: hasData,
                            partial: partial,
                            maxVal: maxVal <= 0 ? 1 : maxVal,
                            color: category.color,
                            currentIndex: values.length - 1,
                            masked: store.masked,
                            onTapBar: (i) => _tapBar(context, windows[i]),
                          ),
                        ),
                        _ChartStat(
                          showTrend: showTrend,
                          average: average,
                          highLabel:
                              hiIndex < 0 ? '' : _barLabel(windows[hiIndex], l),
                          highValue: hiIndex < 0 ? 0 : values[hiIndex],
                          periodsWithData: periodsWithData,
                          currentPartial: currentPartial,
                          currentMonthName: monthLong(window.end.month, l),
                          anyEmpty: hasData.any((h) => !h),
                          masked: store.masked,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  if (expense)
                    _budgetBridge(context, store, l, category, current),

                  _movements(context, store, l, category, window, expense),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Forward stepping stops at the period containing today (spec §6.5).
  void _step(BuildContext context, int steps) {
    final store = StoreScope.read(context);
    final w = store.insightWindow;
    if (steps > 0 && !w.end.isBefore(_startOfToday)) return;
    HapticFeedback.lightImpact();
    store.setInsightWindow(w.copyShifted(steps));
  }

  /// Tapping a bar sets the window to that period; the chart then re-derives its
  /// six periods ending with the tapped one, so it moves to the right edge
  /// (spec §6.5).
  void _tapBar(BuildContext context, DateRange w) {
    final store = StoreScope.read(context);
    if (w.start == store.insightWindow.start &&
        w.end == store.insightWindow.end) {
      return;
    }
    HapticFeedback.selectionClick();
    store.setInsightWindow(w);
  }

  Widget _comparison(
    BuildContext context,
    AppStore store,
    AppLocalizations l, {
    required DateRange window,
    required double current,
    required bool currentPartial,
    required int elapsedDays,
    required bool expense,
    required bool showTrend,
    required double Function(DateRange) valueOf,
  }) {
    if (!showTrend) return const SizedBox.shrink();
    final prevWindow = window.copyShifted(-1);

    final double prev;
    final String rangeLabel;
    if (currentPartial) {
      // Compare the same elapsed slice of the previous period — comparing nine
      // days with a full month measures the calendar, not the spending
      // (spec §6.3).
      final ps = prevWindow.start;
      final pe = DateTime(ps.year, ps.month, ps.day + elapsedDays - 1,
          23, 59, 59, 999);
      final prevElapsed = DateRange(ps, pe);
      prev = valueOf(prevElapsed);
      rangeLabel = prevElapsed.label(AppStore.today, l);
    } else {
      prev = valueOf(prevWindow);
      rangeLabel = insightWindowLabel(prevWindow, l);
    }

    if (prev <= _eps) {
      return Text(l.insNoPreviousPeriod,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary));
    }
    final delta = current - prev;
    final rising = delta > 0;
    // Colour by good/bad, not direction: less spending is good, less income is
    // bad ("Yön ≠ renk").
    final good = expense ? !rising : rising;
    final color = delta.abs() < _eps
        ? AppColors.textSecondary
        : (good ? AppColors.positive : AppColors.negative);
    final pct = prev == 0 ? 0.0 : delta / prev;
    final signedPct = (delta < 0 ? '−' : '+') + percent(pct.abs(), decimals: 0);

    return Row(
      children: [
        Text(rising ? '▲' : '▼', style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            l.insVsRange(
                money(delta.abs(), masked: store.masked), rangeLabel, signedPct),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ),
      ],
    );
  }

  Widget _budgetBridge(BuildContext context, AppStore store, AppLocalizations l,
      Category category, double spent) {
    final limit = store.effectiveLimitOf(category);
    void openEditor() => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => EditBudgetScreen(categoryId: category.id),
          ),
        );

    if (limit == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: AppCard(
          child: InkWell(
            onTap: openEditor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.insAddBudget,
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

    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final over = ratio > 1;
    final remainder = limit - spent;
    final color = over
        ? AppColors.negative
        : (ratio >= store.warnThresholdOf(category)
            ? AppColors.warning
            : AppColors.positive);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        child: InkWell(
          onTap: openEditor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.insMonthlyBudget(
                          money(limit, masked: store.masked),
                          percent(ratio, decimals: 0),
                        ),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      over
                          ? l.insOverBudget(
                              money(remainder.abs(), masked: store.masked))
                          : l.insLeft(money(remainder, masked: store.masked)),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              over ? AppColors.negative : AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(value: ratio, color: color, height: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _movements(BuildContext context, AppStore store, AppLocalizations l,
      Category category, DateRange window, bool expense) {
    final rows = store
        .txnsInWindow(window)
        .where((t) => expense
            ? t.type == TxnType.expense && t.toRef == categoryId
            : t.type == TxnType.income && t.fromRef == categoryId)
        .toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `AUG · 2 TRANSACTIONS` — the format the budget screen already uses;
        // `MOVEMENTS 2` was Insight's own coinage and is gone (spec §6.6).
        SectionLabel(
          '${monthShort(window.end.month, l).toUpperCase()} · '
          '${l.countTransactions(rows.length)}',
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const RowDivider(indent: 47),
                _MovementRow(
                  txn: rows[i],
                  category: category,
                  expense: expense,
                  store: store,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The label under each bar: monthShort for month/quarter units, `d MMM` for
  /// weeks (spec §6.1).
  String _barLabel(DateRange w, AppLocalizations l) {
    switch (w.preset) {
      case RangePreset.thisWeek:
      case RangePreset.lastWeek:
      case null:
        return dayMonth(w.start, l);
      case RangePreset.thisYear:
        return '${w.start.year}';
      default:
        return monthShort(w.end.month, l);
    }
  }
}

/// A live transaction row: tap opens the editor, swipe exposes edit and copy
/// (spec §6.6). Kept local rather than reusing `LedgerTxnRow`, whose API is
/// bound to the scoped ledger's `ScopedTxn`/day-grouping state — reported per
/// §6.6.
class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.txn,
    required this.category,
    required this.expense,
    required this.store,
  });

  final Txn txn;
  final Category category;
  final bool expense;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The account on the other side of the entry (expense: source; income:
    // destination).
    final accId = expense ? txn.fromRef : txn.toRef;
    final acc = store.accountById(accId);
    final title = txn.note.isEmpty ? category.name : txn.note;
    // "August rent, 1,100 dollars, 2 August, Main Checking." (spec §9).
    final a11y = l.insA11yTxnRow(
        title,
        money(txn.amount, currency: txn.currency, masked: store.masked),
        dayMonth(txn.date, l),
        acc?.name ?? '—');

    return SwipeActions(
      actions: [
        SwipeActionItem(
          icon: Icons.edit_rounded,
          label: l.actionEdit,
          color: AppColors.surfaceHigh,
          onTap: () => showQuickAdd(context, editing: txn),
        ),
        SwipeActionItem(
          icon: Icons.copy_rounded,
          label: l.actionCopy,
          color: AppColors.info,
          onTap: () => showQuickAdd(context, copyOf: txn),
        ),
      ],
      child: InkWell(
        onTap: () {
          // If another row's swipe strip is open, the first tap only dismisses
          // it — it never opens the editor from under the user.
          if (anySwipeRowOpen) {
            closeOpenSwipeRow();
            return;
          }
          showQuickAdd(context, editing: txn);
        },
        child: Semantics(
          button: true,
          label: a11y,
          child: ExcludeSemantics(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              IconTile(category.icon, color: category.color, size: 24),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(fontSize: 14)),
                    Text('${dayMonth(txn.date, l)} · ${acc?.name ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              AmountText(txn.amount,
                  currency: txn.currency,
                  style: AppText.amount.copyWith(fontSize: 14)),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

/// The zero-based six-column chart. Bars scale to the tallest of the six; a
/// period with no records is a `—` outlined placeholder, excluded from the
/// average. **No horizontal line of any kind** (spec §6.4): the dashed average
/// line and its `Avg.` tag were deleted — the tag also collided with the current
/// period's value label near the maximum.
class _ColumnChart extends StatelessWidget {
  const _ColumnChart({
    required this.labels,
    required this.a11yLabels,
    required this.values,
    required this.hasData,
    required this.partial,
    required this.maxVal,
    required this.color,
    required this.currentIndex,
    required this.masked,
    required this.onTapBar,
  });

  final List<String> labels;
  final List<String> a11yLabels;
  final List<double> values;
  final List<bool> hasData;
  final List<bool> partial;
  final double maxVal;
  final Color color;
  final int currentIndex;
  final bool masked;
  final ValueChanged<int> onTapBar;

  static const _barsBand = 76.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('ins-chart'),
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                label: a11yLabels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTapBar(i),
                  child: ExcludeSemantics(child: _column(i)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _column(int i) {
    final isCurrent = i == currentIndex;
    final has = hasData[i];
    final isPartial = partial[i];
    final barH = has ? (_barsBand * (values[i] / maxVal).clamp(0.02, 1.0)) : 20.0;

    return Column(
      children: [
        // Value label band (13 pt).
        SizedBox(
          height: 13,
          child: Center(
            child: has
                ? Text(money(values[i], masked: masked),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCurrent
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()]))
                : const Text('—',
                    style: TextStyle(fontSize: 9.5, color: AppColors.textTertiary)),
          ),
        ),
        // Bars band (76 pt).
        SizedBox(
          height: _barsBand,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: has
                  ? (isPartial
                      // Still growing: a 2pt dashed top edge and no rounded cap.
                      ? _PartialBar(height: barH, color: color)
                      : Container(
                          height: barH,
                          decoration: BoxDecoration(
                            color:
                                isCurrent ? color : AppColors.tint(color, 0.55),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ))
                  : Container(
                      height: 20,
                      decoration: BoxDecoration(
                        // A period with no transactions is NOT a zero: a faint
                        // outlined placeholder, excluded from the average.
                        border:
                            Border.all(color: AppColors.divider, width: 1),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
            ),
          ),
        ),
        // Month/day label band (15 pt).
        SizedBox(
          height: 15,
          child: Center(
            child: Text(labels[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? AppColors.textSecondary
                        : AppColors.textTertiary)),
          ),
        ),
      ],
    );
  }
}

/// The current, still-growing period: solid fill with a 2pt dashed top edge and
/// a flat (uncapped) top (spec §6.2).
class _PartialBar extends StatelessWidget {
  const _PartialBar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            top: 2,
            child: ColoredBox(color: color),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: _DashedTop(color: color),
          ),
        ],
      ),
    );
  }
}

class _DashedTop extends StatelessWidget {
  const _DashedTop({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const dash = 4.0, gap = 3.0;
      final count = (c.maxWidth / (dash + gap)).ceil();
      return Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Container(width: dash, height: 2, color: color),
            const SizedBox(width: gap),
          ],
        ],
      );
    });
  }
}

/// The stat line under the chart: average · highest / still-running · empty note,
/// or the too-few-periods sentence. **May wrap to two lines** (spec §6.4): in
/// `ru` and at 320pt a truncated explanation is worse than none.
class _ChartStat extends StatelessWidget {
  const _ChartStat({
    required this.showTrend,
    required this.average,
    required this.highLabel,
    required this.highValue,
    required this.periodsWithData,
    required this.currentPartial,
    required this.currentMonthName,
    required this.anyEmpty,
    required this.masked,
  });

  final bool showTrend;
  final double average;
  final String highLabel;
  final double highValue;
  final int periodsWithData;
  final bool currentPartial;
  final String currentMonthName;
  final bool anyEmpty;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final String text;
    if (showTrend) {
      final parts = <String>[
        l.insAverageValue(money(average, masked: masked)),
        // While the current period is partial it ends with "{month} still
        // running"; otherwise the highest period (spec §6.2/§6.4).
        if (currentPartial)
          l.insStillRunning(currentMonthName)
        else
          l.insHighest(highLabel, money(highValue, masked: masked)),
        if (anyEmpty) l.insEmptyMonthsExcluded,
      ];
      text = parts.join(' · ');
    } else {
      text = l.insTooFewPeriods(periodsWithData);
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Text(text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11, height: 1.2, color: AppColors.textTertiary)),
    );
  }
}
