import 'package:flutter/widgets.dart';

/// The five bottom-navigation glyphs, drawn rather than taken from a font.
///
/// Material's icon set has no complete outline/filled pair for this particular
/// combination, and mixing families gives visibly different stroke weights —
/// which makes the bar look unsettled. Drawing them here guarantees one stroke
/// width (1.75) and one optical size across all five.
enum NavGlyph { balance, ledger, planner, insight, more }

class NavIcon extends StatelessWidget {
  const NavIcon({
    super.key,
    required this.glyph,
    required this.filled,
    required this.color,
    this.size = 24,
  });

  final NavGlyph glyph;
  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NavIconPainter(glyph: glyph, filled: filled, color: color),
      ),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter({
    required this.glyph,
    required this.filled,
    required this.color,
  });

  final NavGlyph glyph;
  final bool filled;
  final Color color;

  static const _stroke = 1.75;

  @override
  void paint(Canvas canvas, Size size) {
    // Glyphs are authored on a 24-unit grid and scaled to the requested size.
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case NavGlyph.balance:
        _balance(canvas, paint);
      case NavGlyph.ledger:
        _ledger(canvas, paint);
      case NavGlyph.planner:
        _planner(canvas, paint);
      case NavGlyph.insight:
        _insight(canvas, paint);
      case NavGlyph.more:
        _more(canvas, paint);
    }

    canvas.restore();
  }

  /// Donut chart with a quarter segment lifted out.
  void _balance(Canvas canvas, Paint paint) {
    const center = Offset(12, 12);
    if (filled) {
      canvas.drawCircle(center, 9, paint);
      // Punch the wedge out so the filled variant still reads as a chart.
      final wedge = Path()
        ..moveTo(12, 12)
        ..lineTo(12, 2.4)
        ..arcToPoint(
          const Offset(21.6, 12),
          radius: const Radius.circular(9.6),
          clockwise: true,
        )
        ..close();
      canvas.drawPath(wedge, Paint()..blendMode = BlendMode.clear);
      return;
    }
    canvas.drawCircle(center, 9, paint);
    canvas.drawLine(const Offset(12, 3), center, paint);
    canvas.drawLine(center, const Offset(21, 12), paint);
  }

  /// Open book.
  void _ledger(Canvas canvas, Paint paint) {
    final left = Path()
      ..moveTo(12, 6.5)
      ..cubicTo(10, 4.6, 7, 4.4, 4, 5)
      ..lineTo(4, 18)
      ..cubicTo(7, 17.4, 10, 17.6, 12, 19.5);
    final right = Path()
      ..moveTo(12, 6.5)
      ..cubicTo(14, 4.6, 17, 4.4, 20, 5)
      ..lineTo(20, 18)
      ..cubicTo(17, 17.4, 14, 17.6, 12, 19.5);

    if (filled) {
      canvas.drawPath(left..close(), paint);
      canvas.drawPath(right..close(), paint);
      return;
    }
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
    canvas.drawLine(const Offset(12, 6.5), const Offset(12, 19.5), paint);
  }

  /// Calendar.
  void _planner(Canvas canvas, Paint paint) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 5, 17, 15),
      const Radius.circular(3),
    );

    if (filled) {
      canvas.drawRRect(body, paint);
      final knock = Paint()..blendMode = BlendMode.clear;
      // Header band and two day marks, cleared out of the solid shape.
      canvas.drawLine(
        const Offset(4.5, 9.5),
        const Offset(19.5, 9.5),
        knock..strokeWidth = 1.4..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(const Offset(9, 14), 1.15, knock..style = PaintingStyle.fill);
      canvas.drawCircle(const Offset(15, 14), 1.15, knock);
      return;
    }
    canvas.drawRRect(body, paint);
    canvas.drawLine(const Offset(3.5, 9.5), const Offset(20.5, 9.5), paint);
    canvas.drawLine(const Offset(8, 3), const Offset(8, 6.5), paint);
    canvas.drawLine(const Offset(16, 3), const Offset(16, 6.5), paint);
  }

  /// Three bars.
  void _insight(Canvas canvas, Paint paint) {
    const bars = [
      Rect.fromLTRB(4.5, 13, 8, 20),
      Rect.fromLTRB(10.25, 8, 13.75, 20),
      Rect.fromLTRB(16, 4, 19.5, 20),
    ];
    for (final bar in bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(1.4)),
        paint,
      );
    }
  }

  /// Three dots.
  void _more(Canvas canvas, Paint paint) {
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final x in const [5.5, 12.0, 18.5]) {
      canvas.drawCircle(Offset(x, 12), filled ? 2.2 : 1.75, dot);
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.glyph != glyph || old.filled != filled || old.color != color;
}
