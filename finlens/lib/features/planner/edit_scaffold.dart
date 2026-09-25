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
    this.hero,
    this.footer,
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
  /// switch to, so those screens keep the plain title. In creation the whole
  /// chrome becomes the creation session's: a [FormNavBar] (50 pt), a black
  /// [AppColors.formBg] ground and the [hero] slot below the bar — identical to
  /// Quick Add's, so switching type from the pill moves nothing above the fold
  /// (task 058.2 §5).
  final QuickAddType? type;
  final VoidCallback? onTypeTap;

  /// The name field, drawn in the creation session's own geometry: 12 pt under
  /// the nav bar, [kFormMargin] each side, 48 · s tall, surfaceAlt, radius 14 —
  /// the same field Quick Add's TextHero draws, so switching type from the pill
  /// moves nothing above the fold. Only creation screens pass it; editing keeps
  /// the name field as a row inside its first card.
  final Widget? hero;

  /// Pinned below the scrolling list — the docked numeric keypad when an amount
  /// field on the form holds focus. Null keeps the old full-height list.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // A type is set on exactly the creation screens (per the assert). There, the
    // chrome is the creation session's — one bar, one ground, one hero — so a
    // type switch from the pill leaves everything above the name field still.
    final creating = type != null;
    return Scaffold(
      // Creation shares Quick Add's black ground; editing keeps the app bg.
      backgroundColor: creating ? AppColors.formBg : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (creating)
              FormNavBar(
                typeName: type!.label(AppLocalizations.of(context)),
                accent: type!.color,
                onCancel: () => Navigator.of(context).pop(),
                onTypeTap: onTypeTap,
                // The bottom Save is Quick Add's; here the nav bar is the only
                // commit. A null [onSave] means the form is incomplete → grey.
                onSave: onSave ?? () {},
                canSave: onSave != null,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.sm,
                  Insets.sm,
                  Insets.sm,
                  Insets.sm,
                ),
                // Kept on centre alignment (task 031): Cancel and Save are
                // Material TextButtons whose equal 48pt tap targets carry
                // *different* internal baselines — Cancel resolves to Material's
                // labelLarge (line height 1.43) while Save uses AppText.button
                // (no height) and the centre slot is a shorter Text.
                // Baseline-aligning them would grow this header by that baseline
                // gap (~1px), which the task's boundary forbids.
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
                      child: Text(AppLocalizations.of(context).actionSave),
                    ),
                  ],
                ),
              ),
            // The hero sits directly under the bar in the creation session's
            // geometry — 12·s below the bar, [kFormMargin] each side, and 12·s of
            // air to the first card (§5b, matching the Schedule form's D.6). The
            // 12·s above the bar equals Quick Add's ListView top, so the name
            // field lands at the same y on both screens.
            if (creating && hero != null)
              Padding(
                padding: EdgeInsets.fromLTRB(kFormMargin,
                    12 * formScale(context), kFormMargin, 12 * formScale(context)),
                child: hero!,
              ),
            ?header,
            Expanded(
              child: ListView(
                // Creation with a hero: the hero already carries the 12 above the
                // first card, so the list starts flush. Creation with no hero
                // (the budget editor, §5e): the list carries the 12 itself.
                // Editing keeps its Insets.sm top.
                padding: EdgeInsets.only(
                  top: creating
                      ? (hero != null ? 0.0 : 12 * formScale(context))
                      : Insets.sm,
                  bottom: Insets.xxl,
                ),
                children: children,
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
