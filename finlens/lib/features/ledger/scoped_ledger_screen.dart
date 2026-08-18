import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/search_fold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/swipe_actions.dart';
import '../../shared/widgets/swipe_back_route.dart';
import '../../theme/app_colors.dart';
import '../balance/edit_account_screen.dart';
import '../balance/same_transactions_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'ledger_scope.dart';
import 'trans_filter.dart';
import 'transfer_detail_screen.dart';
import 'widgets/ledger_txn_row.dart';
import 'widgets/period_row.dart';
import 'widgets/trans_filter_sheet.dart';

/// The transaction list, scoped to everything / a group / one account.
///
/// Group and account ledgers are this one widget with a different
/// [LedgerScope] — see [LedgerScope] for why they are not two screens.
class ScopedLedgerScreen extends StatefulWidget {
  const ScopedLedgerScreen({super.key, required this.initialScope});

  final LedgerScope initialScope;

  @override
  State<ScopedLedgerScreen> createState() => _ScopedLedgerScreenState();
}

class _ScopedLedgerScreenState extends State<ScopedLedgerScreen> {
  late LedgerScope _scope = widget.initialScope;
  late DateRange _range;

  FlowKind? _filter;

  /// True while the period sheet is open, so the chip can tint (spec §4).
  bool _rangeSheetOpen = false;

  // ── Swipe-back gesture ────────────────────────────────────────────────────
  /// Non-null only while an armed hold is following the finger toward a pop.
  SwipeBackController? _backController;

  /// Set when an armed hold was spent closing an open row menu instead of
  /// popping — the next held drag pops.
  bool _closingMenu = false;

  /// Latest leftward drag distance, so the reduce-motion path (no live follow)
  /// can decide commit vs cancel on release.
  double _lastDragLeft = 0;

  /// Rows the user has deleted but not yet committed. They stay out of the
  /// list while the undo snackbar is up, so Undo restores them in place with
  /// their original id and position — deleting from the store and re-adding
  /// would mint a new id and drop the row at the end.
  final Set<String> _pendingDelete = {};

  /// A swipe leaves no trace on screen, so it is taught once. Held in memory
  /// rather than on disk: the project has no persistence layer, and adding one
  /// would reach past this screen's scope.
  static bool _hintShown = false;

  Timer? _hintTimer;

