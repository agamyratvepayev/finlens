import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/undo_bar.dart';
import '../../shared/widgets/swipe_back_route.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'balance_order.dart';
import 'widgets/reorderable_group.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/ledger_screen.dart' show buildFirstRunHint;
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

/// Why the visible list is empty. The two non-trivial causes are different
/// screens: [noAccounts] is a fact about the user's money ("you have no debts"),
/// [allFiltered] a fact about their filter ("everything here is hidden"). One is
/// good news, the other a state to escape. [none] means the list has rows.
enum SectionEmptyCause { none, noAccounts, allFiltered }

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
    BalanceSection.values[(_section.index + 1) % BalanceSection.values.length],
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
    final hasAccounts = AccountGroup.values.any((g) => store.groupCount(g) > 0);

    // Why the *current section's* list is empty, computed once and handed to
    // both the header and the body — one definition of empty, the way
    // hasAccounts already is. Meaningful only when hasAccounts; the first run
    // keeps its own branch below and never consults it.
    final cause = hasAccounts ? _emptyCause(store) : SectionEmptyCause.none;
    // The block that fills the body when the section is empty, or null when the
    // list has rows (see [_emptyPane]).
    final pane = hasAccounts ? _emptyPane(store, cause) : null;

    return SafeArea(
      bottom: false,
      child: Stack(
        // The chrome Column keeps the same tight, full-body constraints it had
        // before the Stack, so the populated screen is laid out exactly as it
        // was; only the first-run block behind is added.
        fit: StackFit.expand,
        children: [
          // First run: the empty block is laid against the whole tab body so its
          // icon lands on the same y as the Ledger's and the Planner's (§1). It
          // sits behind the header, which paints over its top edge — the two
          // never consume each other's height. Absent once an account exists.
          if (!hasAccounts) Positioned.fill(child: _firstRunPane()),
          // The swipe wraps the whole tab — header included — so a horizontal
          // drag over the label, the hero amount or the empty area below all
          // change section, not just one over the list. Taps on the +, the eye
          // and the tools still reach them: a horizontal-drag recognizer does
          // not compete with taps. On a first run the swipe is absent (the
          // block behind takes the taps and scroll); the header still takes the
          // +'s taps.
          if (hasAccounts)
            HorizontalSectionSwipe(
              onNext: () => _stepSection(1),
              onPrevious: () => _stepSection(-1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Inside the swipe, not behind it. HorizontalSectionSwipe is
                  // HitTestBehavior.opaque, so a sibling pane would be
                  // unreachable — the "Adjust filter" button would render and do
                  // nothing. As a descendant the pane is hit-tested first, and
                  // the drag recognizer still wins the arena for horizontal
                  // gestures, so swiping out of an empty section keeps working.
                  //
                  // Positioned.fill, not a child of the Column: the block is
                  // centred against the *whole body*, so its icon lands on the
                  // same y as the Ledger's and the Planner's however tall this
                  // screen's header is.
                  if (pane != null) Positioned.fill(child: pane),
                  Column(
                    children: [
                      _header(
                        store,
                        hasAccounts,
                        showHero: pane == null,
                        cause: cause,
                      ),
                      // The pane owns the body. A childless SizedBox hit-tests
                      // nothing, so the pane behind it stays tappable and
                      // scrollable.
                      Expanded(
                        child: pane == null
                            ? _list(store, hasAccounts)
                            : const SizedBox.expand(),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _header(
                  store,
                  hasAccounts,
                  showHero: true,
                  cause: SectionEmptyCause.none,
                ),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
        ],
      ),
    );
  }

  /// Why the current section's list is empty. A live query has its own empty
  /// screen ([_noResults]) and is not a section state; leave it to the list.
  SectionEmptyCause _emptyCause(AppStore store) {
    if (_query.isNotEmpty) return SectionEmptyCause.none;
    if (_groupsFor(store, AccountGroup.assets).isNotEmpty ||
        _groupsFor(store, AccountGroup.liabilities).isNotEmpty) {
      return SectionEmptyCause.none;
    }
    // Nothing visible. Does the section own any account at all?
    return _visibleGroups.any((g) => store.groupCount(g) > 0)
        ? SectionEmptyCause.allFiltered
        : SectionEmptyCause.noAccounts;
  }

  /// The block that fills the body, or null when the list has rows. The first
  /// run keeps its own path in [build] and never reaches here. While a search is
  /// open the list owns the empty path ([_noResults] or rows), so no pane shows.
  Widget? _emptyPane(AppStore store, SectionEmptyCause cause) {
    if (_searching) return null;
    return switch (cause) {
      SectionEmptyCause.none => null,
      SectionEmptyCause.noAccounts => _sectionEmptyPane(),
      SectionEmptyCause.allFiltered => _allFilteredPane(store),
    };
  }

  /// The section owns no account of its kind. Not a failure and not a first run:
  /// the other section has rows, and the header above still names where the user
  /// is. The copy names the *section*, never the app.
  Widget _sectionEmptyPane() {
    // NET WORTH always owns some non-empty group when hasAccounts is true, so it
    // can only ever be [allFiltered], never here.
    assert(_section != BalanceSection.all);
    final l = AppLocalizations.of(context);
    // A NUL the localized string can never contain, swapped in for `{plus}` —
    // same convention as [_firstRunPane].
    final sentinel = String.fromCharCode(0);
    final debts = _section == BalanceSection.liabilities;
    return FirstRunBlock(
      icon: debts
          ? Icons.credit_card_off_rounded
          : Icons.account_balance_wallet_rounded,
      // Owing nothing is good news, not a gap to fill: the liabilities copy
      // states a fact, the assets copy invites. The same sentence would be wrong
      // for both.
      title: debts ? l.balNoDebtsTitle : l.balNoAssetsTitle,
      message: debts ? l.balNoDebtsMsg : l.balNoAssetsMsg,
      action: FittedBox(
        fit: BoxFit.scaleDown,
        child: buildFirstRunHint(
          debts ? l.balNoDebtsHint(sentinel) : l.balNoAssetsHint(sentinel),
          sentinel,
          semanticsLabel: debts ? l.balNoDebtsHintA11y : l.balNoAssetsHintA11y,
        ),
      ),
    );
  }

  /// The section owns accounts and the filter hides every one. The only state of
  /// the three with a way out, so it is the only one with a button.
  Widget _allFilteredPane(AppStore store) {
    final l = AppLocalizations.of(context);
    var hidden = 0;
    for (final g in _visibleGroups) {
      hidden += store.accountsIn(g).length;
    }
    return FirstRunBlock(
      icon: Icons.filter_alt_rounded,
      title: l.balAllHiddenTitle,
      message: l.balAllHiddenMsg(hidden),
      action: TextButton(
        onPressed: () => showBalanceFilterSheet(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, 36),
        ),
        child: Text(l.balAdjustFilter),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  /// Header: row 1 (label + dots + controls), then the hero amount sharing one
  /// row with the four tools. On NET WORTH the slim ratio bar still follows.
  /// Pinned — only the list scrolls.
  Widget _header(
    AppStore store,
    bool hasAccounts, {
    required bool showHero,
    required SectionEmptyCause cause,
  }) {
    final filter = store.balanceFilter;
    final showRatio = _section == BalanceSection.all && !_searching;
    // An empty section keeps only its filter/search tools, and only when the
    // filter is the way out of it (all-filtered). Nothing to sort or collapse
    // with no rows; the section-empty state carries no tool row at all. During
    // search the field owns the row, so the reduced row stands down.
    final showReducedTools =
        !_searching && cause == SectionEmptyCause.allFiltered;

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
        // 6 above row 1, 14 below the amount row — the largest gap is the last,
        // because the header-ends / list-begins boundary is the most important
        // one on the screen. `height: 1.0` even-leading on the amount (see
        // [_amountStyle]) strips the font's own dead space, so these render at
        // the value specified rather than ~7pt larger.
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 6, Insets.gutter, 14),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              // Align the outgoing and incoming states at the top-left so the
              // content grows downward from the +'s row rather than the switcher
              // centring a shorter child and nudging it as it fades.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topLeft,
                children: [...previousChildren, ?currentChild],
              ),
              child: hasAccounts
                  ? Column(
                      key: const ValueKey('balance-header-populated'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1 survives in every state: the label and dots say
                        // where you are and where you can go, the date and the
                        // eye are controls the other two sections share (removing
                        // them for one section alone would make them flicker as
                        // the user swipes), and the + is the app's only create
                        // affordance.
                        SizedBox(
                          height: HeaderCircleButton.diameter,
                          child: _headerRow1(store),
                        ),
                        // The hero + tools row and the ratio bar belong to a
                        // section with something to report. An empty section
                        // drops both: there is no figure when there is nothing to
                        // total (§1). Searching keeps showHero true so the field
                        // still swaps in here.
                        if (showHero) ...[
                          const SizedBox(height: 8),
                          // The amount and the four tools share one row (see
                          // [_amountRow]); the delta badge and the count line are
                          // gone. Searching swaps this whole row for the field.
                          _headerRow2(store),
                          // The ratio bar reports a split between two figures.
                          // With neither on screen it has nothing to divide, so
                          // it rides with the hero — same NET-WORTH-only
                          // condition, same widget, same gap.
                          if (showRatio) ...[
                            const SizedBox(height: 8),
                            _RatioBar(
                              assets: filter.sectionTotal(store, assets: true),
                              liabilities: filter
                                  .sectionTotal(store, assets: false)
                                  .abs(),
                            ),
                          ],
                        ],
                        // All-filtered keeps a reduced tool row — filter and
                        // search only — because the filter is the way out of it.
                        if (showReducedTools) ...[
                          const SizedBox(height: 8),
                          _reducedToolRow(store),
                        ],
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
                      height: HeaderCircleButton.diameter,
                      width: double.infinity,
                    ),
            ),
            // The persistent create affordance. Same icon, size, destination and
            // top-right position in both states; row 1 of the populated content
            // reserves its footprint so nothing under it shifts.
            Positioned(
              top: 0,
              right: 0,
              child: HeaderCircleButton(
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
        HeaderCircleButton(
          icon: store.masked
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          onTap: store.toggleMasked,
        ),
        // The + is drawn as a persistent overlay (see _header); reserve its
        // footprint — the sm gap plus its 36pt width — so the eye keeps the
        // exact x-position it had when the + was an inline sibling here.
        const SizedBox(width: Insets.sm + HeaderCircleButton.diameter),
      ],
    );
  }

  /// The amount and the four tools share this row now; search replaces it in
  /// place, so the row never changes height.
  Widget _headerRow2(AppStore store) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _searching ? _searchField() : _amountRow(store),
    );
  }

  /// The hero amount on the left, the four tools on the right, optically
  /// centred against each other. The delta badge and the "N groups · M
  /// accounts" count are both gone — the one slot beside the amount now holds
  /// the tools, and the filter button alone carries the "total is partial"
  /// signal when a filter is active.
  Widget _amountRow(AppStore store) {
    final filter = store.balanceFilter;
    final l = AppLocalizations.of(context);
    // Every headline figure is the *filtered* one — hiding Valuables has to
    // move Net Worth, not just drop a row. The store getters stay unfiltered so
    // no other tab is affected; the filtering lives here.
    final liabTotal = filter.sectionTotal(store, assets: false);
    final (amount, color) = switch (_section) {
      BalanceSection.all => (filter.netWorth(store), null),
      BalanceSection.assets => (filter.sectionTotal(store, assets: true), null),
      BalanceSection.liabilities => (
        liabTotal,
        // Colour is good/bad, not a section badge: nothing owed is not an alarm,
        // so a paid-off card summing to exactly zero renders neutral, not red.
        liabTotal == 0 ? null : AppColors.negative,
      ),
    };

    // The three pages' totals are all computable here, so the font size is
    // solved from the widest of them and never jumps when the user swipes
    // between sections. Each is measured through [_display] with its own kind,
    // so a minus on a below-zero net worth or assets total (task 011) is part of
    // the width the ladder solves and can never overflow.
    final measured = <String>[
      _display(store, filter.netWorth(store)),
      _display(store, filter.sectionTotal(store, assets: true)),
      _display(store, filter.sectionTotal(store, assets: false),
          isLiability: true),
    ];

    // The tools act on the list. When the current section has nothing to act on
    // — e.g. LIABILITIES with no liabilities ($0) — they are not built, and the
    // amount stands alone. A section whose accounts are all filter-hidden keeps
    // its tools so the filter stays reachable (the in-list "Adjust filter" link
    // is the other way back).
    final listHasAccounts =
        _visibleGroups.any((g) => store.groupCount(g) > 0);
    final tools =
        listHasAccounts ? _buildTools(store) : const <_HeaderTool>[];

    // Without this line a user can easily believe a historical view is live
    // data. It rides under the amount; the tools centre against the amount.
    final asOf = store.isHistorical
        ? Text('as of ${dayMonthYear(store.asOf!, l)}', style: AppText.asOfLine)
        : null;

    return Align(
      key: const ValueKey('amount'),
      alignment: Alignment.centerLeft,
      child: _BalanceAmountRow(
        // Only the LIABILITIES section shows a liability-kind figure; net worth
        // and the assets total are asset-side and print a minus when negative.
        display: _display(store, amount,
            isLiability: _section == BalanceSection.liabilities),
        color: color,
        measured: measured,
        asOf: asOf,
        tools: tools,
      ),
    );
  }

  /// The amount string exactly as [AmountText.balance] would render it (same
  /// `money()` call and same sign rule), so the width the ladder measures
  /// matches what paints — masking included.
  ///
  /// [isLiability] mirrors the widget's flag: the liabilities section total is a
  /// negative sum that agrees with its kind and stays unsigned, while a negative
  /// net worth (or a below-zero assets total) contradicts its kind and prints
  /// its minus (task 011).
  String _display(AppStore store, double value, {bool isLiability = false}) {
    final contradicts = isLiability ? value > 0 : value < 0;
    return money(
      value,
      currency: store.baseCurrency,
      signless: !contradicts,
      showSign: contradicts && isLiability,
      masked: store.masked,
    );
  }

  /// The four tools, same icons / actions / active semantics as before; only
  /// their size (via the ladder) and the filter button's active look change.
  List<_HeaderTool> _buildTools(AppStore store) {
    final filter = store.balanceFilter;
    final l = AppLocalizations.of(context);
    return [
      // The sort tool brightens its glyph one step (muted → high-emphasis) when
      // the order is non-default; the surface never changes. Unchanged.
      _HeaderTool(
        icon: Icons.swap_vert_rounded,
        onTap: _pickSort,
        semanticLabel: l.balSortTooltip,
        semanticValue:
            store.sortIsActive ? store.balanceSort.label(l) : l.balSortDefault,
        iconColor: store.sortIsActive ? AppColors.textPrimary : null,
      ),
      _HeaderTool(
        icon: _anyOpen
            ? Icons.unfold_less_rounded
            : Icons.unfold_more_rounded,
        onTap: _toggleAll,
        semanticLabel:
            _anyOpen ? l.actionCollapseAll : l.actionExpandAll,
        filled: !_anyOpen,
      ),
      // With the count line gone, the filter button carries the whole "this
      // total is partial" signal, so its active state is unmistakable: accent
      // @ 20% fill, accentLight glyph.
      _HeaderTool(
        icon: filter.isActive
            ? Icons.filter_alt_rounded
            : Icons.filter_alt_outlined,
        onTap: () => showBalanceFilterSheet(context),
        semanticLabel: l.balFilterCategories,
        semanticValue: filter.isActive
            ? l.balFilterActive(filter.hiddenItemCount(store))
            : l.balFilterOff,
        filterActive: filter.isActive,
      ),
      _HeaderTool(
        icon: Icons.search_rounded,
        onTap: _openSearch,
        semanticLabel: l.actionSearch,
      ),
    ];
  }

  /// The all-filtered state's standalone tool row: filter and search only, drawn
  /// without the hero (there is no figure). The two buttons are lifted verbatim
  /// from [_buildTools] — indices 2 (filter) and 3 (search) — so their icons,
  /// actions, active states and styling are byte-identical to the populated row,
  /// only the sort and collapse tools are dropped (nothing to sort or collapse).
  Widget _reducedToolRow(AppStore store) {
    final all = _buildTools(store);
    final tools = <_HeaderTool>[all[2], all[3]];
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) const SizedBox(width: _kToolGap),
            _ToolButton(
              tool: tools[i],
              size: _kTool,
              radius: _kToolRadius,
            ),
          ],
        ],
      ),
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
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
    final picked = await showReportingDateSheet(context,
        selected: store.asOf, today: store.today);
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
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.divider,
                ),
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
      // No accounts at all is the "add your first account" case. A section that
      // owns accounts but has them all filtered out is handled by the empty pane
      // behind the header (see [build] / [_allFilteredPane]), so it never
      // reaches here with rows to draw — the list simply stands down.
      if (!hasAccounts) return _firstRunPane();
      return const SizedBox.expand();
    }

    // Section headers only show on All: on a filtered section the total already
    // sits in the header 60px above, and it must appear in exactly one place.
    final showHeaders = _section == BalanceSection.all;

    // A section renders only when it has visible groups. A section whose groups
    // are all hidden (or that owns no account) drops out entirely — the whole
    // list being empty is the empty pane's job, not a per-section notice.
    // A plain scroll view rather than a ListView: the reorderable groups are
    // non-scrolling columns nested inside it, and the list is small enough that
    // laziness buys nothing.
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_section != BalanceSection.liabilities && assets.isNotEmpty)
            _sectionBlock(
              store,
              assets: true,
              groups: assets,
              showHeader: showHeaders,
            ),
          if (_section != BalanceSection.assets && liabilities.isNotEmpty)
            _sectionBlock(
              store,
              assets: false,
              groups: liabilities,
              showHeader: showHeaders,
            ),
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
        // Callers only build a section block for a section with visible groups,
        // so this always renders rows. An all-hidden section is the empty pane's
        // job (see [_allFilteredPane]), never a per-section $0 notice here.
        for (final g in groups) _categoryBlock(store, g),
      ],
    );
  }

  Widget _noResults() => Padding(
    padding: const EdgeInsets.only(top: 72),
    child: EmptyState(
      icon: Icons.search_off_rounded,
      title: AppLocalizations.of(context).balNoResults,
      message: AppLocalizations.of(context).balNoAccountMatch,
    ),
  );

  /// The one place an "add account" call to action belongs: what is redundant
  /// noise in a populated list is the only way forward in an empty one.
  ///
  /// The fourth row names what fills the screen. Balance is filled by the header
  /// `+` above it, exactly as the Ledger and the Planner are, so it points at
  /// that control with the same sentence rather than carrying a second, rival
  /// create button of its own — "Add an account" duplicated the `+` two rows
  /// below it.
  ///
  /// The block is centred against the whole body by [FirstRunBlock]; see the
  /// Stack in [build].
  Widget _firstRunPane() {
    final l = AppLocalizations.of(context);
    // A NUL the localized string can never contain, swapped in for `{plus}` so a
    // translation is free to move the glyph; a string that lost the placeholder
    // degrades to plain text with the glyph omitted.
    final sentinel = String.fromCharCode(0);
    return FirstRunBlock(
      icon: Icons.account_balance_wallet_rounded,
      title: l.balNoAccountsYet,
      message: l.balEmptyBenefit,
      // The hint sits in the reserved fourth-row box, below the text. It never
      // wraps — a second line would change the block height and undo the
      // shared-height guarantee — so it scales down instead.
      action: FittedBox(
        fit: BoxFit.scaleDown,
        child: buildFirstRunHint(l.ldgFirstRunHint(sentinel), sentinel,
            semanticsLabel: l.ldgFirstRunHintA11y),
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
        .where(
          (g) => store.groupCount(g) > 0 && filter.isGroupVisible(store, g),
        )
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
    return store.balanceFilter
        .visibleAccounts(store, group)
        .any((a) => a.name.toLowerCase().contains(q));
  }

  /// Children of [group], narrowed by the query and sorted by [_sort] —
  /// independently per group, since the sort applies to accounts, not to
  /// the (fixed) group order.
  List<Account> _children(AppStore store, AccountGroup group) {
    final q = _query.toLowerCase();
    final groupMatches = group
        .label(AppLocalizations.of(context))
        .toLowerCase()
        .contains(q);

    final list = store.balanceFilter
        .visibleAccounts(store, group)
        .where(
          (a) =>
              _query.isEmpty ||
              groupMatches ||
              a.name.toLowerCase().contains(q),
        )
        .toList();

    if (store.balanceSort == AccountSort.custom) {
      // Order by the user's arrangement; the visible subset keeps that relative
      // order (filtering happens after ordering).
      final rank = <String, int>{};
      var i = 0;
      for (final a in store.balanceOrder.orderedAccounts(store, group)) {
        rank[a.id] = i++;
      }
      list.sort(
        (a, b) => (rank[a.id] ?? 1 << 30).compareTo(rank[b.id] ?? 1 << 30),
      );
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
    final matchedOnChild =
        _query.isNotEmpty &&
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
    final sectionTotal = filter
        .sectionTotal(store, assets: group.isAsset)
        .abs();
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
                        () => _activeDrag = _ActiveDrag.account(group),
                      ),
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
                            ? liabilitySubtitle(
                                store,
                                a,
                                AppLocalizations.of(context),
                              ).text
                            : null,
                        subtitleColor: group.isLiability
                            ? liabilitySubtitle(
                                store,
                                a,
                                AppLocalizations.of(context),
                              ).color
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
  CustomOrder _baseOrder(AppStore store) =>
      store.balanceSort == AccountSort.custom
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
    _pendingMove = _PendingMove(
      order: store.balanceOrder,
      sort: store.balanceSort,
    );
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
        AccountSort.valueDesc =>
          store
              .balanceInBase(b.id)
              .abs()
              .compareTo(store.balanceInBase(a.id).abs()),
        AccountSort.valueAsc =>
          store
              .balanceInBase(a.id)
              .abs()
              .compareTo(store.balanceInBase(b.id).abs()),
        AccountSort.nameAsc => a.name.compareTo(b.name),
        AccountSort.activity =>
          store.accountActivity(b.id).compareTo(store.accountActivity(a.id)),
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

  void _openAccountLedger(Account account) =>
      _openLedger(AccountScope(account.id));

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

// ── Header amount row + tools ─────────────────────────────────────────────
//
// The amount and the four tool buttons share one row, optically centred. The
// amount is never truncated, abbreviated or rounded; a three-step ladder shrinks
// the font (30 → 22), then the buttons (28 → 24), then drops the tools to their
// own row — in that order, and only as far as needed. See [_BalanceAmountRow].

const double _kAmountMax = 30; // never larger
const double _kAmountMin = 22; // never smaller — below this the balance stops
// outranking the 13.5pt account rows beneath it, so it never gives way further.

const double _kTool = 28, _kToolGap = 6, _kToolRadius = 8;
const double _kToolTight = 24, _kToolGapTight = 4, _kToolRadiusTight = 7;

const double _kAmountToolsMinGap = 10;
const double _kToolGlyph = 15;
const double _kToolsBelowGap = 8; // step 3 only

/// The amount's style. `height: 1.0` with even leading removes the font's own
/// dead space from the box, so the gaps above and below render at the value
/// specified rather than ~7pt larger. `letterSpacing` is a fraction of the size,
/// so rendered width is exactly proportional to it — which is why the ladder can
/// solve step 1 from a single measurement instead of iterating.
TextStyle _amountStyle(double size, Color? color) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.025 * size,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
      color: color ?? AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// One header tool. Same fields the shared [Tool] carried, so the four buttons
/// keep their icons, actions and active semantics; [filterActive] is the one new
/// state (see [_ToolButton]).
class _HeaderTool {
  const _HeaderTool({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.semanticValue,
    this.filled = false,
    this.iconColor,
    this.filterActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String? semanticValue;

  /// Collapse-all's "on" look — accent fill, white glyph. Unchanged.
  final bool filled;

  /// Sort's "non-default" look — glyph brightened one step, surface unchanged.
  final Color? iconColor;

  /// Only the filter tool sets this. The count line is gone, so the active
  /// filter carries the whole "partial total" signal: accent @ 20% fill,
  /// accentLight glyph.
  final bool filterActive;
}

/// One rung of the scale-down ladder.
class _Step {
  const _Step(
    this.fontSize,
    this.toolSize,
    this.toolGap,
    this.toolRadius,
    this.toolsBelow,
  );

  final double fontSize, toolSize, toolGap, toolRadius;
  final bool toolsBelow;
}

/// The amount + tools row and its ladder. The amount leads, the tools trail, and
/// the space between them is whatever is left — nothing is ever placed there.
class _BalanceAmountRow extends StatelessWidget {
  const _BalanceAmountRow({
    required this.display,
    required this.color,
    required this.measured,
    required this.asOf,
    required this.tools,
  });

  /// The current section's amount, already formatted (never reformatted here).
  final String display;
  final Color? color;

  /// All three pages' formatted totals; the font size is solved from the widest
  /// so it does not jump on a section swipe.
  final List<String> measured;
  final Widget? asOf;
  final List<_HeaderTool> tools;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth));
  }

  Widget _row(BuildContext context, double maxWidth) {
    final step = _resolve(context, maxWidth);

    // Never wraps, never ellipsises, never abbreviates. The ladder guarantees it
    // fits, so an overflow could only mean the ladder is wrong — let it show in
    // debug rather than silently truncating a figure.
    final amount = Text(
      display,
      maxLines: 1,
      softWrap: false,
      style: _amountStyle(step.fontSize, color),
    );

    final left = asOf == null
        ? amount
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [amount, asOf!],
          );

    if (step.toolsBelow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: left),
          const SizedBox(height: _kToolsBelowGap),
          Align(alignment: Alignment.centerRight, child: _toolRow(step)),
        ],
      );
    }

    return Row(
      // center, not baseline: 28pt buttons hung from a 30pt text baseline sit
      // visibly below the digits' optical centre.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: left)),
        if (tools.isNotEmpty) _toolRow(step),
      ],
    );
  }

  Widget _toolRow(_Step step) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) SizedBox(width: step.toolGap),
            _ToolButton(
              tool: tools[i],
              size: step.toolSize,
              radius: step.toolRadius,
            ),
          ],
        ],
      );

  /// Each step is entered only when the previous one does not fit. The amount
  /// never gives way: it is not truncated, abbreviated or rounded at any step.
  _Step _resolve(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);

    double toolsWidth(double size, double gap) => tools.isEmpty
        ? 0
        : tools.length * size + (tools.length - 1) * gap + _kAmountToolsMinGap;

    // The widest of the three totals at [fontSize]. letterSpacing is
    // proportional to the size, so this is proportional to it too.
    double widthAt(double fontSize) {
      var w = 0.0;
      for (final s in measured) {
        final width = (TextPainter(
          text: TextSpan(text: s, style: _amountStyle(fontSize, color)),
          textDirection: dir,
          textScaler: scaler,
          maxLines: 1,
        )..layout())
            .width;
        if (width > w) w = width;
      }
      return w;
    }

    final wMax = widthAt(_kAmountMax);

    // step 0 — it fits as it is
    final room0 = maxWidth - toolsWidth(_kTool, _kToolGap);
    if (wMax <= room0) {
      return const _Step(_kAmountMax, _kTool, _kToolGap, _kToolRadius, false);
    }

    // step 1 — shrink the font, down to the floor
    final fitted = (_kAmountMax * room0 / wMax).clamp(_kAmountMin, _kAmountMax);
    if (fitted > _kAmountMin) {
      return _Step(fitted, _kTool, _kToolGap, _kToolRadius, false);
    }

    // step 2 — font is on the floor; tighten the buttons
    final room2 = maxWidth - toolsWidth(_kToolTight, _kToolGapTight);
    if (widthAt(_kAmountMin) <= room2) {
      return const _Step(
        _kAmountMin,
        _kToolTight,
        _kToolGapTight,
        _kToolRadiusTight,
        false,
      );
    }

    // step 3 — the amount takes the full width, the tools drop below it
    return const _Step(_kAmountMin, _kTool, _kToolGap, _kToolRadius, true);
  }
}

