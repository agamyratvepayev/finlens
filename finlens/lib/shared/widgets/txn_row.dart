import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/search_fold.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'amount_text.dart';
import 'app_card.dart';
import 'destructive_sheet.dart';
import 'swipe_actions.dart';
import 'title_tag_row.dart';

/// One Ledger line. The main Ledger tab (2.1) drives it with the description
/// toggle; the account-detail *perspective* (`perspectiveAccountId` +
/// `runningBalance`) is preserved unchanged for the screens/tests that still
/// use it.
///
/// The main Ledger tab renders **no running balance**: its list interleaves
/// every account, so a per-row figure reconciles against no series a reader can
/// follow (balance spec §1). A balance appears only on the perspective callers,
/// which are a single account's tape.
///
/// Layout (spec §4): two compact lines by default —
///   line 1  `title ————— amount`
///   line 2  `account #tags ——— balance` (one secondary figure, intrinsic width)
/// and, when [showDescription] is on (or a search matched the note), a third
/// description line that grows in with an `AnimatedSize`.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.txn,
    this.runningBalance,
    this.perspectiveAccountId,
    this.showDescription = false,
    this.searchQuery,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Txn txn;

  /// Account Detail shows the balance after each entry — the only path on which
  /// this row renders a balance at all. Null on the main Ledger tab, where a
  /// running balance is never legible (balance spec §1).
  final double? runningBalance;

  /// Which side of the entry we are looking from — decides the sign shown and
  /// drops the (already-stated) account from line 2.
  final String? perspectiveAccountId;

  /// Whether the global descriptions toggle is on (spec §4.4). A noted row gains
  /// its third line; noteless rows are unaffected.
  final bool showDescription;

  /// The active search query, already folded (spec §4.4). A row whose note
  /// matched reveals its description even with the toggle off, and matched text
  /// is highlighted on every line.
  final String? searchQuery;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  // Denser geometry (spec §4.1): a 26pt tile (was 30), a 9pt gap to the text
  // column, 5pt vertical padding. The text column's left edge — and any line
  // indented to it — sits at _iconSize + _iconGap.
  static const double _iconSize = 26;
  static const double _iconRadius = 7;
  static const double _iconGlyph = 13;
  static const double _iconGap = 9;
  static const double _vPad = 5;

  static const _titleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: AppColors.textPrimary,
  );
  static const _accountStyle = TextStyle(
    fontSize: 10.5,
    height: 1.15,
    color: AppColors.textTertiary,
  );
  // The tag now rides the title line, in tagDot at the meta size — the same
  // colour the scoped LedgerTxnRow uses, so a tag reads identically on both
  // screens (it was previously accentLight here, which was half the drift).
  static const _tagStyle = TextStyle(
    fontSize: 10.5,
    height: 1.15,
    color: AppColors.tagDot,
  );
  static const _balanceStyle = TextStyle(
    fontSize: 10.5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _descStyle = TextStyle(
    fontSize: 10.5,
    height: 1.15,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    if (txn.type == TxnType.transfer) {
      return perspectiveAccountId != null
          ? _swipeWrap(l, _buildTransferDetail(context, l, store))
          : _swipeWrap(l, _buildTransferLedger(context, l, store));
    }
    return _swipeWrap(l, _buildStandard(context, l, store));
  }

  /// The affected account's after-balance for this row — supplied only by the
  /// perspective callers (a single account's tape). Null on the main Ledger tab,
  /// where no running balance renders (balance spec §1).
  double? get _balance => runningBalance;

  // ── Standard rows: expense / income / rebalance ────────────────────────────

  Widget _buildStandard(
      BuildContext context, AppLocalizations l, AppStore store) {
    final signed = _signedAmount(store);
    final amountColor = txn.type == TxnType.rebalance
        ? (txn.amount >= 0 ? AppColors.positive : AppColors.negative)
        : (signed >= 0 ? AppColors.positive : AppColors.negative);

    final forceDecimals = signed.abs() % 1 != 0;
    final amount = AmountText(
      signed,
      currency: txn.currency,
      signless: true,
      color: amountColor,
      forceDecimals: forceDecimals,
    );
    final amountStr = money(signed,
        currency: txn.currency,
        signless: true,
        forceDecimals: forceDecimals,
        masked: store.masked);

    final title = _title(l, store);
    final account = _accountLabel(l, store);
    final balance = _balance;

    // One secondary figure on line 2 (spec §4.3): a rebalance's "no cash · value"
    // caption, otherwise the remaining balance.
    final Widget? secondary = txn.type == TxnType.rebalance
        ? _noCashValue(l, store, balance)
        : (balance != null ? _balanceWidget(store, balance) : null);

    // The tag left line 2 for the title line; the meta line is now account +
    // secondary only. Under a perspective (account implied) a tagged, noteless
    // row is two lines, not three.
    final hasLine2 = account.isNotEmpty || secondary != null;

    final scaler = MediaQuery.textScalerOf(context);

    return Semantics(
      label: _standardSemantics(l, store, signed, account, balance),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(_icon(store),
                  color: _color(store),
                  size: _iconSize,
                  iconSize: _iconGlyph),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TitleTagRow(
                      title: _highlighted(title, _titleStyle),
                      titleWidth:
                          TitleTagRow.measure(title, _titleStyle, scaler),
                      tags: txn.tags,
                      tagStyle: _tagStyle,
                      buildTag: (run) => _highlighted(run, _tagStyle),
                      trailing: amount,
                      trailingWidth: TitleTagRow.measure(
                          amountStr, AppText.amount, scaler),
                    ),
                    if (hasLine2) ...[
                      const SizedBox(height: 1),
                      _MetaLine(
                        account: account,
                        secondary: secondary,
                        query: searchQuery,
                        accountStyle: _accountStyle,
                      ),
                    ],
                    _descriptionLine(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Transfers: main Ledger (spec §4.6) ─────────────────────────────────────

  Widget _buildTransferLedger(
      BuildContext context, AppLocalizations l, AppStore store) {
    final parties = store.transferParties(txn);
    final fromCur = store.accountById(txn.fromRef)?.currency ?? txn.currency;
    final toCur = store.accountById(txn.toRef)?.currency ?? txn.currency;
    final crossCurrency =
        fromCur != toCur || (txn.toAmount != null && txn.toAmount != txn.amount);
    final balance = _balance;

    // Line 1: the source account name + the sent amount, both neutral. The
    // sent amount is denominated in the transaction's own currency.
    final amountStr = money(txn.amount,
        currency: txn.currency, signless: true, masked: store.masked);
    final amount = Text(
      amountStr,
      style: AppText.amount.copyWith(color: AppColors.transferAmount),
    );

    // Line-2 secondary, by priority (spec §4.3): a differing destination amount,
    // then a fee, then the destination's after-balance.
    final Widget? secondary;
    if (crossCurrency) {
      secondary = Text(
        money(txn.toAmount ?? txn.amount,
            currency: toCur, signless: true, masked: store.masked),
        style: _balanceStyle.copyWith(color: AppColors.transfer),
      );
    } else if (txn.fee != null && txn.fee! > 0) {
      secondary = Text(
        'fee ${money(txn.fee!, currency: fromCur, masked: store.masked)}',
        style: _balanceStyle.copyWith(color: AppColors.textTertiary),
      );
    } else if (balance != null) {
      secondary = _balanceWidget(store, balance);
    } else {
      secondary = null;
    }

    final titleStyle = _titleStyle.copyWith(color: AppColors.transferAmount);
    final scaler = MediaQuery.textScalerOf(context);

    return Semantics(
      label: _transferSemantics(l, store, parties, balance),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _transferTile(Icons.swap_horiz_rounded),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: source account + the tag (title line) + sent amount.
                TitleTagRow(
                  title: Text(parties.from,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  titleWidth:
                      TitleTagRow.measure(parties.from, titleStyle, scaler),
                  tags: txn.tags,
                  tagStyle: _tagStyle,
                  buildTag: (run) => _highlighted(run, _tagStyle),
                  trailing: amount,
                  trailingWidth:
                      TitleTagRow.measure(amountStr, AppText.amount, scaler),
                ),
                const SizedBox(height: 1),
                // ↘ destination + secondary. The destination takes the
                // account's protected role in the overflow order (spec §4.6).
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.south_east_rounded,
                          size: 10, color: AppColors.transfer),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetaLine(
                        account: parties.to,
                        secondary: secondary,
                        query: searchQuery,
                        accountStyle:
                            _accountStyle.copyWith(color: AppColors.transfer),
                      ),
                    ),
                  ],
                ),
                // The description aligns under the destination name, not the ↘.
                _descriptionLine(indent: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Transfers: account-detail perspective (preserved) ──────────────────────

  Widget _buildTransferDetail(
      BuildContext context, AppLocalizations l, AppStore store) {
    final parties = store.transferParties(txn);
    final outgoing = txn.fromRef == perspectiveAccountId;
    final toCur = store.accountById(txn.toRef)?.currency ?? txn.currency;

    final glyph =
        outgoing ? Icons.north_east_rounded : Icons.south_west_rounded;
    final other = outgoing ? '→ ${parties.to}' : '← ${parties.from}';

    final double topValue =
        outgoing ? txn.amount : (txn.toAmount ?? txn.amount);
    // The sent leg is in the transaction's currency; the received leg is in the
    // destination account's currency.
    final String topCurrency = outgoing ? txn.currency : toCur;
    final amountStr =
        money(topValue, currency: topCurrency, signless: true, masked: store.masked);
    final amountTop = Text(
      amountStr,
      style: AppText.amount.copyWith(color: AppColors.transferAmount),
    );

    final note = txn.note.trim();
    final balance = _balance;
    final Widget? line2Left = note.isEmpty
        ? null
        : Text(note,
            style: _descStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    final Widget? line2Right =
        balance == null ? null : _balanceWidget(store, balance);
    final hasLine2 = line2Left != null || line2Right != null;

    final scaler = MediaQuery.textScalerOf(context);

    return Semantics(
      label: _transferSemantics(l, store, parties, balance),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _transferTile(glyph),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TitleTagRow(
                  title: Text(other,
                      style: _titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  titleWidth: TitleTagRow.measure(other, _titleStyle, scaler),
                  tags: txn.tags,
                  tagStyle: _tagStyle,
                  buildTag: (run) => _highlighted(run, _tagStyle),
                  trailing: amountTop,
                  trailingWidth:
                      TitleTagRow.measure(amountStr, AppText.amount, scaler),
                ),
                if (hasLine2) ...[
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Expanded(child: line2Left ?? const SizedBox.shrink()),
                      if (line2Right != null) ...[
                        const SizedBox(width: Insets.sm),
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
    );
  }

  Widget _transferTile(IconData glyph) => Container(
        width: _iconSize,
        height: _iconSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.transferTileBg,
          borderRadius: BorderRadius.circular(_iconRadius),
        ),
        child: Icon(glyph, size: _iconGlyph, color: AppColors.transferGlyph),
      );

  // ── The third line (description) ───────────────────────────────────────────

  /// The description line, behind the toggle. Grows/shrinks with an
  /// `AnimatedSize` so the list never jumps (spec §4.4). Absent entirely for a
  /// noteless row; forced open (with the match highlighted) when a search hit
  /// the note even with the toggle off.
  Widget _descriptionLine({double indent = 0}) {
    final note = txn.note.trim();
    final q = searchQuery;
    final noteMatched =
        q != null && q.isNotEmpty && foldSearch(note).contains(q);
    final open = note.isNotEmpty && (showDescription || noteMatched);

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: open
          ? Padding(
              padding: EdgeInsets.only(top: 1, left: indent),
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 180),
                child: _highlighted(note, _descStyle),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  // ── Secondary figures ──────────────────────────────────────────────────────

  /// The remaining balance (spec §4.5): tertiary when non-negative, and — the
  /// balance-like exception — red with its minus sign when below zero.
  Widget _balanceWidget(AppStore store, double value) => AmountText(
        value,
        style: _balanceStyle,
        color: value < 0 ? AppColors.negative : AppColors.textTertiary,
      );

  /// A rebalance carries no cash; its secondary is the caption plus the asset's
  /// new value as one muted run (spec §4.3).
  Widget _noCashValue(AppLocalizations l, AppStore store, double? value) {
    final tail = value == null ? '' : ' · ${money(value, masked: store.masked)}';
    return Text('${l.ldgNoCash.toLowerCase()}$tail',
        style: _balanceStyle.copyWith(color: AppColors.textTertiary));
  }

  // ── Semantics ──────────────────────────────────────────────────────────────

  String _standardSemantics(AppLocalizations l, AppStore store, double signed,
      String account, double? balance) {
    final parts = <String>[
      _directionWord(l, signed),
      money(signed, currency: txn.currency, signless: true, masked: store.masked),
      // Every tag is named — the `+N` collapse is a visual truncation only, and
      // the announcement does not change with the perspective.
      if (txn.tags.isNotEmpty) tagSemanticsLabel(txn.tags),
    ];
    if (balance != null) {
      final where = account.isNotEmpty ? '$account ' : '';
      parts.add(
          '$where${l.a11yBalanceWord} ${money(balance, currency: txn.currency, masked: store.masked)}');
    }
    return parts.join(', ');
  }

  String _transferSemantics(AppLocalizations l, AppStore store,
      ({String from, String to}) parties, double? balance) {
    final parts = <String>[
      l.transferFromTo(parties.from, parties.to),
      money(txn.amount, currency: txn.currency, signless: true, masked: store.masked),
      if (txn.tags.isNotEmpty) tagSemanticsLabel(txn.tags),
      if (balance != null)
        l.a11yAccountBalance(
            parties.to, money(balance, currency: txn.currency, masked: store.masked)),
    ];
    return parts.join(', ');
  }

  // ── Resolvers (unchanged semantics) ────────────────────────────────────────

  String _accountLabel(AppLocalizations l, AppStore store) {
    if (perspectiveAccountId != null) return '';
    return switch (txn.type) {
      TxnType.expense => store.refName(txn.fromRef),
      TxnType.income => store.refName(txn.toRef),
      TxnType.transfer => '',
      TxnType.rebalance => l.txnRevaluation,
    };
  }

  String _directionWord(AppLocalizations l, double signed) => switch (txn.type) {
        TxnType.expense => l.txnTypeExpense,
        TxnType.income => l.txnTypeIncome,
        TxnType.rebalance => l.txnRevaluation,
        TxnType.transfer => signed < 0 ? l.txnTransferOut : l.txnTransferIn,
      };

  double _signedAmount(AppStore store) {
    if (perspectiveAccountId != null) {
      if (txn.toRef == perspectiveAccountId && txn.type != TxnType.expense) {
        return txn.toAmount ?? txn.amount;
      }
      return -txn.amount;
    }
    return switch (txn.type) {
      TxnType.expense => -txn.amount,
      TxnType.income => txn.amount,
      TxnType.rebalance => txn.amount,
      TxnType.transfer => txn.amount,
    };
  }

  String _title(AppLocalizations l, AppStore store) => switch (txn.type) {
        TxnType.expense => store.refName(txn.toRef),
        TxnType.income => store.refName(txn.fromRef),
        TxnType.transfer => l.txnTypeTransfer,
        TxnType.rebalance => store.refName(txn.toRef),
      };

  IconData _icon(AppStore store) => switch (txn.type) {
        TxnType.expense => store.refIcon(txn.toRef),
        TxnType.income => store.refIcon(txn.fromRef),
        TxnType.transfer => Icons.swap_horiz_rounded,
        TxnType.rebalance => Icons.donut_large_rounded,
      };

  Color _color(AppStore store) => switch (txn.type) {
        TxnType.expense => store.refColor(txn.toRef),
        TxnType.income => store.refColor(txn.fromRef),
        TxnType.transfer => AppColors.transfer,
        TxnType.rebalance => AppColors.rebalance,
      };

  // ── Search highlight (replicated for the main Ledger's rows) ───────────────

  /// [text] in [style], with each occurrence of the folded [searchQuery]
  /// background-highlighted. Falls back to a plain ellipsizing [Text] when there
  /// is no query or no match, so a row outside search mode is unchanged.
  Widget _highlighted(String text, TextStyle style) {
    final query = searchQuery;
    if (query == null || query.isEmpty) {
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final folded = foldSearch(text);
    var at = folded.indexOf(query);
    if (at < 0) {
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Chrome: swipe actions + tap target ─────────────────────────────────────

  Widget _swipeWrap(AppLocalizations l, Widget body) {
    return SwipeActions(
      actions: [
        SwipeActionItem(
          icon: Icons.edit_rounded,
          label: l.actionEdit,
          color: AppColors.surfaceHigh,
          onTap: onEdit,
        ),
        SwipeActionItem(
          icon: Icons.copy_rounded,
          label: l.actionCopy,
          color: AppColors.info,
          onTap: onCopy,
        ),
        SwipeActionItem(
          icon: Icons.delete_rounded,
          label: l.actionDelete,
          color: AppColors.negative,
          onTap: onDelete,
        ),
      ],
      child: InkWell(
        // When another row's swipe strip is open, the first tap only dismisses
        // it — it never navigates out from under the user (spec §1). Shares the
        // scoped ledger's helpers, not a second mechanism.
        onTap: () {
          if (anySwipeRowOpen) {
            closeOpenSwipeRow();
            return;
          }
          onTap();
        },
        // Both a tap and a swipe target: never smaller than 44pt. No fixed
        // height beyond that floor — everything else is padding + intrinsic
        // content, so rows grow at large text scales rather than clipping.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: _vPad,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Line 2 — `account ——— secondary`. The tag has moved to the title line, so
/// the meta line now carries only the account (highlighted, ellipsizing) and
/// the one secondary figure, which is laid out at intrinsic width on the right
/// and never moves (spec §4.3).
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.account,
    required this.secondary,
    required this.query,
    required this.accountStyle,
  });

  final String account;
  final Widget? secondary;
  final String? query;
  final TextStyle accountStyle;

  Widget _text(String text, TextStyle style) {
    final q = query;
    if (q == null || q.isEmpty || !foldSearch(text).contains(q)) {
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final folded = foldSearch(text);
    final mark = TextStyle(
      color: Colors.white,
      backgroundColor: AppColors.accent.withValues(alpha: 0.3),
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    var at = folded.indexOf(q);
    while (at >= 0) {
      if (at > cursor) spans.add(TextSpan(text: text.substring(cursor, at)));
      final end = at + q.length;
      spans.add(TextSpan(text: text.substring(at, end), style: mark));
      cursor = end;
      at = folded.indexOf(q, cursor);
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: style, children: spans),
        maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _text(account, accountStyle)),
        if (secondary != null) ...[
          const SizedBox(width: Insets.sm),
          secondary!,
        ],
      ],
    );
  }
}

/// Spec 2.4 — delete confirmation stating the balances each side returns to.
Future<bool> confirmDeleteTxn(BuildContext context, Txn txn) async {
  final store = StoreScope.read(context);
  final impact = <ImpactLine>[];

  for (final ref in {txn.fromRef, txn.toRef}) {
    final account = store.accountById(ref);
    if (account == null) continue;
    final before = store.balanceOf(account.id);
    final after = store.balanceWithout(account.id, txn);
    if (before == after) continue;
    impact.add(ImpactLine.lost(
      '${account.name} ${money(before, currency: account.currency)} '
      '→ ${money(after, currency: account.currency)}',
    ));
  }

  for (final ref in {txn.fromRef, txn.toRef}) {
    final category = store.categoryById(ref);
    if (category == null || category.monthlyBudget == null) continue;
    final month = DateTime(txn.date.year, txn.date.month);
    final before = store.spentInCategory(category.id, month);
    final after = store.categorySpendWithout(category.id, txn);
    if (before == after) continue;
    impact.add(ImpactLine.lost(AppLocalizations.of(context)
        .txnBudgetImpact(category.name, money(before), money(after))));
  }

  final l = AppLocalizations.of(context);
  impact.add(ImpactLine.kept(l.txnDeleteNothingElse));

  return showDestructiveConfirm(
    context,
    title: l.txnDeleteEntryTitle(txn.type.label(l).toLowerCase()),
    message: l.txnDeleteEntryMessage,
    impact: impact,
    confirmLabel: l.txnDeleteEntryConfirm,
  );
}
