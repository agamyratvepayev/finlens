import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Spacing and radius tokens. Screens reference these instead of raw numbers so
/// rhythm stays consistent across the 29 documented screens.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  /// Horizontal page gutter used by every screen. Headers, toolbars and list
  /// rows all use it, so they align pixel-for-pixel down the page.
  static const gutter = 20.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const card = 16.0;
  static const sheet = 22.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.negative,
      ),
      dividerColor: AppColors.divider,
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.title,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppText.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );
  }
}
