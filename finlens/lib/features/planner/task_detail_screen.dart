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
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/same_transactions_screen.dart';
import '../ledger/transfer_detail_screen.dart';
import 'edit_task_screen.dart';
import 'mark_paid_sheet.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _navBar(context, l, task),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _header(context, store, l, task),
                  if (paused) _pausedBanner(l, task),
                  _summaryCard(context, store, l, task),
                  if ((task.note ?? '').trim().isNotEmpty) _note(l, task),
                  if (task.isRecurring) _upcoming(store, l, task),
                  _paymentHistory(context, store, l, task, payments),
                ],
              ),
            ),
            _actions(context, store, l, task, paused),
          ],
        ),
      ),
    );
  }

  Widget _navBar(BuildContext context, AppLocalizations l, Task task) {
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
    final color = task.isPayOut ? AppColors.negative : AppColors.positive;
    final category = store.categoryById(task.categoryId)?.name ??
        (task.payToAccountId != null
            ? store.accountById(task.payToAccountId)?.name
            : null);
    final account = store.accountById(task.linkedAccountId)?.name;
    final cadence = task.isRecurring
        ? repeatCadenceLabel(task.repeats, task.weekdays, task.daysOfMonth,
            task.dueDate, l)
        : null;
    final subtitle = [
      ?category,
      ?account,
      ?cadence,
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

  Widget _summaryCard(
      BuildContext context, AppStore store, AppLocalizations l, Task task) {
    final cols = <(String, Widget)>[];
    if (task.isRecurring) {
      cols.add((l.tdNext, _dateValue(dayMonth(task.dueDate, l))));
      cols.add((l.tdAmount, _amountValue(task.expectedAmount.abs())));
      final perYear = store.taskAmountInBase(task) *
          (task.occurrencesPerYear ?? 0);
      cols.add((l.tdPerYear, _amountValue(perYear)));
    } else {
      cols.add((l.tdDue, _dateValue(dayMonth(task.dueDate, l))));
      cols.add((l.tdAmount, _amountValue(task.expectedAmount.abs())));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 9, 6, 10),
          child: Row(
            children: [
              for (final (label, value) in cols)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      value,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateValue(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );

  Widget _amountValue(double v) => AmountText(
        v,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        forceDecimals: v % 1 != 0,
      );

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

  Widget _upcoming(AppStore store, AppLocalizations l, Task task) {
    // The next three occurrences after the current due date — the same
    // computation the edit screen previews (§7.5), never a second one.
    final upcoming = task.upcomingPreview(4).skip(1).take(3).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.tdUpcoming),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md, vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(dayMonthYear(upcoming[i], l),
                              style: AppText.rowTitle
                                  .copyWith(fontWeight: FontWeight.w500)),
                        ),
                        AmountText(
                          task.expectedAmount.abs(),
                          style: AppText.amount
                              .copyWith(color: AppColors.textTertiary),
                          forceDecimals: task.expectedAmount.abs() % 1 != 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentHistory(BuildContext context, AppStore store,
      AppLocalizations l, Task task, List<Txn> payments) {
    final shown = _showAllPayments ? payments : payments.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.tdPaymentHistory),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: payments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(l.tdNoPayments,
                          style: AppText.caption),
                    ),
                  )
                : Column(
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

  Widget _actions(BuildContext context, AppStore store, AppLocalizations l,
      Task task, bool paused) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                paused
                    ? l.tdResume
                    : (task.isPayOut ? l.tdMarkPaid : l.tdMarkReceived),
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
    store.skipTask(task);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)
            .etSkippedNext(dayMonth(task.dueDate, AppLocalizations.of(context)))),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, Task task) async {
    final store = StoreScope.read(context);
    final action = await showTaskMenu(context, task: task);
    if (!context.mounted || action == null) return;
    switch (action) {
      case TaskMenuAction.edit:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditTaskScreen(taskId: task.id)),
        );
      case TaskMenuAction.skip:
        _skip(context, store, task);
      case TaskMenuAction.pause:
        store.pauseTask(task);
        Navigator.of(context).maybePop();
      case TaskMenuAction.delete:
        final ok = await confirmDeleteTask(context, store, task);
        if (!ok || !context.mounted) return;
        store.deleteTask(task);
        Navigator.of(context).maybePop();
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
