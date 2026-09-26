import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The one place a budget is removed (task 067.3 §4c). Both confirmations that
/// existed before — the budget detail's destructive sheet for a monthly
/// single-category budget (→ [AppStore.removeBudget], keeping the category and
/// its transactions) and the editor's dialog for any other budget (→
/// [AppStore.archiveBudget]) — moved here unchanged in text and effect.
///
/// Returns whether the budget was removed. It never pops a route: the detail and
/// the editor pop themselves after `true` as they always have, and the Budgets
/// tab's swipe pops nothing.
Future<bool> confirmAndRemoveBudget(
    BuildContext context, AppStore store, Budget b) async {
  final l = AppLocalizations.of(context);
  final monthlyCategory = b.scope == BudgetScope.categories &&
      b.period == BudgetPeriod.month &&
      b.repeats &&
      b.targets.length == 1;

  if (monthlyCategory) {
    final category = store.categoryById(b.targets.first);
    if (category == null) return false;
    final count = store.txnCountForCategory(category.id);
    final newTotal =
        store.totalBudget - (store.effectiveLimitOf(category) ?? 0);
    final ok = await showDestructiveConfirm(
      context,
      title: l.ebRemoveTitle(category.name),
      message: l.ebRemoveMsg,
      impact: [
        ImpactLine.kept(l.ebCategoryStays(category.name, count)),
        ImpactLine.lost(l.ebWarningsDisappear),
        ImpactLine.lost(
            l.ebTotalDrops(money(store.totalBudget), money(newTotal))),
      ],
      confirmLabel: l.ebRemoveBudget,
    );
    if (!ok) return false;
    store.removeBudget(category);
    return true;
  }

  // Any other budget (account / tag / non-monthly / multi-category): the
  // editor's dialog, archiving the budget object.
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceAlt,
      title: Text(l.ebRemoveTitle(b.name), style: AppText.rowTitle),
      content: Text(l.ebRemoveMsg, style: AppText.body.copyWith(fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.negative),
          child: Text(l.ebRemoveBudget),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  store.archiveBudget(b);
  return true;
}
