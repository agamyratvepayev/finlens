import 'package:flutter/material.dart';

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
    final total = reached.length + gaveUp.length + budgets.length;

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
                                icon: g.icon,
                                color: AppColors.textSecondary,
                                title: g.name,
                                subtitle: l.arStoppedLine(
                                    dayMonth(g.stoppedAt!, l),
                                    money(g.saved),
                                    money(g.targetAmount)),
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
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.onTap});

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
      child: Text(AppLocalizations.of(context).actionRestore),
    );
  }
}
