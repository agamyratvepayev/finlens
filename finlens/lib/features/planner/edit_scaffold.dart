import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/widgets/form_kit.dart';

/// Cancel / title / Save shell shared by Edit Budget, Edit Goal and Edit Task
/// (specs 5.4, 5.6, 5.7 — all three use the same chrome).
class EditScaffold extends StatelessWidget {
  const EditScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.header,
    this.type,
    this.onTypeTap,
  }) : assert((type == null) == (onTypeTap == null),
            'a pill is a type and a way to change it, or neither');

  /// The centred title, used when no [type] is supplied.
  final String title;
  final List<Widget> children;

  /// null disables Save — the form is incomplete.
  final VoidCallback? onSave;

  /// Optional block pinned under the header (e.g. a goal's progress bar).
  final Widget? header;

  /// When set, the centre slot is a [TypePill] for this type instead of [title].
  /// Only creation screens pass it: editing an existing record has nothing to
  /// switch to, so those screens keep the plain title.
  final QuickAddType? type;
  final VoidCallback? onTypeTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.sm,
                Insets.sm,
                Insets.sm,
                Insets.sm,
              ),
              // Kept on centre alignment (task 031): Cancel and Save are Material
              // TextButtons whose equal 48pt tap targets carry *different*
              // internal baselines — Cancel resolves to Material's labelLarge
              // (line height 1.43) while Save uses AppText.button (no height) and
              // the centre slot is a shorter Text/TypePill. Baseline-aligning
              // them would grow this header by that baseline gap (~1px), which the
              // task's boundary forbids. The picker sheets have no such mismatch.
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(AppLocalizations.of(context).actionCancel),
                  ),
                  Expanded(
                    child: Center(
                      child: type == null
                          ? Text(title, style: AppText.rowTitle)
                          : TypePill(
                              typeName:
                                  type!.label(AppLocalizations.of(context)),
                              accent: type!.color,
                              onTap: onTypeTap,
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSoft,
                      disabledForegroundColor: AppColors.textTertiary,
                      textStyle: AppText.button,
                    ),
                    child: Text(AppLocalizations.of(context).actionSave),
                  ),
                ],
              ),
            ),
            ?header,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  top: Insets.sm,
                  bottom: Insets.xxl,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