/// One header tool button. Painted at [size]; the hit area follows the screen's
/// existing tool-button convention (opaque, at paint size — see [ToolCluster]).
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.size,
    required this.radius,
  });

  final _HeaderTool tool;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color glyph;
    if (tool.filterActive) {
      // accent @ 20% fill, accentLight glyph — the sole "partial total" cue.
      fill = AppColors.tint(AppColors.accent, 0.20);
      glyph = AppColors.accentLight;
    } else if (tool.filled) {
      fill = AppColors.accent;
      glyph = Colors.white;
    } else {
      fill = AppColors.surfaceAlt;
      glyph = tool.iconColor ?? AppColors.textSecondary;
    }

    return Semantics(
      button: true,
      label: tool.semanticLabel,
      value: tool.semanticValue,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tool.onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(tool.icon, size: _kToolGlyph, color: glyph),
        ),
      ),
    );
  }
}

// ── Header pieces ───────────────────────────────────────────────────────────

class _ListSectionHeader extends StatelessWidget {
  const _ListSectionHeader(this.label, this.total, {required this.assets});

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
            // The liabilities section total is the raw (negative) sum; flagging
            // it liability-side keeps it unsigned, and lets an asset section that
            // has gone below zero show its minus (task 011).
            isLiability: !assets,
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

/// Shared empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.titleAsHeader = false,
    this.iconBackdrop = false,
    this.messageMaxWidth,
    this.iconSize,
    this.textBlockHeight,
    this.actionHeight,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Marks [title] as a heading for the screen reader. Off by default so every
  /// existing caller's semantics tree is untouched; Balance's first-run state
  /// opts in (§7).
  final bool titleAsHeader;

