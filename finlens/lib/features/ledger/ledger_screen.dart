import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../core/utils/search_fold.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
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
    if (_tagIds.isNotEmpty && !t.tags.any(_tagIds.contains)) return false;
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
    final window = store.ledgerWindow;

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
                _tagIds.clear();
                _min = null;
                _max = null;
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
                            backLabel: 'Ledger',
                          ),
                        ),
                      )
                    : Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SameTransactionsScreen(
                            originTxnId: day.txns[i].id,
                            backLabel: 'Ledger',
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

  /// The unified filter sheet (spec §2.2). All per-item counts and the range
  /// are computed once here from the current period's transactions and handed to
  /// the shared sheet; the sheet's snapshot is mapped back onto this screen's
  /// filter state on every change so the list behind updates immediately.
  ///
  /// Note: there is deliberately no free-text/notes field here — description
  /// search belongs to the list search, which already matches notes and tags
  /// and combines multiplicatively with this filter (spec §7).
  Future<void> _openFilter(AppStore store) async {
    final all = store.txnsInWindow(store.ledgerWindow);
    final accountIds = {for (final a in store.accounts) a.id};

    // One O(n) pass over the period for the per-item counts (spec §4, §7 —
    // never per-row queries).
    final catCount = <String, int>{};
    final accCount = <String, int>{};
    final tagCount = <String, int>{};
    var rangeMin = double.infinity;
    var rangeMax = 0.0;
    for (final t in all) {
      final cref = switch (t.type) {
        TxnType.expense => t.toRef,
        TxnType.income => t.fromRef,
        _ => null,
      };
      if (cref != null) catCount[cref] = (catCount[cref] ?? 0) + 1;
      for (final id in {t.fromRef, t.toRef}) {
        if (accountIds.contains(id)) accCount[id] = (accCount[id] ?? 0) + 1;
      }
      for (final tag in t.tags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
      final amt = Fx.toBase(t.amount, t.currency).abs();
      if (amt < rangeMin) rangeMin = amt;
      if (amt > rangeMax) rangeMax = amt;
    }
    if (rangeMin == double.infinity) rangeMin = 0;

    // Order fixed once from the period counts (non-zero desc, then zeros
    // alphabetically) so a direction toggle re-dims without reflowing (§4).
    int order(String aId, String aName, String bId, String bName,
        Map<String, int> counts) {
      final ca = counts[aId] ?? 0, cb = counts[bId] ?? 0;
      if ((ca == 0) != (cb == 0)) return ca == 0 ? 1 : -1;
      if (ca != cb && ca != 0) return cb.compareTo(ca);
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    }

    final cats = [...store.categories]
      ..sort((a, b) => order(a.id, a.name, b.id, b.name, catCount));
    final accs = [...store.accounts]
      ..sort((a, b) => order(a.id, a.name, b.id, b.name, accCount));
    final tags = tagCount.keys.toList()
      ..sort((a, b) {
        final c = (tagCount[b]!).compareTo(tagCount[a]!);
        return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
      });

    // A category's count is contextual to the DIRECTION: a category of the
    // opposite kind (or any category under Transfers) contributes 0 in that
    // context and so dims to 40% by the sheet's single count==0 rule (§4).
    int catCtx(Category c, TxnType? dir) {
      final base = catCount[c.id] ?? 0;
      return switch (dir) {
        null => base,
        TxnType.income => c.type == CategoryType.income ? base : 0,
        TxnType.expense => c.type == CategoryType.expense ? base : 0,
        _ => 0,
      };
    }

    List<FilterChipItem> catItems(TxnType? dir) => [
          for (final c in cats)
            FilterChipItem(
              id: c.id,
              label: c.name,
              icon: c.icon,
              color: c.color,
              count: catCtx(c, dir),
            ),
        ];
    List<FilterChipItem> accItems(TxnType? _) => [
          for (final a in accs)
            FilterChipItem(
              id: a.id,
              label: a.name,
              icon: a.displayIcon,
              color: a.color,
              count: accCount[a.id] ?? 0,
            ),
        ];
    List<FilterChipItem> tagItems(TxnType? _) => [
          for (final tg in tags)
            FilterChipItem(id: tg, label: '#$tg', count: tagCount[tg]!),
        ];

    int countMatches(FilterSnapshot s) {
      final cat = s.sel('categories');
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
        if (tg.isNotEmpty && !t.tags.any(tg.contains)) continue;
        final amt = Fx.toBase(t.amount, t.currency).abs();
        if (s.min != null && amt < s.min!) continue;
        if (s.max != null && amt > s.max!) continue;
        n++;
      }
      return n;
    }

    await showFilterSheet(
      context,
      total: all.length,
      searchable: true,
      direction: const [
        DirectionOption('All', null),
        DirectionOption('Income', TxnType.income),
        DirectionOption('Expenses', TxnType.expense),
        DirectionOption('Transfers', TxnType.transfer),
      ],
      initial: FilterSnapshot(
        direction: _direction,
        selections: {
          'categories': {..._categoryIds},
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
          ..addAll(s.sel('categories'));
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
        SectionFilterBlock(FilterSection(
          key: 'categories',
          label: 'CATEGORIES',
          kind: FilterSectionKind.rows,
          showCount: true,
          showControls: true,
          truncateAt: 5,
          itemsFor: catItems,
        )),
        SectionFilterBlock(FilterSection(
          key: 'accounts',
          label: 'ACCOUNTS',
          kind: FilterSectionKind.rows,
          showCount: true,
          showControls: true,
          truncateAt: 5,
          itemsFor: accItems,
        )),
        if (tags.isNotEmpty)
          SectionFilterBlock(FilterSection(
            key: 'tags',
            label: 'TAGS',
            kind: FilterSectionKind.chips,
            showCount: true,
            showControls: true,
            truncateAt: 6,
            itemsFor: tagItems,
          )),
        AmountFilterBlock(
          rangeMin: rangeMin,
          rangeMax: rangeMax,
          maxHint: 'Any',
        ),
      ],
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
                Expanded(child: _PeriodTitle(store: store, onTap: onPickMonth)),
                // The way out of the range lens sits beside the state it undoes
                // (§1): a third circle, purple like the title it clears, present
                // only while a lens is active — so in month mode this row is
                // byte-identical to before.
                if (store.isRangeLensActive) ...[
                  const SizedBox(width: Insets.sm),
                  Semantics(
                    button: true,
                    label: 'Clear custom range',
                    hint: 'Back to ${monthYearLong(store.period)}',
                    child: _CircleButton(
                      icon: Icons.close_rounded,
                      tint: AppColors.accentLight,
                      onTap: store.clearRangeLens,
                    ),
                  ),
                ],
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

/// The period title: the month in white, or — while a range lens is active —
/// the range in accent purple (the app's temporary-lens language) with a
/// `{n} days` subtitle. The ⌄ chevron and the tap-to-open behaviour are
/// unchanged in both states; the range form shrinks/ellipsizes before it can
/// reach the eye/`+` buttons.
class _PeriodTitle extends StatelessWidget {
  const _PeriodTitle({required this.store, required this.onTap});

  final AppStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lens = store.rangeLens;
    final isLens = lens != null;
    final titleText =
        isLens ? lens.label(AppStore.today) : monthYearLong(store.period);
    final days = isLens ? lens.days : 0;
    final semanticLabel = isLens
        ? '$titleText, $days ${days == 1 ? 'day' : 'days'}'
        : monthYearLong(store.period);

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: 'Change period',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
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
                  '$days ${days == 1 ? 'day' : 'days'}',
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
  const _CircleButton(
      {required this.icon, this.onTap, this.accent = false, this.tint});

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
