import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/section_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'account_detail_screen.dart';
import 'balance_order.dart';
import 'widgets/reorderable_group.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import '../quick_add/quick_add_sheet.dart';
import 'widgets/account_rows.dart';
import 'widgets/balance_filter_sheet.dart';
import 'widgets/date_sheet.dart';

/// The three views of the same list. Filtering here is *focusing*, not
/// narrowing: asking for assets and then expanding each group by hand would be
/// a redundant step, so a filtered section opens all of its groups.
enum BalanceSection {
  all('Net worth'),
  assets('Assets'),
  liabilities('Liabilities');

  const BalanceSection(this.label);

  final String label;
}

/// Spec 1.1 — Balance.
///
/// The header answers "what am I worth" in 106px, including the tool cluster;
/// everything below belongs to the account list, which is the part of the
/// screen people actually read.
class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key, this.scrollToTopSignal = 0});

  /// Bumped by the shell when this tab is reselected while already active —
  /// the screen responds by scrolling its list back to the top.
  final int scrollToTopSignal;

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  BalanceSection _section = BalanceSection.all;

  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  final _scrollController = ScrollController();

  /// Groups the user has explicitly toggled, layered over the section default.
  final Set<AccountGroup> _opened = {};
  final Set<AccountGroup> _closed = {};

  /// Non-null only while a row is lifted. Drives the containment cue: the
  /// regions an item can't legally reach dim to 42% while it travels.
  _ActiveDrag? _activeDrag;

  /// The single move that Undo would revert. Replaced by each new drag; only
  /// the most recent move is ever undoable (no undo stack).
  _PendingMove? _pendingMove;

  @override
  void initState() {
    super.initState();
    _applySectionDefault();
  }

  @override
  void didUpdateWidget(covariant BalanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToTopSignal != oldWidget.scrollToTopSignal) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Spendable starts open on All: "how much can I spend right now" is the most
  /// frequent question here and shouldn't cost a tap. A filtered section opens
  /// everything in it instead.
  ///
  /// Collapsing Spendable is deliberately not remembered across launches —
  /// otherwise one stray tap hides the screen's most valuable information for
  /// good and the user may never notice.
  void _applySectionDefault() {
    _opened
      ..clear()
      ..addAll(switch (_section) {
        BalanceSection.all => [AccountGroup.spendable],
        BalanceSection.assets => AccountGroup.assets,
        BalanceSection.liabilities => AccountGroup.liabilities,
      });
    _closed.clear();
  }

  bool _isOpen(AccountGroup g) => _opened.contains(g) && !_closed.contains(g);

  void _setSection(BalanceSection s) {
    setState(() {
      _section = s;
      _applySectionDefault();
    });
  }

  void _advanceSection() => _setSection(
        BalanceSection.values[
            (_section.index + 1) % BalanceSection.values.length],
      );

  /// Wraps in both directions, same as the label tap — no swipe is ever a
  /// no-op. Dart's `%` is Euclidean (always non-negative for a positive
  /// divisor), so this handles the -1 case without an extra branch.
  void _stepSection(int delta) {
    final n = BalanceSection.values.length;
    _setSection(BalanceSection.values[(_section.index + delta) % n]);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(store),
          Expanded(
            child: HorizontalSectionSwipe(
              onNext: () => _stepSection(1),
              onPrevious: () => _stepSection(-1),
              child: _list(store),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  /// 106px: label + dots + controls, then the amount beside the tools, then the
  /// ratio bar. Pinned — only the list scrolls.
  Widget _header(AppStore store) {
    final filter = store.balanceFilter;
    final showRatio = _section == BalanceSection.all && !_searching;

    // 34 + 4 + 34 + 8 + 4 + 4 + 14 + 4 = 106 on the All section. The height is
    // not hard-coded: with the ratio bar hidden the header shrinks and hands
    // the space to the list, and it grows by one line when a past date is
    // selected. Every vertical value here is a multiple of 2.
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 34, child: _headerRow1(store)),
            const SizedBox(height: 4),
            _headerRow2(store),
            if (showRatio) ...[
              const SizedBox(height: 8),
              _RatioBar(
                assets: filter.sectionTotal(store, assets: true),
                liabilities: filter.sectionTotal(store, assets: false).abs(),
              ),
              const SizedBox(height: 4),
              _ratioLabels(store),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerRow1(AppStore store) {
    return Row(
      children: [
        SectionIndicator(
          label: _section == BalanceSection.all
              ? 'Net worth'
              : _section.label,
          count: BalanceSection.values.length,
          index: _section.index,
          onAdvance: _advanceSection,
        ),
        const Spacer(),
        _DatePill(
          label: store.isHistorical ? dayMonth(store.asOf!) : 'Today',
          onTap: () => _pickDate(store),
        ),
        const SizedBox(width: Insets.sm),
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
          onTap: () => showQuickAdd(context),
        ),
      ],
    );
  }

  /// The amount and the tool cluster share one row; search replaces both
  /// in place, so the row never changes height.
  Widget _headerRow2(AppStore store) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _searching ? _searchField() : _amountAndTools(store),
    );
  }

  Widget _amountAndTools(AppStore store) {
    final filter = store.balanceFilter;
    // Every headline figure is the *filtered* one — hiding Valuables has to
    // move Net Worth, not just drop a row. The store getters stay unfiltered so
    // no other tab is affected; the filtering lives here.
    final (amount, color) = switch (_section) {
      BalanceSection.all => (filter.netWorth(store), null),
      BalanceSection.assets => (filter.sectionTotal(store, assets: true), null),
      BalanceSection.liabilities => (
          filter.sectionTotal(store, assets: false),
          AppColors.negative,
        ),
    };

    return Row(
      key: const ValueKey('amount'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AmountText.balance(
                  amount,
                  style: AppText.heroAmount,
                  color: color,
                ),
              ),
              // Without this line a user can easily believe a historical view
              // is live data.
              if (store.isHistorical)
                Text(
                  'as of ${dayMonthYear(store.asOf!)}',
                  style: AppText.asOfLine,
                ),
            ],
          ),
        ),
        const SizedBox(width: Insets.sm),
        Padding(
          // Sits level with the amount's baseline.
          padding: const EdgeInsets.only(bottom: 2),
          child: ToolCluster(
            tools: [
              Tool(
                icon: Icons.swap_vert_rounded,
                tooltip: 'Sort',
                showDot: store.balanceSort != AccountSort.defaultSort,
                onTap: _pickSort,
              ),
              Tool(
                icon: _anyOpen
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                tooltip: _anyOpen ? 'Collapse all' : 'Expand all',
                filled: !_anyOpen,
                onTap: _toggleAll,
              ),
              Tool(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: _openSearch,
              ),
              // Active state is icon-only by design: the funnel fills and
              // brightens one step, the surface never changes. The live Net
              // Worth preview inside the sheet is what tells the user the cost.
              Tool(
                icon: filter.isActive
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
                iconColor: filter.isActive ? AppColors.textPrimary : null,
                tooltip: 'Filter categories',
                semanticValue: filter.isActive
                    ? 'Active, ${filter.hiddenItemCount(store)} items hidden'
                    : 'Off',
                onTap: () => showBalanceFilterSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return Row(
      key: const ValueKey('search'),
      children: [
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(bottom: 0),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (q) => setState(() => _query = q),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14, height: 1.2),
                    cursorColor: AppColors.accentSoft,
                    cursorHeight: 16,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Search accounts',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeSearch,
          child: const Padding(
            padding: EdgeInsets.only(left: Insets.md),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: AppColors.accentSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ratioLabels(AppStore store) {
    final filter = store.balanceFilter;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: _RatioLabel(
            caption: 'Assets ',
            value: filter.sectionTotal(store, assets: true),
            color: AppColors.positive,
            alignment: Alignment.centerLeft,
          ),
        ),
        Flexible(
          child: _RatioLabel(
            caption: 'Liabilities ',
            value: filter.sectionTotal(store, assets: false),
            color: AppColors.negative,
            alignment: Alignment.centerRight,
          ),
        ),
      ],
    );
  }

  // ── Tools ─────────────────────────────────────────────────────────────────

  bool get _anyOpen => _visibleGroups.any(_isOpen);

  List<AccountGroup> get _visibleGroups => switch (_section) {
        BalanceSection.all => AccountGroup.values,
        BalanceSection.assets => AccountGroup.assets,
        BalanceSection.liabilities => AccountGroup.liabilities,
      };

  void _toggleAll() {
    setState(() {
      if (_anyOpen) {
        _closed.addAll(_visibleGroups);
      } else {
        _closed.clear();
        _opened.addAll(_visibleGroups);
      }
    });
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    // The section filter is preserved on cancel.
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  Future<void> _pickDate(AppStore store) async {
    final picked = await showReportingDateSheet(context, selected: store.asOf);
    if (picked == null) return;
    store.setAsOf(picked == liveDate ? null : picked);
  }

  Future<void> _pickSort() async {
    final current = StoreScope.read(context).balanceSort;
    final picked = await showModalBottomSheet<AccountSort>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) {
        Widget check(AccountSort option) => Opacity(
              opacity: option == current ? 1 : 0,
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.accentSoft,
              ),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Insets.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.lg,
                  Insets.gutter,
                  Insets.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SORT',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              // The four automatic orderings — unchanged.
              for (final option in AccountSort.automatic)
                ListTile(
                  leading: check(option),
                  title: Text(option.label, style: AppText.body),
                  // Applies immediately and dismisses — no confirm step.
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              // The divider splits "pick an automatic ordering" from "use the
              // order I made myself".
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Divider(height: 1, thickness: 1, color: AppColors.divider),
              ),
              ListTile(
                leading: check(AccountSort.custom),
                title: Text(AccountSort.custom.label, style: AppText.body),
                // The one and only advertisement of the press-and-hold gesture.
                subtitle: const Text(
                  'Press and hold a row to move it',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                // No chevron: selecting Custom pushes nothing, exactly like the
                // rows above it.
                onTap: () => Navigator.of(sheetContext).pop(AccountSort.custom),
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) {
      StoreScope.read(context).setBalanceSort(picked);
    }
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _list(AppStore store) {
    final assets = _groupsFor(store, AccountGroup.assets);
    final liabilities = _groupsFor(store, AccountGroup.liabilities);

    if (assets.isEmpty && liabilities.isEmpty) {
      if (_query.isNotEmpty) return _noResults();
      // No accounts at all is the "add your first account" case; accounts that
      // exist but are all filtered out fall through to per-section empty rows.
      final anyAccounts =
          AccountGroup.values.any((g) => store.groupCount(g) > 0);
      if (!anyAccounts) return _emptyState();
    }

    // Section headers only show on All: on a filtered section the total already
    // sits in the header 60px above, and it must appear in exactly one place.
    final showHeaders = _section == BalanceSection.all;

    // A section renders (header + rows, or the "all hidden" notice) whenever it
    // has visible groups OR it has accounts that the filter has hidden. A truly
    // empty section (no accounts) stays absent, as before.
    bool sectionHasAccounts(List<AccountGroup> section) =>
        !_searching && section.any((g) => store.groupCount(g) > 0);
    final assetsHasContent =
        assets.isNotEmpty || sectionHasAccounts(AccountGroup.assets);
    final liabsHasContent =
        liabilities.isNotEmpty || sectionHasAccounts(AccountGroup.liabilities);

    // A plain scroll view rather than a ListView: the reorderable groups are
    // non-scrolling columns nested inside it, and the list is small enough that
    // laziness buys nothing.
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_section != BalanceSection.liabilities && assetsHasContent)
            _sectionBlock(store,
                assets: true, groups: assets, showHeader: showHeaders),
          if (_section != BalanceSection.assets && liabsHasContent)
            _sectionBlock(store,
                assets: false, groups: liabilities, showHeader: showHeaders),
        ],
      ),
    );
  }

  /// One section: its header (dimmable) plus a reorderable column of its
  /// category blocks. Categories reorder only among themselves — a separate
  /// [ReorderableGroup] per section is what makes crossing the ASSETS /
  /// LIABILITIES boundary impossible.
  Widget _sectionBlock(
    AppStore store, {
    required bool assets,
    required List<AccountGroup> groups,
    required bool showHeader,
  }) {
    final filter = store.balanceFilter;
    final label = assets ? 'Assets' : 'Liabilities';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _sectionHeaderOpacity(assets),
            child: _ListSectionHeader(
                label, filter.sectionTotal(store, assets: assets)),
          ),
        if (groups.isEmpty)
          _filteredAwayRow()
        else
          ReorderableGroup<AccountGroup>(
            key: ValueKey('categories-$label'),
            items: groups,
            scrollController: _scrollController,
            semanticLabel: (g, i, n) =>
                '${g.label}, position ${i + 1} of $n in $label',
            onDragStart: (_) =>
                setState(() => _activeDrag = _ActiveDrag.category(assets)),
            onDragEnd: () => setState(() => _activeDrag = null),
            onReorder: (moved, target) => _onCategoryReorder(
              store,
              assets: assets,
              moved: moved,
              target: target,
              visible: groups,
            ),
            itemBuilder: (context, g) => _categoryBlock(store, g),
          ),
      ],
    );
  }

  /// Shown when a section's accounts are all filtered out — never a $0 group
  /// row. Offers the one way back: reopen the filter sheet.
  Widget _filteredAwayRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xl),
        child: Column(
          children: [
            Text(
              'No visible categories',
              style: AppText.body.copyWith(color: AppColors.textTertiary),
            ),
            TextButton(
              onPressed: () => showBalanceFilterSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Adjust filter'),
            ),
          ],
        ),
      );

  Widget _noResults() => const Padding(
        padding: EdgeInsets.only(top: 72),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results',
          message: 'No account or group matches your search.',
        ),
      );

  /// The one place an "add account" call to action belongs: what is redundant
  /// noise in a populated list is the only way forward in an empty one.
  Widget _emptyState() => Padding(
        padding: const EdgeInsets.only(top: 72),
        child: EmptyState(
          icon: Icons.account_balance_wallet_rounded,
          title: 'No accounts yet',
          message: 'Add your accounts and FinLens works out your net worth '
              'from the transactions you record.',
          action: FilledButton.icon(
            onPressed: () => showNewAccountSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add your first account'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.xl,
                vertical: 12,
              ),
            ),
          ),
        ),
      );

  /// Groups that survive the section filter and the search query — a hidden
  /// group has zero accounts left, never an empty header. Order is always
  /// [source]'s declared order: groups are screen structure, not data, so no
  /// sort option ever touches it.
  List<AccountGroup> _groupsFor(AppStore store, List<AccountGroup> source) {
    if (_section == BalanceSection.assets && source.first.isLiability) {
      return const [];
    }
    if (_section == BalanceSection.liabilities && source.first.isAsset) {
      return const [];
    }

    // Custom mode reorders the section's groups; the four automatic sorts leave
    // group order at the fixed declaration order. A filter-hidden group has
    // zero visible accounts, so it drops out here the same way a group with no
    // accounts does — never rendered as an empty row.
    final filter = store.balanceFilter;
    final ordered = store.balanceSort == AccountSort.custom
        ? store.balanceOrder.orderedCategories(assets: source.first.isAsset)
        : source;
    var groups = ordered
        .where((g) => store.groupCount(g) > 0 && filter.isGroupVisible(store, g))
        .toList();

    if (_query.isNotEmpty) {
      groups = groups.where((g) => _matchesQuery(store, g)).toList();
    }

    return groups;
  }

  bool _matchesQuery(AppStore store, AccountGroup group) {
    final q = _query.toLowerCase();
    if (group.label.toLowerCase().contains(q)) return true;
    // Search only sees visible accounts — one hidden inside a group must not
    // surface a match (spec §4.4.11).
    return store.balanceFilter.visibleAccounts(store, group).any(
          (a) => a.name.toLowerCase().contains(q),
        );
  }

  /// Children of [group], narrowed by the query and sorted by [_sort] —
  /// independently per group, since the sort applies to accounts, not to
  /// the (fixed) group order.
  List<Account> _children(AppStore store, AccountGroup group) {
    final q = _query.toLowerCase();
    final groupMatches = group.label.toLowerCase().contains(q);

    final list = store.balanceFilter
        .visibleAccounts(store, group)
        .where((a) =>
            _query.isEmpty || groupMatches || a.name.toLowerCase().contains(q))
        .toList();

    if (store.balanceSort == AccountSort.custom) {
      // Order by the user's arrangement; the visible subset keeps that relative
      // order (filtering happens after ordering).
      final rank = <String, int>{};
      var i = 0;
      for (final a in store.balanceOrder.orderedAccounts(store, group)) {
        rank[a.id] = i++;
      }
      list.sort((a, b) =>
          (rank[a.id] ?? 1 << 30).compareTo(rank[b.id] ?? 1 << 30));
      return list;
    }

    list.sort(_accountComparator(store));
    return list;
  }

  /// One category: its group header plus (when open) a reorderable column of
  /// its accounts. The whole block is what a category drag carries; the account
  /// rows inside are their own [ReorderableGroup] with a shorter press delay, so
  /// pressing an account never lifts the category.
  ///
  /// Wrapped in an opacity that dims to 42% when another region is the active
  /// drag's legal target — the containment cue.
  Widget _categoryBlock(AppStore store, AccountGroup group) {
    // A group matched only through one of its accounts opens itself, so the
    // match the user typed is actually visible.
    final matchedOnChild = _query.isNotEmpty &&
        !group.label.toLowerCase().contains(_query.toLowerCase());
    final open = matchedOnChild || _isOpen(group);
    final children = _children(store, group);

    // Amount, count and share are all recomputed against the filtered set: the
    // percentage's denominator is the filtered section total, so hiding
    // Valuables pushes Investments from 21.4% to 65.1% rather than leaving a
    // stale figure.
    final filter = store.balanceFilter;
    final filteredTotal = filter.filteredTotal(store, group);
    final sectionTotal =
        filter.sectionTotal(store, assets: group.isAsset).abs();
    final share = sectionTotal == 0
        ? 0.0
        : (filteredTotal.abs() / sectionTotal).clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _blockOpacity(group),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GroupRow(
            group: group,
            total: filteredTotal,
            count: filter.visibleAccounts(store, group).length,
            share: share,
            isOpen: open,
            onToggle: () => setState(() {
              if (open) {
                _closed.add(group);
              } else {
                _closed.remove(group);
                _opened.add(group);
              }
            }),
            onOpenLedger: () => _openGroupLedger(group),
            // The long-press "add account" shortcut is intentionally dropped:
            // press-and-hold now lifts the row for reordering. Accounts are
            // still added via the header +, the empty state, and the More tab.
          ),
          // AnimatedSize rather than AnimatedCrossFade: a closed group must not
          // build its account rows at all, only animate when it opens.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open || children.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    // No top padding — the first child sits directly under the
                    // group row so indentation alone reads as parent-child.
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ReorderableGroup<Account>(
                      key: ValueKey('accounts-${group.name}'),
                      items: children,
                      // Shorter than the category delay so an account press wins
                      // the gesture arena over its parent block.
                      delay: const Duration(milliseconds: 350),
                      scrollController: _scrollController,
                      semanticLabel: (a, i, n) =>
                          '${a.name}, position ${i + 1} of $n in ${group.label}',
                      onDragStart: (_) => setState(
                          () => _activeDrag = _ActiveDrag.account(group)),
                      onDragEnd: () => setState(() => _activeDrag = null),
                      onReorder: (moved, target) => _onAccountReorder(
                        store,
                        group: group,
                        moved: moved,
                        target: target,
                        visible: children,
                      ),
                      itemBuilder: (context, a) => AccountRow(
                        account: a,
                        balance: store.balanceOf(a.id),
                        subtitle: group.isLiability
                            ? liabilitySubtitle(store, a).text
                            : null,
                        subtitleColor: group.isLiability
                            ? liabilitySubtitle(store, a).color
                            : null,
                        onOpenAccount: () => _openAccountDetail(a),
                        onOpenLedger: () => _openAccountLedger(a),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Reordering ──────────────────────────────────────────────────────────

  /// The order to move relative to: the live custom order when already in
  /// Custom, otherwise a snapshot of what is on screen right now, so flipping to
  /// Custom rearranges nothing beyond the move the user just made.
  CustomOrder _baseOrder(AppStore store) => store.balanceSort == AccountSort.custom
      ? store.balanceOrder
      : _snapshotDisplayedOrder(store);

  CustomOrder _snapshotDisplayedOrder(AppStore store) {
    final accountOrder = <AccountGroup, List<String>>{};
    for (final g in AccountGroup.values) {
      final full = store.accountsIn(g).toList();
      if (full.isEmpty) continue;
      full.sort(_accountComparator(store));
      accountOrder[g] = full.map((a) => a.id).toList();
    }
    return CustomOrder(
      // The automatic sorts never reorder categories, so the displayed category
      // order is just the declaration order.
      assetOrder: AccountGroup.assets.toList(),
      liabilityOrder: AccountGroup.liabilities.toList(),
      accountOrder: accountOrder,
    );
  }

  void _onCategoryReorder(
    AppStore store, {
    required bool assets,
    required AccountGroup moved,
    required int target,
    required List<AccountGroup> visible,
  }) {
    final next = _baseOrder(store).withCategoryMove(
      assets: assets,
      moved: moved,
      visibleTargetIndex: target,
      visibleOrder: visible,
    );
    _applyDrag(store, next);
  }

  void _onAccountReorder(
    AppStore store, {
    required AccountGroup group,
    required Account moved,
    required int target,
    required List<Account> visible,
  }) {
    final next = _baseOrder(store).withAccountMove(
      store,
      group: group,
      moved: moved.id,
      visibleTargetIndex: target,
      visibleOrder: visible.map((a) => a.id).toList(),
    );
    _applyDrag(store, next);
  }

  /// Commits a completed move: the new order, and a silent flip to Custom (so
  /// the automatic comparator can't snap the row back). Records what Undo would
  /// restore, then offers the bar.
  void _applyDrag(AppStore store, CustomOrder next) {
    _pendingMove =
        _PendingMove(order: store.balanceOrder, sort: store.balanceSort);
    store.setBalanceOrder(next, sort: AccountSort.custom);
    _showUndoBar(store);
  }

  void _showUndoBar(AppStore store) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Undo and nothing else — the bar offers a way back, it does not
          // narrate the switch to Custom.
          content: Semantics(
            liveRegion: true,
            label: 'Reordered',
            child: const SizedBox.shrink(),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoLastMove(store),
          ),
        ),
      );
  }

  /// Reverts the most recent move — both the row's position and, when the move
  /// flipped the sort, the previous sort selection.
  void _undoLastMove(AppStore store) {
    final move = _pendingMove;
    if (move == null) return;
    _pendingMove = null;
    store.setBalanceOrder(move.order, sort: move.sort);
  }

  int Function(Account, Account) _accountComparator(AppStore store) =>
      (a, b) => switch (store.balanceSort) {
            AccountSort.valueDesc => store
                .balanceInBase(b.id)
                .abs()
                .compareTo(store.balanceInBase(a.id).abs()),
            AccountSort.valueAsc => store
                .balanceInBase(a.id)
                .abs()
                .compareTo(store.balanceInBase(b.id).abs()),
            AccountSort.nameAsc => a.name.compareTo(b.name),
            AccountSort.activity => store
                .accountActivity(b.id)
                .compareTo(store.accountActivity(a.id)),
            AccountSort.custom => 0,
          };

  // ── Drag containment cue ──────────────────────────────────────────────────

  double _sectionHeaderOpacity(bool assets) {
    final d = _activeDrag;
    if (d == null) return 1;
    // Category drag lights only its own section; account drag lights only the
    // owning category, so both section headers dim.
    if (d.isCategory) return d.isAsset == assets ? 1 : 0.42;
    return 0.42;
  }

  double _blockOpacity(AccountGroup group) {
    final d = _activeDrag;
    if (d == null) return 1;
    if (d.isCategory) return group.isAsset == d.isAsset ? 1 : 0.42;
    return group == d.group ? 1 : 0.42;
  }

  void _openAccountLedger(Account account) => _openLedger(
        AccountScope(account.id),
      );

  /// The name side asks "what is this", so it opens the account's own page.
  void _openAccountDetail(Account account) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(accountId: account.id),
      ),
    );
  }

  void _openGroupLedger(AccountGroup group) => _openLedger(GroupScope(group));

  /// Both entry points land on the same screen with a different scope, so the
  /// back stack stays one deep however long the user browses.
  void _openLedger(LedgerScope scope) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ScopedLedgerScreen(initialScope: scope),
      ),
    );
  }
}

