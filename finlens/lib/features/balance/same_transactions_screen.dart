import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/swipe_actions.dart';
import '../../shared/widgets/txn_row.dart' show confirmDeleteTxn;
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/quick_add_sheet.dart';
import 'same_transactions.dart';
import 'widgets/same_range_sheet.dart';

/// The screen a transaction row opens. The tapped transaction comes first — a
/// read-only detail card (note · time · account+balance-after · tags) sits
/// directly under the header — followed by the range control (now the section
/// header), the range summary, and the list of every transaction sharing the
/// tapped one's key (spec §1/§2/§3). Reached by tapping a row; a tap never opens
/// the editor.
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
    final info = _KeyInfo.resolve(store, origin, key, AppLocalizations.of(context));
    final choice = store.sameListRange;
    final range = choice.resolve(AppStore.today);
    final all = store.sameTransactions(key, from: range.start, to: range.end);
    // The frequency rate divides by the selected window, except All time, whose
    // year-2000 start is artificial — there the transaction span stands in.
    final unbounded =
        !choice.isCustom && choice.preset == SameRangePreset.allTime;
    final stats =
        SameStats.of(all, AppStore.today, window: unbounded ? null : range);
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
                  // Specific → general: the tapped transaction, then the range
                  // that scopes everything below it, then the range's summary,
                  // then the list (spec §2/§3).
                  _header(info, origin),
                  ?_detailCard(context, store, origin),
                  _rangeHeader(context, store, key),
                  _summaryCard(stats),
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
            // Expanded (not Flexible) so the back control owns the whole run and
            // the ••• lands hard against the bar's right padding; a Spacer here
            // would split the slack 50/50 with the Flexible and float the ••• in.
            // Align(centerStart) keeps the control at the leading edge while
            // still passing a bounded width down, so a long backLabel ellipsises.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
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
                          widget.backLabel ??
                              AppLocalizations.of(context).actionBack,
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
            ),
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
            _menuRow(sheetContext, Icons.edit_rounded, AppLocalizations.of(context).actionEdit,
                () => showQuickAdd(context, editing: origin)),
            _menuRow(sheetContext, Icons.copy_rounded, AppLocalizations.of(context).actionCopy,
                () => showQuickAdd(context, copyOf: origin)),
            _menuRow(
              sheetContext,
              Icons.delete_rounded,
              AppLocalizations.of(context).actionDelete,
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

  Widget _header(_KeyInfo info, Txn origin) {
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
          const SizedBox(width: Insets.sm),
          // The origin's own amount, unsigned magnitude in its direction colour
          // (spec §1) — colour, not a sign, carries income/expense here as
          // everywhere. Masks with privacy.
          AmountText.balance(
            origin.amount,
            currency: origin.currency,
            color: info.amountColor,
            style: const TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.48, // −0.02em @ 24pt
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail card (the tapped transaction) ────────────────────────────────────

  /// The block the whole restructure exists for (spec §1): the one transaction
  /// the user tapped, sitting directly under the header and inside every scope
  /// below it. Four label/value rows — NOTE · WHEN · PAID WITH · TAGS — with no
  /// dividers (the 62pt caps label column does the separating) and no actions
  /// (the ••• menu stays the only place to act on the origin).
  ///
  /// A row is omitted when its field is empty; the card itself is omitted only
  /// if every row would be. WHEN is derived from [Txn.date] and so is always
  /// present, which is the point — the time of day is the one fact the list row
  /// cannot show.
  Widget? _detailCard(BuildContext context, AppStore store, Txn origin) {
    final l = AppLocalizations.of(context);
    final rows = <Widget>[];

    final note = origin.note.trim();
    if (note.isNotEmpty) {
      rows.add(_detailRow(l.stDetailNote, note));
    }

    // WHEN — day, month, year and the time, composed through the same
    // locale-aware separator the audit trail uses ("9 Aug 2026, 08:12").
    rows.add(_detailRow(
      l.stDetailWhen,
      l.dateWithTime(dayMonthYear(origin.date, l), hhmm(origin.date)),
    ));

    // PAID WITH — resolvable only when the key pins a single account: expense
    // pays from [Txn.fromRef], income lands in [Txn.toRef], a rebalance revalues
    // [Txn.toRef]. A transfer names both accounts in the header and routes to
    // TransferDetailScreen anyway, so it carries no PAID WITH row here.
    if (origin.type != TxnType.transfer) {
      final accountId =
          origin.type == TxnType.expense ? origin.fromRef : origin.toRef;
      final account = store.accountById(accountId);
      if (account != null) {
        rows.add(_detailRow(
          l.stDetailPaidWith,
          account.name,
          clampValue: true,
          // The balance the account stood at right after this transaction, in
          // the account's own currency (a €-wallet reads €). Masks with privacy.
          trailing: money(
            store.runningBalanceAt(account.id, origin),
            currency: account.currency,
            masked: store.masked,
          ),
        ));
      }
    }

    if (origin.tags.isNotEmpty) {
      rows.add(_detailRow(
        l.stDetailTags,
        origin.tags.map((t) => '#$t').join(' '),
        valueColor: AppColors.tagDot,
      ));
    }

    if (rows.isEmpty) return null;

    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// One `LABEL value` line of the detail card. The caps label is top-aligned so
  /// that when [value] wraps (a long note) the label stays against the first
  /// line. [clampValue] ellipsises the value on one line (a long account name),
  /// leaving [trailing] — the balance-after figure — its intrinsic width.
  Widget _detailRow(
    String label,
    String value, {
    String? trailing,
    Color? valueColor,
    bool clampValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              // Nudge the small caps down onto the value's first line rather
              // than floating at the very top of the taller value box.
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.57, // 0.06em @ 9.5pt
                  color: AppColors.detailLabel,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: clampValue ? 1 : null,
              overflow:
                  clampValue ? TextOverflow.ellipsis : TextOverflow.clip,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.3,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Insets.sm),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _summaryCard(SameStats stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            // One inline row of key·value pairs (~26pt), down from three stacked
            // key-over-value columns (~50pt) (spec §5). The range row that used
            // to head this card is now the section header above it (spec §2).
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            child: Row(
              children: [
                // TOTAL and AVG are base-currency aggregates (spec §3): a list
                // can span currencies, so their sum is folded through Fx.
                _metric('TOTAL', money(stats.total, currency: Fx.baseCurrency)),
                _metric('AVG', money(stats.average, currency: Fx.baseCurrency)),
                _metric('COUNT', '${stats.count}'),
              ],
            ),
          ),
          if (stats.perMonth != null)
            _frequencyLine(stats)
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Range header (the control) ──────────────────────────────────────────────

  /// The range control, promoted from the summary card's first row to the
  /// section header above it (spec §2). Accent text and a chevron mark it
  /// tappable where every other section header in the app is neutral grey; the
  /// whole ≥44pt row opens the existing range sheet, unchanged. It carries the
  /// selected range's own name — a preset's label or a custom range's dates —
  /// never the category, which the 21pt header two blocks up already states.
  Widget _rangeHeader(BuildContext context, AppStore store, SameKey key) {
    final choice = store.sameListRange;
    final l = AppLocalizations.of(context);
    final label = (choice.isCustom
            ? choice.resolve(AppStore.today).label(AppStore.today, l)
            : choice.preset!.label(l))
        .toUpperCase();

    return InkWell(
      onTap: () async {
        setState(() => _rangeSheetOpen = true);
        final picked =
            await showSameRangeSheet(context, key: key, current: choice);
        if (mounted) setState(() => _rangeSheetOpen = false);
        if (picked != null && context.mounted) {
          store.setSameListRange(picked);
        }
      },
      child: Container(
        // The ink is 10.5pt; the ≥44pt tap target comes from the minimum-height
        // constraint and padding, not the glyph (spec §2).
        constraints: const BoxConstraints(minHeight: 44),
        color: _rangeSheetOpen ? AppColors.tint(AppColors.accent, 0.10) : null,
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 6, Insets.gutter, 6),
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.63, // 0.06em @ 10.5pt
                  color: AppColors.accentLight,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Material rounded chevron; its visible glyph reads ~12pt (spec §2).
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.accentLight),
          ],
        ),
      ),
    );
  }

  /// One inline `KEY value` pair, centred in an equal-flex third of the band
  /// (spec §5). The caps key sits beside its value on the shared baseline rather
  /// than stacked above it, which takes the band from ~50pt to ~26pt.
  ///
  /// Built as one wrapping [Text.rich], not a fixed [Row]: at normal scale it is
  /// a single line, and at large text scale it wraps at the space between key
  /// and value — never mid-number and never clipping — so the band grows from
  /// its intrinsic height instead (spec §8, §9).
  Widget _metric(String caps, String value) {
    return Expanded(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: caps,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.475, // 0.05em @ 9.5pt
              color: AppColors.textSecondary,
            ),
          ),
          // A space, not a SizedBox: it is the wrap opportunity that lets the
          // value drop below the key cleanly at large text scale.
          const TextSpan(text: ' '),
          TextSpan(
            text: value,
            // AppText.amount is already 15pt / w600 / tabular / white.
            style: AppText.amount,
          ),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _frequencyLine(SameStats stats) {
    final l = AppLocalizations.of(context);
    final n = stats.perMonth!.round();
    final days = stats.lastDaysAgo ?? 0;
    final last = days == 0 ? l.dueToday : l.daysAgo(days);

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
            TextSpan(text: l.freqLessThanMonthly, style: base)
          else ...[
            TextSpan(text: l.freqAbout, style: base),
            TextSpan(text: '$n', style: value),
            // Singular at exactly one — a common result now the denominator is
            // the window, not a recent cluster's span.
            TextSpan(text: l.freqTimesAMonth(n), style: base),
          ],
          TextSpan(text: l.freqLastOne, style: base),
          TextSpan(text: last, style: value),
        ]),
        textAlign: TextAlign.center,
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
    final label = range.label(AppStore.today, AppLocalizations.of(context));
    // The account no longer scopes an income/expense key, so the empty message
    // names the category alone (spec §6); a transfer's categoryName is its
    // "A → B" title.
    final subject = info.categoryName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 24, Insets.gutter, 24),
      child: Text(
        AppLocalizations.of(context).balNoBetween(subject, label),
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
            AppLocalizations.of(context).balSeeAll(total),
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

/// A compact, non-tappable list row.
///
/// For an income/expense key — whose list can span accounts — line 1 is the
/// row's own account and line 2 the note (absent when empty). For a
/// transfer/rebalance key, whose account(s) the header already fixes, the row
/// stays one line: the note, else a fallback. No chevron (rows aren't
/// tappable), but the swipe menu stays.
///
/// **Rows native, aggregates base.** A row prints its amount in the currency it
/// happened in (spec §3) — a €42 row reads €42. The summary card's TOTAL and
/// AVERAGE instead print in base currency, converting each row through [Fx],
/// because a figure summed across currencies belongs to no single statement.
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

  /// The row's own account name, for an income/expense key (spec §4). expense
  /// pays from [Txn.fromRef]; income lands in [Txn.toRef]. A deleted account
  /// still resolves through [AppStore.refName], so the row renders regardless.
  String _rowAccountName(AppStore store) =>
      store.refName(txn.type == TxnType.income ? txn.toRef : txn.fromRef);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final note = txn.note.trim();

    // The account line renders only when the key does not pin the account — an
    // income/expense list can span accounts, so each row names its own on
    // line 1. A transfer key fixes both accounts and a rebalance key's
    // "category" is the account, so for them a per-row account would repeat the
    // header (spec §4).
    final String? account = info.showsRowAccount ? _rowAccountName(store) : null;

    // Line 1 leads with the account (always present), so a note-less row never
    // borrows the category name as a title — the fallback artefact §4 fixes.
    // Where the key pins the account, line 1 is the note, else the fallback.
    final String primary;
    final String? secondary;
    if (account != null) {
      primary = account;
      secondary = note.isEmpty ? null : note;
    } else {
      primary = note.isNotEmpty ? note : info.rowFallbackTitle;
      secondary = null;
    }

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
        // Top-aligned so the date and amount sit against line 1 when a note
        // adds a second line; for a one-line row this equals centre.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              dayMonth(txn.date, AppLocalizations.of(context)),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          // Native currency — a row prints the amount in the currency it
          // happened in (spec §3); only the aggregates convert to base.
          AmountText(
            txn.amount,
            currency: txn.currency,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            color: info.amountColor,
          ),
        ],
      ),
    );

    final semanticsLabel = [
      // Direction in words — colour is the only other cue for an unsigned row.
      info.directionWord,
      dayMonth(txn.date, AppLocalizations.of(context)),
      // primary names the account for an income/expense row — the fact that
      // distinguishes two otherwise identical rows (spec §4).
      primary,
      ?secondary,
      money(txn.amount,
          currency: txn.currency,
          signless: true,
          masked: store.masked),
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
          label: AppLocalizations.of(context).actionEdit,
          color: AppColors.surfaceHigh,
          onTap: onEdit,
        ),
        SwipeActionItem(
          icon: Icons.copy_rounded,
          label: AppLocalizations.of(context).actionCopy,
          color: AppColors.info,
          onTap: onCopy,
        ),
        SwipeActionItem(
          icon: Icons.delete_rounded,
          label: AppLocalizations.of(context).actionDelete,
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

/// Everything the screen needs to render a key: titles, icon/color, and the row
/// amount color. Resolved once per build from the store.
///
/// Currency is deliberately absent — rows print in their own [Txn.currency] and
/// aggregates in [Fx.baseCurrency], so nothing here fixes one currency for the
/// whole list (spec §3).
class _KeyInfo {
  const _KeyInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.amountColor,
    required this.directionWord,
    required this.rowFallbackTitle,
    required this.categoryName,
    required this.showsRowAccount,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color amountColor;

  /// Direction in words for the row amount's semantics — colour is otherwise
  /// the only cue now that amounts are unsigned.
  final String directionWord;
  final String rowFallbackTitle;
  final String categoryName;

  /// Whether rows carry a per-row account line: true only for an income/expense
  /// key, whose list can span accounts. A transfer/rebalance key pins its
  /// account(s) in the header, so its rows stay one line (spec §4).
  final bool showsRowAccount;

  static _KeyInfo resolve(
      AppStore store, Txn origin, SameKey key, AppLocalizations l) {
    if (key is TransferKey) {
      // One shared helper composes "{from} → {to}" for the header, the row
      // fallback title, and the section label — never a second implementation.
      final parties = store.transferParties(origin);
      final title = store.transferTitle(origin);
      return _KeyInfo(
        title: title,
        subtitle: l.txnTypeTransfer,
        icon: Icons.swap_horiz_rounded,
        color: AppColors.transfer,
        // The app's existing transfer colour — never red/green.
        amountColor: AppColors.transfer,
        // Names both accounts in the row's semantics (spec §3).
        directionWord: l.transferFromTo(parties.from, parties.to),
        // A note-less transfer row shows the path, not the word "Transfer".
        rowFallbackTitle: title,
        categoryName: title,
        // Both accounts are fixed by the key — no per-row account line.
        showsRowAccount: false,
      );
    }

    final ledger = key as LedgerKey;
    final isRebalance = ledger.direction == TxnType.rebalance;
    // For a rebalance the key holds the account in categoryId (there is no
    // category); refName resolves it to the account's name either way.
    final categoryName = store.refName(ledger.categoryId);
    final directionWord = switch (ledger.direction) {
      TxnType.income => l.txnTypeIncome,
      TxnType.rebalance => l.txnTypeRebalance,
      _ => l.txnTypeExpense,
    };
    final amountColor = switch (ledger.direction) {
      TxnType.income => AppColors.positive,
      TxnType.rebalance => AppColors.freqValue,
      _ => AppColors.negative,
    };

    return _KeyInfo(
      title: categoryName,
      // Income/expense keys drop the account from their labels (spec §6):
      // subtitle is the direction alone ("Expense"), section label the category
      // alone ("GROCERIES"). A rebalance key still pins its account, so §6
      // leaves its labels unchanged — the account (== categoryName here) stays.
      subtitle: isRebalance ? '$categoryName · $directionWord' : directionWord,
      icon: isRebalance
          ? Icons.donut_large_rounded
          : store.refIcon(ledger.categoryId),
      color: isRebalance
          ? AppColors.rebalance
          : store.refColor(ledger.categoryId),
      amountColor: amountColor,
      directionWord: directionWord,
      rowFallbackTitle: categoryName,
      categoryName: categoryName,
      // Only an income/expense key leaves the account unpinned (spec §4).
      showsRowAccount: !isRebalance,
    );
  }
}
