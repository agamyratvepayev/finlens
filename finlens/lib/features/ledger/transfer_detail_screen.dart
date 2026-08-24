import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/txn_row.dart' show confirmDeleteTxn;
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';

/// Read-only detail for a single transfer (spec §5). Reached by tapping a
/// transfer row; a tap never opens the editor, and — unlike an ordinary row —
/// never the category/description Same-transactions screen either, since a
/// transfer has no category key to resolve.
///
/// This is the one screen in the app where each leg carries a sign (`−`/`+`):
/// the two sides are being compared to each other, and the signs are what make
/// the pairing legible. Everywhere else a transfer amount stays unsigned.
class TransferDetailScreen extends StatelessWidget {
  const TransferDetailScreen({
    super.key,
    required this.txnId,
    this.backLabel,
  });

  /// Kept as an id, not a [Txn], so every rebuild re-resolves against live
  /// data: an edit rebuilds for the new figures, a delete pops the screen.
  final String txnId;

  /// Label for the `‹` back affordance — the screen the user came from.
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final txn = store.txnById(txnId);

    // Deleted from the ••• menu: never linger on a subject that no longer
    // exists — pop back where we came from.
    if (txn == null || txn.type != TxnType.transfer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final from = store.accountById(txn.fromRef);
    final to = store.accountById(txn.toRef);
    final fromCur = from?.currency ?? txn.currency;
    final toCur = to?.currency ?? txn.currency;
    final crossCurrency = fromCur != toCur;

    final sentAmount = txn.amount;
    final receivedAmount = txn.toAmount ?? txn.amount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _navBar(context, store, txn),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _hero(context, store, txn),
                  _accountsCard(
                    store,
                    txn,
                    from: from,
                    to: to,
                    fromCur: fromCur,
                    toCur: toCur,
                    sentAmount: sentAmount,
                    receivedAmount: receivedAmount,
                    crossCurrency: crossCurrency,
                  ),
                  _metaCard(store, txn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────

  Widget _navBar(BuildContext context, AppStore store, Txn txn) {
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
                        backLabel ?? 'Back',
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
              onPressed: () => _showMenu(context, store, txn),
            ),
          ],
        ),
      ),
    );
  }

  /// The ••• menu — Edit · Copy · Delete, the same three the swipe strip offers.
  /// No `Move`: a transfer has no category to move it into.
  Future<void> _showMenu(BuildContext context, AppStore store, Txn txn) async {
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
                () => showQuickAdd(context, editing: txn)),
            _menuRow(sheetContext, Icons.copy_rounded, 'Copy',
                () => showQuickAdd(context, copyOf: txn)),
            _menuRow(
              sheetContext,
              Icons.delete_rounded,
              'Delete',
              () async {
                final ok = await confirmDeleteTxn(context, txn);
                if (ok && context.mounted) store.deleteTxn(txn);
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

  // ── Hero ─────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, AppStore store, Txn txn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.lg, Insets.md, Insets.sm),
      child: Column(
        children: [
          // 44pt neutral tile with the exchange glyph — no "Transfer" label; the
          // glyph carries it.
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.transferTileBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                size: 22, color: AppColors.transferGlyph),
          ),
          const SizedBox(height: Insets.md),
          Text(
            money(txn.amount,
                currency: txn.currency, signless: true, masked: store.masked),
            style: const TextStyle(
              fontSize: 27,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dayMonthYear(txn.date, AppLocalizations.of(context)),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Accounts card ──────────────────────────────────────────────────────────

  Widget _accountsCard(
    AppStore store,
    Txn txn, {
    required Account? from,
    required Account? to,
    required String fromCur,
    required String toCur,
    required double sentAmount,
    required double receivedAmount,
    required bool crossCurrency,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _legRow(
              store,
              account: from,
              caps: 'FROM',
              // The source loses money: negative, here and only here.
              signedAmount: -sentAmount,
              currency: fromCur,
              balanceAfter: from == null
                  ? null
                  : store.runningBalanceAt(from.id, txn),
            ),
            const Divider(
                height: 1, thickness: 1, color: AppColors.divider),
            _legRow(
              store,
              account: to,
              caps: 'TO',
              signedAmount: receivedAmount,
              currency: toCur,
              balanceAfter:
                  to == null ? null : store.runningBalanceAt(to.id, txn),
            ),
            if (crossCurrency) ...[
              const Divider(
                  height: 1, thickness: 1, color: AppColors.divider),
              _rateRow(txn, fromCur, toCur, sentAmount, receivedAmount),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legRow(
    AppStore store, {
    required Account? account,
    required String caps,
    required double signedAmount,
    required String currency,
    required double? balanceAfter,
  }) {
    const capsStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.08 * 10.5,
      height: 1.2,
      color: AppColors.textTertiary,
    );
    const nameStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AppColors.textPrimary,
    );
    const afterStyle = TextStyle(
      fontSize: 11.5,
      height: 1.2,
      color: AppColors.textTertiary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: account?.color ?? AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(caps, style: capsStyle),
                const SizedBox(height: 2),
                Text(
                  account?.name ?? 'Deleted account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money(signedAmount,
                    currency: currency,
                    showSign: true,
                    masked: store.masked),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: signedAmount < 0
                      ? AppColors.amountChildNeg
                      : AppColors.positive,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (balanceAfter != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${money(balanceAfter, currency: currency, masked: store.masked)} after',
                  style: afterStyle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _rateRow(
      Txn txn, String fromCur, String toCur, double sent, double received) {
    // Prefer the two real leg figures over the stored rate: they are what the
    // balances were actually built from, so the printed rate can never disagree
    // with the amounts above it.
    final rate = (txn.exchangeRate != null && txn.exchangeRate! > 0)
        ? txn.exchangeRate!
        : (sent == 0 ? 0.0 : received / sent);
    final rateText = rate == 0
        ? '—'
        : '1 $fromCur = ${_trimRate(rate)} $toCur';
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.md),
      child: Row(
        children: [
          Text('Rate',
              style: AppText.body.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            rateText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _trimRate(double r) {
    // Up to four decimals, trailing zeros dropped, so 1.1000 reads "1.1".
    var s = r.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ── Meta card ──────────────────────────────────────────────────────────────

  Widget _metaCard(AppStore store, Txn txn) {
    final note = txn.note.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _metaRow('Note', note.isEmpty ? '—' : note),
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            // The one place the app states plainly why a transfer is coloured
            // differently from everything around it: it changed no net worth.
            _metaRow('Net worth', 'Unchanged'),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}
