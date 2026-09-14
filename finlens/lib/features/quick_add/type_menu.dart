import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'pickers.dart';
import 'quick_add_sheet.dart';

/// The `What are you adding?` sheet (§3). Returns the picked type, or null when
/// the sheet was dismissed. The caller decides what a pick means — Quick Add
/// switches config in place, the full-screen creation forms hand off to
/// [switchCreationType].
Future<QuickAddType?> showQuickAddTypeMenu(
  BuildContext context, {
  required QuickAddType current,
}) {
  return showAppSheet<QuickAddType>(
    context,
    title: AppLocalizations.of(context).qaWhatAdding,
    // Seven fixed rows: hug them instead of opening at a fraction (task 20).
    contentSized: true,
    builder: (sheetContext, controller) => ListView(
      controller: controller,
      // shrinkWrap so the list is only as tall as its rows; the sheet's outer
      // Flexible caps it and it scrolls once the rows outgrow the sheet.
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        0,
        Insets.gutter,
        Insets.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < QuickAddType.values.length; i++) ...[
                if (i > 0) const RowDivider(indent: Insets.md),
                _typeOption(sheetContext, QuickAddType.values[i], current),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _typeOption(
  BuildContext sheetContext,
  QuickAddType type,
  QuickAddType current,
) {
  return InkWell(
    onTap: () => Navigator.of(sheetContext).pop(type),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: type.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
              child: Text(type.label(AppLocalizations.of(sheetContext)),
                  style: AppText.rowTitle)),
          if (type == current)
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.accent,
            ),
        ],
      ),
    ),
  );
}

/// Replace this creation screen with the one for [next].
///
/// The current screen is popped first, so `Cancel` on the new screen returns
/// where the old one came from rather than to a half-filled form the user just
/// left. [showQuickAdd] then routes: the four transaction types and New task
/// open the Quick Add shell, New goal opens the goal editor, New budget asks
/// for a category first.
///
/// Runs off the root navigator's overlay context, which is a descendant of the
/// root navigator (so `Navigator.of` and `showModalBottomSheet` resolve to it)
/// and outlives the popped screen — the screen's own context does not.
Future<void> switchCreationType(BuildContext context, QuickAddType next) {
  final nav = Navigator.of(context, rootNavigator: true);
  final overlay = nav.overlay!.context;
  nav.pop();
  return showQuickAdd(overlay, type: next);
}
