import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale lifted from the mockups. Amounts use tabular figures so digits
/// stay column-aligned in lists.
abstract final class AppText {
  static const _amountFeatures = [FontFeature.tabularFigures()];

  /// Screen title in the header ("Balance", "Assets").
  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  /// The single hero metric each tab answers with (spec 6.2 "Tek özet kuralı").
  static const hero = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
    fontFeatures: _amountFeatures,
  );

  /// Uppercase, letter-spaced section label ("NET WORTH", "ASSETS").
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.9,
  );

  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const rowSubtitle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: _amountFeatures,
  );

  static const amountLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: _amountFeatures,
  );

  static const delta = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    fontFeatures: _amountFeatures,
  );

  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const caption = TextStyle(
    fontSize: 11.5,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

  static const navLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // ── Balance type scale ──
  // Sizes are kept far enough apart that hierarchy reads instantly; two sizes
  // within ~1px of each other read as a mistake rather than a distinction.
  // Every row sets an explicit height, because an undefined line height
  // resolves differently per device and produces spacing that looks uneven
  // without an obvious cause.

  /// Header amount.
  static const heroAmount = TextStyle(
    fontSize: 33,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.92,
    color: AppColors.textPrimary,
    fontFeatures: _amountFeatures,
  );

  /// Uppercase label beside the indicator dots.
  static const sectionLabel = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  /// Uppercase list section header (ASSETS / LIABILITIES).
  static const listSectionLabel = TextStyle(
    fontSize: 10.5,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.textSecondary,
  );

  /// The single section total that now lives on the ASSETS / LIABILITIES
  /// header (the bar's duplicate label row is gone). Coloured by direction at
  /// the call site — [AppColors.positive] for assets, [AppColors.negative] for
  /// liabilities.
  static const sectionTotal = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontFeatures: _amountFeatures,
  );

  /// Group-row second line — "4 accounts · 10.0%". The share sits here in
  /// neutral grey; on this screen green/red mean money direction only, and a
  /// share is neither a gain nor a loss.
  static const groupSubtitle = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  static const groupName = TextStyle(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const groupAmount = TextStyle(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.amountGroup,
    fontFeatures: _amountFeatures,
  );

  static const accountCount = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const childName = TextStyle(
    fontSize: 13.5,
    height: 1.25,
    fontWeight: FontWeight.w400,
    color: AppColors.nameChild,
  );

  /// One step below [groupAmount] in both colour and weight. Flutter's
  /// FontWeight is quantised to 100s, so the intended 650/550 pair lands on
  /// 600/500 — the same two-level relationship, one full step apart.
  static const childAmount = TextStyle(
    fontSize: 13.5,
    height: 1.25,
    fontWeight: FontWeight.w500,
    color: AppColors.amountChild,
    fontFeatures: _amountFeatures,
  );

  static const datePill = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const sharePercent = TextStyle(
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontFeatures: _amountFeatures,
  );

  static const asOfLine = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.accentSoft,
  );
}
