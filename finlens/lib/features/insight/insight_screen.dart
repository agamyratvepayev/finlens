import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/range_picker_sheet.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';
import 'category_detail_screen.dart';
import 'see_all_screen.dart';

/// Insight — the money-flow report.
///
/// **Ledger says *how much*. Insight says *where from, where to, and what it did
/// to what you own.*** Its one job that no other tab can do is to report the
/// revaluation that `TxnType.rebalance` deliberately keeps out of every
/// income/expense metric: the Ledger truthfully says `IN · OUT · LEFT` and never
/// mentions that gold and stocks moved, yet net worth did. That gap is this tab.
///
/// Insight owns its OWN window (spec §2) — stepping it never touches
/// `store.period` or the Ledger's range lens. Everything here is `Container`s and
/// `Row`s; there is no charting package.
class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key});

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

/// Expense preview length, chosen so the next section's card edge is visible at
/// 390 × 844 — the reader must be able to see the page continues. Drops to 4 when
/// the contradiction warning is present (it eats one row of height).
const _kInsightPreviewRows = 5;

class _InsightScreenState extends State<InsightScreen> {
  DateRange? _window;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Land on the period containing today for the persisted unit; the cursor is
    // never persisted (spec §2.5).
    _window ??= currentPresetFor(StoreScope.read(context).insightPeriodUnit)
        .resolve(AppStore.today);
  }

  DateTime get _startOfToday =>
      DateTime(AppStore.today.year, AppStore.today.month, AppStore.today.day);

  /// A report of the past never looks forward: stepping stops at the period
  /// containing today (spec §2.1).
  bool get _canStepForward => _window!.end.isBefore(_startOfToday);

  void _step(int steps) {
    if (steps > 0 && !_canStepForward) return;
    HapticFeedback.lightImpact();
    setState(() => _window = _window!.copyShifted(steps));
  }

  Future<void> _pickRange() async {
    final store = StoreScope.read(context);
    final picked = await showRangePickerSheet(
      context,
      current: _window!,
      hasData: (day) =>
          store.ledgerDaysWithData(DateTime(day.year, day.month)).contains(day),
      countBetween: (from, to) =>
          store.txnsInWindow(DateRange(from, to)).length,
    );
    if (picked == null || !mounted) return;
    // A preset persists its unit; a custom range is a question, not a setting,
    // and persists nothing (spec §2.5). `allTime` has no unit, so it leaves the
    // stored unit untouched.
    final unit = picked.preset?.unit;
    if (unit != null) store.setInsightPeriodUnit(unit);
    setState(() => _window = picked);
  }

  void _clearCustom() {
    final store = StoreScope.read(context);
    setState(() => _window =
        currentPresetFor(store.insightPeriodUnit).resolve(AppStore.today));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final w = _window!;
    final report = _Report.of(store, w);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            titleWidget: HorizontalSectionSwipe(
              onNext: () => _step(1),
              onPrevious: () => _step(-1),
              child: _PeriodControl(
                label: _windowLabel(w, l),
                onTap: _pickRange,
              ),
            ),
            onAdd: () => showQuickAdd(context),
          ),
          if (w.preset == null)
            _CustomBadge(
              days: w.days,
              canForward: _canStepForward,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onClear: _clearCustom,
            ),
          Expanded(
            child: report.isEmpty
                ? _EmptyBody(report: report, window: w, onBack: () => _step(-1))
                : ListView(
                    padding: const EdgeInsets.only(bottom: Insets.xxl),
                    children: [
                      _Hero(report: report),
                      if (report.showWarning) _Warning(report: report),
                      _FlowBlock(
                        report: report,
                        income: false,
                        window: w,
                      ),
                      _FlowBlock(
                        report: report,
                        income: true,
                        window: w,
                      ),
                      _DebtBlock(report: report),
                      if (report.revalued != 0) _RevaluationBlock(report: report),
                      if (report.transfers.isNotEmpty)
                        _TransferFootnote(report: report),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The human label for the window: month presets read "August 2026" (not
/// "1–31 Aug"); the year reads "2026"; all-time reads its own word; everything
/// else uses the compressed day-range label.
String _windowLabel(DateRange w, AppLocalizations l) {
  switch (w.preset) {
    case RangePreset.thisMonth:
    case RangePreset.lastMonth:
      return monthYearLong(w.start, l);
    case RangePreset.thisYear:
      return '${w.start.year}';
    case RangePreset.allTime:
      return l.rangeAllTime;
    case RangePreset.thisWeek:
    case RangePreset.lastWeek:
    case RangePreset.last3Months:
    case null:
      return w.label(AppStore.today, l);
  }
}

// ── The report ───────────────────────────────────────────────────────────────
// Computed once per build (spec §1 performance note) and passed down, so the
// nine-pass hero math never runs inside a row builder.

class _Report {
  _Report({
    required this.store,
    required this.window,
    required this.netChange,
    required this.nwBefore,
    required this.nwAfter,
    required this.inflow,
    required this.outflow,
    required this.revalued,
    required this.leak,
    required this.groupChanges,
    required this.incomeRows,
    required this.expenseRows,
    required this.debtNow,
    required this.debtDelta,
    required this.creditNow,
    required this.creditDelta,
    required this.charged,
    required this.paid,
    required this.revaluations,
    required this.transfers,
  });

  final AppStore store;
  final DateRange window;
  final double netChange;
  final double nwBefore;
  final double nwAfter;
  final double inflow;
  final double outflow;
  final double revalued;
  final double leak;

  /// (group, change) in declaration order, non-zero only.
  final List<(AccountGroup, double)> groupChanges;

  /// (category, amount) descending.
  final List<(Category?, String, double)> incomeRows;
  final List<(Category?, String, double)> expenseRows;

  final double debtNow;
  final double debtDelta;
  final double creditNow;
  final double creditDelta;
  final double charged;
  final double paid;
  final List<Txn> revaluations;
  final List<Txn> transfers;

  bool get isEmpty => store.txnsInWindow(window).isEmpty;

  bool get showWarning {
    final spentMoreThanEarned = outflow > inflow;
    final netWorthRose = netChange > 0;
    return spentMoreThanEarned == netWorthRose; // they disagree
  }

  static const _eps = 0.005;

  static _Report of(AppStore store, DateRange w) {
    final startDay = DateTime(w.start.year, w.start.month, w.start.day);
    final before = startDay.subtract(const Duration(days: 1));

    final flow = store.categoryFlowInWindow(w);
    List<(Category?, String, double)> rows(Map<String, double> m) {
      final out = <(Category?, String, double)>[];
      m.forEach((id, amount) {
        if (amount.abs() < _eps) return;
        final cat = store.categoryById(id);
        out.add((cat, cat?.name ?? '—', amount));
      });
      out.sort((a, b) => b.$3.compareTo(a.$3));
      return out;
    }

    final groupChanges = <(AccountGroup, double)>[];
    for (final g in AccountGroup.values) {
      final c = store.groupChangeInWindow(g, w);
      if (c.abs() >= _eps) groupChanges.add((g, c));
    }

    return _Report(
      store: store,
      window: w,
      netChange: store.netWorthChangeInWindow(w),
      nwBefore: store.netWorthOn(before),
      nwAfter: store.netWorthOn(w.end),
      inflow: store.inflowInWindow(w),
      outflow: store.outflowInWindow(w),
      revalued: store.revaluedInWindow(w),
      leak: store.transferLeakInWindow(w),
      groupChanges: groupChanges,
      incomeRows: rows(flow.income),
      expenseRows: rows(flow.expense),
      debtNow: store.totalLiabilitiesOn(w.end),
      debtDelta:
          store.totalLiabilitiesOn(w.end) - store.totalLiabilitiesOn(before),
      creditNow: store.totalReceivablesOn(w.end),
      creditDelta:
          store.totalReceivablesOn(w.end) - store.totalReceivablesOn(before),
      charged: store.chargedToCardsInWindow(w),
      paid: store.paidToLiabilitiesInWindow(w),
      revaluations: store.revaluationsInWindow(w),
      transfers: store.transfersInWindow(w),
    );
  }
}

// ── Period control (spec §2.1) ───────────────────────────────────────────────

class _PeriodControl extends StatelessWidget {
  const _PeriodControl({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomBadge extends StatelessWidget {
  const _CustomBadge({
    required this.days,
    required this.canForward,
    required this.onPrev,
    required this.onNext,
    required this.onClear,
  });

  final int days;
  final bool canForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.sm),
      child: Row(
        children: [
          _Chevron(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: Insets.xs),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.accent, 0.16),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              l.insCustomRange(days).toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accentLight,
              ),
            ),
          ),
          const SizedBox(width: Insets.xs),
          _Chevron(
            icon: Icons.chevron_right_rounded,
            onTap: canForward ? onNext : null,
          ),
          const Spacer(),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(l.insClearRange,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(icon,
          size: 20,
          color: onTap == null ? AppColors.stepperDisabled : AppColors.textSecondary),
    );
  }
}

// ── ① Net worth hero ─────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = report.netChange;
    final zero = v.abs() < 0.005;
    final color = zero
        ? AppColors.textQuaternary
        : (v > 0 ? AppColors.positive : AppColors.negative);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (!zero)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(v > 0 ? '▲' : '▼',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                AmountText(v.abs(),
                    style: AppText.hero.copyWith(fontSize: 34), color: color),
                const SizedBox(width: Insets.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l.insNetWorthCaption,
                      style:
                          const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              AmountText.balance(report.nwBefore,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 12, color: AppColors.textTertiary),
              ),
              AmountText.balance(report.nwAfter,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: Insets.md),
          _GroupStack(changes: report.groupChanges),
          const SizedBox(height: Insets.sm),
          _Legend(changes: report.groupChanges),
          const SizedBox(height: Insets.md),
          _ThreeUp(report: report),
        ],
      ),
    );
  }
}

