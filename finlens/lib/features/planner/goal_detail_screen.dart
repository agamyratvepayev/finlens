import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../ledger/ledger_scope.dart';
import '../ledger/scoped_ledger_screen.dart';
import 'edit_goal_screen.dart';
import 'goal_presentation.dart';

/// A goal's detail (§5). Everything here is *read* from the ledger — the goal
/// keeps no history of its own. The most valuable figure, `AT THIS RATE`,
/// cannot be computed on the card and lives here.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final goal = store.goalById(goalId);

    // The goal may have been deleted from the ••• menu while this was open.
    if (goal == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final m = store.goalMetrics(goal);
    final verdict = goalVerdict(l, goal, m);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(goal: goal),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  _header(l, store, goal, m, verdict),
                  const SizedBox(height: Insets.lg),
                  _figures(l, m),
                  const SizedBox(height: Insets.xl),
                  if (store.goalOffersArchive(goal))
                    _ArchiveActions(store: store, goal: goal),
                  _columns(l, m),
                  _watching(context, l, store, goal, m),
                  if (goal.source.isAccount)
                    _movements(context, l, store, goal),
                  if (goal.note.trim().isNotEmpty) _note(l, goal),
                  _changes(l, goal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(
    AppLocalizations l,
    AppStore store,
    Goal goal,
    GoalMetrics m,
    ({String text, bool attention}) verdict,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, 0),
      child: Row(
        children: [
          IconTile(
            m.reached ? Icons.check_rounded : store.goalIcon(goal),
            color: m.reached ? AppColors.positive : AppColors.goal,
            size: 40,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: AppText.title.copyWith(fontSize: 21),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  verdict.text,
                  style: AppText.rowSubtitle.copyWith(
                    color: goalVerdictColor(m, verdict.attention),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Figures ──────────────────────────────────────────────────────────────

  Widget _figures(AppLocalizations l, GoalMetrics m) {
    final pct = m.progress;
    final daysElapsed = m.daysTotal > 0 ? m.daysElapsed.clamp(0, m.daysTotal) : m.daysElapsed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountText.balance(
                m.current,
                style: AppText.hero.copyWith(fontSize: 30),
                color: goalBarColor(m),
              ),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: Text(
                  m.reached
                      ? '${l.goalOfWord} ${money(m.target)}'
                      : l.goalOfToGo(money(m.target), money(m.remaining)),
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          ProgressBar(
            value: m.progress,
            color: goalBarColor(m),
            paceMarker: goalPaceFraction(m),
            height: 8,
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                m.targetDate == null
                    ? percent(pct, decimals: 0)
                    : l.goalDaysCaption(
                        percent(pct, decimals: 0),
                        daysElapsed,
                        m.daysTotal,
                      ),
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
              if (goalPaceFraction(m) != null) ...[
                const Spacer(),
                Container(width: 2, height: 10, color: AppColors.textPrimary),
                const SizedBox(width: 5),
                Text(l.plPace, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── STARTED · TARGET · AT THIS RATE ────────────────────────────────────────

  Widget _columns(AppLocalizations l, GoalMetrics m) {
    final now = AppStore.today;
    final started = DateTime(now.year, now.month - m.monthsElapsed, now.day);
    // AT THIS RATE lands amber when it falls after TARGET, positive when before,
    // neutral when there is nothing to project (§5).
    final Color rateColor;
    final String rateText;
    if (m.actualRate == null || m.projectedEnd == null) {
      rateColor = AppColors.textSecondary;
      rateText = '—';
    } else {
      rateText = monthYear(m.projectedEnd!, l);
      rateColor = (m.targetDate != null && m.projectedEnd!.isAfter(m.targetDate!))
          ? AppColors.warning
          : AppColors.positive;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          children: [
            Row(
              children: [
                _Col(label: l.goalColStarted, value: monthYear(started, l)),
                _Col(
                  label: l.goalColTarget,
                  value: m.targetDate == null ? '—' : monthYear(m.targetDate!, l),
                ),
                _Col(
                  label: l.goalColAtThisRate,
                  value: rateText,
                  color: rateColor,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.md),
              child: RowDivider(indent: 0),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _averagingLine(l, m),
                style: AppText.caption.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _averagingLine(AppLocalizations l, GoalMetrics m) {
    if (m.reached) return l.goalReachedSummary;
    if (m.actualRate == null) return l.goalNotMovingYet;
    final needs = m.requiredRate;
    if (needs == null) return l.goalAveragingOnly(money(m.actualRate!));
    return l.goalAveraging(money(m.actualRate!), money(needs));
  }

  // ── WATCHING ─────────────────────────────────────────────────────────────

  Widget _watching(
    BuildContext context,
    AppLocalizations l,
    AppStore store,
    Goal goal,
    GoalMetrics m,
  ) {
    if (goal.source.isCategory) {
      final cat = store.categoryById(goal.source.id);
      final windowEnd = goal.targetDate ?? AppStore.today;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l.goalWatching),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    IconTile(cat?.icon ?? Icons.help_outline_rounded,
                        color: cat?.color ?? AppColors.textSecondary, size: 34),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat?.name ?? l.goalSourceUnavailable,
                              style: AppText.rowTitle),
                          const SizedBox(height: 2),
                          Text(
                            l.goalCategoryWindow(
                              dayMonth(goal.createdAt, l),
                              dayMonth(windowEnd, l),
                            ),
                            style: AppText.rowSubtitle.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final acc = store.accountById(goal.source.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalWatching),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: acc == null
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ScopedLedgerScreen(
                            initialScope: AccountScope(acc.id),
                          ),
                        ),
                      ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    IconTile(acc?.displayIcon ?? Icons.help_outline_rounded,
                        color: acc?.color ?? AppColors.textSecondary, size: 34),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(acc?.name ?? l.goalSourceUnavailable,
                              style: AppText.rowTitle),
                          const SizedBox(height: 2),
                          Text(
                            acc == null ? '' : acc.group.label(l),
                            style: AppText.rowSubtitle.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    AmountText.balance(m.current),
                    if (acc != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOVEMENTS ──────────────────────────────────────────────────────────────

  Widget _movements(
    BuildContext context,
    AppLocalizations l,
    AppStore store,
    Goal goal,
  ) {
    final all = store.txnsForAccount(goal.source.id);
    if (all.isEmpty) return const SizedBox.shrink();
    final preview = all.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalMovements),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  _MovementRow(
                    store: store,
                    txn: preview[i],
                    accountId: goal.source.id,
                  ),
                ],
                const RowDivider(indent: Insets.md),
                InkWell(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ScopedLedgerScreen(
                        initialScope: AccountScope(goal.source.id),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: [
                        Text(
                          l.goalSeeAll(all.length),
                          style: AppText.body.copyWith(
                            color: AppColors.accentSoft,
                            fontSize: 13.5,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.accentSoft),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── NOTE ─────────────────────────────────────────────────────────────────

  Widget _note(AppLocalizations l, Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(l.goalNoteSection),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(goal.note, style: AppText.body.copyWith(fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── CHANGES (§7) ─────────────────────────────────────────────────────────

  Widget _changes(AppLocalizations l, Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Insets.md),
        SectionLabel(l.goalChanges),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            child: Column(
              children: [
                for (var i = 0; i < goal.history.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  _ChangeRow(l: l, edit: goal.history[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xs),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            label: Text(l.plTabGoals),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            color: AppColors.textPrimary,
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final store = StoreScope.read(context);
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.sm),
            _MenuRow(
              icon: Icons.edit_rounded,
              label: l.goalMenuEdit,
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            _MenuRow(
              icon: Icons.flag_rounded,
              label: l.egMarkReached,
              onTap: () => Navigator.of(sheetContext).pop('reached'),
            ),
            _MenuRow(
              icon: Icons.pause_circle_rounded,
              label: l.goalStopTracking,
              subtitle: l.goalStopTrackingDesc,
              onTap: () => Navigator.of(sheetContext).pop('stop'),
            ),
            _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: l.egDeleteGoal,
              danger: true,
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'edit':
        openGoalEditor(context, goalId: goal.id);
      case 'reached':
        store.markGoalReached(goal);
        Navigator.of(context).pop();
      case 'stop':
        store.abandonGoal(goal);
        Navigator.of(context).pop();
      case 'delete':
        final ok = await confirmGoalDelete(context, store, goal);
        if (!ok || !context.mounted) return;
        store.deleteGoal(goal);
        Navigator.of(context).pop();
    }
  }
}

/// §4 — a latched goal whose account has reached \$0 offers two actions, because
/// there are two objects: the goal and the account.
class _ArchiveActions extends StatelessWidget {
  const _ArchiveActions({required this.store, required this.goal});

  final AppStore store;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.lg),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.goalReachedAtZero, style: AppText.body.copyWith(fontSize: 13.5)),
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        store.markGoalReached(goal);
                        Navigator.of(context).pop();
                      },
                      child: Text(l.goalKeepAccount),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        store.reachGoalAndArchiveAccount(goal);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(l.goalArchiveBoth),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.rowTitle.copyWith(
              fontSize: 14,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.store,
    required this.txn,
    required this.accountId,
  });

  final AppStore store;
  final Txn txn;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final effect = store.effectOfTxnOn(txn, accountId);
    final other = txn.fromRef == accountId ? txn.toRef : txn.fromRef;
    final title = txn.note.trim().isNotEmpty ? txn.note.trim() : store.refName(other);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Row(
        children: [
          IconTile(store.refIcon(other), color: store.refColor(other), size: 30),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.rowTitle.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(dayMonth(txn.date, l),
                    style: AppText.rowSubtitle.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          AmountText(
            effect,
            showSign: true,
            color: effect < 0 ? AppColors.negative : AppColors.positive,
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.l, required this.edit});

  final AppLocalizations l;
  final GoalEdit edit;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = switch (edit.field) {
      'created' => l.goalChangeCreated,
      'target' => l.goalChangeTarget,
      _ => l.goalChangeDate,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${edit.at.day}.${edit.at.month}',
              style: AppText.caption.copyWith(fontSize: 11.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fieldLabel,
                    style: AppText.rowSubtitle.copyWith(fontSize: 12.5)),
                const SizedBox(height: 1),
                Text(
                  edit.field == 'created' ? edit.to : '${edit.from} → ${edit.to}',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (edit.amber)
            const Icon(Icons.schedule_rounded,
                size: 15, color: AppColors.warning),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.negative : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: Insets.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.rowTitle.copyWith(color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: AppText.rowSubtitle.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
