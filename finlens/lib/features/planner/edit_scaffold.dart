import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Cancel / title / Save shell shared by Edit Budget, Edit Goal and Edit Task
/// (specs 5.4, 5.6, 5.7 — all three use the same chrome).
class EditScaffold extends StatelessWidget {
  const EditScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.header,
  });

  final String title;
  final List<Widget> children;

  /// null disables Save — the form is incomplete.
  final VoidCallback? onSave;

  /// Optional block pinned under the header (e.g. a goal's progress bar).
  final Widget? header;

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
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(title, style: AppText.rowTitle),
                    ),
                  ),
                  TextButton(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSoft,
                      disabledForegroundColor: AppColors.textTertiary,
                      textStyle: AppText.button,
                    ),
                    child: const Text('Save'),
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
