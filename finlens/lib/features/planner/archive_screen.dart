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

/// Spec 5.8 — reached goals, abandoned goals and removed budgets on one page.
///
/// Reached goals are deliberately *not* restorable: a completed goal is part of
/// your history. The other two groups come back with Restore.
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
    final budgets = store.removedBudgets;
    final accounts = store.archivedAccounts;
    final cats = store.archivedCategories;
    final pausedTasks = store.pausedTasks;
    final completedTasks = store.completedTasks;
    final deletedTasks = store.deletedTasks;
    final total = reached.length +
        gaveUp.length +
        budgets.length +
        accounts.length +
        cats.length +
        pausedTasks.length +
        completedTasks.length +
        deletedTasks.length;

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
                        // Goal performance moved here from Insight (§7): a
                        // statistic about finished goals belongs next to the
                        // goals it describes, where it turns into advice. Hidden
                        // when no goal has finished.
                        if (reached.isNotEmpty || gaveUp.isNotEmpty)
                          _GoalPerformanceCard(reached: reached, gaveUp: gaveUp),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.gutter,
                            0,
                            Insets.gutter,
                            Insets.md,
                          ),
                          child: Text(
                            l.arFootnote,
                            style: AppText.caption.copyWith(fontSize: 12.5),
                          ),
                        ),
                        // Task sections sit at the top (§9), above goals/budgets.
                        if (pausedTasks.isNotEmpty) ...[
                          SectionLabel(l.arPausedTasks),
                          _card([
                            for (final t in pausedTasks)
                              _taskRow(
                                context,
                                store,
                                t,
                                subtitle: l.arPausedLine(
                                    dayMonth(t.statusChangedAt ?? t.dueDate, l),
                                    store.paymentsForTask(t.id).length,
                                    money(store.paymentTotalForTask(t.id))),
                                trailing: _pillWithChevron(_RestoreButton(
                                    onTap: () => store.resumeTask(t),
                                    label: l.actionResume)),
                              ),
                          ]),
                        ],
                        if (completedTasks.isNotEmpty) ...[
                          SectionLabel(l.arCompletedTasks),
                          _card([
                            for (final t in completedTasks)
                              _taskRow(
                                context,
                                store,
                                t,
                                subtitle: t.status == TaskStatus.skipped
                                    ? l.arCancelledLine(
                                        dayMonth(t.statusChangedAt ?? t.dueDate, l))
                                    : l.arCompletedLine(
                                        dayMonth(t.statusChangedAt ?? t.dueDate, l),
                                        money(store.paymentTotalForTask(t.id))),
                                trailing: const Icon(Icons.chevron_right_rounded,
                                    size: 18, color: AppColors.textTertiary),
                              ),
                          ]),
                        ],
                        if (deletedTasks.isNotEmpty) ...[
                          SectionLabel(l.arDeletedTasks),
                          _card([
                            for (final t in deletedTasks)
                              _taskRow(
                                context,
                                store,
                                t,
                                subtitle: l.arDeletedLineTask(
                                    dayMonth(t.statusChangedAt ?? t.dueDate, l),
                                    store.paymentsForTask(t.id).length,
                                    money(store.paymentTotalForTask(t.id))),
                                trailing: _pillWithChevron(
                                    _UndoButton(onTap: () => store.undoDeleteTask(t))),
                              ),
                          ]),
                        ],
                        if (reached.isNotEmpty) ...[
                          SectionLabel(l.arReachedGoals),
                          _card([
                            for (final g in reached)
                              _ArchiveRow(
                                icon: Icons.check_rounded,
                                color: AppColors.positive,
                                title: g.name,
                                subtitle: l.arReachedLine(
                                    dayMonthYear(g.completedAt!, l),
                                    g.durationMonths ?? 0),
                                onTap: () => _openGoal(context, g, l),
                                trailing: AmountText(
                                  g.targetAmount,
                                  style: AppText.amountLarge,
                                ),
                              ),
                          ]),
                        ],
                        if (gaveUp.isNotEmpty) ...[
                          SectionLabel(l.arGaveUp),
                          _card([
                            for (final g in gaveUp)
                              _ArchiveRow(
                                icon: store.goalIcon(g),
                                color: AppColors.textSecondary,
                                title: g.name,
                                subtitle: l.arStoppedLine(
                                    dayMonth(g.stoppedAt!, l),
                                    // `saved` is gone, and the figure is frozen:
                                    // what the source held on the day the goal
                                    // stopped, not what it holds today (§3).
                                    money(store
                                        .goalMetrics(g, asOf: g.stoppedAt!)
                                        .current),
                                    money(g.targetAmount)),
                                onTap: () => _openGoal(context, g, l),
                                trailing: _RestoreButton(
                                  onTap: () => store.restoreGoal(g),
                                ),
                              ),
                          ]),
                        ],
                        if (budgets.isNotEmpty) ...[
                          SectionLabel(l.arRemovedBudgets),
                          _card([
                            for (final c in budgets)
                              _ArchiveRow(
                                icon: c.icon,
                                color: c.color,
                                title: c.name,
                                subtitle: l.arRemovedLine(
                                    dayMonth(c.removedOn!, l)),
                                trailing: _RestoreButton(
                                  // The old limit is not retained once cleared,
                                  // so restoring seeds a sensible default from
                                  // recent spend.
                                  onTap: () => store.restoreBudget(
                                    c,
                                    _suggestLimit(store, c),
                                  ),
                                ),
                              ),
                          ]),
                        ],
                        // Archived accounts and categories — restore is the
                        // reversal of an archive and destroys nothing, so it is
                        // one tap with no confirmation (§2). An account returns
                        // to its group with its balance and history; a category
                        // reappears in every picker (its old budget does not —
                        // that has its own Restore above).
                        if (accounts.isNotEmpty) ...[
                          SectionLabel(l.arAccounts),
                          _card([
                            for (final a in accounts)
                              _ArchiveRow(
                                icon: a.displayIcon,
                                color: a.color,
                                title: a.name,
                                subtitle: l.arAccountLine(
                                  a.group.label(l),
                                  store.txnsForAccount(a.id).length,
                                ),
                                onTap: () =>
                                    Navigator.of(context, rootNavigator: true)
                                        .push(MaterialPageRoute(
                                  builder: (_) => ScopedLedgerScreen(
                                    initialScope: AccountScope(a.id),
                                  ),
                                )),
                                trailing: _RestoreButton(
                                  onTap: () => store.restoreAccount(a),
                                ),
                              ),
                          ]),
                        ],
                        if (cats.isNotEmpty) ...[
                          SectionLabel(l.arCategories),
                          _card([
                            for (final c in cats)
                              _ArchiveRow(
                                icon: c.icon,
                                color: c.color,
                                title: c.name,
                                subtitle: l.countTransactions(
                                    store.txnCountForCategory(c.id)),
                                trailing: _RestoreButton(
                                  onTap: () => store.restoreCategory(c),
                                ),
                              ),
                          ]),
                        ],
                        const SizedBox(height: Insets.xl),
                        Center(
                          child: Text(
                            AppLocalizations.of(context).countArchivedItems(total),
                            style: AppText.caption,
                          ),
                        ),
                        const SizedBox(height: Insets.lg),
                        Center(
                          child: TextButton(
                            onPressed: () => _clear(context, store, total),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.negative,
                            ),
                            child: Text(l.arClearPermanently),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// A task archive row — the §4.1-shaped [_ArchiveRow], made tappable so it
  /// pushes the read-only Task detail (§9). Reuses `_ArchiveRow`, not a fork.
  Widget _taskRow(
    BuildContext context,
    AppStore store,
    Task task, {
    required String subtitle,
    required Widget trailing,
  }) {
    final color = task.isPayOut ? AppColors.negative : AppColors.positive;
    return InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
      ),
      child: _ArchiveRow(
        icon: task.icon,
        color: color,
        title: task.title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  /// Opens the goal detail in its archived mode (§2). The back label is this
  /// screen's own title, so the detail reads `‹ Archive`, not `‹ Goals`.
  void _openGoal(BuildContext context, Goal g, AppLocalizations l) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              GoalDetailScreen(goalId: g.id, backLabel: l.moreArchive),
        ),
      );

  Widget _pillWithChevron(Widget pill) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textTertiary),
        ],
      );

  double _suggestLimit(AppStore store, Category c) {
    final spend = store.spentInCategory(
      c.id,
      DateTime(store.period.year, store.period.month - 1),
    );
    return spend > 0 ? (spend / 50).ceil() * 50 : 100;
  }

  Widget _card(List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: AppCard(
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const RowDivider(indent: Insets.md),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, AppStore store, int total) async {
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.arClearTitle,
      message: l.arClearMsg(total),
      impact: [
        ImpactLine.kept(l.arTxnStay),
        ImpactLine.kept(l.arBalancesUnaffected),
        ImpactLine.lost(l.arRestoreImpossible),
        ImpactLine.lost(l.arStatsDisappear),
      ],
      confirmLabel: l.arClearArchive,
    );
    if (!ok || !context.mounted) return;
    store.clearArchive();
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  /// When non-null the whole row becomes tappable (§1); when null it renders
  /// exactly as before — no ripple, no chevron. `_RestoreButton` absorbs its own
  /// hits, so a tap on Restore never also fires this.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          IconTile(icon, color: color, size: 34),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.rowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.rowSubtitle.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentSoft,
        visualDensity: VisualDensity.compact,
        textStyle: AppText.button.copyWith(fontSize: 13.5),
      ),
      child: Text(label ?? AppLocalizations.of(context).actionRestore),
    );
  }
}

