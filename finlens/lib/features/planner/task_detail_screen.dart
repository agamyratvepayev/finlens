import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/undo_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/same_transactions_screen.dart';
import '../ledger/transfer_detail_screen.dart';
import 'edit_task_screen.dart';
import 'mark_paid_sheet.dart';
import 'occurrence_amount_sheet.dart';
import 'task_actions.dart';

/// §7 — the read-only Task detail. A row tap opens this, never the editor;
/// editing is reached only through `•••`.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId, this.backLabel});

  final String taskId;
  final String? backLabel;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _showAllPayments = false;

  /// The Upcoming row whose amount sheet is open — it holds the pressed tint
  /// until the sheet closes (task 064 §3c).
  DateTime? _openRow;

  /// What the item is (task 064 §1a): a receivable earning is blue, any other
  /// pay-in green, a pay-out red. The header tile and the strip's bar share it.
  Color _kindColor(AppStore store, Task task) {
    if (!task.isPayOut &&
        store.accountById(task.linkedAccountId)?.group ==
            AccountGroup.receivables) {
      return AppColors.receivables;
    }
    return task.isPayOut ? AppColors.negative : AppColors.positive;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final task = store.taskById(widget.taskId);
    if (task == null) {
      // The subject was permanently cleared — leave rather than crash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final payments = store.paymentsForTask(task.id);
    final paused = task.status == TaskStatus.paused;
    final archived = task.status == TaskStatus.archived;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _navBar(context, l, task, archived),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: archived
                    ? [
                        _header(context, store, l, task),
                        _archivedBanner(l, task),
                        _archivedStrip(context, store, l, task, payments),
                        if ((task.note ?? '').trim().isNotEmpty) _note(l, task),
                        _paymentHistory(context, store, l, task, payments),
                      ]
                    : [
                        _header(context, store, l, task),
                        if (paused) _pausedBanner(l, task),
                        _strip(context, store, l, task, payments),
                        if (task.isRecurring) _upcoming(store, l, task, paused),
                        if ((task.note ?? '').trim().isNotEmpty) _note(l, task),
                        _paymentHistory(context, store, l, task, payments),
                      ],
              ),
            ),
            archived
                ? _archivedActions(context, store, l, task)
                : _actions(context, store, l, task, paused),
          ],
        ),
      ),
    );
  }

  Widget _navBar(
      BuildContext context, AppLocalizations l, Task task, bool archived) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            label: Text(widget.backLabel ?? l.plTitle),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
          ),
          const Spacer(),
          // No ••• on an archived item (§2c): its actions are Restore and
          // Delete for good, pinned at the bottom.
          if (!archived)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 22),
              color: AppColors.textPrimary,
              onPressed: () => _openMenu(context, task),
            ),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context, AppStore store, AppLocalizations l, Task task) {
    final color = _kindColor(store, task);
    final category = store.categoryById(task.categoryId)?.name ??
        (task.payToAccountId != null
            ? store.accountById(task.payToAccountId)?.name
            : null);
    final account = store.accountById(task.linkedAccountId);
    // §1 — the header prints what this is once. A receivable earning names the
    // debtor (task 064 §1b): "Owed by {account} · {category}"; everything else
    // keeps "category · account". The long cadence lives on Upcoming (§3).
    final isReceivable = account?.group == AccountGroup.receivables &&
        !task.isPayOut;
    final subtitle = isReceivable
        ? [
            l.tdOwedByLine(account!.name),
            ?category,
          ].join(' · ')
        : [
            ?category,
            if (account != null) account.name,
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(task.icon, color: color, size: 40),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.42,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowSubtitle.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pausedBanner(AppLocalizations l, Task task) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
      child: NoticeBanner(
        margin: EdgeInsets.zero,
        color: AppColors.warning,
        icon: Icons.pause_circle_outline_rounded,
        text: l.tdPausedOn(
            dayMonth(task.statusChangedAt ?? task.dueDate, l)),
      ),
    );
  }

  /// §5 — the archived banner: a tinted strip naming the archive date.
  Widget _archivedBanner(AppLocalizations l, Task task) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.accent, 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined,
                size: 16, color: AppColors.accentLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.tdArchivedOn(
                    dayMonthYear(task.statusChangedAt ?? task.dueDate, l)),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// §5 — the strip as a summary of what happened: `{count} done`, a full bar
  /// in the item's colour, the total recorded; below, the first–last recorded
  /// dates and "in total". No history → "Nothing done", no bar, no total.
  Widget _archivedStrip(BuildContext context, AppStore store,
      AppLocalizations l, Task task, List<Txn> payments) {
    final currency =
        store.accountById(task.linkedAccountId)?.currency ?? store.baseCurrency;
    final color = _kindColor(store, task);
    final masked = store.masked;
    final done = payments.length;
    final total = store.paymentTotalForTask(task.id);

    DateTime? first, last;
    for (final t in payments) {
      if (first == null || t.date.isBefore(first)) first = t.date;
      if (last == null || t.date.isAfter(last)) last = t.date;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: AppCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  done > 0 ? l.schDoneCount(done) : l.tdArchivedNothing,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                if (done > 0) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                  Text(
                    _figure(total, masked),
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 3),
                  Text(currency,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary)),
                ] else
                  const Spacer(),
              ],
            ),
            if (done > 0 && first != null && last != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.tdArchivedRange(
                        dayMonth(first, l), dayMonthYear(last, l)),
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  Text(l.tdInTotal,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// §5 — the pinned bottom on an archived item: the resume-date line, Restore,
  /// and Delete for good.
  Widget _archivedActions(BuildContext context, AppStore store,
      AppLocalizations l, Task task) {
    final resumeDate = store.restoreDueDate(task);
    final overdue = DateTime(resumeDate.year, resumeDate.month, resumeDate.day)
        .isBefore(DateTime(store.today.year, store.today.month, store.today.day));
    final line = overdue
        ? l.tdBackOverdue(dayMonthYear(resumeDate, l))
        : l.tdContinuesFrom(dayMonthYear(resumeDate, l));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          SizedBox(
            width: double.infinity,
            height: 47,
            child: FilledButton(
              onPressed: () => _restore(context, store, task),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md)),
              ),
              child: Text(l.tdRestore,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          TextButton(
            onPressed: () => _deleteForGood(context, store, task),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l.tdDeleteForGood),
          ),
        ],
      ),
    );
  }

  /// The strip's figure: unsigned, no decimals at or above 1,000 (058.2's
  /// rule), masked like the rest of the app; the currency code prints beside
  /// it separately.
  String _figure(double v, bool masked) => money(
        v.abs(),
        masked: masked,
        signless: true,
        withSymbol: false,
        forceDecimals: v.abs() < 1000 && v % 1 != 0,
      );

  /// The next occurrence dates from the due date, skipped ones dropped —
  /// [count] of them at most. The count path of "left" walks this; the
  /// end-date path uses [Task.occurrencesIn] directly.
  List<DateTime> _nextDates(Task task, int count) {
    final out = <DateTime>[];
    bool skipped(DateTime x) => task.skippedDates
        .any((s) => s.year == x.year && s.month == x.month && s.day == x.day);
    var d = task.dueDate;
    for (var guard = 0; out.length < count && guard < 500; guard++) {
      final day = DateTime(d.year, d.month, d.day);
      if (!skipped(day)) out.add(day);
      final next = task.nextOccurrence(d);
      if (!next.isAfter(d)) break;
      d = next;
    }
    return out;
  }

  // §2 — one thin line: the next date, a progress bar, the occurrence's own
  // amount; done / left / totals underneath. Totals are sums of per-occurrence
  // amounts (task 064 §7c), never amount × count.
  Widget _strip(BuildContext context, AppStore store, AppLocalizations l,
      Task task, List<Txn> payments) {
    final currency =
        store.accountById(task.linkedAccountId)?.currency ?? store.baseCurrency;
    final color = _kindColor(store, task);
    final masked = store.masked;
    final days = task.daysUntilDue(store.today);
    final done = payments.length;
    final skipped = task.skippedDates.length;
    final hasEnd =
        task.repeatEndCount != null || task.repeatEndDate != null;

    double sumOf(Iterable<DateTime> dates) =>
        dates.fold(0.0, (s, d) => s + task.amountOn(d).abs());

    // What remains of an ending series. The engine reads repeatEndCount from
    // the LIVE due date (occurrence #1), so the display subtracts what already
    // happened — done + skipped — to say something true about the whole series.
    var left = 0;
    var remaining = const <DateTime>[];
    if (task.isRecurring && hasEnd) {
      if (task.repeatEndDate != null) {
        remaining = task.occurrencesIn(task.dueDate, task.repeatEndDate!);
        left = remaining.length;
      } else {
        left = (task.repeatEndCount! - done - skipped).clamp(0, 1 << 30);
        remaining = _nextDates(task, left);
      }
    }

    // Line 2, per §2's table.
    String? leftLine;
    String? rightLine;
    if (!task.isRecurring) {
      leftLine =
          days < 0 ? l.tdStripDueLate(-days) : l.tdStripDueIn(days);
    } else if (hasEnd) {
      leftLine = done > 0 ? l.tdStripDone(done, left) : l.tdStripInLeft(days, left);
      rightLine = l.tdStripLeft('${_figure(sumOf(remaining), masked)} $currency');
    } else {
      leftLine = done > 0 ? l.tdStripDoneSoFar(done) : l.tdStripIn(days);
      // "A year": the next 12 occurrences for monthly, the occurrences inside
      // the next 365 days for every other cadence.
      final year = task.repeats == RepeatFrequency.monthly
          ? _nextDates(task, 12)
          : task.occurrencesIn(
              task.dueDate, task.dueDate.add(const Duration(days: 365)));
      rightLine = l.tdStripYear('${_figure(sumOf(year), masked)} $currency');
    }

    final Widget middle;
    if (!task.isRecurring) {
      middle = const SizedBox.shrink();
    } else if (hasEnd) {
      final total = done + left;
      middle = _ProgressTrack(
          fraction: total == 0 ? 0 : done / total, color: color);
    } else {
      middle = const _DashedTrack();
    }

    const lineStyle = TextStyle(
      fontSize: 11.5,
      color: AppColors.textSecondary,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: AppCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  dayMonthYear(task.dueDate, l),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: middle,
                  ),
                ),
                Text(
                  _figure(task.amountOn(task.dueDate), masked),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  currency,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(leftLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: lineStyle),
                ),
                if (rightLine != null) ...[
                  const SizedBox(width: 8),
                  Text(rightLine, maxLines: 1, style: lineStyle),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(AppLocalizations l, Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.tdNote),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Text(
                task.note!.trim(),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  // Spec's #EBEBF0 — the app's near-white body token (#EBEBF5).
                  color: AppColors.sheetAccountName,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// §3 — the rule and the end as pills over a tappable list: each row is one
  /// future occurrence, its own amount (task 064 §7c), and a chevron into the
  /// per-occurrence amount sheet. A changed amount is white with a dot — the
  /// dot is the mark, no word.
  Widget _upcoming(AppStore store, AppLocalizations l, Task task, bool paused) {
    // The next three occurrences after the current due date — the same
    // computation the edit screen previews (§7.5), never a second one.
    final upcoming = task.upcomingPreview(4).skip(1).take(3).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final currency =
        store.accountById(task.linkedAccountId)?.currency ?? store.baseCurrency;

    final rule = repeatChipLabel(
        task.repeats, task.weekdays, task.daysOfMonth, task.dueDate, l);
    final String? end = task.repeatEndCount != null
        ? l.rcTimes(task.repeatEndCount!)
        : task.repeatEndDate != null
            ? l.tdEndsOn(dayMonthYear(task.repeatEndDate!, l))
            : null;

    Widget pill(String text, {required Color bg, required Color fg}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l.tdUpcoming,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pill(rule,
                  bg: AppColors.surfaceAlt, fg: AppColors.textSecondary),
              if (end != null) ...[
                const SizedBox(width: 6),
                pill(end,
                    bg: AppColors.tint(AppColors.accent, 0.18),
                    fg: AppColors.accentLight),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  _upcomingRow(store, l, task, upcoming[i], currency, paused),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _upcomingRow(AppStore store, AppLocalizations l, Task task,
      DateTime date, String currency, bool paused) {
    final day = DateTime(date.year, date.month, date.day);
    final changed = task.hasOverrideOn(day);
    final amount = '${_figure(task.amountOn(day), store.masked)} $currency';
    final row = Container(
      color: _openRow == day
          ? AppColors.tint(AppColors.accent, 0.14)
          : Colors.transparent,
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(dayMonthYear(day, l),
                style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500)),
          ),
          // A changed amount is said in colour alone (task 067.2 §6 / §3): the
          // amount itself is accentLight w600, with no leading dot.
          Text(
            amount,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: changed ? FontWeight.w600 : FontWeight.w400,
              color: changed ? AppColors.accentLight : AppColors.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppColors.textQuaternary),
        ],
      ),
    );
    // A paused task's rows are not tappable (§3c).
    if (paused) return row;
    return InkWell(
      onTap: () async {
        setState(() => _openRow = day);
        await showOccurrenceAmountSheet(context, task: task, day: day);
        if (mounted) setState(() => _openRow = null);
      },
      child: row,
    );
  }

  Widget _paymentHistory(BuildContext context, AppStore store,
      AppLocalizations l, Task task, List<Txn> payments) {
    // §4 — with no payments there is no section: no label, no card, no centred
    // sentence. One grey line instead, saying payments appear here after the
    // first Mark-as-paid.
    if (payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, 14, Insets.gutter, 0),
        child: Text(
          l.tdNoPayments,
          style: const TextStyle(
            fontSize: 11.5,
            height: 15 / 11.5,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }
    final shown = _showAllPayments ? payments : payments.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.tdPaymentHistory),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _paymentRow(context, store, l, shown[i]),
                      ],
                      if (!_showAllPayments && payments.length > 3) ...[
                        const RowDivider(indent: Insets.md),
                        InkWell(
                          onTap: () => setState(() => _showAllPayments = true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                l.schSeeAll(payments.length),
                                style: AppText.caption.copyWith(
                                    fontSize: 13.5,
                                    color: AppColors.accentLight),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        if (payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 6, Insets.gutter, 0),
            child: Text(
              l.tdPaymentsSince(
                payments.length,
                monthYearLong(payments.last.date, l),
                money(store.paymentTotalForTask(task.id), masked: store.masked),
              ),
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }

  Widget _paymentRow(
      BuildContext context, AppStore store, AppLocalizations l, Txn txn) {
    final account = store.accountById(
      txn.type == TxnType.income ? txn.toRef : txn.fromRef,
    );
    final color =
        txn.type == TxnType.income ? AppColors.positive : AppColors.negative;
    return InkWell(
      onTap: () => _openTxn(context, txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(dayMonth(txn.date, l),
                  style: AppText.caption.copyWith(fontSize: 12)),
            ),
            Expanded(
              child: Text(account?.name ?? '—',
                  style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            AmountText.balance(txn.amount, color: color,
                forceDecimals: txn.amount % 1 != 0),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.formChevron),
          ],
        ),
      ),
    );
  }

  /// §6b — one true sentence about what marking done will change, above the
  /// button. Booking is untouched; this line describes what [markTaskPaid]
  /// already does, using the occurrence's own amount.
  String? _resultLine(AppStore store, AppLocalizations l, Task task) {
    final account = store.accountById(task.linkedAccountId);
    if (account == null) return null;
    final amount = money(task.amountOn(task.dueDate).abs(),
        currency: account.currency, masked: store.masked);
    if (!task.isPayOut) {
      // A pay-in into a liability has no dedicated line; "will go up" is the
      // nearest honest one (the balance moves toward zero).
      return account.group == AccountGroup.receivables
          ? l.tdOwesMore(account.name, amount)
          : l.tdResultUp(account.name, amount);
    }
    if (task.payToAccountId != null) {
      final liability = store.accountById(task.payToAccountId)?.name ?? '—';
      return l.tdResultDebtDown(liability, amount);
    }
    if (account.group.isLiability) {
      return l.tdResultOweMore(account.name, amount);
    }
    return l.tdResultDown(account.name, amount);
  }

  Widget _actions(BuildContext context, AppStore store, AppLocalizations l,
      Task task, bool paused) {
    final result = paused ? null : _resultLine(store, l, task);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                result,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 47,
            child: FilledButton(
              onPressed: paused
                  ? () => store.resumeTask(task)
                  : () => _markPaid(context, store, task),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md)),
              ),
              child: Text(
                // One verb for every kind (task 064 §6a): "done" is true
                // whether the item is paid, received or earned.
                paused ? l.tdResume : l.tdMarkDone,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!paused && task.isRecurring)
            TextButton(
              onPressed: () => _skip(context, store, task),
              style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
              child: Text(l.tdSkipOne),
            ),
        ],
      ),
    );
  }

  Future<void> _markPaid(
      BuildContext context, AppStore store, Task task) async {
    final result = await showMarkPaidSheet(context, task: task);
    if (result != null && context.mounted) {
      showMarkPaidUndoBar(context, store, result);
    }
  }

  void _skip(BuildContext context, AppStore store, Task task) {
    final l = AppLocalizations.of(context);
    // Skip beside Mark as done can be undone (§6b): the shared undo bar, the
    // same one Mark as done uses, carrying the snapshot [undoSkipTask] reverses.
    final skip = store.skipTask(task);
    showUndoBar(
      context,
      message: l.etSkippedNext(dayMonth(task.dueDate, l)),
      onUndo: () => store.undoSkipTask(skip),
    );
  }

  Future<void> _restore(
      BuildContext context, AppStore store, Task task) async {
    final l = AppLocalizations.of(context);
    store.restoreTask(task);
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.tdRestored(task.title))));
  }

  Future<void> _deleteForGood(
      BuildContext context, AppStore store, Task task) async {
    final ok = await confirmDeleteTask(context, store, task, forGood: true);
    if (!ok || !context.mounted) return;
    // Pop first, then purge: removing the task makes this screen's subject
    // null, whose build-guard would also try to pop. No undo — this is the
    // second deliberate step (§3b); Ledger rows keep their data, lose only the
    // recurrence link.
    Navigator.of(context).maybePop();
    store.deleteTaskForGood(task);
  }

  Future<void> _openMenu(BuildContext context, Task task) async {
    final store = StoreScope.read(context);
    final l = AppLocalizations.of(context);
    final action = await showTaskMenu(context, task: task);
    if (!context.mounted || action == null) return;
    switch (action) {
      case TaskMenuAction.edit:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditTaskScreen(taskId: task.id)),
        );
      case TaskMenuAction.pause:
        // The same slot is Resume on a paused item (§2c).
        if (task.status == TaskStatus.paused) {
          store.resumeTask(task);
        } else {
          store.pauseTask(task);
        }
        Navigator.of(context).maybePop();
      case TaskMenuAction.archive:
        final ok = await confirmArchiveTask(context, store, task);
        if (!ok || !context.mounted) return;
        store.archiveTask(task);
        Navigator.of(context).maybePop();
      case TaskMenuAction.delete:
        // Only reachable with no history (the row is inert otherwise, §2b):
        // a hard delete with the shared undo bar (§3a).
        final ok = await confirmDeleteTask(context, store, task);
        if (!ok || !context.mounted) return;
        // Grab the app-level messenger before we leave, pop first (so the
        // null-subject build-guard doesn't also pop), then purge and show the
        // undo bar on the screen we returned to (§3a).
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).maybePop();
        final snapshot = store.deleteTaskForGood(task);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l.tdDeletedBar(task.title)),
            duration: undoBarWindow,
            action: SnackBarAction(
              label: l.actionUndo,
              onPressed: () => store.undoDeleteForGood(snapshot),
            ),
          ));
    }
  }

  void _openTxn(BuildContext context, Txn txn) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => txn.type == TxnType.transfer
            ? TransferDetailScreen(txnId: txn.id)
            : SameTransactionsScreen(originTxnId: txn.id),
      ),
    );
  }
}

/// The strip's progress bar (task 064 §2): a 2 pt divider track, filled from
/// the left in the item's kind colour to done / (done + left). It shrinks with
/// the space between the date and the amount, down to nothing.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return SizedBox(
      height: 2,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (f > 0)
              Container(
                width: c.maxWidth * f,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A series without an end shows a 1 pt dashed line where the bar would be —
/// there is no fraction to fill.
class _DashedTrack extends StatelessWidget {
  const _DashedTrack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    const dash = 4.0, gap = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => false;
}

