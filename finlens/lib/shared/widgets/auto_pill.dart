import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The `auto` pill (task 066 §5e, moved to shared for task 067.1 §3): a small
/// accent-tinted chip marking a value the form derived rather than the user
/// typed — the goal's computed half, the budget's derived name. Its key is
/// [AppLocalizations.goalAuto] and its look is unchanged.
class AutoPill extends StatelessWidget {
  const AutoPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tint(AppColors.accent, 0.18),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        AppLocalizations.of(context).goalAuto,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.accentLight,
        ),
      ),
    );
  }
}