/// What is currently lifted, so the screen can dim the regions it can't reach.
class _ActiveDrag {
  const _ActiveDrag.category(bool this.isAsset) : group = null;
  const _ActiveDrag.account(AccountGroup this.group) : isAsset = null;

  /// Set for a category drag: which section the lifted category belongs to.
  final bool? isAsset;

  /// Set for an account drag: the owning category.
  final AccountGroup? group;

  bool get isCategory => group == null;
}

/// The single move Undo would revert: the order before it, and the sort before
/// it (restored too when the move flipped the selection to Custom).
class _PendingMove {
  const _PendingMove({required this.order, required this.sort});

  final CustomOrder order;
  final AccountSort sort;
}

// ── Header pieces ───────────────────────────────────────────────────────────

class _ListSectionHeader extends StatelessWidget {
  const _ListSectionHeader(this.label, this.total);

  final String label;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: AppText.listSectionLabel),
          ),
          AmountText.balance(total, style: AppText.listSectionLabel),
        ],
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  const _RatioBar({required this.assets, required this.liabilities});

  /// Both filtered magnitudes (liabilities passed as a positive number).
  final double assets;
  final double liabilities;

  @override
  Widget build(BuildContext context) {
    final total = assets + liabilities;
    // Everything hidden: no ratio to draw — a flat neutral track (spec §5),
    // and the guard that keeps the division below safe.
    if (total <= 0) {
      return SizedBox(height: 4, child: _seg(AppColors.sheetCard));
    }
    // One side fully hidden reads as a single solid bar, not a bar with a
    // 1-flex sliver of the other colour.
    if (liabilities <= 0) {
      return SizedBox(height: 4, child: _seg(AppColors.positive));
    }
    if (assets <= 0) {
      return SizedBox(height: 4, child: _seg(AppColors.negative));
    }

    final ratio = (liabilities / total).clamp(0.0, 1.0);
    return SizedBox(
      height: 4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: ((1 - ratio) * 1000).round().clamp(1, 1000),
            child: _seg(AppColors.positive),
          ),
          const SizedBox(width: 1.5),
          Expanded(
            flex: (ratio * 1000).round().clamp(1, 1000),
            child: _seg(AppColors.negative),
          ),
        ],
      ),
    );
  }

  Widget _seg(Color color) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// One side of the ratio caption. Scales down rather than overflowing when the
/// figure is long or the text scale is large.
class _RatioLabel extends StatelessWidget {
  const _RatioLabel({
    required this.caption,
    required this.value,
    required this.color,
    required this.alignment,
  });

  final String caption;
  final double value;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final style = AppText.sharePercent.copyWith(color: color);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(caption, style: style),
          AmountText.balance(value, style: style),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.datePill),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
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
          width: 34,
          height: 34,
          child: Icon(icon, size: accent ? 19 : 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Shared empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: Insets.md),
          Text(
            title,
            style: AppText.rowTitle.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xs),
          Text(message, style: AppText.caption, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Insets.xl), action!],
        ],
      ),
    );
  }
}
