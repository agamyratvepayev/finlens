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
    // §1 — the header prints what this is once: category · account. The long
    // cadence leaves the subtitle for the Upcoming label (§3), where the dates
    // beneath it prove it, so the line no longer wraps to a second row.
    final subtitle = [
      ?category,
      ?account,
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

  // §2 — the strip. NEXT/DUE is a date; AMOUNT and PER YEAR are money cells
  // where the currency prints beside the figure as a small unit, not at the
  // figure's own size (which overflowed the moment the numbers got large). The
  // three cells share one size step so they never disagree.
  Widget _summaryCard(
      BuildContext context, AppStore store, AppLocalizations l, Task task) {
    // A task's amount is in its own account's currency; the per-year total is a
    // base-currency aggregate. The two can disagree, so each cell carries the
    // code for the number it qualifies (§2b).
    final taskCurrency =
        store.accountById(task.linkedAccountId)?.currency ?? store.baseCurrency;
    final cols = <_StripCell>[];
    if (task.isRecurring) {
      cols.add(_StripCell.date(l.tdNext, dayMonth(task.dueDate, l)));
      cols.add(_StripCell.money(l.tdAmount, task.expectedAmount, taskCurrency));
      final perYear =
          store.taskAmountInBase(task) * (task.occurrencesPerYear ?? 0);
      cols.add(_StripCell.money(l.tdPerYear, perYear, store.baseCurrency));
    } else {
      cols.add(_StripCell.date(l.tdDue, dayMonth(task.dueDate, l)));
      cols.add(_StripCell.money(l.tdAmount, task.expectedAmount, taskCurrency));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: AppCard(
        child: Padding(
          // Thinner than before (§2a): 8/6/9/6, was 9/6/10/6.
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
          child: _SummaryStrip(cells: cols, masked: store.masked),
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

  Widget _upcoming(AppStore store, AppLocalizations l, Task task) {
    // The next three occurrences after the current due date — the same
    // computation the edit screen previews (§7.5), never a second one.
    final upcoming = task.upcomingPreview(4).skip(1).take(3).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    // §3 — the long cadence rides the Upcoming label as a footnote (not a second
    // label): lower-case, textTertiary, not letter-spaced or upper-cased. The
    // dates beneath it prove it. A one-off task has no Upcoming section, so the
    // cadence is printed nowhere — which is correct.
    final cadence = repeatCadenceLabel(
        task.repeats, task.weekdays, task.daysOfMonth, task.dueDate, l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l.tdUpcoming,
          trailing: Text(
            cadence.toLowerCase(),
            style: const TextStyle(
              fontSize: 11.5,
              height: 14 / 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ),
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
                          task.expectedAmount,
                          kind: AmountKind.magnitude,
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

/// One column of the summary strip (§2): a labelled date, or a labelled money
/// value. A money cell carries the currency of the number it qualifies —
/// AMOUNT in the task's account currency, PER YEAR in the base — because two
/// screens can legitimately disagree, so the code sits with its figure.
class _StripCell {
  const _StripCell.date(this.label, String this.text)
      : value = 0,
        currency = null;
  const _StripCell.money(this.label, this.value, String this.currency)
      : text = null;

  final String label;

  /// The date text (date cells) — null on a money cell.
  final String? text;

  /// The money value (money cells) — meaningless on a date cell.
  final double value;

  /// The money cell's currency, or null for a date cell.
  final String? currency;

  bool get isMoney => currency != null;
}

/// The strip's three (or two) cells, sized as one (§2d). The label sits above a
/// value whose figure is the number and whose currency is a small unit beside
/// it, never a second figure. All cells drop to the same step together —
/// 18/16.5/15 for the figure, 11.5/11/10.5 for the code — never below 15 and
/// never abbreviated; a measured pass picks the largest step that fits every
/// column, so the three never disagree.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.cells, required this.masked});

  final List<_StripCell> cells;
  final bool masked;

  /// (figure, code) sizes, dropped together.
  static const List<(double, double)> _steps = [
    (18.0, 11.5),
    (16.5, 11.0),
    (15.0, 10.5),
  ];

  /// The decimal rule (§2c): cents below 1,000, whole at or above it.
  bool _decimals(double v) => v.abs() < 1000 && v % 1 != 0;

  /// A money cell's bare number (no token) — masked to `••••` like the rest of
  /// the app (§2e).
  String _number(_StripCell c) => money(
        c.value,
        currency: c.currency,
        signless: true,
        masked: masked,
        withSymbol: false,
        forceDecimals: _decimals(c.value),
      );

  /// A glyph currency ($) renders the figure with its flush prefix and no
  /// separate code (§2b); the string is measured/rendered whole.
  String _glyphMoney(_StripCell c) => money(
        c.value,
        currency: c.currency,
        signless: true,
        masked: masked,
        forceDecimals: _decimals(c.value),
      );

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = constraints.maxWidth / cells.length;
        // The measured cell must clear the column with an 8pt breathing gap.
        final usable = column - 8;
        final step = _chooseStep(ts, usable);
        return Row(
          children: [
            for (final c in cells)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      c.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _value(c, step),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  (double, double) _chooseStep(TextScaler ts, double usable) {
    for (final step in _steps) {
      if (cells.every((c) => _fits(c, step, ts, usable))) return step;
    }
    return _steps.last;
  }

  bool _fits(_StripCell c, (double, double) step, TextScaler ts, double usable) {
    final figure = step.$1;
    final code = step.$2;
    if (!c.isMoney) {
      return _measure(c.text!, figure, FontWeight.w700, ts) <= usable;
    }
    final def = currencyDef(c.currency!);
    if (def.tokenHugs) {
      return _measure(_glyphMoney(c), figure, FontWeight.w700, ts) <= usable;
    }
    final w = _measure(_number(c), figure, FontWeight.w700, ts, tabular: true) +
        4 +
        _measure(def.token, code, FontWeight.w600, ts);
    return w <= usable;
  }

  double _measure(String text, double size, FontWeight weight, TextScaler ts,
      {bool tabular = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: ts,
    )..layout();
    return tp.width;
  }

  Widget _value(_StripCell c, (double, double) step) {
    final figure = step.$1;
    final code = step.$2;
    // The line box is pinned to 21 at every step so a smaller figure doesn't
    // change the row height (§2a).
    final numberStyle = TextStyle(
      fontSize: figure,
      fontWeight: FontWeight.w700,
      height: 21 / figure,
      color: AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget value;
    if (!c.isMoney) {
      value = Text(
        c.text!,
        maxLines: 1,
        style: TextStyle(
          fontSize: figure,
          fontWeight: FontWeight.w700,
          height: 21 / figure,
        ),
      );
    } else {
      final def = currencyDef(c.currency!);
      if (def.tokenHugs) {
        value = Text(_glyphMoney(c), maxLines: 1, style: numberStyle);
      } else {
        final number = Text(_number(c), maxLines: 1, style: numberStyle);
        final unit = Text(
          def.token,
          maxLines: 1,
          style: TextStyle(
            fontSize: code,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        );
        value = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: def.symbolBefore
              ? [unit, const SizedBox(width: 4), number]
              : [number, const SizedBox(width: 4), unit],
        );
      }
    }
    // The measured step is chosen to fit the real font (§2d); the FittedBox is a
    // pure safety net for the degenerate tail — a huge amount at 320 pt, or a
    // large text scale — that would otherwise exceed even the 15 pt floor. It
    // shrinks uniformly rather than clipping a digit or overflowing the row, and
    // is a no-op whenever the step already fits, so it never changes the normal
    // render or makes the three cells disagree.
    return FittedBox(fit: BoxFit.scaleDown, child: value);
  }
}
