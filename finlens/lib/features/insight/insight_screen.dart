import 'dart:math' as math;

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
import '../../shared/widgets/undo_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_filter.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'category_detail_screen.dart';
import 'insight_filter.dart';
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
/// `store.period` or the Ledger's range lens. Everything here is `Container`s in
/// `Stack`s and `Row`s; there is no charting package.
///
/// The rule this screen applies (second spec): every element carries a number the
/// reader cannot get anywhere else on the screen, or it is gone. Nothing here
/// explains itself in a sentence.
class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key});

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

/// Expense preview length, chosen so the next section's card edge is visible at
/// 390 × 844 — the reader must be able to see the page continues.
const _kInsightPreviewRows = 5;

class _InsightScreenState extends State<InsightScreen> {
  /// Whether the group grid is showing every mover (spec §5.2). Resets whenever
  /// the window changes — a set of movers named for August is not the set for
  /// July, so a stale "expanded" flag would be a lie. Local view state; the
  /// window itself now lives in the store (spec §6.1).
  bool _gridExpanded = false;

  DateTime get _startOfToday =>
      DateTime(AppStore.today.year, AppStore.today.month, AppStore.today.day);

  /// A report of the past never looks forward: stepping stops at the period
  /// containing today (spec §2.1).
  bool _canStepForward(DateRange w) => w.end.isBefore(_startOfToday);

  void _step(int steps) {
    final store = StoreScope.read(context);
    final w = store.insightWindow;
    if (steps > 0 && !_canStepForward(w)) return;
    HapticFeedback.lightImpact();
    store.setInsightWindow(w.copyShifted(steps));
    setState(() => _gridExpanded = false);
  }

