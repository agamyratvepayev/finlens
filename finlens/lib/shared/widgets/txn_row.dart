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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: 11,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconTile(_icon(store), color: _color(store), size: 34),
              const SizedBox(width: Insets.md),
              Expanded(child: _titleBlock(store)),
              const SizedBox(width: Insets.sm),
              _amountBlock(store),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(AppStore store) {
    final subtitleParts = <String>[
      if (txn.note.isNotEmpty) txn.note,
    ];
    final metaParts = <String>[
      _contextLabel(store),
      ...txn.tags.map((t) => '#$t'),
    ].where((s) => s.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A transfer's title is "{source} → {destination}" (both sides
        // ellipsize together); every other type keeps its single-name title.
        if (txn.type == TxnType.transfer)
          TransferTitleText(
            from: store.transferParties(txn).from,
            to: store.transferParties(txn).to,
            style: AppText.rowTitle,
          )
        else
          Text(
            _title(store),
            style: AppText.rowTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitleParts.join(' · '),
            style: AppText.rowSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            metaParts.join(' · '),
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _amountBlock(AppStore store) {
    // Spec 2.1 — a transfer reads "FROM amount → TO amount"; a rebalance is
    // flagged "no cash" because it moves no money.
    if (txn.type == TxnType.transfer && perspectiveAccountId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
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
                  style:
                      AppText.amount.copyWith(color: AppColors.textSecondary),
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
                  currency:
                      store.accountById(txn.toRef)?.currency ?? txn.currency,
                  color: AppColors.info,
                ),
              ],
            ),
          ),
          if (txn.fee != null && txn.fee! > 0) ...[
            const SizedBox(height: 2),
            Text(
              'fee ${money(txn.fee!, currency: txn.currency)}',
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ],
        ],
      );
    }

    final signed = _signedAmount(store);
    final color = txn.type == TxnType.rebalance
        ? (txn.amount >= 0 ? AppColors.positive : AppColors.negative)
        : (signed >= 0 ? AppColors.positive : AppColors.negative);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Unsigned — colour carries direction (spec "Yön ≠ renk"). The sign
        // would be a second, redundant cue; for colour-blind and screen-reader
        // users the semantics label below names the direction in words instead.
        Semantics(
          // A transfer names both accounts; other types name their direction.
          // One label per row — no competing amount/row announcements.
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
        ),
        if (txn.type == TxnType.rebalance) ...[
          const SizedBox(height: 2),
          Text(
            'no cash',
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ] else if (runningBalance != null) ...[
          const SizedBox(height: 2),
          AmountText(
            runningBalance!,
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
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

  String _contextLabel(AppStore store) {
    return switch (txn.type) {
      TxnType.expense => store.refName(txn.fromRef),
      TxnType.income => store.refName(txn.toRef),
      // The "{from} → {to}" path now lives in the title, so it is dropped here
      // to avoid printing the same path twice on one row (the meta line keeps
      // only the tags).
      TxnType.transfer => '',
      TxnType.rebalance => 'Revaluation',
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
