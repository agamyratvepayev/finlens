import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import 'goal_detail_screen.dart';
import 'task_detail_screen.dart';

/// The Archive (§6), grouped by *what you can do*, not by entity:
///
///   FINISHED         reached goals · paid one-offs        — read (amount)
///   UNFINISHED       abandoned goals · cancelled tasks    — read (amount or —)
///   CAN COME BACK    paused tasks · removed budgets · accounts — one action pill
///   RECENTLY DELETED deleted tasks                        — Undo
///
/// Settled outcomes are read; pending things are brought back. Entity type moved
/// from the section header into the subtitle's first token (`Goal · reached …`,
/// `Account · Spendable · 24 transactions`), so nothing is lost — it just sits on
/// the row it describes. Archived categories are gone entirely: they live in the
/// category management screen now (§2.4), and dropped out of [archivedCount].
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    final reached = store.archivedGoals
        .where((g) => g.status == GoalStatus.reached)
        .toList();
    final gaveUp = store.archivedGoals
        .where((g) => g.status == GoalStatus.abandoned)
        .toList();
    final paidTasks = store.completedTasks
        .where((t) => t.status == TaskStatus.paid)
        .toList();
    final skippedTasks = store.completedTasks
        .where((t) => t.status == TaskStatus.skipped)
        .toList();
    final pausedTasks = store.pausedTasks;
    final budgets = store.removedBudgets;
    final accounts = store.archivedAccounts;
    final deletedTasks = store.deletedTasks;

    final finished = reached.length + paidTasks.length;
    final unfinished = gaveUp.length + skippedTasks.length;
    final canComeBack = pausedTasks.length + budgets.length + accounts.length;
    final total = finished + unfinished + canComeBack + deletedTasks.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.moreArchive,
              showBack: true,
              showEye: false,
              showAdd: false,
            ),
            Expanded(
              child: total == 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: EmptyState(
                        icon: Icons.inventory_2_rounded,
                        title: l.arEmpty,
                        message: l.arEmptyMsg,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: Insets.xxl),
                      children: [
                        if (reached.isNotEmpty || gaveUp.isNotEmpty)
                          _GoalPerformanceCard(reached: reached, gaveUp: gaveUp),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Insets.gutter, 0,
                              Insets.gutter, Insets.md),
                          child: Text(l.arFootnote,
                              style: AppText.caption.copyWith(fontSize: 12.5)),
                        ),

                        // FINISHED — read-only, amount + chevron.
                        if (finished > 0) ...[
                          SectionLabel(
                            l.arGroupFinished,
                            trailing: _ClearLink(
                              label: l.arClearFinished,
                              color: AppColors.accentLight,
                              onTap: () => _confirmClear(context, store,
                                  count: finished,
                                  confirmLabel: l.arClearFinished,
                                  action: store.clearFinished),
                            ),
                          ),
                          _card([
                            for (final g in reached)
                              _row(context,
                                  icon: Icons.check_rounded,
                                  color: AppColors.positive,
                                  title: g.name,
                                  subtitle:
                                      '${l.arTypeGoal} · ${l.arReachedLine(dayMonthYear(g.completedAt!, l), g.durationMonths ?? 0)}',
                                  trailing: _readTrailing(
                                      AmountText(g.targetAmount,
                                          style: AppText.amount)),
                                  onTap: () => _openGoal(context, g, l)),
                            for (final t in paidTasks)
                              _row(context,
                                  icon: t.icon,
                                  color: t.isPayOut
                                      ? AppColors.negative
                                      : AppColors.positive,
                                  title: t.title,
                                  subtitle:
                                      '${l.arTypeTask} · ${l.arCompletedLine(dayMonth(t.statusChangedAt ?? t.dueDate, l), money(store.paymentTotalForTask(t.id)))}',
                                  trailing: _readTrailing(AmountText(
                                      store.paymentTotalForTask(t.id),
                                      style: AppText.amount)),
                                  onTap: () => _openTask(context, t)),
                          ]),
                        ],

                        // UNFINISHED — read-only, amount or —.
                        if (unfinished > 0) ...[
                          SectionLabel(
                            l.arGroupUnfinished,
                            trailing: _ClearLink(
                              label: l.arClearUnfinished,
                              color: AppColors.accentLight,
                              onTap: () => _confirmClear(context, store,
                                  count: unfinished,
                                  confirmLabel: l.arClearUnfinished,
                                  action: store.clearUnfinished),
                            ),
                          ),
                          _card([
                            for (final g in gaveUp)
                              _row(context,
                                  icon: store.goalIcon(g),
                                  color: AppColors.textSecondary,
                                  title: g.name,
                                  subtitle:
                                      '${l.arTypeGoal} · ${l.arStoppedLine(dayMonth(g.stoppedAt!, l), money(store.goalMetrics(g, asOf: g.stoppedAt!).current), money(g.targetAmount))}',
                                  trailing: _readTrailing(
                                      AmountText(g.targetAmount,
                                          style: AppText.amount)),
                                  onTap: () => _openGoal(context, g, l)),
                            for (final t in skippedTasks)
                              _row(context,
                                  icon: t.icon,
                                  color: AppColors.textSecondary,
                                  title: t.title,
                                  subtitle:
                                      '${l.arTypeTask} · ${l.arCancelledLine(dayMonth(t.statusChangedAt ?? t.dueDate, l))}',
                                  trailing: _readTrailing(Text('—',
                                      style: AppText.amount.copyWith(
                                          color: AppColors.textTertiary))),
                                  onTap: () => _openTask(context, t)),
                          ]),
                        ],

                        // CAN COME BACK — one action pill, no clear link.
                        if (canComeBack > 0) ...[
                          SectionLabel(l.arGroupCanComeBack),
                          _card([
                            for (final t in pausedTasks)
                              _row(context,
                                  icon: t.icon,
                                  color: t.isPayOut
                                      ? AppColors.negative
                                      : AppColors.positive,
                                  title: t.title,
                                  subtitle:
                                      '${l.arTypeTask} · ${l.arPausedLine(dayMonth(t.statusChangedAt ?? t.dueDate, l), store.paymentsForTask(t.id).length, money(store.paymentTotalForTask(t.id)))}',
                                  trailing: _ActionPill(
                                      label: l.actionResume,
                                      onTap: () => store.resumeTask(t)),
                                  onTap: () => _openTask(context, t)),
                            for (final c in budgets)
                              _row(context,
                                  icon: c.icon,
                                  color: c.color,
                                  title: c.name,
                                  subtitle:
                                      '${l.arTypeBudget} · ${l.arRemovedLine(dayMonth(store.removedOnOf(c) ?? AppStore.today, l))}',
                                  trailing: _ActionPill(
                                      label: l.actionRestore,
                                      onTap: () => store.restoreBudget(
                                          c, _suggestLimit(store, c)))),
                            for (final a in accounts)
                              _row(context,
                                  icon: a.displayIcon,
                                  color: a.color,
                                  title: a.name,
                                  subtitle:
                                      '${l.arTypeAccount} · ${l.arAccountLine(a.group.label(l), store.txnsForAccount(a.id).length)}',
                                  trailing: _ActionPill(
                                      label: l.actionRestore,
                                      onTap: () => store.restoreAccount(a)),
                                  onTap: () => Navigator.of(context,
                                          rootNavigator: true)
                                      .push(MaterialPageRoute(
                                    builder: (_) => ScopedLedgerScreen(
                                      initialScope: AccountScope(a.id),
                                    ),
                                  ))),
                          ]),
                        ],

                        // RECENTLY DELETED — Undo.
                        if (deletedTasks.isNotEmpty) ...[
                          SectionLabel(
                            l.arGroupRecentlyDeleted,
                            trailing: _ClearLink(
                              label: l.arDeleteNow,
                              color: AppColors.negative,
                              onTap: () => _confirmClear(context, store,
                                  count: deletedTasks.length,
                                  confirmLabel: l.arDeleteNow,
                                  action: store.deleteRecycledTasks),
                            ),
                          ),
                          _card([
                            for (final t in deletedTasks)
                              _row(context,
                                  icon: t.icon,
                                  color: t.isPayOut
                                      ? AppColors.negative
                                      : AppColors.positive,
                                  title: t.title,
                                  subtitle:
                                      '${l.arTypeTask} · ${l.arDeletedLineTask(dayMonth(t.statusChangedAt ?? t.dueDate, l), store.paymentsForTask(t.id).length, money(store.paymentTotalForTask(t.id)))}',
                                  trailing: _ActionPill(
                                      label: l.actionUndo,
                                      onTap: () => store.undoDeleteTask(t)),
                                  onTap: () => _openTask(context, t)),
                          ]),
                        ],

                        const SizedBox(height: Insets.xl),
                        Center(
                          child: Text(l.countArchivedItems(total),
                              style: AppText.caption),
                        ),
                        const SizedBox(height: Insets.md),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only trailing: a value hugging a chevron.
  Widget _readTrailing(Widget value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          value,
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      );

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          IconTile(icon, color: color, size: 28),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.rowTitle.copyWith(height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.rowSubtitle.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: row,
      ),
    );
  }

  Widget _card(List<Widget> rows) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const RowDivider(indent: 52),
                rows[i],
              ],
            ],
          ),
        ),
      );

  void _openGoal(BuildContext context, Goal g, AppLocalizations l) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              GoalDetailScreen(goalId: g.id, backLabel: l.moreArchive),
        ),
      );

  void _openTask(BuildContext context, Task t) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
      );

  double _suggestLimit(AppStore store, Category c) {
    // The old limit is not retained once a budget is cleared (§6.5, reported —
    // not fixed here), so restoring seeds a sensible default from recent spend.
    final spend = store.spentInCategory(
      c.id,
      DateTime(store.period.year, store.period.month - 1),
    );
    return spend > 0 ? (spend / 50).ceil() * 50 : 100;
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppStore store, {
    required int count,
    required String confirmLabel,
    required VoidCallback action,
  }) async {
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.arClearScopedTitle,
      message: l.arClearScopedMsg(count),
      impact: [ImpactLine.lost(l.arRestoreImpossible)],
      confirmLabel: confirmLabel,
    );
    if (!ok || !context.mounted) return;
    action();
  }
}