  // ── Search (transient; never persisted, spec §3/§5) ───────────────────────
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  /// The field's current text (for the clear glyph); filtering uses
  /// [_debouncedQuery], which lags by ~200ms.
  String _query = '';
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    // Land on the period containing today, at the unit saved for this screen
    // type (account vs category) — the cursor is never persisted (spec §5).
    _range = _periodForScope(StoreScope.read(context), _scope);
    if (!_hintShown) {
      _hintShown = true;
      // Cancellable so leaving the screen early does not leave it pending.
      _hintTimer = Timer(
        const Duration(milliseconds: 600),
        () => hintSwipeRow(),
      );
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  DateRange _periodForScope(AppStore store, LedgerScope scope) {
    final unit = scope is AccountScope
        ? store.accountPeriodUnit
        : store.categoryPeriodUnit;
    return currentPresetFor(unit).resolve(AppStore.today);
  }

  /// Persist the chosen unit under this screen's type — account screens share
  /// one preference, category/all screens another.
  void _saveUnit(AppStore store, PeriodUnit unit) {
    if (_scope is AccountScope) {
      store.setAccountPeriodUnit(unit);
    } else {
      store.setCategoryPeriodUnit(unit);
    }
  }

  void _setScope(LedgerScope scope) {
    // Changing scope does not push a route — the switcher is a filter on one
    // screen, so Back stays one deep however long the user browses.
    setState(() {
      _scope = scope;
      _filter = null;
      _exitSearch();
    });
  }

  /// The instance key this scope's filter persists under (spec §5).
  String get _scopeKey => switch (_scope) {
    AllAccountsScope() => 'all',
    GroupScope(:final group) => 'group:${group.name}',
    AccountScope(:final accountId) => 'account:$accountId',
  };

  /// Account screens group by category; the group/all bucket groups by account
  /// (spec §1, adaptive dimension). This drives both the filter's group section
  /// and the by-name sort axis.
  bool get _byCategory => _scope is AccountScope;

  Set<String> _scopeAccountIds(AppStore store) => {
    for (final a in _scope.accountsIn(store)) a.id,
  };

  /// A transaction's ids in the active grouping dimension.
  Set<String> _groupIdsOf(ScopedTxn r, Set<String> scopeAccountIds) {
    if (_byCategory) {
      final id = switch (r.txn.type) {
        TxnType.expense => r.txn.toRef,
        TxnType.income => r.txn.fromRef,
        _ => null, // transfers/rebalances carry no category
      };
      return id == null ? const {} : {id};
    }
    return {r.txn.fromRef, r.txn.toRef}.where(scopeAccountIds.contains).toSet();
  }

  TxnFacts _factsOf(ScopedTxn r, Set<String> scopeAccountIds) => TxnFacts(
    type: r.txn.type,
    groupIds: _groupIdsOf(r, scopeAccountIds),
    absAmount: r.signedAmount,
    tags: r.txn.tags,
  );

  /// The folded haystack a search query is tested against: the category and
  /// account names, the description, the tags and the amount digits (spec §3).
  String _searchable(AppStore store, ScopedTxn r) {
    final t = r.txn;
    return foldSearch(
      [
        store.refName(t.fromRef),
        store.refName(t.toRef),
        t.note,
        ...t.tags,
        r.signedAmount.toStringAsFixed(2),
        r.signedAmount.round().toString(),
      ].join(' '),
    );
  }

  String _sortName(AppStore store, ScopedTxn r, Set<String> scopeAccountIds) {
    if (_byCategory) {
      return switch (r.txn.type) {
        TxnType.expense => store.refName(r.txn.toRef),
        TxnType.income => store.refName(r.txn.fromRef),
        TxnType.transfer => 'Transfer',
        TxnType.rebalance => 'Revaluation',
      };
    }
    final ids = {r.txn.fromRef, r.txn.toRef}.where(scopeAccountIds.contains);
    return ids.isEmpty ? '' : store.refName(ids.first);
  }

  List<ScopedTxn> _sorted(
    List<ScopedTxn> rows,
    TransSort sort,
    AppStore store,
    Set<String> scopeAccountIds,
  ) {
    int byDateDesc(ScopedTxn a, ScopedTxn b) =>
        b.txn.date.compareTo(a.txn.date);
    final out = [...rows];
    switch (sort) {
      case TransSort.dateNewest:
        out.sort(byDateDesc);
      case TransSort.dateOldest:
        out.sort((a, b) => a.txn.date.compareTo(b.txn.date));
      case TransSort.amountHigh:
        out.sort((a, b) {
          final c = b.signedAmount.compareTo(a.signedAmount);
          return c != 0 ? c : byDateDesc(a, b);
        });
      case TransSort.amountLow:
        out.sort((a, b) {
          final c = a.signedAmount.compareTo(b.signedAmount);
          return c != 0 ? c : byDateDesc(a, b);
        });
      case TransSort.byName:
        out.sort((a, b) {
          final c = foldSearch(
            _sortName(store, a, scopeAccountIds),
          ).compareTo(foldSearch(_sortName(store, b, scopeAccountIds)));
          return c != 0 ? c : byDateDesc(a, b);
        });
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final query = LedgerQuery(
      store: store,
      scope: _scope,
      start: _range.start,
      end: _range.end,
    );

    final scopeAccountIds = _scopeAccountIds(store);
    final filter = store.transFilter(_scopeKey);
    final sort = store.transSort(account: _scope is AccountScope);

    // Compose once per rebuild: period → filter → search → sort → grouping.
    final periodRows = query
        .rows()
        .where((r) => !_pendingDelete.contains(r.txn.id))
        .toList();

    final afterFilter = filter.isActive
        ? periodRows
              .where((r) => filter.matches(_factsOf(r, scopeAccountIds)))
              .toList()
        : periodRows;

    final q = foldSearch(_debouncedQuery.trim());
    final afterSearch = q.isEmpty
        ? afterFilter
        : afterFilter.where((r) => _searchable(store, r).contains(q)).toList();

    // The chip's In/Out figures reflect the filtered + searched set (before the
    // chip's own direction toggle), so they always agree with the count (§4).
    final totalIn = afterSearch
        .where((r) => r.kind == FlowKind.inflow)
        .fold(0.0, (s, r) => s + r.signedAmount);
    final totalOut = afterSearch
        .where((r) => r.kind == FlowKind.outflow)
        .fold(0.0, (s, r) => s + r.signedAmount);

    final afterFlow = _filter == null
        ? afterSearch
        : afterSearch.where((r) => r.kind == _filter).toList();
    final visible = _sorted(afterFlow, sort, store, scopeAccountIds);

    final total = periodRows.length;
    final shown = visible.length;

    final _EmptyReason? emptyReason = total == 0
        ? _EmptyReason.period
        : shown == 0
        ? (filter.isActive
              ? _EmptyReason.filter
              : (_searching && q.isNotEmpty
                    ? _EmptyReason.search
                    : _EmptyReason.period))
        : null;

    return Scaffold(
      backgroundColor: AppColors.formBg,
      body: _swipeBack(
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _navBar(store),
              _hero(store, query),
              PeriodRow(
                range: _range,
                totalIn: totalIn,
                totalOut: totalOut,
                filter: _filter,
                highlighted: _rangeSheetOpen,
                onStep: (steps) =>
                    setState(() => _range = _range.copyShifted(steps)),
                onPickRange: () => _pickRange(store),
                // Tapping the active figure again clears it.
                onFilter: (kind) =>
                    setState(() => _filter = _filter == kind ? null : kind),
              ),
              _searching
                  ? _searchBar(shown)
                  : _toolbar(
                      store,
                      total,
                      shown,
                      filter,
                      periodRows,
                      scopeAccountIds,
                    ),
              Expanded(
                child: _list(
                  visible,
                  emptyReason: emptyReason,
                  grouped: sort.groupsByDay,
                  highlight: (_searching && q.isNotEmpty) ? q : null,
                  store: store,
                ),
              ),
              _addButton(store),
            ],
          ),
        ),
      ),
    );
  }

  // ── Swipe-back gesture ────────────────────────────────────────────────────
  //
  // Hold ~300ms, then drag left to pop. The hold is the discriminator: a
  // [LongPressGestureRecognizer] only claims the pointer after the hold, so a
  // quick left drag still loses to (and opens) the row's action menu, while a
  // held drag wins the arena and the row's slidable never animates.

  /// Wraps the screen body. Translucent so taps/scrolls/row-drags still reach
  /// the children; the long-press only wins after the hold.
  Widget _swipeBack(Widget child) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 300),
              ),
              (rec) => rec
                ..onLongPressStart = _onSwipeArm
                ..onLongPressMoveUpdate = _onSwipeMove
                ..onLongPressEnd = _onSwipeEnd
                ..onLongPressCancel = _onSwipeCancel,
            ),
      },
      child: child,
    );
  }

  /// Active only when this is the current, non-root [SwipeBackPageRoute] — so
  /// it is inert under a bottom sheet or dialog (not current) and at a tab root
  /// (nothing to pop to).
  bool get _canSwipeBack {
    final route = ModalRoute.of(context);
    return route is SwipeBackPageRoute && route.isCurrent && !route.isFirst;
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _onSwipeArm(LongPressStartDetails details) {
    _lastDragLeft = 0;
    if (!_canSwipeBack) return;
    // The only signal that the drag will navigate rather than open a menu.
    HapticFeedback.lightImpact();
    if (anySwipeRowOpen) {
      // First held drag over an open menu just closes it — never also pops.
      closeOpenSwipeRow();
      _closingMenu = true;
      return;
    }
    if (_reduceMotion) return; // decided on release, no follow-the-finger
    _backController = SwipeBackController(
      route: ModalRoute.of(context)! as SwipeBackPageRoute,
      width: MediaQuery.of(context).size.width,
    );
  }

  void _onSwipeMove(LongPressMoveUpdateDetails details) {
    if (_closingMenu) return;
    // Horizontal component only — the route never drifts vertically.
    final dragLeft = -details.localOffsetFromOrigin.dx;
    _lastDragLeft = dragLeft;
    // Begin following once the finger has clearly moved left (spec ~12pt).
    _backController?.update(dragLeft < 12 ? 0 : dragLeft);
  }

  void _onSwipeEnd(LongPressEndDetails details) {
    if (_closingMenu) {
      _closingMenu = false;
      return;
    }
    final vx = details.velocity.pixelsPerSecond.dx;
    if (_backController != null) {
      _backController!.end(vx);
      _backController = null;
      return;
    }
    // Reduce motion: no live follow, so decide from the final drag distance.
    if (_reduceMotion && _canSwipeBack) {
      final past = _lastDragLeft > MediaQuery.of(context).size.width * 0.4;
      if (past || vx < -700) Navigator.of(context).pop();
    }
  }

  void _onSwipeCancel() {
    _closingMenu = false;
    _backController?.cancel();
    _backController = null;
  }

  // ── Chrome ────────────────────────────────────────────────────────────────

  Widget _navBar(AppStore store) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          // Always reads Balance: the switcher changes what is shown, it never
          // pushes, so there is only ever one thing behind this screen.
          //
          // Sized to its content rather than a fixed slot — the nav bar has no
          // centre title to balance against, so a fixed width bought nothing
          // and clipped the label to "Balan…".
          Flexible(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  Flexible(
                    child: Text(
                      'Balance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // For a single account, ••• opens Edit Account — the only path to it
          // now that the legacy account-detail screen is gone. For group / all
          // scopes there is no account to edit, so it stays inert.
          if (_scope is AccountScope)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditAccountScreen(
                    accountId: (_scope as AccountScope).accountId,
                  ),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.only(right: 16, left: 8, top: 8, bottom: 8),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// Avatar, name-as-scope-switcher, subtitle and balance in one row. The nav
  /// bar has no centre title precisely because this carries the name — two
  /// copies of it would just push the list down.
  Widget _hero(AppStore store, LedgerQuery query) {
    final colour = _scopeColour(store);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _scopeIcon(store),
              size: 20,
              color: Color.lerp(colour, Colors.black, 0.72),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _pickScope(store),
                  child: ConstrainedBox(
                    // The switcher is the name itself, so it has to clear 44pt.
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _scope.title(store),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.015 * 17,
                              height: 1.15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 10,
                          color: AppColors.textPrimary.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _metaPrefix(store),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: AppColors.formDim2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            money(query.balance, signless: true, masked: store.masked),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.022 * 22,
              height: 1.15,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Color _scopeColour(AppStore store) => switch (_scope) {
    AllAccountsScope() => AppColors.accent,
    GroupScope(:final group) => group.color,
    AccountScope(:final accountId) =>
      store.accountById(accountId)?.group.color ?? AppColors.accent,
  };

  IconData _scopeIcon(AppStore store) => switch (_scope) {
    AllAccountsScope() => Icons.grid_view_rounded,
    GroupScope(:final group) => group.icon,
    AccountScope(:final accountId) =>
      store.accountById(accountId)?.group.icon ?? Icons.wallet_rounded,
  };

  String _metaPrefix(AppStore store) {
    switch (_scope) {
      case AllAccountsScope():
        return '${store.accounts.length} accounts';
      case GroupScope(:final group):
        final n = store.groupCount(group);
        return '$n ${n == 1 ? 'account' : 'accounts'}  ·  '
            '${percent(store.groupShare(group))} of '
            '${group.isAsset ? 'assets' : 'liabilities'}';
      case AccountScope(:final accountId):
        final a = store.accountById(accountId);
        return a == null ? '' : '${a.group.label}  ·  ${a.currency}';
    }
  }

  Widget _toolbar(
    AppStore store,
    int total,
    int shown,
    TransFilter filter,
    List<ScopedTxn> periodRows,
    Set<String> scopeAccountIds,
  ) {
    // Narrowed whenever fewer rows show than the period holds — from the §2
    // filter, the search, or the direction chip. The `N of M` reading is the
    // primary signal; the filled funnel is secondary (spec §4).
    final narrowed = shown != total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    if (narrowed)
                      TextSpan(
                        text: '$shown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    TextSpan(
                      text: narrowed
                          ? ' of $total transactions'
                          : '$total transactions',
                    ),
                  ],
                ),
              ),
            ),
          ),
          ToolCluster(
            tools: [
              Tool(
                icon: Icons.swap_vert_rounded,
                tooltip: 'Sort transactions',
                onTap: () => _openSort(store),
              ),
              // Active state follows the Balance filter button: the glyph fills
              // and brightens one step; the background never changes (spec §2).
              Tool(
                icon: filter.isActive
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
                tooltip: 'Filter transactions',
                iconColor: filter.isActive ? AppColors.textPrimary : null,
                semanticValue: filter.isActive
                    ? 'Active, $shown of $total shown'
                    : 'Off',
                onTap: () =>
                    _openFilter(store, filter, periodRows, scopeAccountIds),
              ),
              Tool(
                icon: Icons.search_rounded,
                tooltip: 'Search transactions',
                onTap: () => setState(() => _searching = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search in place (spec §3) ─────────────────────────────────────────────

  void _exitSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _searching = false;
    _query = '';
    _debouncedQuery = '';
  }

  Widget _searchBar(int results) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
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
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(_exitSearch),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              '$results ${results == 1 ? 'result' : 'results'}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = value);
    });
  }

  // ── Sort & filter sheets ──────────────────────────────────────────────────

  Future<void> _openSort(AppStore store) async {
    final account = _scope is AccountScope;
    final current = store.transSort(account: account);
    final lastLabel = _byCategory ? 'Category — A to Z' : 'Account — A to Z';
    final picked = await showModalBottomSheet<TransSort>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SORT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08 * 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            for (final s in TransSort.values)
              _sortRow(
                sheetContext,
                s,
                s == TransSort.byName ? lastLabel : s.label,
                s == current,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      store.setTransSort(account: account, sort: picked);
    }
  }

  Widget _sortRow(
    BuildContext sheetContext,
    TransSort sort,
    String label,
    bool active,
  ) {
    return Semantics(
      button: true,
      selected: active,
      child: ListTile(
        leading: SizedBox(
          width: 22,
          child: active
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.accentLight,
                )
              : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        onTap: () => Navigator.of(sheetContext).pop(sort),
      ),
    );
  }

  void _openFilter(
    AppStore store,
    TransFilter current,
    List<ScopedTxn> periodRows,
    Set<String> scopeAccountIds,
  ) {
    final groupCounts = <String, int>{};
    final tagCounts = <String, int>{};
    for (final r in periodRows) {
      for (final id in _groupIdsOf(r, scopeAccountIds)) {
        groupCounts[id] = (groupCounts[id] ?? 0) + 1;
      }
      for (final tag in r.txn.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final groups =
        groupCounts.entries
            .map(
              (e) => FilterChipItem(
                id: e.key,
                label: store.refName(e.key),
                count: e.value,
                color: store.refColor(e.key),
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final tags =
        tagCounts.entries
            .map((e) => FilterChipItem(id: e.key, label: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    final amounts = periodRows.map((r) => r.signedAmount).toList();
    final rangeMin = amounts.isEmpty ? 0.0 : amounts.reduce(math.min);
    final rangeMax = amounts.isEmpty ? 0.0 : amounts.reduce(math.max);
    final facts = periodRows.map((r) => _factsOf(r, scopeAccountIds)).toList();

    showTransFilterSheet(
      context,
      groupSectionLabel: _byCategory ? 'CATEGORIES' : 'ACCOUNTS',
      groups: groups,
      tags: tags,
      rangeMin: rangeMin,
      rangeMax: rangeMax,
      total: periodRows.length,
      facts: facts,
      initial: current,
      // Every change applies immediately to the screen behind the sheet (§2).
      onChanged: (f) => setState(() => store.setTransFilter(_scopeKey, f)),
    );
  }

  /// Prefilled with the scope's account where there is exactly one.
  Widget _addButton(AppStore store) {
    final accounts = _scope.accountsIn(store);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: FilledButton(
          onPressed: () => showQuickAdd(
            context,
            fixedFromAccountId: accounts.length == 1 ? accounts.first.id : null,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '+  Add expense',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _list(
    List<ScopedTxn> rows, {
    required _EmptyReason? emptyReason,
    required bool grouped,
    required String? highlight,
    required AppStore store,
  }) {
    if (emptyReason != null) return _emptyState(store, emptyReason);

    // Under a date sort, group by day; under amount/name sorts, one flat card
    // with no day headers (spec §1).
    final List<DayGroup> groups;
    if (grouped) {
      // `rows` is already in the chosen date order (newest- or oldest-first);
      // group in first-appearance order so the day headers follow that order
      // rather than being forced back to descending.
      final byDay = <DateTime, List<ScopedTxn>>{};
      for (final r in rows) {
        final key = DateTime(r.txn.date.year, r.txn.date.month, r.txn.date.day);
        byDay.putIfAbsent(key, () => []).add(r);
      }
      groups = byDay.entries
          .map((e) => DayGroup(date: e.key, rows: e.value))
          .toList();
    } else {
      groups = [DayGroup(date: rows.first.txn.date, rows: rows)];
    }

    return NotificationListener<ScrollStartNotification>(
      // Scrolling closes an open swipe strip.
      onNotification: (n) {
        if (n.dragDetails != null) closeOpenSwipeRow();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 28),
        itemCount: groups.length,
        itemBuilder: (context, i) => LedgerDayCard(
          isFirstCard: i == 0,
          flat: !grouped,
          highlight: highlight,
          group: groups[i],
          scope: _scope,
          // A row tap opens a read-only screen, never the editor — the back
          // label names the screen we came from. A transfer has no category
          // key, so it opens its own transfer detail (spec §5) rather than the
          // category/description Same-transactions screen.
          onOpen: (txn) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => txn.type == TxnType.transfer
                  ? TransferDetailScreen(
                      txnId: txn.id,
                      backLabel: _scope.title(store),
                    )
                  : SameTransactionsScreen(
                      originTxnId: txn.id,
                      backLabel: _scope.title(store),
                    ),
            ),
          ),
          onEdit: (txn) => showQuickAdd(context, editing: txn),
          // Opens the form on a copy dated today rather than saving silently —
          // a duplicate appearing unannounced reads as a bug.
          onCopy: (txn) => showQuickAdd(context, copyOf: txn),
          onDelete: _deleteWithUndo,
        ),
      ),
    );
  }

  /// The list area's empty states (spec §6). Never replaces the chip, the count
  /// row, or the tool buttons — only the list itself.
  Widget _emptyState(AppStore store, _EmptyReason reason) {
    switch (reason) {
      case _EmptyReason.period:
        return const Padding(
          padding: EdgeInsets.only(top: 64),
          child: Text(
            'No transactions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.formDim2),
          ),
        );
      case _EmptyReason.filter:
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
                onTap: () => store.setTransFilter(_scopeKey, TransFilter.empty),
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
      case _EmptyReason.search:
        return Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Text(
            'No results for "${_debouncedQuery.trim()}"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        );
    }
  }

  /// No confirm dialog: a dialog costs every user a tap to guard against a
  /// mistake undo already fixes better, and undo also covers realising a
  /// second later, which a dialog does not.
  void _deleteWithUndo(Txn txn) {
    setState(() => _pendingDelete.add(txn.id));
    final store = StoreScope.read(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) setState(() => _pendingDelete.remove(txn.id));
            },
          ),
        ),
      ).closed.then((reason) {
        if (reason == SnackBarClosedReason.action) return;
        // Left to expire, or the user navigated away: commit.
        if (_pendingDelete.remove(txn.id)) store.deleteTxn(txn);
      });
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  /// The sheet rows, in display order: the default (This month) first, the
  /// extra "All time" kept last (spec §4). Every preset is a whole-period.
  static const _rangeRows = <RangePreset>[
    RangePreset.thisMonth,
    RangePreset.lastMonth,
    RangePreset.thisWeek,
    RangePreset.lastWeek,
    RangePreset.last3Months,
    RangePreset.thisYear,
    RangePreset.allTime,
  ];

  Future<void> _pickRange(AppStore store) async {
    setState(() => _rangeSheetOpen = true);
    final today = AppStore.today;
    final picked = await showModalBottomSheet<RangePreset>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      // Scrollable so seven rows never overflow the box, even at 320×568 / 130%.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Period',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final p in _rangeRows) _rangeRow(sheetContext, p, today),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _rangeSheetOpen = false);
    if (picked != null) {
      setState(() => _range = picked.resolve(today));
      final unit = picked.unit;
      if (unit != null) _saveUnit(store, unit);
    }
  }

  Widget _rangeRow(BuildContext sheetContext, RangePreset p, DateTime today) {
    final resolved = p.resolve(today);
    final active = resolved.start == _range.start && resolved.end == _range.end;
    return ListTile(
      // A left check slot the app uses on its other option sheets; inactive
      // rows keep the same-width empty slot so labels stay aligned.
      leading: SizedBox(
        width: 22,
        child: active
            ? const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.accentLight,
              )
            : null,
      ),
      title: Text(
        p.label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        resolved.label(today),
        style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      ),
      onTap: () => Navigator.of(sheetContext).pop(p),
    );
  }

  Future<void> _pickScope(AppStore store) async {
    final picked = await showModalBottomSheet<LedgerScope>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Show',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text(
                      'All accounts',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${store.accounts.length} accounts · '
                      '${AccountGroup.values.length} groups',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.formDim2,
                      ),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(const AllAccountsScope()),
                  ),
                  for (final g in AccountGroup.values)
                    if (store.groupCount(g) > 0) ...[
                      ListTile(
                        leading: Icon(g.icon, size: 20, color: g.color),
                        title: Text(
                          g.label,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${store.groupCount(g)} accounts',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.formDim2,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(sheetContext).pop(GroupScope(g)),
                      ),
                      for (final a in store.accountsIn(g))
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              a.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFD4D4D9),
                              ),
                            ),
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop(AccountScope(a.id)),
                          ),
                        ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) _setScope(picked);
  }
}

/// Why the list area is empty — each renders a different message (spec §6).
enum _EmptyReason { period, filter, search }