class _GroupStack extends StatelessWidget {
  const _GroupStack({required this.changes});
  final List<(AccountGroup, double)> changes;

  @override
  Widget build(BuildContext context) {
    final positives = changes.where((e) => e.$2 > 0).toList();
    final negatives = changes.where((e) => e.$2 < 0).toList();
    final segments = <Widget>[];

    void addRun(List<(AccountGroup, double)> run, {required bool negative}) {
      for (var i = 0; i < run.length; i++) {
        if (segments.isNotEmpty) {
          segments.add(const SizedBox(width: 2)); // gap in the page background
        }
        segments.add(Expanded(
          flex: (run[i].$2.abs() * 1000).round().clamp(1, 1000000),
          child: ColoredBox(
              color: negative ? AppColors.negative : run[i].$1.color),
        ));
      }
    }

    addRun(positives, negative: false);
    if (positives.isNotEmpty && negatives.isNotEmpty) {
      segments.add(const SizedBox(width: 2)); // the deliberate positive↔negative gap
    }
    addRun(negatives, negative: true);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: segments.isEmpty
            ? const ColoredBox(color: AppColors.surfaceHigh)
            : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: segments),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.changes});
  final List<(AccountGroup, double)> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    // Max three named; a fourth and beyond collapse into ● Other ±$n.
    final named = changes.take(3).toList();
    final rest = changes.skip(3).toList();

    return Wrap(
      spacing: Insets.md,
      runSpacing: 4,
      children: [
        for (final (g, c) in named)
          _LegendItem(color: g.color, label: g.label(l), amount: c),
        if (rest.isNotEmpty)
          _LegendItem(
            color: AppColors.textTertiary,
            label: l.insOther,
            amount: rest.fold(0.0, (s, e) => s + e.$2),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        AmountText(amount,
            showSign: true,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// The three-up strip. It has the shape of Ledger's `IN / OUT / LEFT` strip, and
/// its third column — DEĞERLENDİ — is different on purpose: it is the revaluation
/// the Ledger can never show. The column renders even at $0; its absence would
/// read as "no such thing", and the whole point is that the thing exists.
class _ThreeUp extends StatelessWidget {
  const _ThreeUp({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('ins-threeup'),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _col(l.insIn.toUpperCase(), report.inflow),
          _col(l.insOut.toUpperCase(), report.outflow),
          _col(l.insRevalued.toUpperCase(), report.revalued),
        ],
      ),
    );
  }

  Widget _col(String label, double value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(value,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      );
}

class _Warning extends StatelessWidget {
  const _Warning({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gap = (report.outflow - report.inflow).abs();
    final first = report.netChange > 0
        ? l.insContradictionUp(money(gap, masked: report.store.masked))
        : l.insContradictionDown(money(gap, masked: report.store.masked));

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.warning, 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tint(AppColors.warning, 0.28), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1, right: 8),
              child: Icon(Icons.warning_amber_rounded,
                  size: 15, color: AppColors.warning),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$first '),
                  if (report.revalued != 0)
                    TextSpan(text: l.insContradictionRevalued),
                ]),
                style: const TextStyle(
                    fontSize: 11.5, height: 1.3, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ② Gelir · ③ Gider ────────────────────────────────────────────────────────

class _FlowBlock extends StatelessWidget {
  const _FlowBlock({
    required this.report,
    required this.income,
    required this.window,
  });

  final _Report report;
  final bool income;
  final DateRange window;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = income ? report.incomeRows : report.expenseRows;
    if (rows.isEmpty) return const SizedBox.shrink();

    final total = rows.fold(0.0, (s, r) => s + r.$3);
    final previewCount = income
        ? rows.length
        : (report.showWarning ? _kInsightPreviewRows - 1 : _kInsightPreviewRows);
    final shown = rows.take(previewCount).toList();
    final hasMore = rows.length > shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          income ? l.insIncome : l.insSpending,
          trailing: AmountText(total,
              style: AppText.amount.copyWith(fontSize: 15)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
                  child: _StackedBar(rows: rows, total: total),
                ),
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 47),
                  _CategoryRow(
                    key: Key(income ? 'ins-incrow-$i' : 'ins-exprow-$i'),
                    cat: shown[i].$1,
                    name: shown[i].$2,
                    amount: shown[i].$3,
                    total: total,
                    onTap: shown[i].$1 == null
                        ? null
                        : () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailScreen(
                                  categoryId: shown[i].$1!.id,
                                  window: window,
                                ),
                              ),
                            ),
                  ),
                ],
                if (hasMore)
                  _InsightFoot(
                    text: l.insSeeAll(rows.length),
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SeeAllScreen(
                          income: income,
                          window: window,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacked bar whose segment widths are each category's share of the BLOCK
/// total — never of the largest row. A month where one category is 90% must look
/// different from a month where five are 20% each.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.rows, required this.total});
  final List<(Category?, String, double)> rows;
  final double total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: total <= 0
            ? const ColoredBox(color: AppColors.surfaceHigh)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: (rows[i].$3 / total * 1000).round().clamp(1, 1000000),
                      child: ColoredBox(
                          color: rows[i].$1?.color ?? AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.cat,
    required this.name,
    required this.amount,
    required this.total,
    this.onTap,
  });

  final Category? cat;
  final String name;
  final double amount;
  final double total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : amount / total;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            IconTile(cat?.icon ?? Icons.help_outline_rounded,
                color: cat?.color ?? AppColors.textTertiary, size: 24),
            const SizedBox(width: 11),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                      fontSize: 14,
                      color: cat == null ? AppColors.textTertiary : null)),
            ),
            AmountText(amount,
                style: AppText.amount.copyWith(fontSize: 14)),
            const SizedBox(width: Insets.sm),
            SizedBox(
              width: 36,
              child: Text(percent(pct, decimals: 0),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// The card-bottom strip used everywhere in this module: 30 pt, centred, one
/// line, 0.5 pt top rule.
class _InsightFoot extends StatelessWidget {
  const _InsightFoot({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('ins-foot'),
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: onTap == null
                          ? AppColors.textSecondary
                          : AppColors.accentLight)),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.accentLight),
          ],
        ),
      ),
    );
  }
}

