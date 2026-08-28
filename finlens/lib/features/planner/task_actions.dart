import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The four lifecycle actions behind `•••` (§8). Each is genuinely different
/// from the other three; the sheet returns which one the user chose and the
/// caller performs it (so navigation stays with the screen).
enum TaskMenuAction { edit, skip, pause, delete }

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
    final payments = store.paymentsForTask(task.id).length;
    final next = task.nextOccurrence(task.dueDate);

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
            if (task.isRecurring)
              _item(
                context,
                icon: Icons.skip_next_rounded,
                label: l.tmSkip,
                subtitle: l.tmSkipSub(dayMonth(task.dueDate, l), dayMonth(next, l)),
                action: TaskMenuAction.skip,
              ),
            _item(
              context,
              icon: Icons.pause_circle_outline_rounded,
              label: l.tmPause,
              subtitle: l.tmPauseSub,
              action: TaskMenuAction.pause,
            ),
            _item(
              context,
              icon: Icons.delete_outline_rounded,
              label: l.tmDelete,
              subtitle: l.tmDeleteSub(payments),
              action: TaskMenuAction.delete,
              destructive: true,
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
  }) {
    final color = destructive ? AppColors.negative : AppColors.textPrimary;
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      child: Padding(
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
                  Text(label,
                      style: AppText.rowTitle.copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppText.caption.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// §8.1 — the delete confirmation, reusing the standard ImpactLine sheet.
/// (The spec's "Pause instead" secondary action cannot be expressed by
/// `showDestructiveConfirm` without forking it, so it is omitted — see report.)
Future<bool> confirmDeleteTask(
  BuildContext context,
  AppStore store,
  Task task,
) {
  final l = AppLocalizations.of(context);
  final payments = store.paymentsForTask(task.id).length;
  return showDestructiveConfirm(
    context,
    title: l.tdDeleteTitle(task.title),
    message: l.tdDeleteMsg,
    impact: [
      ImpactLine.kept(l.tdKeptPayments(payments)),
      ImpactLine.kept(l.tdKeptBalances),
      ImpactLine.kept(l.tdKeptHistory),
      ImpactLine.lost(l.tdLostSchedule),
      ImpactLine.lost(l.tdLostReminders),
    ],
    confirmLabel: l.tdDeleteConfirm,
  );
}
