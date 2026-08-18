import 'package:flutter/material.dart';

/// FinLens palette — dark-first, derived from the design mockups in the
/// Tech Spec v1.1. Semantic names only; screens never hard-code hex values.
abstract final class AppColors {
  // Surfaces
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF161618);
  static const surfaceAlt = Color(0xFF1C1C1E);
  static const surfaceHigh = Color(0xFF2A2A2C);
  static const divider = Color(0xFF2A2A2C);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFF636366);

  // Brand
  static const accent = Color(0xFF5E5CE6);
  static const accentSoft = Color(0xFF5E5CE6);

  /// Spec 6.2 "Yön ≠ renk": colour carries good/bad, arrows carry direction.
  static const positive = Color(0xFF30D158);
  static const negative = Color(0xFFFF453A);
  static const warning = Color(0xFFFF9F0A);
  static const info = Color(0xFF0A84FF);

  // Quick Add type accents, each with the dimmed pair the transaction form
  // uses for untyped decimals and the zero state. The accent says *what you
  // are creating*; it never colours the Save button, which stays [accent]
  // purple in every type so the one constant control stays recognisable.
  //
  // Goal is violet rather than brand purple on purpose: a goal amount in the
  // Save colour would read as an interactive control instead of data.
  static const expense = Color(0xFFFF453A);
  static const expenseDim = Color(0xFF4D2C2A);
  static const income = Color(0xFF30D158);
  static const incomeDim = Color(0xFF1C4A29);
  static const transfer = Color(0xFF0A84FF);
  static const transferDim = Color(0xFF0E3459);

  /// A transfer moves the user's own money between accounts — it is neither a
  /// gain nor a loss, so its row never borrows a category colour. The tile is
  /// the neutral elevated surface, the exchange glyph a muted foreground, and
  /// the amount sits in near-white rather than red or green.
  static const transferTileBg = Color(0xFF3A3A3C);
  static const transferGlyph = Color(0xFFAEAEB2);
  static const transferAmount = Color(0xFFEBEBF5);
  static const rebalance = Color(0xFFFF9F0A);
  static const rebalanceDim = Color(0xFF4D3208);
  static const goal = Color(0xFFBF5AF2);
  static const goalDim = Color(0xFF3D1D4D);
  static const task = Color(0xFF8E8E93);

  /// New Task's hero is text, so it never renders a dimmed amount — this only
  /// exists so every type can answer `accentDim` without a null check.
  static const taskDim = Color(0xFF3A3A3C);

  // ── Transaction form chrome ──
  // This screen sits on pure black rather than the app's near-black, so the
  // field cards read as raised without needing a border.
  static const formBg = Color(0xFF000000);
  static const fieldCard = Color(0xFF141416);
  static const formDim2 = Color(0xFF5E5E63);
  static const formChevron = Color(0xFF3F3F43);
  static const keyPressed = Color(0xFF3A3A3D);
  static const saveDisabledBg = Color(0xFF1C1C1F);
  static const saveDisabledFg = Color(0xFF4A4A4E);
  static const toggleOffFg = Color(0xFFC8C8CD);
  static const toggleOnFg = Color(0xFFA9A7FF);
  static const hintText = Color(0xFFB4B4B9);
  static const decimalKey = Color(0xFFC7C7CC);
  static const chipText = Color(0xFFD8D8DD);

  // Account-group accents (Balance / Assets / Liabilities). Spec groups all
  // borrowing accounts under one colour — "credit cards / loans red" — so
  // every liability group (credit cards, payables, bank loans) shares
  // `negative`, matching the "liabilities are red" rule used everywhere else.
  static const spendable = Color(0xFF30D158);
  static const receivables = Color(0xFF0A84FF);
  static const investments = Color(0xFF5E5CE6);
  static const valuables = Color(0xFFFF9F0A);
  static const creditCards = Color(0xFFFF453A);
  static const payables = Color(0xFFFF453A);
  static const bankLoans = Color(0xFFFF453A);

  // Balance list amount hierarchy. The amount column carries the same two
  // levels the name column does: a child amount sits one step below its
  // group's. Liability children get a muted red rather than grey — grey would
  // read as "not a liability" and break the rule that colour means direction.
  static const amountGroup = Color(0xFFFFFFFF);
  static const amountChild = Color(0xFFC7C7CC);
  static const amountGroupNeg = Color(0xFFFF453A);
  static const amountChildNeg = Color(0xFFD4564D);

  /// Child account name — kept below [amountChild] so that inside a child row
  /// the number stays the brighter of the two.
  static const nameChild = Color(0xFF8E8E93);

  // ── Ledger ──
  // Outflow rows use the muted [amountChildNeg] rather than [negative]; full
  // red is reserved for the active Out filter, so "this is money leaving" and
  // "you are filtering by it" stay distinguishable.
  static const chipBg = Color(0xFF232326);
  static const deleteText = Color(0xFFE08078);
  static const tagDot = Color(0xFFBF5AF2);
  static const stepperDisabled = Color(0xFF313134);

  /// Running balance and list line 3 — a step below [textSecondary] so the
  /// figure the row is actually about stays the brighter one.
  static const runningBalance = Color(0xFF48484C);

  /// The 6-swatch palette offered by New Category (spec 4.1).
  static const categoryPalette = <Color>[
    Color(0xFFF04438),
    Color(0xFFF5A524),
    Color(0xFF34C759),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF8E8E93),
  ];

  // ── Balance filter sheet ──
  // A denser utility surface that sits one step above [surfaceAlt] (the sheet
  // body). These have no equivalent in the ramps above, so they earn their own
  // semantic names rather than raw hex at the call site.
  static const sheetCard = Color(0xFF2C2C2E);
  static const sheetGrabber = Color(0xFF48484A);
  static const sheetAccountName = Color(0xFFEBEBF5);

  /// Hairline between an expanded category's account rows (white @ 7%).
  static const sheetRowDivider = Color(0x12FFFFFF);

  /// Background of a row lifted for reordering (press-and-hold on Balance).
  /// A step above [surfaceHigh] so the floating row reads as raised.
  static const dragLifted = Color(0xFF3A3A3C);

  // ── Same-transactions screen ──
  /// A lighter tint of [accent] for back/•••, the range value, "See all" and
  /// the range ✓ — brighter than the brand purple so it reads as a link.
  static const accentLight = Color(0xFFA5A3FF);

  /// Hairline between list/summary rows on the Same-transactions cards
  /// (white @ 6%), one step lighter than [sheetRowDivider].
  static const hairline = Color(0x0FFFFFFF);

  /// The emphasised variables in the frequency line ("4", "7 days").
  static const freqValue = Color(0xFFD4D4DA);

  /// Calendar day with no transactions under the current key.
  static const emptyDay = Color(0xFF4A4A4E);

  /// Tinted fill used by highlight cards and icon tiles.
  static Color tint(Color c, [double opacity = 0.16]) => c.withValues(alpha: opacity);
}