/// A section-header clear link, living in [SectionLabel]'s trailing slot (§6.3).
class _ClearLink extends StatelessWidget {
  const _ClearLink(
      {required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      ),
    );
  }
}

/// The single action affordance in CAN COME BACK / RECENTLY DELETED (§6.1): a
/// chip pill that absorbs its own hits so a tap on it never also fires the row.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentLight)),
        ),
      ),
    );
  }
}

/// The goal-performance card, collapsed to one centred line (§6.2, ~32 pt inside
/// the same AppCard). It replaces the old 76 pt three-up-stat-over-strip card,
/// whose bottom strip repeated the AVG TIME cell above it. `insight-spec` §4/§12
/// are updated to this height.
class _GoalPerformanceCard extends StatelessWidget {
  const _GoalPerformanceCard({required this.reached, required this.gaveUp});

  final List<Goal> reached;
  final List<Goal> gaveUp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final finished = reached.length + gaveUp.length;
    final rate = finished == 0 ? 0.0 : reached.length / finished;
    final durs = reached.map((g) => g.durationMonths).whereType<int>().toList();
    final avg =
        durs.isEmpty ? 0 : (durs.reduce((a, b) => a + b) / durs.length).round();

    final reachedStr = '${reached.length}';
    final rateStr = finished == 0 ? '—' : percent(rate, decimals: 0);
    final avgStr = durs.isEmpty ? '—' : l.arcMonthsShort(avg);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
      child: AppCard(
        key: const Key('arc-perfcard'),
        child: Semantics(
          label: l.arcOneLine(reachedStr, rateStr, avgStr),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seg(reachedStr, l.arcReachedLabel, AppColors.positive),
                  _sep(),
                  _seg(rateStr, l.arcSuccessLabel, AppColors.goal),
                  _sep(),
                  _seg(avgStr, l.arcAverageLabel, AppColors.info),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(String value, String label, Color color) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const TextSpan(text: ' '),
          TextSpan(
              text: label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ]),
      );

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·',
            style: TextStyle(fontSize: 13, color: AppColors.textQuaternary)),
      );
}
