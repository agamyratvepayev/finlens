import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Section label plus page-dot indicator, as one tappable unit.
///
/// This replaces a tab row: the dots say how many sections exist and which one
/// is showing, in the space a tab row would have spent a whole 44px line on.
/// Tapping advances one section and wraps at the end.
class SectionIndicator extends StatelessWidget {
  const SectionIndicator({
    super.key,
    required this.label,
    required this.count,
    required this.index,
    required this.onAdvance,
  });

  final String label;
  final int count;
  final int index;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAdvance,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppText.sectionLabel),
          const SizedBox(width: 9),
          // All bars are the same size now (14×6, radius 3); only the colour
          // marks the current section. Equal shapes read as one set far better
          // than one long bar among round dots, and the section's name sits
          // immediately to the left, so colour need not carry the cue alone.
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: Insets.xs),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 14,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? AppColors.accent : AppColors.textTertiary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A button in [ToolCluster] — 30×28, radius 8, surface fill.
class Tool {
  const Tool({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
    this.iconColor,
    this.semanticValue,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Brand fill + white icon, for a toggle that is currently "on".
  final bool filled;
  final String? tooltip;

  /// Overrides the icon colour *without* touching the background — the Balance
  /// filter button signals "active" by brightening its glyph one step (muted →
  /// high-emphasis) while its surface stays put. Null keeps the muted default.
  final Color? iconColor;

  /// Exposed as [Semantics.value]. For a button whose only visual change is a
  /// glyph fill, this is the sole cue a screen-reader user gets.
  final String? semanticValue;
}

/// The right-hand tool buttons. Shared by Balance and (next) Ledger.
class ToolCluster extends StatelessWidget {
  const ToolCluster({super.key, required this.tools});

  final List<Tool> tools;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tools.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          _ToolButton(tool: tools[i]),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});

  final Tool tool;

  @override
  Widget build(BuildContext context) {
    final iconColor = tool.filled
        ? Colors.white
        : (tool.iconColor ?? AppColors.textSecondary);
    return Semantics(
      button: true,
      label: tool.tooltip,
      value: tool.semanticValue,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tool.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 30,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tool.filled ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              // The glyph cross-fades and its colour eases when a tool flips
              // state (outline funnel → filled funnel on the filter button);
              // an unchanged tool renders an identical idle frame.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: Icon(
                  tool.icon,
                  key: ValueKey('${tool.icon.codePoint}-${iconColor.toARGB32()}'),
                  size: 15,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detects a deliberate horizontal swipe without stealing vertical scrolls.
///
/// It claims the horizontal drag from the gesture arena; any enclosing
/// scrollable keeps the vertical drag, so flicking down a long list never trips
/// a section change. A swipe commits on enough distance or a fast enough fling.
class HorizontalSectionSwipe extends StatefulWidget {
  const HorizontalSectionSwipe({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrevious,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  // A deliberate drag either travels far enough or is flung fast enough. The
  // distance floor can sit low because velocity now carries the short case: a
  // quick flick that covers little ground still reads as intentional. The
  // ±250 fling test mirrors [SwipeActions].
  static const _threshold = 40.0;
  static const _flingVelocity = 250.0;

  @override
  State<HorizontalSectionSwipe> createState() => _HorizontalSectionSwipeState();
}

class _HorizontalSectionSwipeState extends State<HorizontalSectionSwipe> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Opaque so the whole area is hit-testable: an empty section (a list with
      // no rows) has nothing under the finger, and deferToChild would leave the
      // drag unclaimed there — the bug this fixes. The gesture arena still hands
      // vertical drags to any enclosing scrollable, so only horizontal drags
      // reach these callbacks; no hand-rolled dominance test is needed.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final flung = v.abs() >= HorizontalSectionSwipe._flingVelocity;
        final far = _dx.abs() >= HorizontalSectionSwipe._threshold;
        if (!flung && !far) return;
        // Negative is leftward (a right-to-left swipe): it advances to the next
        // section (and wraps past the last); rightward goes back (and wraps past
        // the first), matching the platform carousel convention. A fling's sign
        // is authoritative; a slow drag uses net travel.
        final leftward = flung ? v < 0 : _dx < 0;
        leftward ? widget.onNext() : widget.onPrevious();
      },
      child: widget.child,
    );
  }
}
