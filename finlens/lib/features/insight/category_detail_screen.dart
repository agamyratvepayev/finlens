import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/edit_budget_screen.dart';

/// One screen for both directions and both entry points: Insight's income row,
/// Insight's expense row and Planner's budget row all push *this*. Two category
/// screens is how two figures for the same category start disagreeing.
///
/// Pushed on the root navigator, so it covers the bottom nav.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.window,
  });

  final String categoryId;
  final DateRange window;

  static const _periods = 6;
  static const _eps = 0.005;

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
            ScreenHeader(title: l.insMovements, showBack: true, showAdd: false),
          ]),
        ),
      );
    }

    final expense = category.type == CategoryType.expense;
    double valueOf(DateRange w) => expense
        ? store.spentInCategoryWindow(categoryId, w)
        : store.earnedInCategoryWindow(categoryId, w);

    // Six periods ending with the current one, stepped by the window's unit.
    final windows = [
      for (var n = _periods - 1; n >= 0; n--) window.copyShifted(-n),
    ];
    final values = [for (final w in windows) valueOf(w)];
    final hasData = [for (final v in values) v > _eps];
    final current = values.last;

    final withData = [
      for (var i = 0; i < values.length; i++)
        if (hasData[i]) values[i]
    ];
    final periodsWithData = withData.length;
    // Under three periods with data: no average, no percentage, no dashed line —
    // a claim built on two points is a confident lie.
    final showTrend = periodsWithData >= 3;
    final average =
        withData.isEmpty ? 0.0 : withData.reduce((a, b) => a + b) / withData.length;
    final maxVal = values.fold(0.0, (m, v) => v > m ? v : m);

    // Highest period with data.
    var hiIndex = -1;
    for (var i = 0; i < values.length; i++) {
      if (hasData[i] && (hiIndex < 0 || values[i] > values[hiIndex])) hiIndex = i;
    }

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
                  // Hero: this window's figure, with the window on the right.
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
                        child: Text(_periodTitle(window, l),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textTertiary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _comparison(context, store, l,
                      current: current, expense: expense, showTrend: showTrend),
                  const SizedBox(height: Insets.md),

                  // The six-period column chart.
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      children: [
                        _ColumnChart(
                          labels: [for (final w in windows) _barLabel(w, l)],
                          values: values,
                          hasData: hasData,
                          maxVal: maxVal <= 0 ? 1 : maxVal,
                          average: showTrend ? average : null,
                          color: category.color,
                          currentIndex: values.length - 1,
                          masked: store.masked,
                          l: l,
                        ),
                        _ChartStat(
                          showTrend: showTrend,
                          average: average,
                          highLabel: hiIndex < 0 ? '' : _barLabel(windows[hiIndex], l),
                          highValue: hiIndex < 0 ? 0 : values[hiIndex],
                          periodsWithData: periodsWithData,
                          masked: store.masked,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),

                  if (expense)
                    _budgetBridge(context, store, l, category, current),

                  _movements(context, store, l, category, expense),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparison(
    BuildContext context,
    AppStore store,
    AppLocalizations l, {
    required double current,
    required bool expense,
    required bool showTrend,
  }) {
    if (!showTrend) return const SizedBox.shrink();
    final prevWindow = window.copyShifted(-1);
    final prev = expense
        ? store.spentInCategoryWindow(categoryId, prevWindow)
        : store.earnedInCategoryWindow(categoryId, prevWindow);
    if (prev <= _eps) {
      return Text(l.insNoPreviousPeriod,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary));
    }
    final delta = current - prev;
    final rising = delta > 0;
    // Colour by good/bad, not by direction: less spending is good, less income
    // is bad ("Yön ≠ renk").
    final good = expense ? !rising : rising;
    final color = delta.abs() < _eps
        ? AppColors.textSecondary
        : (good ? AppColors.positive : AppColors.negative);
    final pct = prev == 0 ? 0.0 : delta / prev;

    return Row(
      children: [
        Text(rising ? '▲' : '▼', style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(width: 3),
        Text(
          l.insVsLastPeriod(
            money(delta.abs(), masked: store.masked),
            (delta < 0 ? '−' : '+') + percent(pct.abs(), decimals: 0),
          ),
          style: TextStyle(fontSize: 12.5, color: color),
        ),
      ],
    );
  }

  Widget _budgetBridge(BuildContext context, AppStore store, AppLocalizations l,
      Category category, double spent) {
    final limit = category.effectiveLimit;
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
        : (ratio >= category.warnThreshold
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
                          ? l.insOverBudget(money(remainder.abs(), masked: store.masked))
                          : l.insLeft(money(remainder, masked: store.masked)),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: over ? AppColors.negative : AppColors.textPrimary),
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
      Category category, bool expense) {
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
        // Section header: the count sits BESIDE the label, never in the amount
        // column (a lone number there reads as an amount) — spec §3.6.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, Insets.sm, 0, Insets.sm),
          child: Row(
            children: [
              Text(l.insMovements.toUpperCase(), style: AppText.label),
              const SizedBox(width: Insets.sm),
              Text('${rows.length}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const RowDivider(indent: 47),
                _movementRow(context, store, l, rows[i], category, expense),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _movementRow(BuildContext context, AppStore store, AppLocalizations l,
      Txn t, Category category, bool expense) {
    // The account on the other side of the entry (expense: the source account;
    // income: the destination account).
    final accId = expense ? t.fromRef : t.toRef;
    final acc = store.accountById(accId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          IconTile(category.icon, color: category.color, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note.isEmpty ? category.name : t.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 14)),
                Text('${dayMonth(t.date, l)} · ${acc?.name ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
          AmountText(t.amount,
              currency: t.currency, style: AppText.amount.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  /// The window heading on the hero row.
  String _periodTitle(DateRange w, AppLocalizations l) {
    switch (w.preset) {
      case RangePreset.thisMonth:
      case RangePreset.lastMonth:
        return monthYearLong(w.start, l);
      case RangePreset.thisYear:
        return '${w.start.year}';
      case RangePreset.allTime:
        return l.rangeAllTime;
      default:
        return w.label(AppStore.today, l);
    }
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

/// The zero-based six-column chart. Bars scale to the tallest bar in the six; a
/// period with no records is a hatched placeholder with a `—` label, excluded
/// from the average. A dashed average line makes the honest scale readable when
/// the bars are nearly equal.
class _ColumnChart extends StatelessWidget {
  const _ColumnChart({
    required this.labels,
    required this.values,
    required this.hasData,
    required this.maxVal,
    required this.average,
    required this.color,
    required this.currentIndex,
    required this.masked,
    required this.l,
  });

  final List<String> labels;
  final List<double> values;
  final List<bool> hasData;
  final double maxVal;
  final double? average;
  final Color color;
  final int currentIndex;
  final bool masked;
  final AppLocalizations l;

  static const _barsBand = 76.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('ins-chart'),
      height: 104,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(child: _column(i)),
            ],
          ),
          if (average != null)
            Positioned(
              left: 0,
              right: 0,
              top: 13 + _barsBand * (1 - (average! / maxVal).clamp(0.0, 1.0)),
              child: const _DashedLine(),
            ),
          if (average != null)
            Positioned(
              right: 0,
              top: 13 +
                  _barsBand * (1 - (average! / maxVal).clamp(0.0, 1.0)) -
                  12,
              child: Text(l.insAverage,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }

  Widget _column(int i) {
    final isCurrent = i == currentIndex;
    final has = hasData[i];
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
                  ? Container(
                      height: barH,
                      decoration: BoxDecoration(
                        color: isCurrent ? color : AppColors.tint(color, 0.55),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    )
                  : Container(
                      height: 20,
                      decoration: BoxDecoration(
                        // A period with no transactions is NOT a zero: a faint
                        // outlined placeholder, excluded from the average.
                        border: Border.all(
                            color: AppColors.divider, width: 1),
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

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const dash = 4.0, gap = 3.0;
      final count = (c.maxWidth / (dash + gap)).floor();
      return Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Container(
                width: dash, height: 1, color: AppColors.textTertiary),
            const SizedBox(width: gap),
          ],
        ],
      );
    });
  }
}

/// The 30 pt stat line under the chart: average · highest · empty-periods note,
/// or the too-few-periods sentence.
class _ChartStat extends StatelessWidget {
  const _ChartStat({
    required this.showTrend,
    required this.average,
    required this.highLabel,
    required this.highValue,
    required this.periodsWithData,
    required this.masked,
  });

  final bool showTrend;
  final double average;
  final String highLabel;
  final double highValue;
  final int periodsWithData;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = showTrend
        ? '${l.insAverageValue(money(average, masked: masked))}'
            ' · ${l.insHighest(highLabel, money(highValue, masked: masked))}'
            ' · ${l.insEmptyMonthsExcluded}'
        : l.insTooFewPeriods(periodsWithData);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11, height: 1.0, color: AppColors.textTertiary)),
    );
  }
}
