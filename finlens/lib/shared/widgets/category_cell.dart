import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// One category tile: a 46 pt colour-tinted square above a two-line, centred
/// label (spec 4.1). Shared by the Quick Add category picker grid and the More >
/// Categories management grid so the two never drift — the geometry is fixed and
/// must not change. The `selected` state fills the tile with the colour, whitens
/// the glyph with a 2 pt ring, and weights the label; the management grid always
/// passes `selected: false`.
class CategoryCell extends StatelessWidget {
  const CategoryCell({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? category.color
                    : Color.alphaBlend(
                        category.color.withValues(alpha: 0.18),
                        AppColors.surfaceAlt),
                borderRadius: BorderRadius.circular(13),
                border:
                    selected ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Icon(
                category.icon,
                size: 22,
                color: selected ? Colors.white : category.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: selected ? Colors.white : AppColors.sheetAccountName,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
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