  /// Renders [icon] on a filled circular backdrop instead of bare. Off by
  /// default: the seven other call sites are unchanged.
  final bool iconBackdrop;

  /// Caps the message's line length. Null keeps the full available width.
  final double? messageMaxWidth;

  /// Overrides the glyph size. Null keeps the default — 24pt on a backdrop, 40pt
  /// bare. The Planner's first-run tabs pass per-glyph values so three icons of
  /// different natural heights read at one cap height (§4.2).
  final double? iconSize;

  /// Floors the title+message region to a shared height, top-aligned. Null lets
  /// it grow to its content. The six first-run screens pass one height derived
  /// across all their title/message pairs so the icon lands on the same y on
  /// every screen (§2/§3). It is a *minimum*, not a fixed height: when a
  /// measurement and a render disagree the region grows rather than clipping.
  final double? textBlockHeight;

  /// Floors the action row to a shared height, so the block below the message is
  /// one height on every first-run screen — Balance's link and the hint reserve
  /// the same box (§4). Null renders the action at its natural height (every
  /// out-of-scope call site). Also a minimum, for the same reason as
  /// [textBlockHeight].
  final double? actionHeight;

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

    // A bare 40pt glyph has nothing holding it once a block is centred; the
    // opt-in backdrop is a 54pt surface circle with a 24pt glyph (§2.2). Off by
    // default so the other call sites keep their bare 40pt icon.
    final Widget iconWidget = iconBackdrop
        ? Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize ?? 24,
              color: AppColors.textTertiary,
            ),
          )
        : Icon(icon, size: iconSize ?? 40, color: AppColors.textTertiary);

    Widget messageWidget = Text(
      message,
      style: AppText.caption,
      textAlign: TextAlign.center,
    );
    if (messageMaxWidth != null) {
      messageWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: messageMaxWidth!),
        child: messageWidget,
      );
    }

    // The title and message, optionally pinned to a fixed height. Top-aligned so
    // a shorter message leaves its slack at the foot of the box, not above the
    // icon — which is exactly what keeps the icon from sliding down (§4.3).
    Widget textBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        titleText,
        const SizedBox(height: Insets.xs),
        messageWidget,
      ],
    );
    if (textBlockHeight != null) {
      // A minimum, not a fixed height: content one pixel taller than the derived
      // figure grows the region instead of clipping it (§3).
      textBlock = ConstrainedBox(
        constraints: BoxConstraints(minHeight: textBlockHeight!),
        child: Align(alignment: Alignment.topCenter, child: textBlock),
      );
    }

    Widget? actionWidget = action;
    if (actionWidget != null && actionHeight != null) {
      // The reserved fourth-row box, shared by Balance's link and the hint (§4).
      // A minimum for the same reason the text block is — it never clips.
      actionWidget = ConstrainedBox(
        constraints: BoxConstraints(minHeight: actionHeight!),
        child: Align(alignment: Alignment.topCenter, child: action!),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: Insets.md),
          textBlock,
          if (actionWidget != null) ...[
            const SizedBox(height: Insets.xl),
            actionWidget,
          ],
        ],
      ),
    );
  }
}

