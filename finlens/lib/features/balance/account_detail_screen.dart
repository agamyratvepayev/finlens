import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';
import 'balance_screen.dart' show EmptyState;
import 'edit_account_screen.dart';
import 'same_transactions_screen.dart';

/// Spec 1.4 — one account's summary, limit bar, history and quick actions.
class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final account = store.accountById(accountId);

    // The account can vanish underneath us if it is removed from Edit Account.
    if (account == null) {
      return const Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Account removed',
            message: 'This account is no longer available.',
          ),
        ),
      );
    }

    final balance = store.balanceOf(account.id);
    final entries = store.txnsForAccount(account.id);
    final isCard = account.group == AccountGroup.creditCards;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, account),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _summary(context, store, account, balance),
                  if (isCard && account.paymentDue != null)
                    _statementBanner(store, account),
                  _periodSummary(store, entries),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 56),
                      child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No transactions yet',
                        message:
                            'Entries involving this account will show up here.',
                      ),
                    )
                  else
                    ..._history(context, store, account, entries),
                ],
              ),
            ),
            _actions(context, account, isCard),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Account account) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            // Spec 1.4 — the ••• menu is the only way into Edit Account.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditAccountScreen(accountId: account.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    AppStore store,
    Account account,
    double balance,
  ) {
    final utilisation = store.utilisationOf(account.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                account.displayIcon,
                color: account.color,
                size: 40,
                solid: true,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: AppText.title.copyWith(fontSize: 18),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.group.label} · ${account.currency}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              AmountText(
                balance,
                currency: account.currency,
                style: AppText.hero.copyWith(fontSize: 24),
                color: account.isAsset ? null : AppColors.negative,
              ),
            ],
          ),
          if (utilisation != null) ...[
            const SizedBox(height: Insets.lg),
            // Credit-health thresholds, not budget thresholds: anything over
            // ~30% utilisation already reads as heavy, which is why the
            // mockup shows this bar amber well before it is half full.
            ProgressBar(
              value: utilisation,
              color: utilisation > 0.7
                  ? AppColors.negative
                  : (utilisation > 0.3 ? AppColors.warning : AppColors.positive),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${percent(utilisation, decimals: 0)} of '
                '${money(account.creditLimit!, currency: account.currency)}',
                style: AppText.caption.copyWith(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Spec 1.4 — the amber statement band is credit-card only.
  Widget _statementBanner(AppStore store, Account account) {
    final due = DateTime(
      AppStore.today.year,
      AppStore.today.month +
          (account.paymentDue! < AppStore.today.day ? 1 : 0),
      account.paymentDue!,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.lg,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.warning, 0.13),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.tint(AppColors.warning, 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 17,
            color: AppColors.warning,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              'Statement due ${dayMonth(due)}',
              style: AppText.body.copyWith(fontSize: 13.5),
            ),
          ),
          AmountText(
            store.balanceOf(account.id).abs(),
            currency: account.currency,
            style: AppText.amount.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _periodSummary(AppStore store, List<Txn> entries) {
    final cutoff = AppStore.today.subtract(const Duration(days: 30));
    final recent = entries.where((t) => t.date.isAfter(cutoff));
    var inflow = 0.0;
    var outflow = 0.0;
    for (final t in recent) {
      final effect = _effect(store, t);
      if (effect > 0) {
        inflow += effect;
      } else {
        outflow += -effect;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.sm,
      ),
      child: Row(
        children: [
          Text(
            'Last 30 days',
            style: AppText.body.copyWith(fontSize: 13.5),
          ),
          const Spacer(),
          Text('In ', style: AppText.caption.copyWith(fontSize: 11.5)),
          AmountText(
            inflow,
            style: AppText.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.positive,
            ),
          ),
          const SizedBox(width: Insets.md),
          Text('Out ', style: AppText.caption.copyWith(fontSize: 11.5)),
          AmountText(
            outflow,
            style: AppText.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.negative,
            ),
          ),
        ],
      ),
    );
  }

  /// Signed effect of [t] on this account — positive is money in.
  double _effect(AppStore store, Txn t) =>
      store.balanceOf(accountId) - store.balanceWithout(accountId, t);

  /// Date-grouped history sharing the Ledger's swipe pattern (spec 1.4 / 2.2).
  List<Widget> _history(
    BuildContext context,
    AppStore store,
    Account account,
    List<Txn> entries,
  ) {
    final groups = <String, List<Txn>>{};
    for (final t in entries) {
      groups.putIfAbsent(dateGroupLabel(t.date).toUpperCase(), () => []).add(t);
    }

    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.lg,
            Insets.gutter,
            Insets.sm,
          ),
          child: Text(entry.key, style: AppText.label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  TxnRow(
                    txn: entry.value[i],
                    perspectiveAccountId: account.id,
                    runningBalance:
                        store.runningBalanceAt(account.id, entry.value[i]),
                    // A tap opens the read-only Same-transactions screen — it
                    // must never open the editor and risk a stray-tap edit.
                    // Editing stays behind the swipe menu and the new screen's
                    // ••• menu.
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SameTransactionsScreen(
                          originTxnId: entry.value[i].id,
                          backLabel: account.name,
                        ),
                      ),
                    ),
                    onEdit: () => showQuickAdd(context, editing: entry.value[i]),
                    onCopy: () => showQuickAdd(context, copyOf: entry.value[i]),
                    onDelete: () async {
                      final ok = await confirmDeleteTxn(context, entry.value[i]);
                      if (ok && context.mounted) {
                        store.deleteTxn(entry.value[i]);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
  }

  /// Spec 1.4 — both actions pre-fill one side so the user skips a step.
  Widget _actions(BuildContext context, Account account, bool isCard) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          if (account.isLiability) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => showQuickAdd(
                  context,
                  type: QuickAddType.transfer,
                  // FROM stays empty; TO is pinned to this account.
                  fixedToAccountId: account.id,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.surfaceHigh),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  textStyle: AppText.button,
                ),
                child: Text(isCard ? 'Pay card' : 'Make payment'),
              ),
            ),
            const SizedBox(width: Insets.md),
          ],
          Expanded(
            child: FilledButton(
              onPressed: () => showQuickAdd(
                context,
                fixedFromAccountId: account.id,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                textStyle: AppText.button,
              ),
              child: const Text('Add expense'),
            ),
          ),
        ],
      ),
    );
  }
}
