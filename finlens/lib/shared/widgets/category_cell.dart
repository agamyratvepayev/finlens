import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// One category tile: a colour-tinted square above a two-line, centred label.
/// Shared by the Quick Add category picker grid (54 pt, `reserveTwoLines: true`)
/// and the More > Categories management grid (its original 46 pt, variable
/// height — the defaults leave it byte-for-byte unchanged). The `selected` state
/// fills the tile with the colour, whitens the glyph with a 2 pt ring, and
/// weights the label; the management grid always passes `selected: false`.
///
/// The whole cell is one opaque tap target, so tapping the *label* selects the
/// category just as tapping the tile does (spec §2). A category carrying an
/// [Category.emoji] renders that glyph on a tinted tile instead of the icon; the
/// emoji keeps its own colours (spec §7).
class CategoryCell extends StatelessWidget {
  const CategoryCell({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.tileSize = 46,
    this.reserveTwoLines = false,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  /// Fixed tile edge in pt — 46 for the More grid, 54 for the picker (spec §2).
  /// The glyph is ~half the tile; on narrower devices the *gaps* shrink, never
  /// this size (the grid owns the gap, spec §9).
  final double tileSize;

  /// When true the label always occupies two lines' worth of height, so every
  /// cell is the same height and rows never stagger (spec §2). It grows with the
  /// text scale, so five columns still hold at 130 % (spec §9). Off by default so
  /// the management grid keeps its original content-height cells.
  final bool reserveTwoLines;

  @override
  Widget build(BuildContext context) {
    final hasEmoji = category.hasEmoji;
    // Roughly half the tile: 22 at the More grid's 46 pt, 26 at the picker's 54 pt
    // (spec §2). Kept as an exact step so the existing 46 pt grid is unchanged.
    final glyphSize = tileSize >= 50 ? 26.0 : 22.0;
    final radius = tileSize >= 50 ? 14.0 : 13.0;
    // Emoji: always a tinted tile (the glyph carries its own colours), a touch
    // stronger when selected. Icons: filled with the colour when selected, else
    // the same dark tint. Matches the icon picker's AccountGlyphTile so the two
    // never drift.
    final Color bg = hasEmoji
        ? Color.alphaBlend(
            category.color.withValues(alpha: selected ? 0.28 : 0.18),
            AppColors.surfaceAlt)
        : (selected
            ? category.color
            : Color.alphaBlend(
                category.color.withValues(alpha: 0.18), AppColors.surfaceAlt));

    const labelStyleBase = TextStyle(fontSize: 12, height: 1.25);
    final label = Text(
      category.name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: labelStyleBase.copyWith(
        color: selected ? Colors.white : AppColors.sheetAccountName,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                border:
                    selected ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: hasEmoji
                  ? Text(category.emoji!,
                      style: TextStyle(fontSize: glyphSize))
                  : Icon(
                      category.icon,
                      size: glyphSize,
                      color: selected ? Colors.white : category.color,
                    ),
            ),
            const SizedBox(height: 6),
            if (reserveTwoLines)
              // Two lines of the label's own line-height, scaled with the user's
              // text setting so the row grows rather than clipping at 130 %.
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(12) * 1.25 * 2,
                child: label,
              )
            else
              label,
          ],
        ),
      ),
    );
  }
}

/// The create cell, last in a category grid section (spec 4.1 / §2): a dashed
/// accent tile + "New".
class NewCategoryCell extends StatelessWidget {
  const NewCategoryCell({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).qaNewCategory,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _DashedRRectPainter(
                color: AppColors.accent,
                radius: 13,
                strokeWidth: 1.5,
              ),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.sheetCard,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 22, color: AppColors.accentLight),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).qaNewShort,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: AppColors.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strokes a dashed rounded rectangle — Flutter has no dashed border built in.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth,
          size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
