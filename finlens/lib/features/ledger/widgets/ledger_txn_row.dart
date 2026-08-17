import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/models/models.dart';
import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/swipe_actions.dart';
import '../../../shared/widgets/transfer_title.dart';
import '../../../theme/app_colors.dart';
import '../ledger_scope.dart';

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
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.isFirstCard = false,
  });

  final bool isFirstCard;
  final DayGroup group;
  final LedgerScope scope;
  final ValueChanged<Txn> onEdit;
  final ValueChanged<Txn> onCopy;
  final ValueChanged<Txn> onDelete;

  @override
  Widget build(BuildContext context) {
    // Internal transfers net to zero by definition, so they are left out of
    // the day net exactly as they are left out of In and Out.
    final net = group.total;
    final rows = group.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateGroupLabel(group.date).toUpperCase(),
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
                label: '${net < 0 ? 'Net out' : 'Net in'}, '
                    '${money(net, signless: true, masked: StoreScope.of(context).masked)}',
                excludeSemantics: true,
                child: Text(
                money(net, signless: true,
                    masked: StoreScope.of(context).masked),
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
                  onEdit: () => onEdit(rows[i].txn),
                  onCopy: () => onCopy(rows[i].txn),
                  onDelete: () => onDelete(rows[i].txn),
                  hint: isFirstCard && i == 0,
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
/// Tapping does nothing: the row already shows everything the old expansion
/// disclosed, so there is nothing left to reveal — and a row that lights up
/// under a finger but does nothing is worse than one that never responds,
/// which is why there is no press highlight either.
class LedgerTxnRow extends StatelessWidget {
  const LedgerTxnRow({
    super.key,
    required this.row,
    required this.scope,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.hint = false,
  });

  final bool hint;
  final ScopedTxn row;
  final LedgerScope scope;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final txn = row.txn;
    final category = _categoryLabel(store, txn);
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
    final accountName = (scope is! AccountScope && !isTransfer)
        ? (store
                .accountById(txn.type == TxnType.income ? txn.toRef : txn.fromRef)
                ?.name ??
            '')
        : '';
    final tag = txn.tags.isEmpty ? null : txn.tags.first;
    final hasMeta = accountName.isNotEmpty || tag != null;

    final money0 = money(row.signedAmount, signless: true, masked: store.masked);
    final balance0 = money(_runningBalance(store, txn), masked: store.masked);
    // Parts in reading order — title, amount, direction, description, balance,
    // account, tag — not one merged string (spec §5).
    final semanticsLabel = [
      isTransfer ? 'Transfer from ${parties!.from} to ${parties.to}' : category,
      money0,
      if (!isTransfer)
        switch (row.kind) {
          FlowKind.inflow => 'income',
          FlowKind.outflow => 'expense',
          FlowKind.internal => 'internal transfer',
        },
      if (hasNote) note,
      'balance $balance0',
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
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
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
        const CustomSemanticsAction(label: 'Edit'): onEdit,
        const CustomSemanticsAction(label: 'Copy'): onCopy,
        const CustomSemanticsAction(label: 'Delete'): onDelete,
      },
      label: semanticsLabel,
      child: SwipeActions(
        actionWidth: 72,
        hintOnFirstBuild: hint,
        actions: [
          SwipeActionItem(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: const Color(0xFF2C2C2E),
            onTap: onEdit,
          ),
          SwipeActionItem(
            icon: Icons.copy_rounded,
            label: 'Copy',
            color: const Color(0xFF0A84FF),
            onTap: onCopy,
          ),
          SwipeActionItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFFF453A),
            onTap: onDelete,
          ),
        ],
        child: ColoredBox(
          color: AppColors.fieldCard,
          // No fixed height: a 44pt floor (tap + swipe target), everything else
          // intrinsic from padding + content, so rows grow at large text scale.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                              // Line 1: title | amount. With no description the
                              // balance sits beside the amount here instead of
                              // on its own second line.
                              Row(
                                children: [
                                  Expanded(child: titleWidget),
                                  const SizedBox(width: 10),
                                  if (hasNote)
                                    amountWidget
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        amountWidget,
                                        const SizedBox(width: 6),
                                        balanceWidget,
                                      ],
                                    ),
                                ],
                              ),
                              if (hasNote) ...[
                                const SizedBox(height: 2),
                                // Line 2: description | balance.
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: descStyle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    balanceWidget,
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
                                child: Text(
                                  accountName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaStyle,
                                ),
                              ),
                            if (accountName.isNotEmpty && tag != null)
                              const Text('  ·  ', style: metaStyle),
                            // The tag is laid out first (fixed), so the account
                            // ellipsizes to make room rather than the tag.
                            if (tag != null)
                              Text(
                                tag,
                                style: metaStyle.copyWith(
                                    color: AppColors.tagDot),
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

  String _categoryLabel(AppStore store, Txn txn) => switch (txn.type) {
        TxnType.expense => store.refName(txn.toRef),
        TxnType.income => store.refName(txn.fromRef),
        TxnType.transfer => scope is AccountScope
            ? 'Transfer ${row.counterpartyLine ?? ''}'.trim()
            : 'Transfer',
        TxnType.rebalance => 'Revaluation',
      };

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
        child: const Text(
          'NO CASH',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05 * 9.5,
            height: 1.2,
            color: AppColors.formDim2,
          ),
        ),
      );
}
