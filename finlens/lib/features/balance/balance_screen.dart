import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/undo_bar.dart';
import '../../shared/widgets/swipe_back_route.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
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
enum BalanceSection { all, assets, liabilities }

extension BalanceSectionL10n on BalanceSection {
  String label(AppLocalizations l) => switch (this) {
        BalanceSection.all => l.balanceSectionAll,
        BalanceSection.assets => l.balanceSectionAssets,
        BalanceSection.liabilities => l.balanceSectionLiabilities,
      };
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

    // One definition of "empty", computed once and handed to both the header
    // and the list. Deliberately not netWorth == 0 (two accounts can cancel to
    // zero and that user is not new) and not "all filtered away" (a filtered
    // user still has accounts). Only a store with literally no account is a
    // first run.
    final hasAccounts =
        AccountGroup.values.any((g) => store.groupCount(g) > 0);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(store, hasAccounts),
          Expanded(
            child: HorizontalSectionSwipe(
              onNext: () => _stepSection(1),
              onPrevious: () => _stepSection(-1),
              child: _list(store, hasAccounts),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  /// Header: label + dots + controls, then the hero amount alone, the slim
  /// ratio bar, and a tool row (counter + the four tools). Pinned — only the
  /// list scrolls.
  Widget _header(AppStore store, bool hasAccounts) {
    final filter = store.balanceFilter;
    final showRatio = _section == BalanceSection.all && !_searching;

    // Height is not hard-coded: the ratio bar shows only on the All section,
    // the "as of" line appears only for a past date, and searching swaps the
    // tool row for the field. AnimatedSize hands any freed space to the list.
    //
    // The label, hero, ratio bar and tools all belong to a populated tab; on a
    // first run they are absent from the tree entirely, and an AnimatedSwitcher
    // cross-fades the two states so the header text fades in over 180ms when the
    // first account lands (§6). The + is the one exception: it is *not* inside
    // the switcher. It sits in a Positioned overlay pinned to the top-right
    // corner, drawn once over both states, so it never fades, moves or rebuilds
    // — a user who opens the app to record something reaches the same button in
    // the same place whether or not any account exists yet.
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 4),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              // Align the outgoing and incoming states at the top-left so the
              // content grows downward from the +'s row rather than the switcher
              // centring a shorter child and nudging it as it fades.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topLeft,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: hasAccounts
                  ? Column(
                      key: const ValueKey('balance-header-populated'),
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
                            liabilities:
                                filter.sectionTotal(store, assets: false).abs(),
                          ),
                        ],
                        // The tools left the hero's line for a row of their own,
                        // mirroring the Ledger's counter + tool-cluster grammar.
                        // The search field takes this row's place while
                        // searching, so the row never stacks on top of the field.
                        if (!_searching) _toolRow(store),
                      ],
                    )
                  // First run: no NET WORTH label, no hero, no delta line — a
                  // header with nothing to report should not appear (§2). All
                  // that remains is empty space the height of the +, so the Stack
                  // is exactly as tall as the + and the empty state below claims
                  // the rest of the screen. These slots are absent from the tree,
                  // not hidden — an opacity-0 or 0-height widget still holds
                  // layout and still reaches the screen reader.
                  : const SizedBox(
                      key: ValueKey('balance-header-empty'),
                      height: 34,
                      width: double.infinity,
                    ),
            ),
            // The persistent create affordance. Same icon, size, destination and
            // top-right position in both states; row 1 of the populated content
            // reserves its footprint so nothing under it shifts.
            Positioned(
              top: 0,
              right: 0,
              child: _CircleButton(
                icon: Icons.add_rounded,
                accent: true,
                onTap: () => showQuickAdd(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow1(AppStore store) {
    return Row(
      children: [
        SectionIndicator(
          label: _section.label(AppLocalizations.of(context)),
          count: BalanceSection.values.length,
          index: _section.index,
          onAdvance: _advanceSection,
        ),
        const Spacer(),
        _DatePill(
          label: store.isHistorical
              ? dayMonth(store.asOf!, AppLocalizations.of(context))
              : AppLocalizations.of(context).dateToday,
          onTap: () => _pickDate(store),
        ),
        const SizedBox(width: Insets.sm),
        _CircleButton(
          icon: store.masked
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          onTap: store.toggleMasked,
        ),
        // The + is drawn as a persistent overlay (see _header); reserve its
        // footprint — the sm gap plus its 34pt width — so the eye keeps the
        // exact x-position it had when the + was an inline sibling here.
        const SizedBox(width: Insets.sm + 34),
      ],
    );
  }

  /// The hero amount owns its line now; search replaces it in place, so the
  /// row never changes height.
  Widget _headerRow2(AppStore store) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _searching ? _searchField() : _amountOnly(store),
    );
  }

  Widget _amountOnly(AppStore store) {
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

    final amountColumn = Column(
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
            'as of ${dayMonthYear(store.asOf!, AppLocalizations.of(context))}',
            style: AppText.asOfLine,
          ),
      ],
    );

    // Net worth keeps the ratio bar below it. The assets-only and
    // liabilities-only views have no bar, so the period-comparison chip that
    // used to live on the deleted Assets/Liabilities screens renders here — the
    // only place these two views carry a comparison at all.
    if (_section == BalanceSection.all) {
      return Align(
        key: const ValueKey('amount'),
        alignment: Alignment.centerLeft,
        child: amountColumn,
      );
    }
    return Align(
      key: const ValueKey('amount'),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: amountColumn),
          const SizedBox(width: Insets.sm),
          DeltaChip(
            fraction: store.netWorthDeltaFraction,
            caption: store.comparePeriod.caption(AppLocalizations.of(context)),
            isLiability: _section == BalanceSection.liabilities,
          ),
        ],
      ),
    );
  }

  /// Counter on the left, the four tools on the right — the Ledger's tool-row
  /// grammar, brought to Balance. The buttons are the same [ToolCluster] that
  /// used to sit beside the hero; only their position changed.
  Widget _toolRow(AppStore store) {
    final filter = store.balanceFilter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 9, 0, 2),
      child: Row(
        children: [
          Expanded(child: _counter(store)),
          const SizedBox(width: Insets.sm),
          ToolCluster(
            tools: [
              // No dot: the sort tool joins the filter's convention two entries
              // below — it brightens its glyph one step (muted → high-emphasis)
              // when the order is non-default, and the surface never changes.
              // swap_vert_rounded has no meaningful outlined counterpart, so the
              // brightness step alone carries the state.
              Tool(
                icon: Icons.swap_vert_rounded,
                tooltip: AppLocalizations.of(context).balSortTooltip,
                iconColor: store.sortIsActive ? AppColors.textPrimary : null,
                semanticValue: store.sortIsActive
                    ? store.balanceSort.label(AppLocalizations.of(context))
                    : AppLocalizations.of(context).balSortDefault,
                onTap: _pickSort,
              ),
              Tool(
                icon: _anyOpen
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                tooltip: _anyOpen ? AppLocalizations.of(context).actionCollapseAll : AppLocalizations.of(context).actionExpandAll,
                filled: !_anyOpen,
                onTap: _toggleAll,
              ),
              // Active state is icon-only by design: the funnel fills and
              // brightens one step, the surface never changes. The live Net
              // Worth preview inside the sheet is what tells the user the cost.
              Tool(
                icon: filter.isActive
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
                iconColor: filter.isActive ? AppColors.textPrimary : null,
                tooltip: AppLocalizations.of(context).balFilterCategories,
                semanticValue: filter.isActive
                    ? AppLocalizations.of(context)
                        .balFilterActive(filter.hiddenItemCount(store))
                    : AppLocalizations.of(context).balFilterOff,
                onTap: () => showBalanceFilterSheet(context),
              ),
              Tool(
                icon: Icons.search_rounded,
                tooltip: AppLocalizations.of(context).actionSearch,
                onTap: _openSearch,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "7 groups · 24 accounts", or "7 groups · 18 of 24 accounts" when the
  /// filter hides some — each half stays short until it is actually narrowed.
  /// Counts the section currently in view; ellipsizes before it can push the
  /// tools.
  Widget _counter(AppStore store) {
    final filter = store.balanceFilter;
    final groups =
        _visibleGroups.where((g) => store.accountsIn(g).isNotEmpty).toList();
    final groupsTotal = groups.length;
    final groupsVisible =
        groups.where((g) => filter.isGroupVisible(store, g)).length;
    var accountsTotal = 0;
    var accountsVisible = 0;
    for (final g in groups) {
      accountsTotal += store.accountsIn(g).length;
      accountsVisible += filter.visibleAccounts(store, g).length;
    }

    return Semantics(
      liveRegion: true,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          children: [
            ..._countSpans(groupsVisible, groupsTotal, 'group', 'groups'),
            const TextSpan(text: ' · '),
            ..._countSpans(accountsVisible, accountsTotal, 'account',
                'accounts'),
          ],
        ),
      ),
    );
  }

  /// One half of the counter — short "N nouns" when nothing is hidden, or the
  /// bright "V of T nouns" reading (V emphasised) when it is narrowed.
  List<InlineSpan> _countSpans(int visible, int total, String one, String many) {
    final noun = total == 1 ? one : many;
    if (visible == total) {
      return [TextSpan(text: '$total $noun')];
    }
    return [
      TextSpan(
        text: '$visible',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      TextSpan(text: ' of $total $noun'),
    ];
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
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: AppLocalizations.of(context).balSearchAccounts,
                      hintStyle: const TextStyle(
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
          child: Padding(
            padding: const EdgeInsets.only(left: Insets.md),
            child: Text(
              AppLocalizations.of(context).actionCancel,
              style: const TextStyle(
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
    final l = AppLocalizations.of(context);
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
                  title: Text(option.label(l), style: AppText.body),
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
                title: Text(AccountSort.custom.label(l), style: AppText.body),
                // The second, permanent advertisement of the gesture (the
                // section-header hint is the first, and self-dismissing).
                subtitle: Text(
                  AppLocalizations.of(context).balPressHoldMove,
                  style: const TextStyle(
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

  Widget _list(AppStore store, bool hasAccounts) {
    final assets = _groupsFor(store, AccountGroup.assets);
    final liabilities = _groupsFor(store, AccountGroup.liabilities);

    if (assets.isEmpty && liabilities.isEmpty) {
      if (_query.isNotEmpty) return _noResults();
      // No accounts at all is the "add your first account" case; accounts that
      // exist but are all filtered out fall through to per-section empty rows.
      // hasAccounts is the same test the header uses — one definition of empty.
      if (!hasAccounts) return _emptyState();
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

  /// One section: its header (dimmable) plus its category blocks. Categories no
  /// longer reorder — they render in fixed [AccountGroup] declaration order
  /// under every sort mode, so the section is a plain column. The only drag
  /// surface is the per-category account list inside each block.
  Widget _sectionBlock(
    AppStore store, {
    required bool assets,
    required List<AccountGroup> groups,
    required bool showHeader,
  }) {
    final filter = store.balanceFilter;
    final label = assets
        ? AppLocalizations.of(context).balanceSectionAssets
        : AppLocalizations.of(context).balanceSectionLiabilities;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _sectionHeaderOpacity(assets),
            child: _ListSectionHeader(
              label,
              filter.sectionTotal(store, assets: assets),
              assets: assets,
            ),
          ),
        if (groups.isEmpty)
          _filteredAwayRow()
        else
          for (final g in groups) _categoryBlock(store, g),
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
              AppLocalizations.of(context).balNoVisibleCategories,
              style: AppText.body.copyWith(color: AppColors.textTertiary),
            ),
            TextButton(
              onPressed: () => showBalanceFilterSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: const Size(0, 36),
              ),
              child: Text(AppLocalizations.of(context).balAdjustFilter),
            ),
          ],
        ),
      );

  Widget _noResults() => Padding(
        padding: const EdgeInsets.only(top: 72),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: AppLocalizations.of(context).balNoResults,
          message: AppLocalizations.of(context).balNoAccountMatch,
        ),
      );

  /// The one place an "add account" call to action belongs: what is redundant
  /// noise in a populated list is the only way forward in an empty one. The
  /// action is a low-emphasis text button — a one-time account creation should
  /// not compete with the persistent + — and it stays beside the sentence that
  /// motivates it rather than migrating to the corner glyph (§4).
  Widget _emptyState() {
    final l = AppLocalizations.of(context);
    // Centred between the + row above and the nav bar below (§3). The screen has
    // no upward-nudge convention, so geometric centring is correct — no optical
    // offset invented. A ConstrainedBox pinned to the viewport height keeps it
    // centred when there is room and lets it scroll rather than clip when there
    // is not (a large text scale, or a short/landscape viewport — §8).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: l.balNoAccountsYet,
              titleAsHeader: true,
              message: l.balEmptyBenefit,
              action: TextButton(
                onPressed: () => showNewAccountSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  // A visually light control that is still physically full-size:
                  // ≥44×44 via the tap target, not a larger font (§4).
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: 10,
                  ),
                ),
                child: Text(l.balAddAccount),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

    // Group order is always the fixed declaration order — no sort mode, custom
    // included, reorders categories. A filter-hidden group has zero visible
    // accounts, so it drops out here the same way a group with no accounts does
    // — never rendered as an empty row.
    final filter = store.balanceFilter;
    var groups = source
        .where((g) => store.groupCount(g) > 0 && filter.isGroupVisible(store, g))
        .toList();

    if (_query.isNotEmpty) {
      groups = groups.where((g) => _matchesQuery(store, g)).toList();
    }

    return groups;
  }

  bool _matchesQuery(AppStore store, AccountGroup group) {
    final q = _query.toLowerCase();
    if (group.label(AppLocalizations.of(context)).toLowerCase().contains(q)) {
      return true;
    }
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
    final groupMatches =
        group.label(AppLocalizations.of(context)).toLowerCase().contains(q);

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
        !group
            .label(AppLocalizations.of(context))
            .toLowerCase()
            .contains(_query.toLowerCase());
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
                      // The 350ms hold stays even with no outer group to race:
                      // it is what lets a fast flick scroll instead of lift.
                      delay: const Duration(milliseconds: 350),
                      // Dragging is off while a search query narrows the list —
                      // a relative move inside a temporary lens produces
                      // surprising stored orders. Toggling this never remounts
                      // the rows.
                      enabled: _query.isEmpty,
                      scrollController: _scrollController,
                      semanticLabel: (a, i, n) =>
                          '${a.name}, position ${i + 1} of $n in ${group.label(AppLocalizations.of(context))}',
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
                            ? liabilitySubtitle(store, a, AppLocalizations.of(context)).text
                            : null,
                        subtitleColor: group.isLiability
                            ? liabilitySubtitle(store, a, AppLocalizations.of(context)).color
                            : null,
                        // The whole row is one tap target now: name, amount and
                        // the space between all open the account's ledger.
                        onTap: () => _openAccountLedger(a),
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
    return CustomOrder(accountOrder: accountOrder);
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
  /// restore, then offers the labeled bar.
  void _applyDrag(AppStore store, CustomOrder next) {
    // True when this drag flips an automatic sort to Custom — the bar names
    // that, so the changed sort is not a silent surprise.
    final flipped = store.balanceSort != AccountSort.custom;
    _pendingMove =
        _PendingMove(order: store.balanceOrder, sort: store.balanceSort);
    store.setBalanceOrder(next, sort: AccountSort.custom);
    _showUndoBar(store, flipped: flipped);
  }

  void _showUndoBar(AppStore store, {required bool flipped}) {
    // Names the flip to Custom the first time, plain "Moved" once already there.
    final l = AppLocalizations.of(context);
    final text = flipped ? l.balMovedCustom : l.balMoved;
    showUndoBar(
      context,
      message: text,
      onUndo: () => _undoLastMove(store),
    ).closed.then((reason) {
      // The bar has gone away without an undo (expired, hidden by the next
      // move, or the user navigated off). Drop the stale undo target so it
      // can't be reversed out from under whatever came after.
      if (reason == SnackBarClosedReason.action) return;
      _pendingMove = null;
    });
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
    // An account drag keeps its own section's header lit; the opposite section
    // dims, matching the dimmed non-owning category blocks.
    return d.group.isAsset == assets ? 1 : 0.42;
  }

  double _blockOpacity(AccountGroup group) {
    final d = _activeDrag;
    if (d == null) return 1;
    // Only the owning category stays lit while one of its accounts travels.
    return group == d.group ? 1 : 0.42;
  }

  void _openAccountLedger(Account account) => _openLedger(
        AccountScope(account.id),
      );

  void _openGroupLedger(AccountGroup group) => _openLedger(GroupScope(group));

  /// Both entry points land on the same screen with a different scope, so the
  /// back stack stays one deep however long the user browses.
  void _openLedger(LedgerScope scope) {
    Navigator.of(context, rootNavigator: true).push(
      // A SwipeBackPageRoute keeps the standard push transition but adds the
      // hold-then-drag-left back gesture on the detail screen.
      SwipeBackPageRoute(
        builder: (_) => ScopedLedgerScreen(initialScope: scope),
      ),
    );
  }
}

/// The account currently lifted, so the screen can dim every region but its
/// owning category. Only accounts drag now, so this is always an account drag.
class _ActiveDrag {
  const _ActiveDrag.account(this.group);

  /// The lifted account's owning category.
  final AccountGroup group;
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
  const _ListSectionHeader(
    this.label,
    this.total, {
    required this.assets,
  });

  final String label;
  final double total;

  /// Colours the total — green for assets, red for liabilities. With the bar's
  /// duplicate label row gone, this header is the section total's only home.
  final bool assets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: AppText.listSectionLabel),
          // The flexible middle pushes the total to the right edge and is what
          // yields first at narrow widths, so the total always keeps its full
          // width.
          const Spacer(),
          AmountText.balance(
            total,
            style: AppText.sectionTotal,
            color: assets ? AppColors.positive : AppColors.negative,
          ),
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
      return SizedBox(height: 3, child: _seg(AppColors.surfaceHigh));
    }
    // One side fully hidden reads as a single solid bar, not a bar with a
    // 1-flex sliver of the other colour.
    if (liabilities <= 0) {
      return SizedBox(height: 3, child: _seg(AppColors.positive));
    }
    if (assets <= 0) {
      return SizedBox(height: 3, child: _seg(AppColors.negative));
    }

    final ratio = (liabilities / total).clamp(0.0, 1.0);
    return SizedBox(
      height: 3,
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
    this.titleAsHeader = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Marks [title] as a heading for the screen reader. Off by default so every
  /// existing caller's semantics tree is untouched; Balance's first-run state
  /// opts in (§7).
  final bool titleAsHeader;

  @override
  Widget build(BuildContext context) {
    Widget titleText = Text(
      title,
      style: AppText.rowTitle.copyWith(fontSize: 16),
      textAlign: TextAlign.center,
    );
    if (titleAsHeader) {
      titleText = Semantics(header: true, child: titleText);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: Insets.md),
          titleText,
          const SizedBox(height: Insets.xs),
          Text(message, style: AppText.caption, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Insets.xl), action!],
        ],
      ),
    );
  }
}