/// The Undo pill on a deleted-task row (§9) — restores the previous status.
class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentSoft,
        visualDensity: VisualDensity.compact,
        textStyle: AppText.button.copyWith(fontSize: 13.5),
      ),
      child: Text(AppLocalizations.of(context).actionUndo),
    );
  }
}

/// Goal performance (spec §7) — reached count, success rate and average duration
/// of finished goals, at the §4 density (76 pt). Moved here from Insight: in a
/// money-flow report it was a statistic; next to the goals it describes it turns
/// into advice ("your goals take about five months") worth reading while setting
/// the next one's date.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
      child: AppCard(
        key: const Key('arc-perfcard'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, 11, Insets.lg, 10),
              child: Row(
                children: [
                  _stat(l.arcReached, '${reached.length}', AppColors.positive),
                  _stat(l.arcSuccess,
                      finished == 0 ? '—' : percent(rate, decimals: 0),
                      AppColors.goal),
                  _stat(l.arcAvgTime,
                      durs.isEmpty ? '—' : l.arcMonthsShort(avg), AppColors.info),
                ],
              ),
            ),
            if (durs.isNotEmpty) _foot(l.arcGoalsTakeAbout(avg)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppText.label.copyWith(fontSize: 10)),
            const SizedBox(height: 3),
            Text(value,
                style: AppText.amountLarge.copyWith(fontSize: 17, color: color)),
          ],
        ),
      );

  /// The centred, one-line §4 card-bottom strip.
  Widget _foot(String text) => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, height: 1.45, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}
