import 'package:flutter/material.dart';

/// A thin two-segment proportion bar — extracted from Balance's `_RatioBar`
/// (task 050) so Schedule's section totals can share it (task 062 §3c).
/// Balance keeps its 3 pt height and neutral empty track; Schedule passes
/// `height: 2` and never builds the empty state.
///
/// The bar always spans the available width. A parent column that hands its
/// children a loose width (min 0) would let a childless DecoratedBox size to
/// `constraints.smallest` — the one-sided and empty branches drew at 0 width
/// and the bar vanished. `width: double.infinity` makes every branch tight to
/// the available width, so all states share one geometry.
class RatioBar extends StatelessWidget {
  const RatioBar({
    super.key,
    required this.left,
    required this.right,
    required this.leftColor,
    required this.rightColor,
    this.height = 3,
    this.emptyColor,
  });

  /// The two magnitudes, both passed as positive numbers. [left] draws first.
  final double left;
  final double right;
  final Color leftColor;
  final Color rightColor;
  final double height;

  /// The flat track drawn when both sides are zero — no ratio to show. Null
  /// draws nothing at all (the caller hides the bar instead).
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: _fill(),
    );
  }

  Widget _fill() {
    final total = left + right;
    // No ratio to draw — a flat neutral track, and the guard that keeps the
    // division below safe.
    if (total <= 0) {
      return emptyColor == null ? const SizedBox.shrink() : _seg(emptyColor!);
    }
    // One side fully absent reads as a single solid bar, not a bar with a
    // 1-flex sliver of the other colour.
    if (right <= 0) return _seg(leftColor);
    if (left <= 0) return _seg(rightColor);

    final ratio = (right / total).clamp(0.0, 1.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: ((1 - ratio) * 1000).round().clamp(1, 1000),
          child: _seg(leftColor),
        ),
        const SizedBox(width: 1.5),
        Expanded(
          flex: (ratio * 1000).round().clamp(1, 1000),
          child: _seg(rightColor),
        ),
      ],
    );
  }

  Widget _seg(Color color) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
