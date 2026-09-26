import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The lifecycle actions behind `•••` (task 065 §2): each has one meaning.
/// Skip left the menu — it lives beside Mark as done on the screen (§6). The
/// `pause` slot doubles as Resume on a paused item (§2c). The sheet returns
/// which one the user chose and the caller performs it (navigation stays with
/// the screen).
enum TaskMenuAction { edit, pause, archive, delete }

Future<TaskMenuAction?> showTaskMenu(
  BuildContext context, {
  required Task task,
}) {
  return showModalBottomSheet<TaskMenuAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TaskMenu(task: task),
  );
}

class _TaskMenu extends StatelessWidget {
  const _TaskMenu({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = StoreScope.of(context);
    final done = store.paymentsForTask(task.id).length;
    final hasHistory = done > 0;
    final paused = task.status == TaskStatus.paused;

    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.md),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            _item(
              context,
              icon: Icons.edit_rounded,
              label: l.tmEdit,
              subtitle: l.tmEditSub,
              action: TaskMenuAction.edit,
            ),
            // Pause on a live item; Resume in its place on a paused one (§2c) —
            // the same slot, so the menu keeps one shape.
            _item(
              context,
              icon: paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_circle_outline_rounded,
              label: paused ? l.tdResume : l.tmPause,
              // Resume gets its own line — it starts, not pauses (task 070 B1).
              subtitle: paused ? l.tmResumeSub : l.tmPauseSub,
              action: TaskMenuAction.pause,
            ),
            _item(
              context,
              icon: Icons.archive_outlined,
              label: l.tmArchive,
              subtitle: hasHistory ? l.tmArchiveSub(done) : l.tmArchiveSubNone,
              action: TaskMenuAction.archive,
            ),
            // A series with history is never deleted here (§2b): the row is
            // drawn dim and inert, and says to archive it first.
            _item(
              context,
              icon: Icons.delete_outline_rounded,
              label: l.tmDelete,
              subtitle:
                  hasHistory ? l.tmDeleteSubLocked(done) : l.tmDeleteSubNone,
              action: TaskMenuAction.delete,
              destructive: !hasHistory,
              enabled: !hasHistory,
            ),
            const SizedBox(height: Insets.sm),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, Insets.md),
              child: SizedBox(
                height: 47,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md)),
                  ),
                  child: Text(l.actionCancel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required TaskMenuAction action,
    bool destructive = false,
    bool enabled = true,
  }) {
    final color = destructive ? AppColors.negative : AppColors.textPrimary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.rowTitle.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
    // A disabled row (a series with history, §2b): 40 % opacity, no ink, no
    // callback; announced disabled with its title and subtitle read out.
    if (!enabled) {
      return Semantics(
        enabled: false,
        label: '$label. $subtitle',
        child: Opacity(opacity: 0.4, child: content),
      );
    }
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      child: content,
    );
  }
}

/// §3a — the no-history / archived hard-delete confirm. `forGood` picks the
/// second, "archived" wording (§D.4); otherwise the from-menu wording (§D.2
/// bottom): every entry stays in the Ledger, but the item leaves for good.
Future<bool> confirmDeleteTask(
  BuildContext context,
  AppStore store,
  Task task, {
  bool forGood = false,
}) {
  final l = AppLocalizations.of(context);
  final entries = store.paymentsForTask(task.id).length;
  return showDestructiveConfirm(
    context,
    title: forGood
        ? l.taDeleteForGoodTitle(task.title)
        : l.taDeleteTitle(task.title),
    message: forGood ? l.taDeleteForGoodBody : l.taLeavesSchedule,
    impact: [
      if (entries > 0) ImpactLine.kept(l.taEntriesStay(entries)),
      ImpactLine.kept(l.taLedgerUnchanged),
      if (forGood) ImpactLine.lost(l.taHistoryRemoved),
      ImpactLine.lost(l.taCantRestore),
    ],
    confirmLabel: forGood ? l.taDeleteForGood : l.tdDeleteConfirm,
  );
}

/// §3a / §D.2 — the Archive confirm. Accent, not red: archiving keeps the item.
Future<bool> confirmArchiveTask(
  BuildContext context,
  AppStore store,
  Task task,
) {
  final l = AppLocalizations.of(context);
  final done = store.paymentsForTask(task.id).length;
  return showDestructiveConfirm(
    context,
    title: l.taArchiveTitle(task.title),
    // Archiving happens now, so the body dates today, not the due date (B1).
    message: l.taArchiveBody(dayMonthYear(store.today, l)),
    impact: [
      if (done > 0) ImpactLine.kept(l.taKeptHistory(done)),
      ImpactLine.kept(l.taLedgerUnchanged),
      ImpactLine.kept(l.taRestoreAnyTime),
      ImpactLine.lost(l.taLeavesSchedule),
    ],
    confirmLabel: l.taArchive,
    confirmColor: AppColors.accent,
  );
}
