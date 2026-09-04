import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../core/utils/search_fold.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/restore_flow.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show FirstRunBlock;
import '../balance/same_transactions_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'ledger_day.dart';
import 'transfer_detail_screen.dart';
import 'widgets/ledger_period_sheet.dart';
import 'widgets/trans_filter_sheet.dart';

/// Spec 2.1 — every entry in chronological order, under a monthly
/// In / Out / Left summary. The list groups by calendar day; a day's net is
/// printed in the group's header band only when it is worth reading (§4).
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, this.scrollToTopSignal = 0});

  /// Bumped by the shell when the already-active Ledger tab is re-tapped, to
  /// scroll this list back to the top (spec §1).
  final int scrollToTopSignal;

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  /// Scrolls the transaction list; also the target of the tab-reselect signal.
  final ScrollController _scrollCtrl = ScrollController();

  /// The descriptions toggle (spec §3/§4.4). Screen-owned so a toggle rebuilds
  /// only the list+tool-row subtree (a ValueListenableBuilder), never the header
  /// zone. Seeded from the persisted store value and written back on change.
  late final ValueNotifier<bool> _showDescriptions;

  @override
  void initState() {
    super.initState();
    // read (not of): initState must not register an inherited dependency.
    _showDescriptions = ValueNotifier(
      StoreScope.read(context).ledgerShowDescriptions,
    );
  }

  @override
  void didUpdateWidget(covariant LedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToTopSignal != oldWidget.scrollToTopSignal) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _toggleDescriptions() {
    final next = !_showDescriptions.value;
    _showDescriptions.value = next;
    StoreScope.read(context).setLedgerShowDescriptions(next);
  }

  // ── Session filter (spec §2.2) ─────────────────────────────────────────────
  // A lens on the current view, not a stored preference: it never persists and
  // never survives a month change (reset in [build] when the period moves).
  TxnType? _direction; // null == All
  final Set<String> _categoryIds = {};
  final Set<String> _accountIds = {};
  final Set<String> _tagIds = {};
  double? _min; // absolute base-currency bounds; null == unbounded
  double? _max;

  /// The window the filter/search were last evaluated against, so any period
  /// change — month pick, range apply, swipe-exit — clears them (spec §2.2 —
  /// the filter is a lens, not a setting). Keyed by the effective window's
  /// bounds, not just year/month, so a range change fires the reset too.
  DateRange? _lastWindow;

  bool get _filterActive =>
      _direction != null ||
      _categoryIds.isNotEmpty ||
      _accountIds.isNotEmpty ||
      _tagIds.isNotEmpty ||
      _min != null ||
      _max != null;

  // ── Search (spec §2.1; transient, never persisted) ─────────────────────────
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  /// The field's live text (drives the clear glyph); filtering uses
  /// [_debouncedQuery], which lags ~200ms so the list does not thrash per key.
  String _query = '';
  String _debouncedQuery = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    _showDescriptions.dispose();
    super.dispose();
  }

  // ── Filter / search predicates ─────────────────────────────────────────────

  bool _matchesFilter(Txn t) {
    if (_direction != null && t.type != _direction) return false;
    if (_categoryIds.isNotEmpty) {
      // A transfer/revaluation carries no category, so it drops out whenever a
      // category is selected.
      final categoryRef = switch (t.type) {
        TxnType.expense => t.toRef,
        TxnType.income => t.fromRef,
        _ => null,
      };
      if (categoryRef == null || !_categoryIds.contains(categoryRef)) {
        return false;
      }
    }
    if (_accountIds.isNotEmpty &&
        !_accountIds.contains(t.fromRef) &&
        !_accountIds.contains(t.toRef)) {
      return false;
    }
    if (_tagIds.isNotEmpty && !t.tagIds.any(_tagIds.contains)) return false;
    if (_min != null || _max != null) {
      // Bounds are on absolute base-currency magnitude, matching the sheet's
      // per-item counts and range hint.
      final amt = Fx.toBase(t.amount, t.currency).abs();
      if (_min != null && amt < _min!) return false;
      if (_max != null && amt > _max!) return false;
    }
    return true;
  }

  bool _matchesSearch(AppStore store, Txn t, String folded) {
    if (folded.isEmpty) return true;
    final hay = foldSearch(
      [
        store.refName(t.fromRef),
        store.refName(t.toRef),
        t.note,
        ...store.tagNames(t.tagIds),
      ].join(' '),
    );
    return hay.contains(folded);
  }

  void _enterSearch() => setState(() => _searching = true);

  void _exitSearch() => setState(_clearSearch);

  /// Clears the search state without a [setState] — for use inside [build] when
  /// a month change tears the search down (spec §2.2).
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _searching = false;
    _query = '';
    _debouncedQuery = '';
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final window = store.ledgerWindow;

    // §1 — the one test. Not `days.isEmpty` and not "this window is empty":
    // a user who recorded one coffee in March and swiped to an empty August
    // *has* recorded something, and August must keep every control. `store.txns`
    // holds only user-entered rows — the opening-balance receipt is a
    // scoped-ledger `OpeningEntry`, deliberately never a Txn — so this is true
    // exactly when at least one real entry exists anywhere. Computed once here
    // and threaded down; when false the whole instrument panel goes quiet.
    final everRecorded = store.txns.isNotEmpty;

    // Filter and search are a lens on the current window: any period change —
    // month pick, range apply, or swipe-exit — resets both, so the funnel never
    // silently narrows a period the user just moved to. Keyed by window bounds
    // so a month↔range switch counts as a change even at equal month numbers.
    if (_lastWindow != null &&
        (_lastWindow!.start != window.start ||
            _lastWindow!.end != window.end)) {
      _direction = null;
      _categoryIds.clear();
      _accountIds.clear();
      _tagIds.clear();
      _min = null;
      _max = null;
      // Reset search without touching the controller synchronously: clearing it
      // here would notify a still-mounted field and setState during build. The
      // field is gone this frame (searching = false); tidy its text next frame.
      _searchDebounce?.cancel();
      _searching = false;
      _query = '';
      _debouncedQuery = '';
      if (_searchCtrl.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchCtrl.clear();
        });
      }
    }
    _lastWindow = window;

    // window → filter → search → grouping.
    final all = store.txnsInWindow(window); // newest first
    final total = all.length;
    final filtered = all.where(_matchesFilter).toList();

    final folded = foldSearch(_debouncedQuery.trim());
    final searching = _searching && folded.isNotEmpty;
    final visible = searching
        ? filtered.where((t) => _matchesSearch(store, t, folded)).toList()
        : filtered;
    final shown = visible.length;

    // Transfers and revaluations are already excluded from these — the window
    // income/expense sums cover only income/expense rows.
    final income = store.incomeInWindow(window);
    final expense = store.expenseInWindow(window);
    final left = income - expense;
    // Red fills to Out / In on a neutral track (§1). Guards: In == 0 with
    // Out > 0 fills fully; both zero leaves an empty track.
    final ratio = income > 0
        ? (expense / income).clamp(0.0, 1.0)
        : (expense > 0 ? 1.0 : 0.0);

    final rowQuery = searching ? folded : null;
    final days = _groupByDay(visible);

    return SafeArea(
      bottom: false,
      child: Stack(
        // The chrome Column keeps the same tight, full-body constraints it had
        // before the Stack, so every populated / empty-month state is laid out
        // exactly as it was; only the first-run block behind is added.
        fit: StackFit.expand,
        children: [
          // First run: the empty block is laid against the whole tab body so its
          // icon lands on the same y as Balance's and the Planner's (§1). It
          // sits behind the header and the restore line, both of which paint
          // over it rather than shortening its area. Absent once anything is
          // recorded.
          if (!everRecorded) Positioned.fill(child: _firstRunBlock()),
          Column(
            children: [
              // Header zone (pinned): title + ratio bar + metrics strip form one
              // horizontal-swipe region that steps the month (§2). The list below
              // keeps its own vertical scroll and row swipe actions.
              HorizontalSectionSwipe(
                // §2 — with nothing recorded every month is equally empty, so the
                // swipe must not step off the one screen that has the +. The widget
                // stays in the tree (stable layout); its callbacks are inert no-ops
                // until the first entry lands, at which point they resume stepping.
                onNext: everRecorded
                    ? () {
                        HapticFeedback.lightImpact();
                        store.shiftPeriod(1);
                      }
                    : () {},
                onPrevious: everRecorded
                    ? () {
                        HapticFeedback.lightImpact();
                        store.shiftPeriod(-1);
                      }
                    : () {},
                child: _HeaderZone(
                  store: store,
                  everRecorded: everRecorded,
                  income: income,
                  expense: expense,
                  left: left,
                  ratio: ratio,
                  onPickMonth: () => showLedgerPeriodSheet(
                    context,
                    store,
                    // Reopening during a lens lands on the calendar page, pre-filled
                    // with the active range.
                    openOnCalendar: store.isRangeLensActive,
                  ),
                  onAdd: () => showQuickAdd(context),
                ),
              ),
              Expanded(
                // §1/§3 — first run is not a row in the list, it is the screen. It
                // has nothing to scroll and carries its own restore line pinned above
                // the nav, so it renders directly in the Expanded rather than as a
                // ListView child. Every other state (populated, empty month, no
                // filter/search match) keeps the ListView below unchanged.
                child: everRecorded
                    ? ValueListenableBuilder<bool>(
                        // A description toggle rebuilds only this subtree, not header.
                        valueListenable: _showDescriptions,
                        builder: (context, showDesc, _) {
                          return Column(
                            children: [
                              _toolRow(
                                store,
                                total: total,
                                shown: shown,
                                searching: searching,
                                showDesc: showDesc,
                              ),
                              if (_searching) _searchField(),
                              const SizedBox(height: Insets.sm),
                              Expanded(
                                child: ListView(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.only(
                                    bottom: Insets.xxl,
                                  ),
                                  children: [
                                    if (days.isEmpty)
                                      _empty(store, searching: searching)
                                    else
                                      for (final day in days) ...[
                                        const SizedBox(height: 8),
                                        _dayCard(
                                          context,
                                          store,
                                          day,
                                          showDesc: showDesc,
                                          query: rowQuery,
                                        ),
                                      ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : _firstRun(store),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<LedgerDay> _groupByDay(List<Txn> txns) {
    final groups = <DateTime, LedgerDay>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(key, () => LedgerDay(key)).txns.add(t);
    }
    return groups.values.toList();
  }

  // ── Tool row (spec §2) ──────────────────────────────────────────────────────

  Widget _toolRow(
    AppStore store, {
    required int total,
    required int shown,
    required bool searching,
    required bool showDesc,
  }) {
    // Never "87 of 87" (§2): the "of" form appears only when the view is
    // actually narrower than the month, not merely because a filter is set.
    final String label;
    if (searching) {
      label = '$shown matching "${_debouncedQuery.trim()}"';
    } else if (shown != total) {
      label = '$shown of $total transactions';
    } else {
      label = '$total transactions';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 0),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // Descriptions toggle · filter · search — three identical siblings
            // (§3). The toggle follows the filter's active-state language: an
            // icon swap plus a brighter glyph, no background change.
            ToolCluster(
              tools: [
                Tool(
                  icon: showDesc
                      ? Icons.keyboard_double_arrow_up_rounded
                      : Icons.keyboard_double_arrow_down_rounded,
                  tooltip: AppLocalizations.of(context).ldgShowDescriptions,
                  iconColor: showDesc ? AppColors.accentLight : null,
                  semanticValue: showDesc
                      ? AppLocalizations.of(context).stateOn
                      : AppLocalizations.of(context).stateOff,
                  onTap: _toggleDescriptions,
                ),
                Tool(
                  icon: _filterActive
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                  tooltip: AppLocalizations.of(context).ldgFilterTransactions,
                  iconColor: _filterActive ? AppColors.textPrimary : null,
                  semanticValue: _filterActive
                      ? AppLocalizations.of(
                          context,
                        ).ldgFilterActive('$shown', '$total')
                      : AppLocalizations.of(context).stateOff,
                  onTap: () => _openFilter(store),
                ),
                Tool(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: AppLocalizations.of(context).ldgSearchTransactions,
                  onTap: () => _searching ? _exitSearch() : _enterSearch(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                cursorColor: AppColors.accent,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context).actionSearch,
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(AppStore store, {required bool searching}) {
    // First run is handled ahead of the list entirely (§1/§3 — [_firstRun]), so
    // this method only ever runs on a store that *has* recorded something: the
    // branches below are the empty-search, empty-filter and empty-month states.
    if (searching) {
      return Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Text(
          AppLocalizations.of(context).ldgNoResultsFor(_debouncedQuery.trim()),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
        ),
      );
    }
    if (_filterActive) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).ldgNoMatchFilter,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _direction = null;
                _categoryIds.clear();
                _accountIds.clear();
                _tagIds.clear();
                _min = null;
                _max = null;
              }),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  AppLocalizations.of(context).ldgClearFilter,
                  style: const TextStyle(fontSize: 14, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // §4 — an empty month on a store that has entries elsewhere. The zeros are
    // the correct answer, not a problem, and the way out (the +) is two lines
    // up: a large call to action would imply something is wrong. So a single
    // centred line, matching the searching branch's shape, naming the month the
    // title already shows.
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Text(
        AppLocalizations.of(context).ldgNothingRecordedInMonth(
          monthLong(store.period.month, AppLocalizations.of(context)),
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
      ),
    );
  }

  // ── First run (spec §2–§5) ──────────────────────────────────────────────────

  /// The first-run overlay drawn over [_firstRunBlock] (§1): a hit-transparent
  /// spacer, so the centred block behind takes the taps and the scroll, and the
  /// quiet restore line pinned above the tab bar — still on top, still tappable.
  /// The block is no longer sized against this column's leftover height; it is
  /// laid against the whole body by the Stack in [build], so its icon lands on
  /// the same y as Balance's and the Planner's rather than being pushed up by
  /// the restore line.
  Widget _firstRun(AppStore store) {
    return Column(
      children: [
        const Expanded(child: SizedBox.expand()),
        _restoreLine(store),
      ],
    );
  }

  /// The centred first-run block: icon on a backdrop, title, message, and the
  /// muted line that names the unlabelled + — "Start with + above", the glyph a
  /// real accent echoing the button (§2–§4). The line sits in the reserved
  /// fourth-row box and scales down rather than wrapping, exactly as the
  /// Planner's does. Laid against the whole body by [FirstRunBlock].
  Widget _firstRunBlock() {
    final l = AppLocalizations.of(context);
    // A NUL sentinel the localized string can never contain, substituted for
    // {plus} so a translation is free to move the glyph.
    final sentinel = String.fromCharCode(0);
    return FirstRunBlock(
      icon: Icons.receipt_long_rounded,
      title: l.ldgNothingHere,
      message: l.ldgNothingHereMsg,
      action: FittedBox(
        fit: BoxFit.scaleDown,
        child: buildFirstRunHint(l.ldgFirstRunHint(sentinel), sentinel),
      ),
    );
  }

  /// The quiet "Restore from a backup" line pinned above the tab bar (§5): the
  /// one screen a restoring user actually lands on. It runs the real shared
  /// restore flow (picker → confirm → load), not a signpost to More.
  Widget _restoreLine(AppStore store) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => runRestoreFlow(context, store),
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: Text(
                l.ldgRestoreFromBackup,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
      ],
    );
  }

  // ── Day card (spec §3) ──────────────────────────────────────────────────────

  /// The whole day is one block: the header band is the card's first child,
  /// clipped by the card's own radius and divided from the first row by the same
  /// hairline that divides the rows (spec §3.1).
  Widget _dayCard(
    BuildContext context,
    AppStore store,
    LedgerDay day, {
    required bool showDesc,
    required String? query,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: AppCard(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _dayBand(store, day),
            const RowDivider(),
            for (var i = 0; i < day.txns.length; i++) ...[
              if (i > 0) const RowDivider(indent: Insets.md),
              TxnRow(
                txn: day.txns[i],
                showDescription: showDesc,
                searchQuery: query,
                // A tap opens a read-only screen, never the editor (spec §1) —
                // matching the scoped ledger. A transfer has no category key, so
                // it opens its own transfer detail; everything else opens the
                // Same-transactions list for its key. Editing stays behind the
                // swipe menu and the ••• on the detail screen.
                onTap: () => day.txns[i].type == TxnType.transfer
                    ? Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransferDetailScreen(
                            txnId: day.txns[i].id,
                            backLabel: AppLocalizations.of(context).navLedger,
                          ),
                        ),
                      )
                    : Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SameTransactionsScreen(
                            originTxnId: day.txns[i].id,
                            backLabel: AppLocalizations.of(context).navLedger,
                          ),
                        ),
                      ),
                onEdit: () => showQuickAdd(context, editing: day.txns[i]),
                onCopy: () => showQuickAdd(context, copyOf: day.txns[i]),
                onDelete: () async {
                  final ok = await confirmDeleteTxn(context, day.txns[i]);
                  if (ok && context.mounted) store.deleteTxn(day.txns[i]);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The header band: the date on the left, the day net on the right — the net
  /// present only when [_LedgerDay.showsDayTotal] (§4). The net is kept in the
  /// tree and faded rather than removed, so the band's height and the date's
  /// baseline are identical whether or not the total shows (§7), and a day
  /// flipping across the threshold cross-fades instead of reflowing.
  Widget _dayBand(AppStore store, LedgerDay day) {
    final shows = day.showsDayTotal;
    final net = day.total;
    final dateLabel = dateGroupLabel(
      day.date,
      AppLocalizations.of(context),
    ).toUpperCase();
    final totalLabel = money(net, signless: true, masked: store.masked);

    final Color netColor = net > 0
        ? AppColors.positive
        : net < 0
        ? AppColors.amountChildNeg
        : AppColors.textSecondary; // a busy day netting to zero (§9)

    return Semantics(
      header: true,
      label: shows ? '$dateLabel, net $totalLabel' : dateLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
        child: Row(
          children: [
            Expanded(child: Text(dateLabel, style: AppText.label)),
            AnimatedOpacity(
              opacity: shows ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: ExcludeSemantics(
                excluding: !shows,
                child: Text(
                  totalLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: netColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter sheet (spec §2.2) ────────────────────────────────────────────────

  /// The unified filter sheet (spec §2.2). All per-item counts and the range
  /// are computed once here from the current period's transactions and handed to
  /// the shared sheet; the sheet's snapshot is mapped back onto this screen's
  /// filter state on every change so the list behind updates immediately.
  ///
  /// Note: there is deliberately no free-text/notes field here — description
  /// search belongs to the list search, which already matches notes and tags
  /// and combines multiplicatively with this filter (spec §7).
  Future<void> _openFilter(AppStore store) async {
    final l = AppLocalizations.of(context);
    final all = store.txnsInWindow(store.ledgerWindow);
    final accountIds = {for (final a in store.accounts) a.id};

    // One O(n) pass over the period for the per-item counts (spec §4, §7 —
    // never per-row queries). Accounts and tags need a *per-direction* tally so
    // the sheet tells the truth under a DIRECTION toggle (spec §3) — recorded in
    // the same walk rather than re-walking the window per toggle. `null` holds
    // the direction-agnostic totals used for ordering.
    const dirs = <TxnType?>[
      null,
      TxnType.expense,
      TxnType.income,
      TxnType.transfer,
      TxnType.rebalance,
    ];
    final catCount = <String, int>{}; // period-wide; drives the stable order
    final accCountDir = {for (final d in dirs) d: <String, int>{}};
    final tagCountDir = {for (final d in dirs) d: <String, int>{}};
    final dMin = <TxnType?, double>{};
    final dMax = <TxnType?, double>{};
    void bound(TxnType? k, double amt) {
      final lo = dMin[k];
      if (lo == null || amt < lo) dMin[k] = amt;
      final hi = dMax[k];
      if (hi == null || amt > hi) dMax[k] = amt;
    }

    for (final t in all) {
      final cref = switch (t.type) {
        TxnType.expense => t.toRef,
        TxnType.income => t.fromRef,
        _ => null,
      };
      if (cref != null) catCount[cref] = (catCount[cref] ?? 0) + 1;
      for (final id in {t.fromRef, t.toRef}) {
        if (accountIds.contains(id)) {
          accCountDir[null]![id] = (accCountDir[null]![id] ?? 0) + 1;
          accCountDir[t.type]![id] = (accCountDir[t.type]![id] ?? 0) + 1;
        }
      }
      for (final id in t.tagIds) {
        tagCountDir[null]![id] = (tagCountDir[null]![id] ?? 0) + 1;
        tagCountDir[t.type]![id] = (tagCountDir[t.type]![id] ?? 0) + 1;
      }
      final amt = Fx.toBase(t.amount, t.currency).abs();
      bound(null, amt);
      bound(t.type, amt);
    }
    final accCount = accCountDir[null]!;
    final tagCount = tagCountDir[null]!;
    final rangeMin = dMin[null] ?? 0.0;
    final rangeMax = dMax[null] ?? 0.0;

    // Order fixed once from the period counts (non-zero desc, then zeros
    // alphabetically). Hiding empties (§1) removes rows; it never reorders the
    // survivors, so the relative order is stable across a direction change.
    int order(
      String aId,
      String aName,
      String bId,
      String bName,
      Map<String, int> counts,
    ) {
      final ca = counts[aId] ?? 0, cb = counts[bId] ?? 0;
      if ((ca == 0) != (cb == 0)) return ca == 0 ? 1 : -1;
      if (ca != cb && ca != 0) return cb.compareTo(ca);
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    }

    // Categories become two sections (spec §4): where money went vs where it
    // came from. The model stays CategoryType; only the split and the words
    // change, and ledger_screen unions the two id sets back into _categoryIds.
    final expenseCats = [
      for (final c in store.categories)
        if (c.type == CategoryType.expense) c,
    ]..sort((a, b) => order(a.id, a.name, b.id, b.name, catCount));
    final incomeCats = [
      for (final c in store.categories)
        if (c.type == CategoryType.income) c,
    ]..sort((a, b) => order(a.id, a.name, b.id, b.name, catCount));
    final accs = [...store.accounts]
      ..sort((a, b) => order(a.id, a.name, b.id, b.name, accCount));
    // Tag ids present in the window, ordered by count then folded name. Archived
    // tags are kept (past rows carry them) and marked subtly in the sheet.
    String tagName(String id) => store.tagById(id)?.name ?? '';
    final tags = tagCount.keys.toList()
      ..sort((a, b) {
        final c = (tagCount[b]!).compareTo(tagCount[a]!);
        return c != 0
            ? c
            : tagName(a).toLowerCase().compareTo(tagName(b).toLowerCase());
      });

    // A category's count is contextual to the DIRECTION: a category of the
    // opposite kind (or any category under Transfers/Revaluations) contributes
    // 0 in that context, so hideEmpty drops it and the whole section vanishes.
    int catCtx(Category c, TxnType? dir) {
      final base = catCount[c.id] ?? 0;
      return switch (dir) {
        null => base,
        TxnType.income => c.type == CategoryType.income ? base : 0,
        TxnType.expense => c.type == CategoryType.expense ? base : 0,
        _ => 0,
      };
    }

    List<FilterChipItem> catItems(List<Category> list, TxnType? dir) => [
      for (final c in list)
        FilterChipItem(
          id: c.id,
          label: c.name,
          icon: c.icon,
          color: c.color,
          count: catCtx(c, dir),
        ),
    ];
    List<FilterChipItem> accItems(TxnType? dir) {
      final counts = accCountDir[dir] ?? const <String, int>{};
      return [
        for (final a in accs)
          FilterChipItem(
            id: a.id,
            label: a.name,
            icon: a.displayIcon,
            color: a.color,
            count: counts[a.id] ?? 0,
          ),
      ];
    }

    List<FilterChipItem> tagItems(TxnType? dir) {
      final counts = tagCountDir[dir] ?? const <String, int>{};
      return [
        for (final id in tags)
          FilterChipItem(
            id: id,
            label: '#${tagName(id)}',
            count: counts[id] ?? 0,
            archived: store.tagById(id)?.archived ?? false,
          ),
      ];
    }

    // Direction-contextual, masked-aware amount placeholders + header range
    // (spec §10). A placeholder must never leak an amount the eye is hiding.
    ({String min, String max, String? header}) amountHints(TxnType? dir) {
      if (store.masked) return (min: '—', max: '—', header: '—');
      final mn = money(dMin[dir] ?? 0.0, signless: true);
      final mx = money(dMax[dir] ?? 0.0, signless: true);
      return (min: mn, max: mx, header: l.ldgAmountRange(mn, mx));
    }

    int countMatches(FilterSnapshot s) {
      // The two category sub-sections are one dimension to the matcher; a
      // transfer/revaluation carries no category and so drops out whenever any
      // category is selected (unchanged semantics, spec Hard boundary).
      final cat = {...s.sel('expenseCategories'), ...s.sel('incomeCategories')};
      final acc = s.sel('accounts');
      final tg = s.sel('tags');
      var n = 0;
      for (final t in all) {
        if (s.direction != null && t.type != s.direction) continue;
        if (cat.isNotEmpty) {
          final cref = switch (t.type) {
            TxnType.expense => t.toRef,
            TxnType.income => t.fromRef,
            _ => null,
          };
          if (cref == null || !cat.contains(cref)) continue;
        }
        if (acc.isNotEmpty &&
            !acc.contains(t.fromRef) &&
            !acc.contains(t.toRef)) {
          continue;
        }
        if (tg.isNotEmpty && !t.tagIds.any(tg.contains)) continue;
        final amt = Fx.toBase(t.amount, t.currency).abs();
        if (s.min != null && amt < s.min!) continue;
        if (s.max != null && amt > s.max!) continue;
        n++;
      }
      return n;
    }

    // Split the current _categoryIds by kind for the two sections' initial sets.
    final catType = {for (final c in store.categories) c.id: c.type};

    await showFilterSheet(
      context,
      total: all.length,
      searchable: true,
      direction: [
        DirectionOption(l.txnTypeIncome, TxnType.income),
        DirectionOption(l.txnTypeExpense, TxnType.expense),
        DirectionOption(l.txnTypeTransfer, TxnType.transfer),
        DirectionOption(l.txnTypeRebalance, TxnType.rebalance),
      ],
      initial: FilterSnapshot(
        direction: _direction,
        selections: {
          'expenseCategories': {
            for (final id in _categoryIds)
              if (catType[id] == CategoryType.expense) id,
          },
          'incomeCategories': {
            for (final id in _categoryIds)
              if (catType[id] == CategoryType.income) id,
          },
          'accounts': {..._accountIds},
          'tags': {..._tagIds},
        },
        min: _min,
        max: _max,
      ),
      matchCount: countMatches,
      onChanged: (s) => setState(() {
        _direction = s.direction;
        _categoryIds
          ..clear()
          ..addAll(s.sel('expenseCategories'))
          ..addAll(s.sel('incomeCategories'));
        _accountIds
          ..clear()
          ..addAll(s.sel('accounts'));
        _tagIds
          ..clear()
          ..addAll(s.sel('tags'));
        _min = s.min;
        _max = s.max;
      }),
      blocks: [
        // A direction that carries no category replaces both category sections
        // with one explanatory line (spec §5.3).
        NoteFilterBlock(
          (dir) => switch (dir) {
            TxnType.transfer => l.ldgTransfersHaveNoCategory,
            TxnType.rebalance => l.ldgRevaluationsMoveNoCash,
            _ => null,
          },
        ),
        SectionFilterBlock(
          FilterSection(
            key: 'expenseCategories',
            label: l.ldgExpenses.toUpperCase(),
            a11yLabel: l.ldgExpenseCategoriesA11y,
            kind: FilterSectionKind.rows,
            showCount: true,
            rich: true,
            hideEmpty: true,
            truncateAt: 5,
            moreLabel: (n) => l.ldgMoreCategories('$n'),
            itemsFor: (dir) => catItems(expenseCats, dir),
          ),
        ),
        SectionFilterBlock(
          FilterSection(
            key: 'incomeCategories',
            label: l.ldgIncomes.toUpperCase(),
            a11yLabel: l.ldgIncomeSourcesA11y,
            kind: FilterSectionKind.rows,
            showCount: true,
            rich: true,
            hideEmpty: true,
            truncateAt: 5,
            moreLabel: (n) => l.ldgMoreCategories('$n'),
            itemsFor: (dir) => catItems(incomeCats, dir),
          ),
        ),
        SectionFilterBlock(
          FilterSection(
            key: 'accounts',
            label: l.ldgAccounts.toUpperCase(),
            kind: FilterSectionKind.rows,
            showCount: true,
            rich: true,
            hideEmpty: true,
            truncateAt: 5,
            moreLabel: (n) => l.ldgMoreAccounts('$n'),
            itemsFor: accItems,
          ),
        ),
        if (tags.isNotEmpty)
          SectionFilterBlock(
            FilterSection(
              key: 'tags',
              label: l.ldgTags.toUpperCase(),
              kind: FilterSectionKind.chips,
              showCount: true,
              rich: true,
              hideEmpty: true,
              truncateAt: 6,
              moreLabel: (n) => l.ldgMoreTags('$n'),
              itemsFor: tagItems,
            ),
          ),
        AmountFilterBlock(
          rangeMin: rangeMin,
          rangeMax: rangeMax,
          hintsFor: amountHints,
        ),
      ],
    );
  }
}

/// Builds the first-run hint's inline spans from [rawWithSentinel] — the hint
/// string with its `{plus}` placeholder already replaced by [sentinel] (§4.1).
/// Splitting on the sentinel lets a translation move the glyph freely; a string
/// that lost the placeholder yields one part, which degrades to a plain readable
/// line with the glyph omitted rather than throwing or drawing an empty label.
/// Top-level and public so the Planner's first-run tabs share the one hint
/// implementation (§4.4), and so the fallback path can be exercised in a test
/// without a broken localization.
Widget buildFirstRunHint(String rawWithSentinel, String sentinel) {
  const baseStyle = TextStyle(fontSize: 12, color: AppColors.textTertiary);
  final parts = rawWithSentinel.split(sentinel);
  if (parts.length != 2) {
    return Text(parts.join(), textAlign: TextAlign.center, style: baseStyle);
  }
  return Text.rich(
    TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: parts[0]),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.add_rounded,
            size: 13,
            color: AppColors.accentLight,
          ),
        ),
        TextSpan(text: parts[1]),
      ],
    ),
    textAlign: TextAlign.center,
  );
}

/// The Ledger's pinned header (spec §1): the month as the screen title (with the
/// eye and `+` cloned from ScreenHeader), a thin passive ratio bar, and the
/// IN / OUT / LEFT metrics strip. The word "Ledger" appears nowhere — it lives
/// only in the tab bar.
class _HeaderZone extends StatelessWidget {
  const _HeaderZone({
    required this.store,
    required this.everRecorded,
    required this.income,
    required this.expense,
    required this.left,
    required this.ratio,
    required this.onPickMonth,
    required this.onAdd,
  });

  final AppStore store;

  /// Whether any entry has ever been recorded (§1). False collapses the header
  /// to just the month title and the +: no chevron, eye, ratio bar or metrics.
  final bool everRecorded;
  final double income;
  final double expense;
  final double left;
  final double ratio;
  final VoidCallback onPickMonth;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // Opaque so the swipe region above receives drags across the whole zone,
    // including the gaps between the rows.
    // §6 — with the title gone on first run, the first entry brings back the
    // title, chevron, eye, ratio bar and metrics strip all at once. AnimatedSize
    // (Balance's exact parameters) grows the apparatus in rather than snapping.
    // The + sits in the fixed-height title row above the growth, so it neither
    // moves nor resizes as the strip below expands.
    return Container(
      color: AppColors.bg,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row — the month is the title. On first run (§1) the leading
            // slot renders nothing: the period is a scope value, and with nothing
            // recorded there is no scope to name. The row's height is set by the
            // 36pt + circle, so it stays stable whether or not the title is drawn.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: everRecorded
                        ? _PeriodTitle(
                            store: store,
                            onTap: onPickMonth,
                            enabled: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                  // The way out of the range lens sits beside the state it undoes
                  // (§1): a third circle, purple like the title it clears, present
                  // only while a lens is active — so in month mode this row is
                  // byte-identical to before. Its clear button is hidden on first
                  // run alongside the eye, so a lens (were one somehow active) is
                  // not clearable here.
                  if (everRecorded && store.isRangeLensActive) ...[
                    const SizedBox(width: Insets.sm),
                    Semantics(
                      button: true,
                      label: AppLocalizations.of(context).ldgClearCustomRange,
                      hint:
                          'Back to ${monthYearLong(store.period, AppLocalizations.of(context))}',
                      child: _CircleButton(
                        icon: Icons.close_rounded,
                        tint: AppColors.accentLight,
                        onTap: store.clearRangeLens,
                      ),
                    ),
                  ],
                  // Eye — hidden on first run (nothing money-shaped is drawn, so
                  // masking has nothing to hide). The `+` always stays: it is the
                  // one control that still does something, and the button a user
                  // must not have to re-find the moment their first entry lands.
                  if (everRecorded) ...[
                    const SizedBox(width: Insets.sm),
                    _CircleButton(
                      icon: store.masked
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      onTap: store.toggleMasked,
                    ),
                  ],
                  const SizedBox(width: Insets.sm),
                  _CircleButton(
                    icon: Icons.add_rounded,
                    accent: true,
                    onTap: onAdd,
                  ),
                ],
              ),
            ),
            // Ratio bar + metrics strip — the figures the screen answers with.
            // Both are absent from the tree until something is recorded (§2):
            // nothing replaces them, because the Ledger's numbers live in a strip
            // that simply should not be drawn (unlike Balance's hero figure).
            if (everRecorded) ...[
              // Ratio bar — passive, 3pt, full width (§1).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Semantics(
                  label: income > 0 || expense > 0
                      ? AppLocalizations.of(context).ldgSpentOf(
                          money(expense, masked: store.masked),
                          money(income, masked: store.masked),
                        )
                      : null,
                  child: ProgressBar(
                    value: ratio,
                    color: AppColors.negative,
                    height: 3,
                    background: AppColors.surfaceHigh,
                  ),
                ),
              ),
              // Metrics strip.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      _Metric(
                        label: AppLocalizations.of(context).ldgIn.toUpperCase(),
                        value: income,
                        color: AppColors.positive,
                      ),
                      const SizedBox(width: 13),
                      _Metric(
                        label: AppLocalizations.of(
                          context,
                        ).ldgOut.toUpperCase(),
                        value: expense,
                        color: AppColors.negative,
                      ),
                      const Spacer(),
                      // LEFT — one step larger; it is the figure the screen answers.
                      // Balance-like: it keeps its minus sign and turns red when the
                      // month is overspent (§1.2).
                      _Metric(
                        label: AppLocalizations.of(
                          context,
                        ).ldgLeft.toUpperCase(),
                        value: left,
                        color: left < 0
                            ? AppColors.negative
                            : AppColors.textPrimary,
                        valueSize: 15,
                        keepSign: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }
}

/// The period title: the month in white, or — while a range lens is active —
/// the range in accent purple (the app's temporary-lens language) with a
/// `{n} days` subtitle. The ⌄ chevron and the tap-to-open behaviour are
/// unchanged in both states; the range form shrinks/ellipsizes before it can
/// reach the eye/`+` buttons.
class _PeriodTitle extends StatelessWidget {
  const _PeriodTitle({
    required this.store,
    required this.onTap,
    this.enabled = true,
  });

  final AppStore store;
  final VoidCallback onTap;

  /// When false (first run, §2) the title is the screen's name only: the chevron
  /// is gone, the tap is inert, and semantics drop to a plain header — every
  /// month is equally empty, so there is nowhere to pick.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lens = store.rangeLens;
    final isLens = lens != null;
    final titleText = isLens
        ? lens.label(AppStore.today, l)
        : monthYearLong(store.period, l);
    final days = isLens ? lens.days : 0;
    final semanticLabel = isLens
        ? '$titleText, ${l.countDays(days)}'
        : monthYearLong(store.period, l);

    return Semantics(
      button: enabled,
      header: !enabled,
      label: semanticLabel,
      hint: enabled ? AppLocalizations.of(context).ldgChangePeriod : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isLens
                          ? AppColors.accentLight
                          : AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                // The chevron is the affordance for tap-to-pick; with picking
                // inert it goes too (§2).
                if (enabled)
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            // The lens's only new vertical cost (~13pt); absent in month mode.
            if (isLens)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  l.countDays(days),
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One IN / OUT / LEFT column of the metrics strip: a caps key beside its value,
/// aligned on the baseline.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    this.valueSize = 13.5,
    this.keepSign = false,
  });

  final String label;
  final double value;
  final Color color;
  final double valueSize;

  /// IN and OUT are magnitudes (never signed); LEFT is balance-like and keeps a
  /// minus when negative.
  final bool keepSign;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 5),
        AmountText(
          value,
          signless: !keepSign,
          color: color,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The eye / `+` circle button, cloned from `ScreenHeader`'s private one so the
/// Ledger keeps its exact previous size, colour, icon and behaviour (§1).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
    this.accent = false,
    this.tint,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  /// Overrides the glyph colour (size/background/behaviour are unchanged). The
  /// lens's × uses it to echo the accent title it clears (§1); eye and `+`
  /// leave it null and keep the default textPrimary glyph.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.accent : AppColors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: accent ? 22 : 19,
            color: tint ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
