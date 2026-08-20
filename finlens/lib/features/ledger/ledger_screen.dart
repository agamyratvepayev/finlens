import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/search_fold.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/pickers.dart';
import '../quick_add/quick_add_sheet.dart';
import 'ledger_day.dart';
import 'transfer_detail_screen.dart';

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
    _showDescriptions =
        ValueNotifier(StoreScope.read(context).ledgerShowDescriptions);
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

  /// The period the filter/search were last evaluated against, so a month
  /// change can clear them (spec §2.2 — the filter is a lens, not a setting).
  DateTime? _lastPeriod;

  bool get _filterActive =>
      _direction != null || _categoryIds.isNotEmpty || _accountIds.isNotEmpty;

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
    return true;
  }

  bool _matchesSearch(AppStore store, Txn t, String folded) {
    if (folded.isEmpty) return true;
    final hay = foldSearch(
      [
        store.refName(t.fromRef),
        store.refName(t.toRef),
        t.note,
        ...t.tags,
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

    // Filter and search are a lens on the current month: a month change resets
    // both, so the funnel never silently narrows a period the user just moved to.
    if (_lastPeriod != null &&
        (_lastPeriod!.year != store.period.year ||
            _lastPeriod!.month != store.period.month)) {
      _direction = null;
      _categoryIds.clear();
      _accountIds.clear();
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
    _lastPeriod = store.period;

    // period → filter → search → grouping.
    final all = store.txnsInMonth(store.period); // newest first
    final total = all.length;
    final filtered = all.where(_matchesFilter).toList();

    final folded = foldSearch(_debouncedQuery.trim());
    final searching = _searching && folded.isNotEmpty;
    final visible = searching
        ? filtered.where((t) => _matchesSearch(store, t, folded)).toList()
        : filtered;
    final shown = visible.length;

    // Transfers and revaluations are already excluded from these — monthIncome/
    // monthExpense sum only income/expense rows.
    final income = store.monthIncome(store.period);
    final expense = store.monthExpense(store.period);
    final left = income - expense;
    // Red fills to Out / In on a neutral track (§1). Guards: In == 0 with
    // Out > 0 fills fully; both zero leaves an empty track.
    final ratio = income > 0
        ? (expense / income).clamp(0.0, 1.0)
        : (expense > 0 ? 1.0 : 0.0);

    // The month's per-row after-balances, assembled once (cached in the store).
    final afterBalances = store.ledgerAfterBalances();
    final rowQuery = searching ? folded : null;
    final days = _groupByDay(visible);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header zone (pinned): title + ratio bar + metrics strip form one
          // horizontal-swipe region that steps the month (§2). The list below
          // keeps its own vertical scroll and row swipe actions.
          HorizontalSectionSwipe(
            onNext: () {
              HapticFeedback.lightImpact();
              store.shiftPeriod(1);
            },
            onPrevious: () {
              HapticFeedback.lightImpact();
              store.shiftPeriod(-1);
            },
            child: _HeaderZone(
              store: store,
              income: income,
              expense: expense,
              left: left,
              ratio: ratio,
              onPickMonth: () => _pickMonth(store),
              onAdd: () => showQuickAdd(context),
            ),
          ),
          Expanded(
            // A description toggle rebuilds only this subtree, not the header.
            child: ValueListenableBuilder<bool>(
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
                        padding: const EdgeInsets.only(bottom: Insets.xxl),
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
                                afterBalances: afterBalances,
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
                  tooltip: 'Show descriptions',
                  iconColor: showDesc ? AppColors.accentLight : null,
                  semanticValue: showDesc ? 'On' : 'Off',
                  onTap: _toggleDescriptions,
                ),
                Tool(
                  icon: _filterActive
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                  tooltip: 'Filter transactions',
                  iconColor: _filterActive ? AppColors.textPrimary : null,
                  semanticValue: _filterActive
                      ? 'Active, $shown of $total shown'
                      : 'Off',
                  onTap: () => _openFilter(store),
                ),
                Tool(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  tooltip: 'Search transactions',
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
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
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
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
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
    if (searching) {
      return Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Text(
          'No results for "${_debouncedQuery.trim()}"',
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
            const Text(
              'No transactions match your filter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _direction = null;
                _categoryIds.clear();
                _accountIds.clear();
              }),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Clear filter',
                  style: TextStyle(fontSize: 14, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Nothing here yet',
        message: 'Entries you add will appear in this list.',
        action: FilledButton.icon(
          onPressed: () => showQuickAdd(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add an entry'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
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
    required Map<String, double> afterBalances,
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
                afterBalance: afterBalances[day.txns[i].id],
                showDescription: showDesc,
                searchQuery: query,
                onTap: () => day.txns[i].type == TxnType.transfer
                    ? Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransferDetailScreen(
                            txnId: day.txns[i].id,
                            backLabel: 'Ledger',
                          ),
                        ),
                      )
                    : showQuickAdd(context, editing: day.txns[i]),
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
    final dateLabel = dateGroupLabel(day.date).toUpperCase();
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

  Future<void> _openFilter(AppStore store) async {
    await showAppSheet<void>(
      context,
      title: 'Filter',
      initialSize: 0.7,
      builder: (sheetContext, controller) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            // Every change applies immediately to the list behind (§2.2); the
            // sheet redraws its own checks through [setSheet].
            void apply(VoidCallback change) {
              setState(change);
              setSheet(() {});
            }

            final categories = store.categories;
            final accounts = store.accounts;

            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                0,
                Insets.gutter,
                Insets.xxl,
              ),
              children: [
                _sheetLabel('DIRECTION'),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    _dirChip('All', null, apply),
                    _dirChip('Income', TxnType.income, apply),
                    _dirChip('Expenses', TxnType.expense, apply),
                    _dirChip('Transfers', TxnType.transfer, apply),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                _sheetLabel('CATEGORIES'),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < categories.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _pickRow(
                          icon: categories[i].icon,
                          color: categories[i].color,
                          name: categories[i].name,
                          selected: _categoryIds.contains(categories[i].id),
                          onTap: () => apply(() => _toggle(
                                _categoryIds,
                                categories[i].id,
                              )),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                _sheetLabel('ACCOUNTS'),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < accounts.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _pickRow(
                          icon: accounts[i].displayIcon,
                          color: accounts[i].color,
                          name: accounts[i].name,
                          selected: _accountIds.contains(accounts[i].id),
                          onTap: () => apply(() => _toggle(
                                _accountIds,
                                accounts[i].id,
                              )),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  children: [
                    TextButton(
                      onPressed: _filterActive
                          ? () => apply(() {
                                _direction = null;
                                _categoryIds.clear();
                                _accountIds.clear();
                              })
                          : null,
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void _toggle(Set<String> set, String id) {
    set.contains(id) ? set.remove(id) : set.add(id);
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, Insets.sm, 4, Insets.sm),
        child: Text(text, style: AppText.label),
      );

  Widget _dirChip(String label, TxnType? type, void Function(VoidCallback) apply) {
    final selected = _direction == type;
    final color = type?.color ?? AppColors.accentSoft;
    return GestureDetector(
      onTap: () => apply(() => _direction = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint(color, 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _pickRow({
    required IconData icon,
    required Color color,
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          children: [
            IconTile(icon, color: color, size: 30, iconSize: 15),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                name,
                style: AppText.rowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Month picker (spec §8) ──────────────────────────────────────────────────

  /// A bottom-sheet month list, reverse-chronological back to the earliest
  /// transaction, the current month checked, a year header separating each year.
  /// Built rather than reused: the app has no month picker (the scoped ledger's
  /// is a whole-period preset picker, a different granularity), and §8 says not
  /// to open a day-granularity calendar here.
  Future<void> _pickMonth(AppStore store) async {
    final txns = store.txns;
    final earliest = txns.isEmpty
        ? store.period
        : txns.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = txns.isEmpty
        ? store.period
        : txns.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final newest =
        store.period.isAfter(latest) ? store.period : latest;

    final months = <DateTime>[];
    var m = DateTime(newest.year, newest.month);
    final stop = DateTime(earliest.year, earliest.month);
    while (!m.isBefore(stop)) {
      months.add(m);
      m = DateTime(m.year, m.month - 1);
    }

    await showAppSheet<void>(
      context,
      title: 'Month',
      initialSize: 0.6,
      builder: (sheetContext, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            0,
            Insets.gutter,
            Insets.xxl,
          ),
          children: [
            for (var i = 0; i < months.length; i++) ...[
              if (i == 0 || months[i].year != months[i - 1].year)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Insets.md, 4, Insets.xs),
                  child: Text('${months[i].year}', style: AppText.label),
                ),
              _monthRow(store, sheetContext, months[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _monthRow(AppStore store, BuildContext sheetContext, DateTime month) {
    final current = store.period.year == month.year &&
        store.period.month == month.month;
    return InkWell(
      onTap: () {
        store.period = month;
        Navigator.of(sheetContext).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: current
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentLight,
                    )
                  : null,
            ),
            Text(
              monthShort(month.month),
              style: TextStyle(
                fontSize: 15,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Ledger's pinned header (spec §1): the month as the screen title (with the
/// eye and `+` cloned from ScreenHeader), a thin passive ratio bar, and the
/// IN / OUT / LEFT metrics strip. The word "Ledger" appears nowhere — it lives
/// only in the tab bar.
class _HeaderZone extends StatelessWidget {
  const _HeaderZone({
    required this.store,
    required this.income,
    required this.expense,
    required this.left,
    required this.ratio,
    required this.onPickMonth,
    required this.onAdd,
  });

  final AppStore store;
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
    return Container(
      color: AppColors.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row — the month is the title.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: monthYearLong(store.period),
                    hint: 'Change month',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onPickMonth,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              monthYearLong(store.period),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                // Eye + `+`, cloned from ScreenHeader (same size/colour/behaviour).
                _CircleButton(
                  icon: store.masked
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  onTap: store.toggleMasked,
                ),
                const SizedBox(width: Insets.sm),
                _CircleButton(
                  icon: Icons.add_rounded,
                  accent: true,
                  onTap: onAdd,
                ),
              ],
            ),
          ),
          // Ratio bar — passive, 3pt, full width (§1).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Semantics(
              label: income > 0 || expense > 0
                  ? 'Spent ${money(expense, masked: store.masked)} of '
                      '${money(income, masked: store.masked)}'
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
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _Metric(label: 'IN', value: income, color: AppColors.positive),
                  const SizedBox(width: 13),
                  _Metric(
                      label: 'OUT',
                      value: expense,
                      color: AppColors.negative),
                  const Spacer(),
                  // LEFT — one step larger; it is the figure the screen answers.
                  // Balance-like: it keeps its minus sign and turns red when the
                  // month is overspent (§1.2).
                  _Metric(
                    label: 'LEFT',
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
          const SizedBox(height: Insets.md),
        ],
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
  const _CircleButton({required this.icon, this.onTap, this.accent = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

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
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
