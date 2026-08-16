import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// Spec 2.2 — swipe a row left to reveal Edit / Copy / Delete.
///
/// Built by hand rather than pulling in a slidable package: three fixed-width
/// actions behind the row is the whole requirement, and only one row may be
/// open at a time.
class SwipeActionItem {
  const SwipeActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 68,
    this.hintOnFirstBuild = false,
  });

  final Widget child;
  final List<SwipeActionItem> actions;
  final double actionWidth;

  /// Only the ledger's first row opts in, so the hint fires once.
  final bool hintOnFirstBuild;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

/// Tracks the row that is currently open so a new swipe closes the previous.
final ValueNotifier<Object?> _openRow = ValueNotifier<Object?>(null);

/// Closes whichever row is open. The list calls this on scroll and on taps
/// outside the strip.
void closeOpenSwipeRow() => _openRow.value = null;

/// Nudges the first row open and back, once, to advertise the gesture.
final ValueNotifier<int> _hintTick = ValueNotifier<int>(0);
void hintSwipeRow() => _hintTick.value++;

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double get _maxDrag => widget.actions.length * widget.actionWidth;

  @override
  void initState() {
    super.initState();
    _openRow.addListener(_onOpenRowChanged);
    if (widget.hintOnFirstBuild) _hintTick.addListener(_playHint);
  }

  /// ~40px out and back — the standard "there is something here" nudge.
  Future<void> _playHint() async {
    if (!mounted) return;
    await _controller.animateTo(40 / _maxDrag,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    if (!mounted) return;
    await _controller.animateTo(0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeIn);
  }

  void _onOpenRowChanged() {
    if (_openRow.value != this && _controller.value > 0) {
      _controller.animateTo(0, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _openRow.removeListener(_onOpenRowChanged);
    _hintTick.removeListener(_playHint);
    if (_openRow.value == this) _openRow.value = null;
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.animateTo(0, curve: Curves.easeOut);
    if (_openRow.value == this) _openRow.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final next = _controller.value - d.primaryDelta! / _maxDrag;
        // Rubber band past the strip: the row resists rather than sliding off
        // screen, and the give tells the finger it has reached the end.
        _controller.value =
            next > 1 ? 1 + (next - 1) * 0.12 : next.clamp(0.0, 1.0);
      },
      onHorizontalDragEnd: (d) {
        final flung = d.primaryVelocity != null && d.primaryVelocity! < -250;
        final shouldOpen = flung || _controller.value > 0.4;
        if (d.primaryVelocity != null && d.primaryVelocity! > 250) {
          _close();
          return;
        }
        if (shouldOpen) {
          if (_openRow.value != this) HapticFeedback.lightImpact();
          _controller.animateTo(1, curve: Curves.easeOut);
          _openRow.value = this;
        } else {
          _close();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.value * _maxDrag;
          return Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ClipRect(
                    child: SizedBox(
                      width: offset,
                      child: OverflowBox(
                        alignment: Alignment.centerRight,
                        maxWidth: _maxDrag,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final a in widget.actions)
                              _ActionButton(
                                item: a,
                                width: widget.actionWidth,
                                onTap: () {
                                  _close();
                                  a.onTap();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(-offset, 0),
                child: child,
              ),
            ],
          );
        },
        child: ColoredBox(color: AppColors.surface, child: widget.child),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final SwipeActionItem item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: double.infinity,
        color: item.color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