// ── First-run empty block, shared by Balance / Ledger / Planner ×3 / Insight ──
//
// The six first-run screens draw one block — a backed icon, a title, a message
// and a fourth row — meant to read as one screen with different words in it. To
// land the icon on the same y on every screen they must all lay the block
// against the same reference: the whole tab body, from the safe area to the top
// of the bottom nav. Each screen does that by putting [FirstRunBlock] in a
// Stack behind its own chrome (header · segmented control · restore line), so
// the chrome paints over the block rather than consuming its height (§1). Two
// derived heights, computed once here across all six string pairs, keep the
// blocks the same size whatever the locale or text scale (§2/§4).

/// The hint's base style, kept in step with `buildFirstRunHint`.
const _firstRunHintTextStyle = TextStyle(fontSize: 12);

/// The fourth row's reserved height.
///
/// Historically this was Balance's "Add an account" link — a 14pt/w500 label
/// plus 10pt of vertical padding, floored at the 44pt tap target. No screen
/// renders a link any more (Balance took the hint, Insight has no fourth row),
/// but the figure is kept as an explicit constant rather than rebased onto the
/// hint: the blocks' icon-centre lines are calibrated to it, and deriving the
/// box from the hint instead would raise every icon by ~13.5pt — including the
/// Ledger's and the Planner's, which are the reference. Still a floor, not a
/// fixed height: a large text scale grows the hint past it and the box grows
/// with it.
const double _firstRunActionBox = 44.0;

