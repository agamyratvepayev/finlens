import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'amount_text.dart';
import 'app_card.dart';
import 'destructive_sheet.dart';
import 'swipe_actions.dart';
import 'transfer_title.dart';

/// One Ledger line. Shared by Ledger (2.1) and Account Detail (1.4), including
/// the swipe actions (2.2).
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.txn,
    this.runningBalance,
    this.perspectiveAccountId,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Txn txn;

  /// Account Detail shows the balance after each entry under the amount.
  final double? runningBalance;

  /// Which side of the entry we are looking from — decides the sign shown.
  final String? perspectiveAccountId;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  // Icon tile side and its gap to the text column. The meta line is indented by
  // their sum (44pt) so its left edge lines up with the text column above it —
  // it is not indented to the icon's left edge.
  static const double _iconSize = 34;
  static const double _iconGap = 10;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // A transfer is neither a gain nor a loss: it renders on its own two-line,
    // neutral-coloured layout (spec §2/§3), never as a category row. Every other
    // type keeps the standard rendering below, byte-for-byte unchanged.
    if (txn.type == TxnType.transfer) return _buildTransfer(context, store);
    final hasDescription = txn.note.isNotEmpty;
    final title = _titleWidget(store);
    final (primary, secondary) = _amountParts(store);
    final meta = _metaLine(store);

    return SwipeActions(
      actions: [
        SwipeActionItem(
          icon: Icons.edit_rounded,
          label: 'Edit',
          color: AppColors.surfaceHigh,
          onTap: onEdit,
        ),
        SwipeActionItem(
          icon: Icons.copy_rounded,
          label: 'Copy',
          color: AppColors.info,
          onTap: onCopy,
        ),
        SwipeActionItem(
          icon: Icons.delete_rounded,
          label: 'Delete',
          color: AppColors.negative,
          onTap: onDelete,
        ),
      ],
      child: InkWell(
        onTap: onTap,
        // Both a tap and a swipe target: never smaller than 44pt. No fixed
        // height beyond that floor — everything else is padding + intrinsic
        // content, so the row grows at large text scales rather than clipping.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: 9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Top block: icon tile + the two-line text/figure column.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconTile(_icon(store),
                        color: _color(store), size: _iconSize),
                    const SizedBox(width: _iconGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Line 1: title | amount. With no description the
                          // balance moves up beside the amount here.
                          Row(
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: Insets.sm),
                              if (hasDescription || secondary == null)
                                primary
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    primary,
                                    const SizedBox(width: 6),
                                    secondary,
                                  ],
                                ),
                            ],
                          ),
                          if (hasDescription) ...[
                            const SizedBox(height: 2),
                            // Line 2: description | balance.
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    txn.note,
                                    style: AppText.rowSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (secondary != null) ...[
                                  const SizedBox(width: Insets.sm),
                                  secondary,
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // ── Meta line: account · tags, full width, left edge aligned
                // with the text column above. Nothing sits to its right, so the
                // account name stops sharing the narrow amount-column width.
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: _iconSize + _iconGap),
                    child: meta,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A transfer's title is "{source} → {destination}" (both sides ellipsize
  /// together); every other type keeps its single-name title.
  Widget _titleWidget(AppStore store) {
    if (txn.type == TxnType.transfer) {
      return TransferTitleText(
        from: store.transferParties(txn).from,
        to: store.transferParties(txn).to,
        style: AppText.rowTitle,
      );
    }
    return Text(
      _title(store),
      style: AppText.rowTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The row's right column: (primary, secondary). Primary is the amount;
  /// secondary is the running balance, the "no cash" flag, or a transfer fee —
  /// null when there is nothing to show beneath the amount.
  (Widget, Widget?) _amountParts(AppStore store) {
    // Spec 2.1 — a transfer reads "FROM amount → TO amount"; the fee, when any,
    // is the secondary figure.
    if (txn.type == TxnType.transfer && perspectiveAccountId == null) {
      final primary = Semantics(
        label: 'Transfer from ${store.transferParties(txn).from} '
            'to ${store.transferParties(txn).to}, '
            '${money(txn.amount, currency: txn.currency, signless: true, masked: store.masked)}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              txn.amount,
              currency: txn.currency,
              style: AppText.amount.copyWith(color: AppColors.textSecondary),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.arrow_right_alt_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
            ),
            AmountText(
              txn.toAmount ?? txn.amount,
              currency: store.accountById(txn.toRef)?.currency ?? txn.currency,
              color: AppColors.info,
            ),
          ],
        ),
      );
      final Widget? secondary = (txn.fee != null && txn.fee! > 0)
          ? Text(
              'fee ${money(txn.fee!, currency: txn.currency)}',
              style: AppText.caption.copyWith(fontSize: 11),
            )
          : null;
      return (primary, secondary);
    }

    final signed = _signedAmount(store);
    final color = txn.type == TxnType.rebalance
        ? (txn.amount >= 0 ? AppColors.positive : AppColors.negative)
        : (signed >= 0 ? AppColors.positive : AppColors.negative);

    // Unsigned — colour carries direction (spec "Yön ≠ renk"). The sign would
    // be a second, redundant cue; for colour-blind and screen-reader users the
    // semantics label names the direction in words instead. One label per row.
    final primary = Semantics(
      label: txn.type == TxnType.transfer
          ? 'Transfer from ${store.transferParties(txn).from} '
              'to ${store.transferParties(txn).to}, '
              '${money(signed, currency: txn.currency, signless: true, masked: store.masked)}'
          : '${_directionWord(signed)}, '
              '${money(signed, currency: txn.currency, signless: true, masked: store.masked)}',
      excludeSemantics: true,
      child: AmountText(
        signed,
        currency: txn.currency,
        signless: true,
        color: color,
        forceDecimals: signed.abs() % 1 != 0,
      ),
    );

    final Widget? secondary = txn.type == TxnType.rebalance
        ? Text(
            'no cash',
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          )
        : (runningBalance != null
            ? AmountText(
                runningBalance!,
                style: AppText.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              )
            : null);

    return (primary, secondary);
  }

  /// The meta line — account name and tags — or null when the row carries
  /// neither. The account is dropped where the screen already states it (an
  /// account-detail perspective) and for transfers (whose title names both
  /// accounts). The tags sit last and stay fixed, so the account ellipsizes
  /// first when the two compete for width.
  Widget? _metaLine(AppStore store) {
    final account = _accountLabel(store);
    final tags = txn.tags.map((t) => '#$t').join(' · ');
    if (account.isEmpty && tags.isEmpty) return null;

    final style = AppText.caption.copyWith(
      fontSize: 11,
      color: AppColors.textTertiary,
    );
    return Row(
      children: [
        if (account.isNotEmpty)
          Flexible(
            child: Text(
              account,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (account.isNotEmpty && tags.isNotEmpty) Text(' · ', style: style),
        if (tags.isNotEmpty)
          Text(tags, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  String _accountLabel(AppStore store) {
    // An account-detail screen already states the account in its header, so
    // repeating it on every row is noise — drop it there.
    if (perspectiveAccountId != null) return '';
    return switch (txn.type) {
      TxnType.expense => store.refName(txn.fromRef),
      TxnType.income => store.refName(txn.toRef),
      // The "{from} → {to}" path lives in the title, so the meta line carries no
      // account for a transfer — only its tags, if any.
      TxnType.transfer => '',
      TxnType.rebalance => 'Revaluation',
    };
  }

  /// Direction in words for the amount's semantics label — the only carrier of
  /// direction left once the sign is gone. A transfer reads out/in by the side
  /// the running-balance perspective is looking from.
  String _directionWord(double signed) => switch (txn.type) {
        TxnType.expense => 'Expense',
        TxnType.income => 'Income',
        TxnType.rebalance => 'Revaluation',
        TxnType.transfer => signed < 0 ? 'Transfer out' : 'Transfer in',
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

  String _title(AppStore store) {
    return switch (txn.type) {
      TxnType.expense => store.refName(txn.toRef),
      TxnType.income => store.refName(txn.fromRef),
      TxnType.transfer => 'Transfer',
      TxnType.rebalance => store.refName(txn.toRef),
    };
  }

  IconData _icon(AppStore store) {
    return switch (txn.type) {
      TxnType.expense => store.refIcon(txn.toRef),
      TxnType.income => store.refIcon(txn.fromRef),
      TxnType.transfer => Icons.swap_horiz_rounded,
      TxnType.rebalance => Icons.donut_large_rounded,
    };
  }

  Color _color(AppStore store) {
    return switch (txn.type) {
      TxnType.expense => store.refColor(txn.toRef),
      TxnType.income => store.refColor(txn.fromRef),
      TxnType.transfer => AppColors.transfer,
      TxnType.rebalance => AppColors.rebalance,
    };
  }

  /// Spec §2/§3 — a transfer's own two-line, neutral-coloured row. In an
  /// all/group ledger both account lines show (source, then `→ destination`);
  /// on an account-detail perspective it collapses to the counterpart alone
  /// with a directional glyph and keeps the note. The tile and amount stay
  /// neutral throughout: colour carries good/bad, and a transfer is neither.
  Widget _buildTransfer(BuildContext context, AppStore store) {
    final parties = store.transferParties(txn);
    final onDetail = perspectiveAccountId != null;
    final outgoing = !onDetail || txn.fromRef == perspectiveAccountId;

    final fromCur = store.accountById(txn.fromRef)?.currency ?? txn.currency;
    final toCur = store.accountById(txn.toRef)?.currency ?? txn.currency;
    final crossCurrency = fromCur != toCur;

    // Line 1: the counterpart on an account detail, else the source account.
    final IconData glyph;
    final Widget line1Title;
    if (onDetail) {
      glyph = outgoing
          ? Icons.north_east_rounded
          : Icons.south_west_rounded;
      final other = outgoing ? '→ ${parties.to}' : '← ${parties.from}';
      line1Title = Text(other,
          style: AppText.rowTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    } else {
      glyph = Icons.swap_horiz_rounded;
      line1Title = Text(parties.from,
          style: AppText.rowTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }

    // Line-1 amount. On an account detail it is this account's own leg; in a
    // full ledger it is the sent amount in the source currency.
    final double topValue = onDetail
        ? (outgoing ? txn.amount : (txn.toAmount ?? txn.amount))
        : txn.amount;
    final String topCurrency = onDetail ? (outgoing ? fromCur : toCur) : fromCur;
    final amountTop = Text(
      money(topValue,
          currency: topCurrency, signless: true, masked: store.masked),
      style: AppText.amount.copyWith(color: AppColors.transferAmount),
    );

    // Line 2.
    Widget? line2Left;
    Widget? line2Right;
    if (onDetail) {
      // §3 — the note (when any) on the left, this account's running balance on
      // the right. The other side's figure belongs on the detail screen.
      final note = txn.note.trim();
      if (note.isNotEmpty) {
        line2Left = Text(note,
            style: AppText.rowSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis);
      }
      line2Right = runningBalance == null
          ? null
          : AmountText(runningBalance!,
              style: AppText.caption
                  .copyWith(fontSize: 11, color: AppColors.textTertiary));
    } else {
      // §2 — the destination on the left; the note is deliberately dropped to
      // hold the row at two lines and protect list density.
      line2Left = Text('→ ${parties.to}',
          style: AppText.rowTitle.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
      line2Right = crossCurrency
          // Cross-currency: the received amount, its own currency, matching the
          // top line's size and neutral colour. No running balance to show.
          ? Text(
              money(txn.toAmount ?? txn.amount,
                  currency: toCur, signless: true, masked: store.masked),
              style: AppText.amount.copyWith(color: AppColors.transferAmount),
            )
          : (runningBalance == null
              ? null
              : AmountText(runningBalance!,
                  style: AppText.caption.copyWith(
                      fontSize: 11, color: AppColors.textTertiary)));
    }

    final hasLine2 = line2Left != null || line2Right != null;

    final body = Semantics(
      label: 'Transfer from ${parties.from} to ${parties.to}, '
          '${money(txn.amount, currency: txn.currency, signless: true, masked: store.masked)}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.transferTileBg,
              borderRadius: BorderRadius.circular(_iconSize * 0.3),
            ),
            child: Icon(glyph, size: _iconSize * 0.5,
                color: AppColors.transferGlyph),
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: line1Title),
                    const SizedBox(width: Insets.sm),
                    amountTop,
                  ],
                ),
                if (hasLine2) ...[
                  const SizedBox(height: 2),
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

    return SwipeActions(
      actions: [
        SwipeActionItem(
          icon: Icons.edit_rounded,
          label: 'Edit',
          color: AppColors.surfaceHigh,
          onTap: onEdit,
        ),
        SwipeActionItem(
          icon: Icons.copy_rounded,
          label: 'Copy',
          color: AppColors.info,
          onTap: onCopy,
        ),
        SwipeActionItem(
          icon: Icons.delete_rounded,
          label: 'Delete',
          color: AppColors.negative,
          onTap: onDelete,
        ),
      ],
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: 9,
            ),
            child: body,
          ),
        ),
      ),
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
    impact.add(ImpactLine.lost(
      '${category.name} budget ${money(before)} → ${money(after)}',
    ));
  }

  impact.add(const ImpactLine.kept('Nothing else in your ledger changes.'));

  return showDestructiveConfirm(
    context,
    title: 'Delete this ${txn.type.label.toLowerCase()}?',
    message: 'This entry is removed for good and the balances below go back to '
        'what they were.',
    impact: impact,
    confirmLabel: 'Delete entry',
  );
}