  Future<void> _pickRange() async {
    final store = StoreScope.read(context);
    // The calendar counts what the report will render, not the raw totals: with
    // accounts hidden, its dots and bottom-bar count must match the filtered
    // report (spec §1.3). A txn "counts" when it touches a visible account.
    final filter = store.insightAccountFilter;
    final visible = filter.isActive ? filter.visibleAccountIds(store) : null;
    bool touchesVisible(Txn t) =>
        visible == null ||
        visible.contains(t.fromRef) ||
        visible.contains(t.toRef);
    final picked = await showRangePickerSheet(
      context,
      current: store.insightWindow,
      firstData: store.firstTxnDate,
      hasData: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return store
            .txnsInWindow(DateRange(
                d, DateTime(d.year, d.month, d.day, 23, 59, 59, 999)))
            .any(touchesVisible);
      },
      countBetween: (from, to) =>
          store.txnsInWindow(DateRange(from, to)).where(touchesVisible).length,
    );
    if (picked == null || !mounted) return;
    // A preset persists its unit; a custom range is a question, not a setting,
    // and persists nothing (spec §2.5). `allTime` has no unit, so it leaves the
    // stored unit untouched.
    final unit = picked.preset?.unit;
    if (unit != null) store.setInsightPeriodUnit(unit);
    store.setInsightWindow(picked);
    setState(() => _gridExpanded = false);
  }

  void _clearCustom() {
    final store = StoreScope.read(context);
    store.setInsightWindow(
        currentPresetFor(store.insightPeriodUnit).resolve(AppStore.today));
    setState(() => _gridExpanded = false);
  }

  void _openFilter() =>
      showInsightFilterSheet(context, StoreScope.read(context).insightWindow);

  /// Quick Add records what happened, not what the reader is viewing: the sheet
  /// keeps its `today` default (spec §8). But a record that lands outside the
  /// window makes nothing on screen change, which reads as a failed save — so if
  /// the total grew while the windowed count did not, show a transient bar
  /// naming the date and offering to move the window to contain it.
  Future<void> _add() async {
    final store = StoreScope.read(context);
    final window = store.insightWindow;
    final beforeIds = store.txns.map((t) => t.id).toSet();
    final beforeWindow = store.txnsInWindow(window).length;

    await showQuickAdd(context);
    if (!mounted) return;

    final added =
        store.txns.where((t) => !beforeIds.contains(t.id)).toList();
    final afterWindow = store.txnsInWindow(window).length;
    if (added.isEmpty || afterWindow != beforeWindow) return;

    // A record landed outside the window. Name its date and offer to go there —
    // the period (in the current unit) containing it.
    final landed = added.first.date;
    final l = AppLocalizations.of(context);
    final target = currentPresetFor(store.insightPeriodUnit)
        .resolve(DateTime(landed.year, landed.month, landed.day));
    showUndoBar(
      context,
      message: l.insSavedOutsideWindow(dayMonth(landed, l)),
      actionLabel: l.insGoToDate,
      onUndo: () => store.setInsightWindow(target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final w = store.insightWindow;
    final report = _Report.of(store, w);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _InsightHeader(
            label: insightWindowLabel(w, l),
            isCustom: w.preset == null,
            filterActive: report.filterActive,
            hiddenCount: report.hiddenCount,
            onTapTitle: _pickRange,
            onNext: () => _step(1),
            onPrevious: () => _step(-1),
            onClearCustom: _clearCustom,
            onFilter: _openFilter,
            onAdd: _add,
          ),
          Expanded(
            child: report.everythingHidden
                ? _EverythingHiddenBody(
                    onShowAll: () => StoreScope.read(context)
                        .setInsightAccountFilter(const BalanceFilter()))
                : report.isEmpty
                    ? _EmptyBody(
                        report: report, window: w, onBack: () => _step(-1))
                    : ListView(
                    padding: const EdgeInsets.only(bottom: Insets.xxl),
                    children: [
                      _Hero(report: report),
                      _Waterfall(report: report),
                      _GroupGrid(
                        report: report,
                        expanded: _gridExpanded,
                        onToggle: () =>
                            setState(() => _gridExpanded = !_gridExpanded),
                      ),
                      _FlowBlock(report: report, income: false),
                      _FlowBlock(report: report, income: true),
                      _DebtBlock(report: report, window: w),
                      if (report.revalued != 0)
                        _RevaluationBlock(report: report, window: w),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}


// ── The report ───────────────────────────────────────────────────────────────
// Computed once per build (spec §1 performance note) and passed down, so the
// windowed store passes never run inside a row builder. Every figure is on the
// visible set — with the account filter active, [visible] is that set; with it
// empty, [visible] is null so every getter is bit-identical to the unfiltered
// build (spec §9.2).

class _Report {
  _Report({
    required this.store,
    required this.window,
    required this.visible,
    required this.filterActive,
    required this.hiddenCount,
    required this.netChange,
    required this.nwBefore,
    required this.nwAfter,
    required this.inflow,
    required this.outflow,
    required this.revalued,
    required this.moved,
    required this.leak,
    required this.groupChanges,
    required this.maxGroupAbs,
    required this.everythingHidden,
    required this.incomeRows,
    required this.expenseRows,
    required this.debtNow,
    required this.debtDelta,
    required this.creditNow,
    required this.creditDelta,
    required this.charged,
    required this.paid,
    required this.revaluations,
    required this.empty,
  });

  final AppStore store;
  final DateRange window;

  /// The visible account set — null when the filter is empty (spec §9.2).
  final Set<String>? visible;
  final bool filterActive;
  final int hiddenCount;

  final double netChange;
  final double nwBefore;
  final double nwAfter;
  final double inflow;
  final double outflow;
  final double revalued;

  /// The MOVED step (spec §9.3) — non-zero only when the filter is active and a
  /// transfer crosses the boundary.
  final double moved;
  final double leak;

  /// (group, change) in declaration order, non-zero only.
  final List<(AccountGroup, double)> groupChanges;

  /// Max |change| over EVERY mover in the window (shown or hidden), so expanding
  /// the grid never rescales a bar (spec §5.1).
  final double maxGroupAbs;

  /// The account filter hid *every* account — a distinct state from an empty
  /// window (spec §2.6): there are records, the reader hid them.
  final bool everythingHidden;

  /// (category, name, amount) descending.
  final List<(Category?, String, double)> incomeRows;
  final List<(Category?, String, double)> expenseRows;

  final double debtNow;
  final double debtDelta;
  final double creditNow;
  final double creditDelta;
  final double charged;
  final double paid;
  final List<Txn> revaluations;

  final bool empty;
  bool get isEmpty => empty;

  static const eps = 0.005;

  static _Report of(AppStore store, DateRange w) {
    final filter = store.insightAccountFilter;
    final active = filter.isActive;
    // Null when inactive → every getter takes its unfiltered path, so an empty
    // filter is bit-identical to no filter (spec §9.1 / §15).
    final visible = active ? filter.visibleAccountIds(store) : null;
    // The active glyph fills for EITHER filter (spec §2.5); the category filter
    // never reaches these figures (spec §2.1), only the header signal.
    final catHidden = store.insightCategoryFilter;
    final anyActive = active || catHidden.isNotEmpty;

    final startDay = DateTime(w.start.year, w.start.month, w.start.day);
    final before = startDay.subtract(const Duration(days: 1));
    // `now` anchors to today, never the future — a report of the past does not
    // claim data it cannot have (spec §4.2).
    final nowAnchor = w.end.isAfter(AppStore.today) ? AppStore.today : w.end;

    final flow = store.categoryFlowInWindow(w, visible: visible);
    List<(Category?, String, double)> rows(Map<String, double> m) {
      final out = <(Category?, String, double)>[];
      m.forEach((id, amount) {
        if (amount.abs() < eps) return;
        final cat = store.categoryById(id);
        out.add((cat, cat?.name ?? '—', amount));
      });
      out.sort((a, b) => b.$3.compareTo(a.$3));
      return out;
    }

    final groupChanges = <(AccountGroup, double)>[];
    var maxAbs = 0.0;
    for (final g in AccountGroup.values) {
      final c = store.groupChangeInWindow(g, w, visible: visible);
      if (c.abs() >= eps) {
        groupChanges.add((g, c));
        maxAbs = math.max(maxAbs, c.abs());
      }
    }

    return _Report(
      store: store,
      window: w,
      visible: visible,
      filterActive: anyActive,
      hiddenCount:
          (active ? filter.hiddenItemCount(store) : 0) + catHidden.length,
      everythingHidden: active && visible != null && visible.isEmpty,
      netChange: store.netWorthChangeInWindow(w, visible: visible),
      nwBefore: store.netWorthOn(before, visible: visible),
      nwAfter: store.netWorthOn(nowAnchor, visible: visible),
      inflow: store.inflowInWindow(w, visible: visible),
      outflow: store.outflowInWindow(w, visible: visible),
      revalued: store.revaluedInWindow(w, visible: visible),
      moved: store.movedAcrossFilterInWindow(w, visible: visible),
      leak: store.transferLeakInWindow(w, visible: visible),
      groupChanges: groupChanges,
      maxGroupAbs: maxAbs,
      incomeRows: rows(flow.income),
      expenseRows: rows(flow.expense),
      debtNow: store.totalLiabilitiesOn(nowAnchor, visible: visible),
      debtDelta: store.totalLiabilitiesOn(nowAnchor, visible: visible) -
          store.totalLiabilitiesOn(before, visible: visible),
      creditNow: store.totalReceivablesOn(nowAnchor, visible: visible),
      creditDelta: store.totalReceivablesOn(nowAnchor, visible: visible) -
          store.totalReceivablesOn(before, visible: visible),
      charged: store.chargedToCardsInWindow(w, visible: visible),
      paid: store.paidToLiabilitiesInWindow(w, visible: visible),
      revaluations: store.revaluationsInWindow(w, visible: visible),
      // Empty is about the window, not the filter — zero is an answer (spec §12).
      empty: store.txnsInWindow(w).isEmpty,
    );
  }
}

// ── Header (spec §2) ─────────────────────────────────────────────────────────
// Cloned from the Ledger's header rather than extended onto ScreenHeader: this
// row carries THREE tools (filter, eye, add) plus an optional custom-range clear,
// which ScreenHeader's single `trailing` slot cannot express without changing
// every other caller.

class _InsightHeader extends StatelessWidget {
  const _InsightHeader({
    required this.label,
    required this.isCustom,
    required this.filterActive,
    required this.hiddenCount,
    required this.onTapTitle,
    required this.onNext,
    required this.onPrevious,
    required this.onClearCustom,
    required this.onFilter,
    required this.onAdd,
  });

  final String label;
  final bool isCustom;
  final bool filterActive;
  final int hiddenCount;
  final VoidCallback onTapTitle;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClearCustom;
  final VoidCallback onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: HorizontalSectionSwipe(
              onNext: onNext,
              onPrevious: onPrevious,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: onTapTitle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Row(
                    // The chevron aligns to the CENTRE of the title, not its
                    // baseline — a baseline-aligned chevron sits visibly below
                    // the word.
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            // A custom range recolours the title accent (spec §2).
                            color: isCustom
                                ? AppColors.accentLight
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          // The way out of the range lens sits beside the state it undoes (spec
          // §2, mirroring the Ledger's ×): only present for a custom range.
          if (isCustom) ...[
            _CircleButton(
              icon: Icons.close_rounded,
              tint: AppColors.accentLight,
              tooltip: l.insClearCustomRange,
              onTap: onClearCustom,
            ),
            const SizedBox(width: 7),
          ],
          Semantics(
            value: filterActive ? l.insFilterActive(hiddenCount) : l.insFilterOff,
            child: _CircleButton(
              icon: filterActive
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              // Active mirrors the `+` treatment: accent fill, white glyph — the
              // only visual cue that the report is filtered (spec §2).
              accent: filterActive,
              tint: filterActive ? Colors.white : AppColors.textSecondary,
              tooltip: l.insFilterAccounts,
              onTap: onFilter,
            ),
          ),
          const SizedBox(width: 7),
          _CircleButton(
            icon: store.masked
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            tint: AppColors.textSecondary,
            onTap: store.toggleMasked,
          ),
          const SizedBox(width: 7),
          _CircleButton(
            icon: Icons.add_rounded,
            accent: true,
            tint: Colors.white,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

/// A 26pt circular tool button — Insight's header clone (spec §2/§13). Smaller
/// than the shared [ScreenHeader]'s 36pt so four of them fit beside a long month
/// at 320pt.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
    this.accent = false,
    this.tint,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;
  final Color? tint;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: accent ? AppColors.accent : AppColors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon,
              size: accent ? 17 : 16, color: tint ?? AppColors.textPrimary),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The distinct "everything hidden" state (spec §2.6): there are records, the
/// reader hid them, so this must not fall through to the ordinary empty state.
class _EverythingHiddenBody extends StatelessWidget {
  const _EverythingHiddenBody({required this.onShowAll});
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: Insets.xxl),
      children: [
        Center(
          child: Text(l.insEverythingHidden,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: Insets.md),
        Center(
          child: TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
            child: Text(l.insShowAllAccounts),
          ),
        ),
      ],
    );
  }
}

// ── ① Net worth hero (spec §3) ───────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.report});
  final _Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final v = report.netChange;
    final zero = v.abs() < _Report.eps;
    final color = zero
        ? AppColors.textQuaternary
        : (v > 0 ? AppColors.positive : AppColors.negative);

    final spoken = money(v.abs(), masked: store.masked);
    final sentence = zero
        ? l.insA11yHeroFlat(spoken)
        : (v > 0 ? l.insA11yHeroUp(spoken) : l.insA11yHeroDown(spoken));

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
      child: Semantics(
        container: true,
        label: sentence,
        child: ExcludeSemantics(
          child: FittedBox(
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
                  // "net worth", not "your net worth" (spec §3).
                  child: Text(l.insNetWorthCaption,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ② The waterfall (spec §4) ────────────────────────────────────────────────
// Replaces the before→after row and the IN/OUT/REVALUED strip. Each bar's top
// and bottom are cumulative positions, not magnitudes from a shared baseline —
// that is what makes it a waterfall and not three columns. `NOW` is drawn at the
// true net worth, not the cumulative total: the two differ by the transfer leak
// (the fee/FX gap that belongs to no step — $3.30 on the seed's August, 0.03pt),
// which must NOT be folded into OUT or closed by moving the NOW line (spec §4.2).

class _Waterfall extends StatelessWidget {
  const _Waterfall({required this.report});
  final _Report report;

  static const double _bandH = 64;
  static const double _labelBandH = 14;
  static const double _totalH = _labelBandH + _bandH + _labelBandH; // 92

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = report.store;

    final before = report.nwBefore;
    final l1 = before + report.inflow;
    final l2 = l1 - report.outflow;
    final l3 = l2 + report.revalued;
    final showMoved = report.filterActive && report.moved.abs() >= _Report.eps;
    final l4 = l3 + report.moved;
    final now = report.nwAfter;

    final levels = <double>[before, l1, l2, l3, if (showMoved) l4, now];
    var lo = levels.reduce(math.min);
    var hi = levels.reduce(math.max);
    var range = hi - lo;
    if (range < 1e-6) {
      // A flat window would divide by zero; give it a nominal span so the two
      // level lines sit mid-band rather than stacking.
      range = 1;
      lo -= 0.5;
      hi += 0.5;
    }
    double yTop(double v) => _bandH * (1 - (v - lo) / range);

    final heroColor = report.netChange.abs() < _Report.eps
        ? AppColors.textQuaternary
        : (report.netChange > 0 ? AppColors.positive : AppColors.negative);

    // Amounts honour the privacy eye; bar heights and the axis never change
    // (spec §12 — shape is not a secret).
    String m(double v, {bool sign = false}) =>
        money(v, masked: store.masked, showSign: sign);

    final sentence = showMoved
        ? l.insA11yWaterfallMoved(m(before), m(report.inflow), m(report.outflow),
            m(report.revalued), m(report.moved), m(now))
        : l.insA11yWaterfall(m(before), m(report.inflow), m(report.outflow),
            m(report.revalued), m(now));

    final columns = <Widget>[
      _endColumn(
        flex: 115,
        value: before,
        label: l.insBefore,
        lineColor: AppColors.textQuaternary,
        labelAbove: true,
        yTop: yTop,
        store: store,
      ),
      _stepColumn(
        flex: 100,
        from: before,
        to: l1,
        axis: l.insIn,
        value: report.inflow,
        color: AppColors.positive,
        yTop: yTop,
        store: store,
      ),
      _stepColumn(
        flex: 100,
        from: l1,
        to: l2,
        axis: l.insOut,
        value: -report.outflow,
        color: AppColors.negative,
        yTop: yTop,
        store: store,
      ),
      _stepColumn(
        flex: 100,
        from: l2,
        to: l3,
        axis: l.insRevalued,
        value: report.revalued,
        color: AppColors.investments,
        yTop: yTop,
        store: store,
      ),
      if (showMoved)
        _stepColumn(
          flex: 100,
          from: l3,
          to: l4,
          axis: l.insMoved,
          value: report.moved,
          // Neutral grey: the money is neither earned nor spent, only out of
          // view (spec §9.3).
          color: AppColors.textSecondary,
          yTop: yTop,
          store: store,
        ),
      _endColumn(
        flex: 115,
        value: now,
        label: l.insNow,
        lineColor: heroColor,
        labelAbove: false,
        yTop: yTop,
        store: store,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
        child: Semantics(
          container: true,
          label: sentence,
          child: ExcludeSemantics(
            child: SizedBox(
              key: const Key('ins-waterfall'),
              height: _totalH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    columns[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _endColumn({
    required int flex,
    required double value,
    required String label,
    required Color lineColor,
    required bool labelAbove,
    required double Function(double) yTop,
    required AppStore store,
  }) {
    final y = yTop(value).clamp(0.0, _bandH);
    // Keep the 10.5pt label (~13pt tall) inside the band, above or below the
    // line — a label below the low line would collide with the axis row.
    final labelTop = labelAbove
        ? (y - 14).clamp(0.0, _bandH - 13)
        : (y + 2).clamp(0.0, _bandH - 13);

    return Expanded(
      flex: flex,
      child: Column(
        children: [
          const SizedBox(height: _labelBandH),
          SizedBox(
            height: _bandH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (y - 1).clamp(0.0, _bandH - 2),
                  height: 2,
                  child: ColoredBox(color: lineColor),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: labelTop,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AmountText.balance(
                      value,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _axisLabel(label),
        ],
      ),
    );
  }

  Widget _stepColumn({
    required int flex,
    required double from,
    required double to,
    required String axis,
    required double value,
    required Color color,
    required double Function(double) yTop,
    required AppStore store,
  }) {
    final loV = math.min(from, to);
    final hiV = math.max(from, to);
    final top = yTop(hiV);
    final bottom = yTop(loV);
    var h = bottom - top;
    final nonZero = value.abs() >= _Report.eps;
    if (nonZero) h = math.max(3.0, h); // a small step must still be visible
    final barTop = (bottom - h).clamp(0.0, _bandH);

    return Expanded(
      flex: flex,
      child: Column(
        children: [
          SizedBox(
            height: _labelBandH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Signed so the steps read "+$6,100", "−$2,972", "+$1,300"; a
                // zero step reads "$0", never "+$0".
                child: AmountText(
                  value,
                  showSign: nonZero,
                  color: color,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: _bandH,
            child: Stack(
              children: [
                if (nonZero)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: barTop,
                    height: h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _axisLabel(axis),
        ],
      ),
    );
  }

  Widget _axisLabel(String text) => SizedBox(
        height: _labelBandH,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                // One step dimmer than the rest of the screen — these five words
                // never change; the numbers are what is read (spec §4.1).
                color: AppColors.textQuaternary,
              ),
            ),
          ),
        ),
      );
}

// ── ③ The group grid (spec §5) ───────────────────────────────────────────────

/// The movers the grid renders, and how many are hidden behind the link (spec
/// §5.2). Selection is by magnitude — six or more movers collapse to the four
/// largest by |change| — but the returned list stays in the caller's
/// (declaration) order, never magnitude order. Five or fewer, or expanded, show
/// everything. Pure and top-level so the selection can be tested against the old
/// `take(3)` bug directly.
({List<(AccountGroup, double)> shown, int hidden}) insightGridMovers(
  List<(AccountGroup, double)> movers, {
  required bool expanded,
}) {
  if (movers.length < 6 || expanded) return (shown: movers, hidden: 0);
  final largest = [...movers]..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
  final keep = largest.take(4).map((e) => e.$1).toSet();
  return (
    shown: movers.where((e) => keep.contains(e.$1)).toList(),
    hidden: movers.length - 4,
  );
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({
    required this.report,
    required this.expanded,
    required this.onToggle,
  });

  final _Report report;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final movers = report.groupChanges; // declaration order, non-zero
    if (movers.isEmpty) return const SizedBox.shrink();

    // Selection is by magnitude; rendering stays in declaration order (spec
    // §5.2). Six or more movers collapse to the four largest plus a link.
    final many = movers.length >= 6;
    final selection = insightGridMovers(movers, expanded: expanded);
    final shown = selection.shown;
    Widget? link;
    if (many && !expanded) {
      link = _link(l.insMore(selection.hidden));
    } else if (many && expanded) {
      link = _link(l.insShowLess);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCols = _fitsTwoColumns(
              shown, constraints.maxWidth, l, MediaQuery.textScalerOf(context));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (twoCols)
                ..._twoColumnRows(context, shown)
              else
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 11),
                  _cell(context, shown[i]),
                ],
              ?link,
            ],
          );
        },
      ),
    );
  }

  Widget _link(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.accentLight)),
          ),
        ),
      );

  List<Widget> _twoColumnRows(
      BuildContext context, List<(AccountGroup, double)> shown) {
    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 11));
      final left = _cell(context, shown[i]);
      final hasRight = i + 1 < shown.length;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(
              child: hasRight
                  ? _cell(context, shown[i + 1])
                  : const SizedBox.shrink()),
        ],
      ));
    }
    return rows;
  }

  /// Measure the widest name and amount; if a half-width cell cannot hold
  /// `name + gap + amount` without ellipsis, fall back to one column (spec §5.3).
  bool _fitsTwoColumns(List<(AccountGroup, double)> shown, double width,
      AppLocalizations l, TextScaler textScaler) {
    if (shown.length < 2) return false;
    const nameStyle = TextStyle(fontSize: 12.5);
    const amtStyle = TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        fontFeatures: [FontFeature.tabularFigures()]);
    double measure(String s, TextStyle st) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: st),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return tp.width;
    }

    var maxName = 0.0;
    var maxAmt = 0.0;
    for (final (g, c) in shown) {
      maxName = math.max(maxName, measure(g.label(l), nameStyle));
      maxAmt = math.max(
          maxAmt, measure(money(c.abs(), showSign: true), amtStyle));
    }
    const columnGap = 14.0;
    const innerGap = 8.0;
    final cellWidth = (width - columnGap) / 2;
    return maxName + innerGap + maxAmt <= cellWidth;
  }

  Widget _cell(BuildContext context, (AccountGroup, double) mover) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final (g, change) = mover;
    final negative = change < 0;
    final frac =
        report.maxGroupAbs <= 0 ? 0.0 : (change.abs() / report.maxGroupAbs);

    final spoken = money(change.abs(), masked: store.masked);
    final sentence = negative
        ? l.insA11yGroupDown(g.label(l), spoken)
        : l.insA11yGroupUp(g.label(l), spoken);

    return Semantics(
      container: true,
      button: true,
      label: sentence,
      child: ExcludeSemantics(
        child: InkWell(
          // GroupDetailScreen is never opened from Insight (spec §4.2): it
          // titles itself Assets, heroes a balance where the row showed a
          // change, and carries a delta from a comparison the reader never
          // chose. The scoped ledger's window IN/OUT subtract to the change the
          // row printed — which is the point of the tap.
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => ScopedLedgerScreen(
                initialScope: GroupScope(g),
                initialRange: report.window,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(4),
          // Intrinsic height (~21pt at 1.0 scale: a 12.5pt line + 5 + 3) rather
          // than a fixed box, so 130% text scale grows the cell instead of
          // overflowing it.
          child: Column(
            key: const Key('ins-gridcell'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.label(l),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.0,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AmountText(
                        change,
                        showSign: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 5),
              SizedBox(height: 3, child: _track(g.color, frac, negative)),
            ],
          ),
        ),
      ),
    );
  }

  /// The 3pt bar. Positive fills from the left, negative from the right; the
  /// sign is carried by direction and by the amount's sign — never by painting
  /// negatives red, which would make two liabilities look identical (spec §5.1).
  Widget _track(Color fill, double frac, bool negative) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final fillW = frac <= 0 ? 0.0 : math.max(3.0, frac * w);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            Positioned(
              left: negative ? null : 0,
              right: negative ? 0 : null,
              top: 0,
              bottom: 0,
              width: fillW,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── ④ Spending · ⑤ Income (spec §6) ──────────────────────────────────────────

class _FlowBlock extends StatelessWidget {
  const _FlowBlock({
    required this.report,
    required this.income,
  });

  final _Report report;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The full rows (account-filtered, unfiltered by category) are the base for
    // percentages and the See-all count. The category filter hides *labels*
    // (spec §2.1/§3): it drops rows from this list and its subtotal, but the
    // shares stay against the full total — hiding a category never inflates the
    // others (spec §5).
    final fullRows = income ? report.incomeRows : report.expenseRows;
    if (fullRows.isEmpty) return const SizedBox.shrink();

    final fullTotal = fullRows.fold(0.0, (s, r) => s + r.$3);
    final hidden = report.store.insightCategoryFilter;
    final rows = fullRows
        .where((r) => r.$1 == null || !hidden.contains(r.$1!.id))
        .toList();
    final displayTotal = rows.fold(0.0, (s, r) => s + r.$3);

    final previewCount = income ? rows.length : _kInsightPreviewRows;
    final shown = rows.take(previewCount).toList();
    // See-all opens the whole list (hidden categories included, with toggles),
    // so it appears whenever the full list is longer than the preview.
    final hasMore = fullRows.length > shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          income ? l.insIncome : l.insSpending,
          trailing: AmountText(displayTotal,
              style: AppText.amount.copyWith(fontSize: 15)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 47),
                  _CategoryRow(
                    key: Key(income ? 'ins-incrow-$i' : 'ins-exprow-$i'),
                    cat: shown[i].$1,
                    name: shown[i].$2,
                    amount: shown[i].$3,
                    total: fullTotal,
                    onTap: shown[i].$1 == null
                        ? null
                        : () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailScreen(
                                  categoryId: shown[i].$1!.id,
                                ),
                              ),
                            ),
                  ),
                ],
                if (hasMore)
                  _InsightFoot(
                    text: l.insSeeAll(fullRows.length),
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SeeAllScreen(income: income),
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
            AmountText(amount, style: AppText.amount.copyWith(fontSize: 14)),
            const SizedBox(width: Insets.sm),
            SizedBox(
              width: 36,
              child: Text(percent(pct, decimals: 0),
                  textAlign: TextAlign.right,
                  // The amount is what is read; the share is a detail the eye
                  // finds when it looks for it (spec §6).
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// The card-bottom strip: 30 pt, centred, one line, 0.5 pt top rule. Survives
/// only for the `See all` link now (spec §1).
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

// ── ⑥ Debt & credit (spec §7) ────────────────────────────────────────────────
// One list, not two cells. The two movement rows explain the DEBT side only;
// under a two-column header they appeared to belong to both.

class _DebtBlock extends StatelessWidget {
  const _DebtBlock({required this.report, required this.window});
  final _Report report;
  final DateRange window;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const eps = _Report.eps;

    final hasCharged = report.charged.abs() >= eps;
    final hasPaid = report.paid.abs() >= eps;
    final showDebt = report.debtNow.abs() >= eps ||
        report.debtDelta.abs() >= eps ||
        hasCharged ||
        hasPaid;
    final showCredit =
        report.creditNow.abs() >= eps || report.creditDelta.abs() >= eps;
    if (!showDebt && !showCredit) return const SizedBox.shrink();

    final rows = <Widget>[];
    if (showDebt) {
      rows.add(_sideRow(
        context,
        label: l.insYourDebt,
        balance: report.debtNow,
        delta: report.debtDelta,
        isLiability: true,
      ));
      if (hasCharged) {
        rows.add(_movementRow(
          context,
          title: l.insChargedToCards,
          // The debt grew: negative (bad), ▲ (up).
          value: report.charged,
          increased: true,
          // Charges are money leaving toward the cards (spec §4.2).
          flow: FlowKind.outflow,
        ));
      }
      if (hasPaid) {
        rows.add(_movementRow(
          context,
          title: l.insPaidToCards,
          // The debt shrank: positive (good), ▼ (down).
          value: -report.paid,
          increased: false,
          // Payments are money arriving at the cards (spec §4.2).
          flow: FlowKind.inflow,
        ));
      }
    }
    if (showCredit) {
      if (rows.isNotEmpty) rows.add(const RowDivider());
      rows.add(_sideRow(
        context,
        label: l.insYourCredit,
        balance: report.creditNow,
        delta: report.creditDelta,
        isLiability: false,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The section-header right edge is empty (spec §7): a delta there would
        // repeat the one printed 20pt below, and SPENDING/INCOME carry a total,
        // not a delta — a second grammar in one slot.
        SectionLabel(l.insDebtCredit),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            key: const Key('ins-debtlist'),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }

  Widget _sideRow(
    BuildContext context, {
    required String label,
    required double balance,
    required double delta,
    required bool isLiability,
  }) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final unchanged = delta.abs() < _Report.eps;

    final balSpoken = money(balance.abs(), masked: store.masked);
    final deltaSpoken = money(delta.abs(), masked: store.masked);
    final sentence = unchanged
        ? l.insA11yDebtFlat(label, balSpoken)
        : (delta > 0
            ? l.insA11yDebtUp(label, balSpoken, deltaSpoken)
            : l.insA11yDebtDown(label, balSpoken, deltaSpoken));

    return Semantics(
      container: true,
      label: sentence,
      child: ExcludeSemantics(
        child: Padding(
          key: const Key('ins-debtside'),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      height: 1.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.textTertiary)),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: AmountText.balance(balance,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
              const SizedBox(width: 6),
              if (unchanged)
                Text(l.insUnchanged,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))
              else
                _DeltaTag(value: delta, isLiability: isLiability),
            ],
          ),
        ),
      ),
    );
  }

  /// Indented to 26pt, no icon, 13.5pt — the indent carries the ownership and
  /// the smaller step keeps them from competing with the side row above.
  Widget _movementRow(
    BuildContext context, {
    required String title,
    required double value,
    required bool increased,
    required FlowKind flow,
  }) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final spoken = money(value.abs(), masked: store.masked);
    final sentence = increased
        ? l.insA11yMovementUp(title, spoken)
        : l.insA11yMovementDown(title, spoken);

    return Semantics(
      container: true,
      button: true,
      label: sentence,
      child: ExcludeSemantics(
        child: InkWell(
          // Both card movements drill into the credit-cards ledger, on Insight's
          // window and pre-narrowed to the matching flow (spec §4.2).
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => ScopedLedgerScreen(
                initialScope: const GroupScope(AccountGroup.creditCards),
                initialRange: window,
                initialFlow: flow,
              ),
            ),
          ),
          child: Padding(
            key: const Key('ins-debtmove'),
            padding: const EdgeInsets.fromLTRB(26, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.0,
                          color: AppColors.textPrimary)),
                ),
                _DeltaTag(value: value, isLiability: true),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
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
    if (value.abs() < _Report.eps) return const SizedBox.shrink();
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

// ── ⑦ Revaluation (spec §8) ──────────────────────────────────────────────────

class _RevaluationBlock extends StatelessWidget {
  const _RevaluationBlock({required this.report, required this.window});
  final _Report report;
  final DateRange window;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          l.insRevaluation,
          trailing: _DeltaTag(value: report.revalued, isLiability: false),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < report.revaluations.length; i++) ...[
                  if (i > 0) const RowDivider(indent: 47),
                  _revalRow(context, report.revaluations[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _revalRow(BuildContext context, Txn t) {
    final l = AppLocalizations.of(context);
    final store = report.store;
    final acc = store.accountById(t.toRef);

    final amountBase = Fx.toBase(t.amount, t.currency);
    // The base from the account's balance immediately before the rebalance.
    final base = acc == null
        ? 0.0
        : store.balanceOnInBase(
            acc.id, t.date.subtract(const Duration(days: 1)));
    final after = base + amountBase;
    // The percentage is the point of the addition: +$800 alone does not say
    // whether that is a good day. Never a divide-by-zero dash (spec §8).
    // Magnitude only — the sign is prepended below and spoken as up/down, so
    // percent()'s own minus must not double up.
    final pctStr = base.abs() < _Report.eps
        ? null
        : percent((amountBase / base).abs(), decimals: 1);
    final up = amountBase >= 0;

    final nameSpoken = acc?.name ?? '—';
    final amtSpoken = money(amountBase.abs(), masked: store.masked);
    final pctPart = pctStr == null ? '' : l.insA11yPercent(pctStr);
    final dateSpoken = dayMonth(t.date, l);
    final sentence = up
        ? l.insA11yRevalUp(nameSpoken, amtSpoken, pctPart, dateSpoken)
        : l.insA11yRevalDown(nameSpoken, amtSpoken, pctPart, dateSpoken);

    return Semantics(
      container: true,
      button: true,
      label: sentence,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: acc == null
              ? null
              : () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ScopedLedgerScreen(
                        initialScope: AccountScope(acc.id),
                        initialRange: window,
                      ),
                    ),
                  ),
          child: Padding(
            key: const Key('ins-revalrow'),
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
                      Text(
                        '$dateSpoken · ${money(base, masked: store.masked)} → '
                        '${money(after, masked: store.masked)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmountText(amountBase,
                        showSign: true,
                        color: up ? AppColors.positive : AppColors.negative,
                        style: AppText.amount.copyWith(fontSize: 14)),
                    if (pctStr != null)
                      Text(
                        (up ? '+' : '−') + pctStr,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state (spec §12) ───────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody(
      {required this.report, required this.window, required this.onBack});
  final _Report report;
  final DateRange window;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prevLabel = insightWindowLabel(window.copyShifted(-1), l);

    // Zero is an answer: the hero stays, at $0 in the quaternary token. The
    // waterfall is NOT drawn — with before == now and three zero steps it is a
    // flat line pretending to be a chart. No opacity on text (forbidden by the
    // design system); the quaternary colour is the fade.
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        _Hero(report: report),
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