double _measureFirstRun(
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler scaler,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    textScaler: scaler,
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

/// The style a `Text` in the block actually resolves: it merges its own style
/// over the ambient [DefaultTextStyle], inheriting whatever the style leaves
/// null — the theme's line height above all. A bare [TextPainter] inherits
/// nothing, so measuring without the ambient under-reserves the floor whenever
/// the theme's line height exceeds the font's own; the floor-setting screen
/// then renders past the floor the other screens sit on, and its icon drifts
/// off the shared line. The link is the one row measured bare: a [TextButton]
/// *replaces* the ambient with its own textStyle rather than merging into it.
TextStyle _resolveFirstRun(TextStyle? ambient, TextStyle style) =>
    ambient == null ? style : ambient.merge(style);

/// The tallest title + message stack across all six first-run screens at this
/// width and text scale (§2). Measured with the exact styles [EmptyState]
/// renders. A locale that runs one message to an extra line grows the box for
/// all six together, never one alone.
double firstRunTextBlockHeight(
  AppLocalizations l,
  double textWidth,
  TextScaler scaler, {
  TextStyle? ambient,
}) {
  final titleStyle = _resolveFirstRun(
    ambient,
    AppText.rowTitle.copyWith(fontSize: 16),
  );
  final messageStyle = _resolveFirstRun(ambient, AppText.caption);
  final pairs = <(String, String)>[
    (l.balNoAccountsYet, l.balEmptyBenefit),
    (l.ldgNothingHere, l.ldgNothingHereMsg),
    (l.plNoBudgetsYet, l.plNoBudgetsMsg),
    (l.plNoGoalsYet, l.plNoGoalsMsg),
    (l.plNothingScheduled, l.plNothingSchedMsg),
    (l.insEmptyNoAccountsTitle, l.insEmptyNoAccountsBody),
  ];
  var maxTitle = 0.0;
  var maxMessage = 0.0;
  for (final (title, message) in pairs) {
    final t = _measureFirstRun(title, titleStyle, textWidth, scaler);
    final m = _measureFirstRun(message, messageStyle, textWidth, scaler);
    if (t > maxTitle) maxTitle = t;
    if (m > maxMessage) maxMessage = m;
  }
  return maxTitle + Insets.xs + maxMessage;
}

/// The reserved height of the fourth row, shared by all five screens (§4): the
/// calibration constant, or the hint's measured line when a large text scale
/// grows it past that. See [_firstRunActionBox] for why the constant is not
/// rebased onto the hint.
double firstRunActionHeight(
  AppLocalizations l,
  double textWidth,
  TextScaler scaler, {
  TextStyle? ambient,
}) {
  final sentinel = String.fromCharCode(0);
  final hintH = _measureFirstRun(
    l.ldgFirstRunHint(sentinel),
    _resolveFirstRun(ambient, _firstRunHintTextStyle),
    textWidth,
    scaler,
  );
  return math.max(_firstRunActionBox, hintH);
}

/// One first-run block, centred against the full height it is given (§1). Place
/// it in a `Positioned.fill` behind the screen's chrome: the `LayoutBuilder`
/// then measures the whole body, so every screen centres the block on the same
/// y. It scrolls rather than clipping when large text or a short viewport leaves
/// no room to centre (§1/§3). The icon rides a 54pt backdrop, so its centre is
/// the block's centre whatever the glyph's own size — the per-tab [iconSize]
/// nudges never move it.
class FirstRunBlock extends StatelessWidget {
  const FirstRunBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.iconSize,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // The ambient style the block's Texts will resolve against — under the
    // Scaffold's Material this is the theme's bodyMedium on every screen, so
    // the measured floors match the render (see [_resolveFirstRun]).
    final ambient = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = (constraints.maxWidth - Insets.xxl * 2).clamp(
          0.0,
          double.infinity,
        );
        final textBlockHeight = firstRunTextBlockHeight(
          l,
          textWidth,
          scaler,
          ambient: ambient,
        );
        final actionHeight = firstRunActionHeight(
          l,
          textWidth,
          scaler,
          ambient: ambient,
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyState(
                icon: icon,
                iconSize: iconSize,
                iconBackdrop: true,
                title: title,
                message: message,
                titleAsHeader: true,
                textBlockHeight: textBlockHeight,
                actionHeight: actionHeight,
                action: action,
              ),
            ),
          ),
        );
      },
    );
  }
}