// ── ④ Borç & Alacak ──────────────────────────────────────────────────────────

class _DebtBlock extends StatelessWidget {
  const _DebtBlock({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasDebt = report.debtNow.abs() >= 0.005 || report.debtDelta.abs() >= 0.005;
    final hasCredit =
        report.creditNow.abs() >= 0.005 || report.creditDelta.abs() >= 0.005;
    if (!hasDebt && !hasCredit) return const SizedBox.shrink();

    final rows = <Widget>[];
    if (report.charged.abs() >= 0.005) {
      rows.add(_movementRow(
        context,
        icon: Icons.credit_card_rounded,
        title: l.insChargedToCards,
        amount: report.charged,
        showSign: false, // a positive magnitude — "$930", not "+$930"
      ));
    }
    if (report.paid.abs() >= 0.005) {
      if (rows.isNotEmpty) rows.add(const RowDivider(indent: 47));
      rows.add(_movementRow(
        context,
        icon: Icons.reply_rounded,
        title: l.insCardPayment,
        amount: -report.paid, // a payment out of cash into the debt — "−$500"
        showSign: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          l.insDebtCredit,
          trailing: _DeltaTag(value: report.debtDelta, isLiability: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                IntrinsicHeight(
                  key: const Key('ins-debtcells'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DebtCell(
                          label: l.insYourDebt,
                          value: report.debtNow,
                          delta: report.debtDelta,
                          isLiability: true,
                        ),
                      ),
                      const VerticalDivider(width: 0.5, thickness: 0.5, color: AppColors.divider),
                      Expanded(
                        child: _DebtCell(
                          label: l.insYourCredit,
                          value: report.creditNow,
                          delta: report.creditDelta,
                          isLiability: false,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rows.isNotEmpty) const RowDivider(),
                ...rows,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _movementRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double amount,
    required bool showSign,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          IconTile(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 14)),
          ),
          AmountText(amount,
              showSign: showSign, style: AppText.amount.copyWith(fontSize: 14)),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _DebtCell extends StatelessWidget {
  const _DebtCell({
    required this.label,
    required this.value,
    required this.delta,
    required this.isLiability,
  });

  final String label;
  final double value;
  final double delta;
  final bool isLiability;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unchanged = delta.abs() < 0.5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText.balance(value,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
              const SizedBox(width: 6),
              if (unchanged)
                Text(l.insUnchanged,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
              else
                _DeltaTag(value: delta, isLiability: isLiability),
            ],
          ),
        ],
      ),
    );
  }
}

/// ▲/▼ + amount, coloured by good/bad (arrows carry direction, colour carries
/// good/bad — spec "Yön ≠ renk"). A growing debt is a red ▲; a shrinking one a
/// green ▼.
class _DeltaTag extends StatelessWidget {
  const _DeltaTag({required this.value, required this.isLiability});
  final double value;
  final bool isLiability;

  @override
  Widget build(BuildContext context) {
    if (value.abs() < 0.5) return const SizedBox.shrink();
    final rising = value > 0;
    final good = isLiability ? !rising : rising;
    final color = good ? AppColors.positive : AppColors.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rising ? '▲' : '▼', style: TextStyle(fontSize: 9, color: color)),
        const SizedBox(width: 1),
        AmountText(value.abs(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

// ── ⑤ Değer değişimi ─────────────────────────────────────────────────────────

class _RevaluationBlock extends StatelessWidget {
  const _RevaluationBlock({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final total = report.revalued;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          l.insRevaluation,
          trailing: _DeltaTag(value: total, isLiability: false),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < report.revaluations.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 47),
                  _revalRow(context, store, report.revaluations[i]),
                ],
                _InsightFoot(
                  text: total >= 0
                      ? l.insUntouchedGained(money(total, masked: store.masked))
                      : l.insUntouchedLost(money(total.abs(), masked: store.masked)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _revalRow(BuildContext context, AppStore store, Txn t) {
    final l = AppLocalizations.of(context);
    final acc = store.accountById(t.toRef);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          IconTile(acc?.displayIcon ?? Icons.donut_large_rounded,
              color: acc?.color ?? AppColors.rebalance, size: 24),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc?.name ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 14)),
                Text('${dayMonth(t.date, l)}${t.note.isEmpty ? '' : ' · ${t.note}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
              ],
            ),
          ),
          AmountText(t.amount,
              showSign: true,
              color: t.amount >= 0 ? AppColors.positive : AppColors.negative,
              style: AppText.amount.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

// ── The transfer footnote ────────────────────────────────────────────────────
// Not a block. Moving money between two of your own accounts is not a financial
// event; its only real content is the leak.

class _TransferFootnote extends StatelessWidget {
  const _TransferFootnote({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = report.store;

    // Card/liability payments are re-homed to the debt block (§3.3, §3.5), so the
    // footnote is about the transfers that are genuinely "between your own
    // accounts" — a currency swap, a move between two cash accounts. The leak,
    // however, is the true total over every transfer (a card payment leaks 0, so
    // report.leak already equals the swap-only leak).
    final swaps = report.transfers
        .where((t) => !(store.accountById(t.toRef)?.group.isLiability ?? false))
        .toList();
    if (swaps.isEmpty) return const SizedBox.shrink();

    final moved =
        swaps.fold(0.0, (s, t) => s + Fx.toBase(t.amount, t.currency));

    final detail = swaps.length == 1
        ? (swaps.first.note.isEmpty ? null : swaps.first.note)
        : l.insTransferCount(swaps.length);

    final parts = <String>[
      l.insTransferFootnote(money(moved, masked: store.masked)),
      if (detail != null) '($detail)',
    ];
    var line = parts.join(' ');
    if (report.leak >= 0.005) {
      line = '$line · ${l.insFee(money(report.leak, masked: store.masked))}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(line,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.3, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (spec §8) ────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.report, required this.window, required this.onBack});
  final _Report report;
  final DateRange window;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prevLabel = _windowLabel(window.copyShifted(-1), l);

    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        // Zero is an answer: the hero, before→after and three-up stay, faded.
        Opacity(opacity: 0.45, child: _Hero(report: report)),
        const SizedBox(height: Insets.xl),
        Center(
          child: Text(l.insNoRecords,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: Insets.md),
        Center(
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(l.insBackToPeriod(prevLabel)),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
          ),
        ),
      ],
    );
  }
}
