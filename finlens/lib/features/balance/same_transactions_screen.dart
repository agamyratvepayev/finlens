import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/swipe_actions.dart';
import '../../shared/widgets/txn_row.dart' show confirmDeleteTxn;
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';
import 'same_transactions.dart';
import 'widgets/same_range_sheet.dart';

/// Read-only list of every transaction sharing the tapped transaction's key
/// (spec §2/§3). Reached by tapping a row; a tap never opens the editor.
class SameTransactionsScreen extends StatefulWidget {
  const SameTransactionsScreen({
    super.key,
    required this.originTxnId,
    this.backLabel,
    this.showAll = false,
  });

  /// Kept as an id, not a [Txn], so every rebuild re-resolves against live data:
  /// an edit that changes the key rebuilds for the new key, a delete pops.
  final String originTxnId;

  /// Label for the `‹` back affordance — the screen the user came from.
  final String? backLabel;

  /// The `See all` view: the full list rather than the 5 most recent.
  final bool showAll;

  @override
  State<SameTransactionsScreen> createState() => _SameTransactionsScreenState();
}

class _SameTransactionsScreenState extends State<SameTransactionsScreen> {
  bool _rangeSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final origin = store.txnById(widget.originTxnId);

    // The subject was deleted (via ••• or a swipe on its own row): never leave
    // the screen showing a key with no subject — pop back where we came from.
    if (origin == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final key = SameKey.of(origin);
    final info = _KeyInfo.resolve(store, origin, key);
    final range = store.sameListRange.resolve(AppStore.today);
    final all = store.sameTransactions(key, from: range.start, to: range.end);
    final stats = SameStats.of(all, AppStore.today);
    final shown = widget.showAll ? all : all.take(5).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _navBar(context, store, origin),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _header(info),
                  _summaryCard(context, store, key, info, stats),
                  _sectionLabel(store, info),
                  if (all.isEmpty)
                    _emptyMessage(info, range)
                  else
                    _listCard(context, store, origin, info, shown),
                  if (!widget.showAll && all.length > shown.length)
                    _seeAll(context, info, all.length),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────

  Widget _navBar(BuildContext context, AppStore store, Txn origin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, 0),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_left_rounded,
                        size: 20, color: AppColors.accentLight),
                    Flexible(
                      child: Text(
                        widget.backLabel ?? 'Back',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.accentLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded,
                  size: 22, color: AppColors.accentLight),
              onPressed: () => _showOriginMenu(context, store, origin),
            ),
          ],
        ),
      ),
    );
  }

  /// The ••• menu — Edit · Copy · Delete on the originating transaction. (The
  /// spec lists "Move" too, but this app has no move-transaction feature and
  /// its shared swipe menu is Edit/Copy/Delete; adding Move is out of scope.)
  Future<void> _showOriginMenu(
      BuildContext context, AppStore store, Txn origin) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
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
            const SizedBox(height: Insets.sm),
            _menuRow(sheetContext, Icons.edit_rounded, 'Edit',
                () => showQuickAdd(context, editing: origin)),
            _menuRow(sheetContext, Icons.copy_rounded, 'Copy',
                () => showQuickAdd(context, copyOf: origin)),
            _menuRow(
              sheetContext,
              Icons.delete_rounded,
              'Delete',
              () async {
                final ok = await confirmDeleteTxn(context, origin);
                if (ok && context.mounted) store.deleteTxn(origin);
              },
              danger: true,
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext sheetContext, IconData icon, String label,
      VoidCallback action,
      {bool danger = false}) {
    final color = danger ? AppColors.negative : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: AppText.body.copyWith(color: color)),
      onTap: () {
        Navigator.of(sheetContext).pop();
        action();
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(_KeyInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.gutter, Insets.md, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(info.color, 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, size: 20, color: info.color),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.42, // −0.02em @ 21pt
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _summaryCard(BuildContext context, AppStore store, SameKey key,
      _KeyInfo info, SameStats stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _rangeRow(context, store, key),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 9, 6, 0),
            child: Row(
              children: [
                _metric('TOTAL', money(stats.total, currency: info.currency)),
                _metric(
                    'AVERAGE', money(stats.average, currency: info.currency)),
                _metric('COUNT', '${stats.count}'),
              ],
            ),
          ),
          if (stats.perMonth != null) _frequencyLine(stats),
        ],
      ),
    );
  }

  Widget _rangeRow(BuildContext context, AppStore store, SameKey key) {
    final choice = store.sameListRange;
    final label = choice.isCustom
        ? choice.resolve(AppStore.today).label(AppStore.today)
        : choice.preset!.label;

    return InkWell(
      onTap: () async {
        setState(() => _rangeSheetOpen = true);
        final picked = await showSameRangeSheet(context, key: key, current: choice);
        if (mounted) setState(() => _rangeSheetOpen = false);
        if (picked != null && context.mounted) {
          store.setSameListRange(picked);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _rangeSheetOpen ? AppColors.tint(AppColors.accent, 0.16) : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.accentLight,
              ),
            ),
            const SizedBox(width: 3),
            const Text('▾',
                style: TextStyle(fontSize: 10, color: AppColors.accentLight)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String caps, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            caps,
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5, // 0.05em @ 10pt
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.amount.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _frequencyLine(SameStats stats) {
    final n = stats.perMonth!.round();
    final days = stats.lastDaysAgo ?? 0;
    final last = days == 0
        ? 'today'
        : (days == 1 ? '1 day ago' : '$days days ago');

    const base = TextStyle(
        fontSize: 11.5, height: 1.2, color: AppColors.textSecondary);
    const value = TextStyle(
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.freqValue);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 7, 14, 0),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Text.rich(
        TextSpan(children: [
          if (n == 0)
            const TextSpan(text: 'Less than once a month', style: base)
          else ...[
            const TextSpan(text: 'About ', style: base),
            TextSpan(text: '$n', style: value),
            const TextSpan(text: ' times a month', style: base),
          ],
          const TextSpan(text: ' · last one ', style: base),
          TextSpan(text: last, style: value),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(AppStore store, _KeyInfo info) {
    final choice = store.sameListRange;
    var text = 'ALL ${info.sectionLabel.toUpperCase()}';
    if (choice.isCustom) {
      text = '$text · '
          '${choice.resolve(AppStore.today).label(AppStore.today).toUpperCase()}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.66, // 0.06em @ 11pt
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── List ─────────────────────────────────────────────────────────────────

  Widget _listCard(BuildContext context, AppStore store, Txn origin,
      _KeyInfo info, List<Txn> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            _SameRow(
              txn: rows[i],
              info: info,
              isCurrent: rows[i].id == origin.id,
              onEdit: () => showQuickAdd(context, editing: rows[i]),
              onCopy: () => showQuickAdd(context, copyOf: rows[i]),
              onDelete: () async {
                final ok = await confirmDeleteTxn(context, rows[i]);
                if (ok && context.mounted) store.deleteTxn(rows[i]);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyMessage(_KeyInfo info, DateRange range) {
    final label = range.label(AppStore.today);
    final subject = info.isTransfer
        ? info.title
        : '${info.categoryName} on ${info.accountName}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 24, Insets.gutter, 24),
      child: Text(
        'No $subject between $label',
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _seeAll(BuildContext context, _KeyInfo info, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 0),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SameTransactionsScreen(
              originTxnId: widget.originTxnId,
              backLabel: info.title,
              showAll: true,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'See all $total  ›',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.accentLight,
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact, non-tappable list row: date · title · unsigned amount. No account
/// line (the account is fixed by the key) and no chevron (rows aren't tappable),
/// but the swipe menu stays.
class _SameRow extends StatelessWidget {
  const _SameRow({
    required this.txn,
    required this.info,
    required this.isCurrent,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Txn txn;
  final _KeyInfo info;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = txn.note.isNotEmpty ? txn.note : info.rowFallbackTitle;

    final content = Container(
      // The row the user came from: a soft accent wash and a solid left edge,
      // no text pill. The semantics label carries "current transaction" so a
      // screen-reader user gets the cue the highlight gives sighted users.
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.tint(AppColors.accent, 0.13) : null,
        border: isCurrent
            ? const Border(
                left: BorderSide(color: AppColors.accent, width: 2.5))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(isCurrent ? 12 - 2.5 : 12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              dayMonth(txn.date),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          AmountText(
            txn.amount,
            currency: info.currency,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            color: info.amountColor,
          ),
        ],
      ),
    );

    final semanticsLabel = [
      // Direction in words — colour is the only other cue for an unsigned row.
      info.directionWord,
      dayMonth(txn.date),
      title,
      money(txn.amount,
          currency: info.currency,
          signless: true,
          masked: StoreScope.of(context).masked),
      if (isCurrent) 'current transaction',
    ].join(', ');

    // SwipeActions stays outermost so its Edit/Copy/Delete affordances remain
    // reachable; the row content itself is labelled and its inner text excluded.
    // Rows carry no tap action — every row shares the screen's key, so a tap
    // could only reopen the same screen.
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
      child: Semantics(
        container: true,
        label: semanticsLabel,
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

/// Everything the screen needs to render a key: titles, icon/color, currency,
/// and the row amount color. Resolved once per build from the store.
class _KeyInfo {
  const _KeyInfo({
    required this.isTransfer,
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    required this.icon,
    required this.color,
    required this.currency,
    required this.amountColor,
    required this.directionWord,
    required this.rowFallbackTitle,
    required this.categoryName,
    required this.accountName,
  });

  final bool isTransfer;
  final String title;
  final String subtitle;
  final String sectionLabel;
  final IconData icon;
  final Color color;
  final String currency;
  final Color amountColor;

  /// Direction in words for the row amount's semantics — colour is otherwise
  /// the only cue now that amounts are unsigned.
  final String directionWord;
  final String rowFallbackTitle;
  final String categoryName;
  final String accountName;

  static _KeyInfo resolve(AppStore store, Txn origin, SameKey key) {
    if (key is TransferKey) {
      final from = store.accountById(key.fromAccountId);
      final to = store.accountById(key.toAccountId);
      final fromName = from?.name ?? store.refName(key.fromAccountId);
      final toName = to?.name ?? store.refName(key.toAccountId);
      final title = '$fromName → $toName';
      return _KeyInfo(
        isTransfer: true,
        title: title,
        subtitle: 'Transfer',
        sectionLabel: title,
        icon: Icons.swap_horiz_rounded,
        color: AppColors.transfer,
        // Source account's currency for a transfer key (spec §5).
        currency: from?.currency ?? Fx.baseCurrency,
        // The app's existing transfer colour — never red/green.
        amountColor: AppColors.transfer,
        directionWord: 'Transfer',
        rowFallbackTitle: 'Transfer',
        categoryName: title,
        accountName: fromName,
      );
    }

    final ledger = key as LedgerKey;
    final account = store.accountById(ledger.accountId);
    final accountName = account?.name ?? store.refName(ledger.accountId);
    final isRebalance = ledger.direction == TxnType.rebalance;
    final categoryName =
        isRebalance ? accountName : store.refName(ledger.categoryId);
    final directionWord = switch (ledger.direction) {
      TxnType.income => 'Income',
      TxnType.rebalance => 'Rebalance',
      _ => 'Expense',
    };
    final amountColor = switch (ledger.direction) {
      TxnType.income => AppColors.positive,
      TxnType.rebalance => AppColors.freqValue,
      _ => AppColors.negative,
    };

    return _KeyInfo(
      isTransfer: false,
      title: categoryName,
      subtitle: '$accountName · $directionWord',
      sectionLabel: '$categoryName · $accountName',
      icon: isRebalance
          ? Icons.donut_large_rounded
          : store.refIcon(ledger.categoryId),
      color: isRebalance
          ? AppColors.rebalance
          : store.refColor(ledger.categoryId),
      currency: account?.currency ?? Fx.baseCurrency,
      amountColor: amountColor,
      directionWord: directionWord,
      rowFallbackTitle: categoryName,
      categoryName: categoryName,
      accountName: accountName,
    );
  }
}
