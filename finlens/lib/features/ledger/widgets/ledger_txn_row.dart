import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/models/models.dart';
import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/search_fold.dart';
import '../../../shared/widgets/swipe_actions.dart';
import '../../../shared/widgets/transfer_title.dart';
import '../../../theme/app_colors.dart';
import '../ledger_scope.dart';

/// Renders [text] in [style], with every occurrence of the already-folded
/// [query] background-highlighted (spec §3). Falls back to a plain [Text] when
/// there is no query or no match, so a row outside search mode is unchanged.
Widget _highlighted(
  String text,
  TextStyle style, {
  required String? query,
  int maxLines = 1,
  TextOverflow overflow = TextOverflow.ellipsis,
}) {
  if (query == null || query.isEmpty) {
    return Text(text, maxLines: maxLines, overflow: overflow, style: style);
  }
  final folded = foldSearch(text);
  var at = folded.indexOf(query);
  if (at < 0) {
    return Text(text, maxLines: maxLines, overflow: overflow, style: style);
  }
  final mark = TextStyle(
    color: Colors.white,
    backgroundColor: AppColors.accent.withValues(alpha: 0.3),
  );
  final spans = <TextSpan>[];
  var cursor = 0;
  while (at >= 0) {
    if (at > cursor) spans.add(TextSpan(text: text.substring(cursor, at)));
    final end = at + query.length;
    spans.add(TextSpan(text: text.substring(at, end), style: mark));
    cursor = end;
    at = folded.indexOf(query, cursor);
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return Text.rich(
    TextSpan(style: style, children: spans),
    maxLines: maxLines,
    overflow: overflow,
  );
}

/// A day's transactions in one card, with the day's net in the header.
///
/// One card per day rather than per transaction: the per-row card forced an
/// 8px gap between every pair of rows, which broke the day grouping into
/// unrelated tiles.
class LedgerDayCard extends StatelessWidget {
  const LedgerDayCard({
    super.key,
    required this.group,
    required this.scope,
    required this.onOpen,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.isFirstCard = false,
    this.flat = false,
    this.highlight,
    this.showDescription = true,
    this.showBalance = true,
  });

  final bool isFirstCard;
  final DayGroup group;
  final LedgerScope scope;

  /// Whether noted rows reveal their description line — the scoped screens'
  /// descriptions toggle (defaults on; a search-matched note still reveals).
  final bool showDescription;

  /// Whether the running-balance column is legible for this list — the
  /// [LedgerListShape.showsRunningBalance] predicate. When false the figure does
  /// not render (and is not announced), and nothing takes its place.
  final bool showBalance;

  /// Row tap — opens the read-only Same-transactions screen. A tap never opens
  /// the editor (spec §1); editing stays behind the swipe menu.
  final ValueChanged<Txn> onOpen;
  final ValueChanged<Txn> onEdit;
  final ValueChanged<Txn> onCopy;
  final ValueChanged<Txn> onDelete;

  /// A non-date sort drops the day header and renders one flat card (spec §1).
  final bool flat;

  /// Folded search query passed to each row for highlighting.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    // Internal transfers net to zero by definition, so they are left out of
    // the day net exactly as they are left out of In and Out.
    final net = group.total;
    final rows = group.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Under amount/name sorts the list is not chronological, so a day header
        // above it would misdescribe the rows — drop it and render one flat card.
        if (flat) const SizedBox(height: 8),
        if (!flat)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateGroupLabel(group.date, AppLocalizations.of(context)).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.09 * 11,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                // Unsigned, like the rows beneath it: colour carries direction
                // on both, so a sign here and none there would be an
                // inconsistency the eye notices without being able to name it.
                // Kept in the tree and faded rather than removed: the header's
                // box must be identical whether or not the total shows, so a
                // date lands on the same pixel row either way and a day flipping
                // between one and two rows cannot reflow the list.
                ExcludeSemantics(
                  excluding: !group.showsDayTotal,
                  child: AnimatedOpacity(
                    opacity: group.showsDayTotal ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Semantics(
                      label:
                          '${net < 0 ? AppLocalizations.of(context).ldgNetOut : AppLocalizations.of(context).ldgNetIn}, '
                          '${money(net, signless: true, masked: StoreScope.of(context).masked)}',
                      excludeSemantics: true,
                      child: Text(
                        money(
                          net,
                          signless: true,
                          masked: StoreScope.of(context).masked,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: net < 0
                              ? AppColors.amountChildNeg
                              : AppColors.positive,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.fieldCard,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 53),
                    child: Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                LedgerTxnRow(
                  row: rows[i],
                  scope: scope,
                  onOpen: () => onOpen(rows[i].txn),
                  onEdit: () => onEdit(rows[i].txn),
                  onCopy: () => onCopy(rows[i].txn),
                  onDelete: () => onDelete(rows[i].txn),
                  hint: isFirstCard && i == 0,
                  highlight: highlight,
                  showDescription: showDescription,
                  showBalance: showBalance,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A 52px transaction row. Edit, Copy and Delete live behind a left swipe.
///
/// Tapping opens the read-only Same-transactions screen (spec §1) — never the
/// editor, so a stray tap while scrolling can no longer silently change
/// financial data. Editing stays behind the swipe menu and the ••• on that
/// screen. A tap while another row's swipe strip is open just closes it.
class LedgerTxnRow extends StatelessWidget {
  const LedgerTxnRow({
    super.key,
    required this.row,
    required this.scope,
    required this.onOpen,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.hint = false,
    this.highlight,
    this.showDescription = true,
    this.showBalance = true,
  });

  final bool hint;
  final ScopedTxn row;
  final LedgerScope scope;

  /// Opens the read-only Same-transactions screen for this row's key (spec §1).
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  /// Folded search query to highlight in this row's text, or null outside
  /// search mode (spec §3).
  final String? highlight;

  /// Whether a noted row reveals its description line. A note-less row is
  /// unaffected; a row whose note matched the search reveals it regardless.
  final bool showDescription;

  /// Whether the running-balance figure renders. False on any list that is not
  /// a contiguous single-account tape (multi-account, non-date sort, or
  /// narrowed) — see [LedgerListShape.showsRunningBalance]. When false the
  /// figure is neither drawn nor announced, and nothing replaces it.
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final txn = row.txn;
    // A transfer renders on its own two-line, neutral layout (spec §2/§3): the
    // source and `→ destination` in a group/all ledger, collapsed to just the
    // counterpart on a single account's screen. Never a category colour.
    if (txn.type == TxnType.transfer) return _buildTransfer(context, store);
    final category = _categoryLabel(context, store, txn);
    final colour = _refColour(store, txn);
    final isTransfer = txn.type == TxnType.transfer;
    final parties = isTransfer ? store.transferParties(txn) : null;

    final amountColour = switch (row.kind) {
      FlowKind.internal => AppColors.textSecondary,
      FlowKind.inflow => AppColors.positive,
      FlowKind.outflow => AppColors.amountChildNeg,
    };

    // Line 2 is the free-text description; the meta line carries the account
    // (dropped where the screen already implies it — account scope — and for a
    // transfer, whose title already names both sides) and the tag.
    final note = txn.note.trim();
    final hasNote = note.isNotEmpty;
    // The description line follows the toggle, but a note the search matched
    // reveals itself regardless (spec §3). A note-less row is unaffected either
    // way.
    final noteMatched = highlight != null &&
        highlight!.isNotEmpty &&
        foldSearch(note).contains(highlight!);
    final descOpen = hasNote && (showDescription || noteMatched);
    final accountName = (scope is! AccountScope && !isTransfer)
        ? (store
                  .accountById(
                    txn.type == TxnType.income ? txn.toRef : txn.fromRef,
                  )
                  ?.name ??
              '')
        : '';
    final tag = txn.tags.isEmpty ? null : txn.tags.first;
    final hasMeta = accountName.isNotEmpty || tag != null;

    final money0 = money(
      row.signedAmount,
      signless: true,
      masked: store.masked,
    );
    final balance0 = money(_runningBalance(store, txn), masked: store.masked);
    // Parts in reading order — title, amount, direction, description, balance,
    // account, tag — not one merged string (spec §5). A figure a sighted user
    // cannot see is never announced: the balance only when the column renders,
    // the description only when it is open.
    final semanticsLabel = [
      isTransfer
          ? AppLocalizations.of(context).transferFromTo(parties!.from, parties.to)
          : category,
      money0,
      if (!isTransfer)
        switch (row.kind) {
          FlowKind.inflow => AppLocalizations.of(context).txnTypeIncome.toLowerCase(),
          FlowKind.outflow => AppLocalizations.of(context).txnTypeExpense.toLowerCase(),
          FlowKind.internal => AppLocalizations.of(context).a11yInternalTransfer,
        },
      if (descOpen) note,
      if (showBalance) '${AppLocalizations.of(context).a11yBalanceWord} $balance0',
      if (accountName.isNotEmpty) accountName,
      if (tag != null) 'tag $tag',
    ].join(', ');

    // Fonts/weights/colours are kept exactly as before — only the layout
    // structure and heights change.
    const titleStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.22,
      color: AppColors.textPrimary,
    );
    const descStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.textSecondary,
    );
    const metaStyle = TextStyle(
      fontSize: 11.5,
      height: 1.2,
      color: AppColors.runningBalance,
    );

    final amountWidget = Text(
      money(row.displayAmount, signless: true, masked: store.masked),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: amountColour,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final balanceWidget = Text(
      balance0,
      style: const TextStyle(
        fontSize: 11,
        height: 1.2,
        color: AppColors.runningBalance,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    final titleWidget = isTransfer
        ? TransferTitleText(
            from: parties!.from,
            to: parties.to,
            style: titleStyle,
          )
        : Row(
            children: [
              Flexible(
                child: _highlighted(category, titleStyle, query: highlight),
              ),
              if (!txn.movesCash) ...[
                const SizedBox(width: 6),
                const _NoCashPill(),
              ],
            ],
          );

    return Semantics(
      // Swipe actions are invisible to assistive tech unless declared, so all
      // three are exposed to the action rotor. The row itself stays read-only.
      customSemanticsActions: {
        CustomSemanticsAction(label: AppLocalizations.of(context).actionEdit): onEdit,
        CustomSemanticsAction(label: AppLocalizations.of(context).actionCopy): onCopy,
        CustomSemanticsAction(label: AppLocalizations.of(context).actionDelete): onDelete,
      },
      label: semanticsLabel,
      child: SwipeActions(
        actionWidth: 72,
        hintOnFirstBuild: hint,
        actions: [
          SwipeActionItem(
            icon: Icons.edit_rounded,
            label: AppLocalizations.of(context).actionEdit,
            color: const Color(0xFF2C2C2E),
            onTap: onEdit,
          ),
          SwipeActionItem(
            icon: Icons.copy_rounded,
            label: AppLocalizations.of(context).actionCopy,
            color: const Color(0xFF0A84FF),
            onTap: onCopy,
          ),
          SwipeActionItem(
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(context).actionDelete,
            color: const Color(0xFFFF453A),
            onTap: onDelete,
          ),
        ],
        child: GestureDetector(
          // A tap opens the read-only Same-transactions screen (spec §1). When
          // another row's swipe strip is open, the first tap just dismisses it
          // — matching the list's tap-outside-to-close behaviour — rather than
          // navigating out from under the user.
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (anySwipeRowOpen) {
              closeOpenSwipeRow();
              return;
            }
            onOpen();
          },
          child: ColoredBox(
            color: AppColors.fieldCard,
            // No fixed height: a 44pt floor (tap + swipe target), everything else
            // intrinsic from padding + content, so rows grow at large text scale.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Top block: icon tile + the two-line text/figure column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: colour.withValues(alpha: 0.17),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              store.refIcon(
                                txn.type == TxnType.expense
                                    ? txn.toRef
                                    : txn.fromRef,
                              ),
                              size: 15,
                              color: colour,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Line 1: title | amount, read on the baseline —
                                // two type sizes side by side pair on their
                                // baselines, not their centres. When the
                                // description is closed and the balance renders,
                                // it sits beside the amount here rather than on a
                                // second line.
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Expanded(child: titleWidget),
                                    const SizedBox(width: 10),
                                    if (!descOpen && showBalance)
                                      // Amount + balance stay centre-aligned to
                                      // each other (they share this line); the
                                      // outer row baselines the pair against the
                                      // title.
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          amountWidget,
                                          const SizedBox(width: 6),
                                          balanceWidget,
                                        ],
                                      )
                                    else
                                      amountWidget,
                                  ],
                                ),
                                if (descOpen) ...[
                                  const SizedBox(height: 2),
                                  // Line 2: description | balance (the balance
                                  // only when the column is legible for this list).
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _highlighted(
                                          note,
                                          descStyle,
                                          query: highlight,
                                        ),
                                      ),
                                      if (showBalance) ...[
                                        const SizedBox(width: 10),
                                        balanceWidget,
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      // ── Meta line: account · tag, full width, left edge aligned
                      // with the text column (icon 30 + gap 11 = 41pt). Nothing is
                      // to its right, so the account stops sharing that width.
                      if (hasMeta) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 41),
                          child: Row(
                            children: [
                              if (accountName.isNotEmpty)
                                Flexible(
                                  child: _highlighted(
                                    accountName,
                                    metaStyle,
                                    query: highlight,
                                  ),
                                ),
                              if (accountName.isNotEmpty && tag != null)
                                const Text('  ·  ', style: metaStyle),
                              // The tag is laid out first (fixed), so the account
                              // ellipsizes to make room rather than the tag.
                              if (tag != null)
                                _highlighted(
                                  tag,
                                  metaStyle.copyWith(color: AppColors.tagDot),
                                  query: highlight,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Spec §2/§3 — a transfer's two-line, neutral-coloured row, replacing the
  /// category layout. In a group/all ledger it names the source then
  /// `→ destination`; on an account screen it collapses to the counterpart
  /// alone with a directional glyph and keeps the note. The tile and amount are
  /// neutral throughout — a transfer is neither a gain nor a loss.
  Widget _buildTransfer(BuildContext context, AppStore store) {
    final txn = row.txn;
    final parties = store.transferParties(txn);
    final onAccount = scope is AccountScope;
    final outgoing = onAccount
        ? txn.fromRef == (scope as AccountScope).accountId
        : true;

    final fromCur = store.accountById(txn.fromRef)?.currency ?? txn.currency;
    final toCur = store.accountById(txn.toRef)?.currency ?? txn.currency;
    final crossCurrency = fromCur != toCur;

    const titleStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.22,
      color: AppColors.textPrimary,
    );
    const descStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: AppColors.textSecondary,
    );
    final amountStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AppColors.transferAmount,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const balanceStyle = TextStyle(
      fontSize: 11,
      height: 1.2,
      color: AppColors.runningBalance,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    // Line 1: counterpart on an account screen, else the source account.
    final IconData glyph;
    final String line1Text;
    final TextStyle line1Style;
    if (onAccount) {
      glyph = outgoing
          ? Icons.north_east_rounded
          : Icons.south_west_rounded;
      line1Text = outgoing ? '→ ${parties.to}' : '← ${parties.from}';
      line1Style = titleStyle;
    } else {
      glyph = Icons.swap_horiz_rounded;
      line1Text = parties.from;
      line1Style = titleStyle;
    }

    // Line-1 amount. Same-currency uses the ledger's base-converted figure, so
    // it stays consistent with the sibling rows around it; cross-currency shows
    // the real per-leg amounts, each in its own currency.
    final Widget amountTop;
    if (crossCurrency) {
      final v = onAccount
          ? (outgoing ? txn.amount : (txn.toAmount ?? txn.amount))
          : txn.amount;
      final c = onAccount ? (outgoing ? fromCur : toCur) : fromCur;
      amountTop = Text(
        money(v, currency: c, signless: true, masked: store.masked),
        style: amountStyle,
      );
    } else {
      amountTop = Text(
        money(row.signedAmount, signless: true, masked: store.masked),
        style: amountStyle,
      );
    }

    final balanceText = money(_runningBalance(store, txn), masked: store.masked);
    final note = txn.note.trim();
    // The account screen's note follows the descriptions toggle (a search-matched
    // note reveals regardless); the group ledger's line 2 is the destination, a
    // structural label the toggle never touches.
    final noteMatched = highlight != null &&
        highlight!.isNotEmpty &&
        foldSearch(note).contains(highlight!);
    final descOpen = note.isNotEmpty && (showDescription || noteMatched);

    // Line 2. The running balance (or, cross-currency, the received leg — which
    // is an amount, not a balance) sits on the right; the balance only when the
    // column is legible for this list, the received leg always.
    String? line2Left;
    TextStyle line2LeftStyle = descStyle;
    final Widget? line2Right;
    if (onAccount) {
      if (descOpen) line2Left = note;
      line2Right = showBalance ? Text(balanceText, style: balanceStyle) : null;
    } else {
      line2Left = '→ ${parties.to}';
      line2LeftStyle = titleStyle.copyWith(color: AppColors.textSecondary);
      line2Right = crossCurrency
          ? Text(
              money(txn.toAmount ?? txn.amount,
                  currency: toCur, signless: true, masked: store.masked),
              style: amountStyle,
            )
          : (showBalance ? Text(balanceText, style: balanceStyle) : null);
    }
    final hasLine2 = line2Left != null || line2Right != null;

    // A number a sighted user cannot see is not announced (spec §5): the balance
    // only when the column renders, the note only when its line is open.
    final semanticsLabel = [
      AppLocalizations.of(context).transferFromTo(parties.from, parties.to),
      money(txn.amount, currency: txn.currency, signless: true, masked: store.masked),
      if (onAccount && descOpen) note,
      if (showBalance) 'balance $balanceText',
    ].join(', ');

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: AppLocalizations.of(context).actionEdit): onEdit,
        CustomSemanticsAction(label: AppLocalizations.of(context).actionCopy): onCopy,
        CustomSemanticsAction(label: AppLocalizations.of(context).actionDelete): onDelete,
      },
      label: semanticsLabel,
      child: SwipeActions(
        actionWidth: 72,
        hintOnFirstBuild: hint,
        actions: [
          SwipeActionItem(
            icon: Icons.edit_rounded,
            label: AppLocalizations.of(context).actionEdit,
            color: const Color(0xFF2C2C2E),
            onTap: onEdit,
          ),
          SwipeActionItem(
            icon: Icons.copy_rounded,
            label: AppLocalizations.of(context).actionCopy,
            color: const Color(0xFF0A84FF),
            onTap: onCopy,
          ),
          SwipeActionItem(
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(context).actionDelete,
            color: const Color(0xFFFF453A),
            onTap: onDelete,
          ),
        ],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (anySwipeRowOpen) {
              closeOpenSwipeRow();
              return;
            }
            onOpen();
          },
          child: ColoredBox(
            color: AppColors.fieldCard,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.transferTileBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(glyph,
                            size: 15, color: AppColors.transferGlyph),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(line1Text,
                                      style: line1Style,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 10),
                                amountTop,
                              ],
                            ),
                            // Line 2 can vanish entirely — a tag-less, note-less
                            // transfer whose balance is suppressed falls to the
                            // 44pt floor, which is correct: the title already
                            // names both sides.
                            if (hasLine2) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: line2Left == null
                                        ? const SizedBox.shrink()
                                        : Text(line2Left,
                                            style: line2LeftStyle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                  ),
                                  if (line2Right != null) ...[
                                    const SizedBox(width: 10),
                                    line2Right,
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The account's balance immediately after this transaction.
  double _runningBalance(AppStore store, Txn txn) {
    final ref = switch (scope) {
      AccountScope(:final accountId) => accountId,
      _ => txn.type == TxnType.income ? txn.toRef : txn.fromRef,
    };
    return store.accountById(ref) == null
        ? 0
        : store.runningBalanceAt(ref, txn);
  }

  String _categoryLabel(BuildContext context, AppStore store, Txn txn) {
    final l = AppLocalizations.of(context);
    return switch (txn.type) {
      TxnType.expense => store.refName(txn.toRef),
      TxnType.income => store.refName(txn.fromRef),
      TxnType.transfer => scope is AccountScope
          ? '${l.txnTypeTransfer} ${row.counterpartyLine ?? ''}'.trim()
          : l.txnTypeTransfer,
      TxnType.rebalance => l.txnRevaluation,
    };
  }

  Color _refColour(AppStore store, Txn txn) => switch (txn.type) {
    TxnType.expense => store.refColor(txn.toRef),
    TxnType.income => store.refColor(txn.fromRef),
    TxnType.transfer => AppColors.transfer,
    TxnType.rebalance => AppColors.rebalance,
  };
}

/// Tells the user not to go looking for a matching bank entry. The amount
/// still counts toward In and Out — the balance genuinely moved.
class _NoCashPill extends StatelessWidget {
  const _NoCashPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.chipBg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      AppLocalizations.of(context).ldgNoCash.toUpperCase(),
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05 * 9.5,
        height: 1.2,
        color: AppColors.formDim2,
      ),
    ),
  );
}
