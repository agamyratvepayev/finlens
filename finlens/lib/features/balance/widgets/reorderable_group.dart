import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

/// A drag payload tagged with its owning group, so nested reorder groups (a
/// section's categories vs a category's accounts) never accept one another's
/// drags even though both carry an `int` index.
@immutable
class _ReorderToken {
  const _ReorderToken(this.tag, this.index);
  final Object tag;
  final int index;
}

/// One independent reorder group: a non-scrolling column of rows the user can
/// press-and-hold to drag *within this group only*.
///
/// Containment is structural, not policed — because a group's drop targets exist
/// only inside itself, a lifted row simply has nowhere illegal to land. When the
/// finger wanders outside, the insertion point clamps to the group's nearest
/// end and stays there; releasing drops it at that clamped slot. There is no
/// rejected drop.
///
/// The whole row is the drag target (no handle). A quick tap falls through to
/// the row's own gesture (navigation); only a press-and-hold lifts it, so a fast
/// flick still scrolls the parent list.
class ReorderableGroup<T> extends StatefulWidget {
  const ReorderableGroup({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    required this.semanticLabel,
    this.onDragStart,
    this.onDragEnd,
    this.scrollController,
    this.delay = const Duration(milliseconds: 500),
    this.enabled = true,
  });

  final List<T> items;

  /// When false, a long press does nothing — no lift, no haptic — and the rotor
  /// `Move up/down` actions are absent. Used to disable dragging while a search
  /// query narrows the list. Toggling this never remounts the rows, so search
  /// open/close does not disturb them.
  final bool enabled;

  /// Builds a row's visible content, including its own tap handlers.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Called once on drop with the moved item and the index it should sit
  /// *before* in the current visible list (`items.length` = dropped at the end).
  /// Never called for a no-op (dropped back where it started).
  final void Function(T moved, int visibleTargetIndex) onReorder;

  /// Row a11y label, e.g. "Cash, position 2 of 4 in Spendable".
  final String Function(T item, int index, int count) semanticLabel;

  final ValueChanged<T>? onDragStart;
  final VoidCallback? onDragEnd;

  /// The parent scrollable, for edge autoscroll while dragging.
  final ScrollController? scrollController;

  /// Press-and-hold delay before a row lifts. A category (outer) group uses the
  /// default; an account (inner) group uses a shorter one, so pressing an
  /// account row wins the gesture arena and never lifts its parent category.
  final Duration delay;

  @override
  State<ReorderableGroup<T>> createState() => _ReorderableGroupState<T>();
}

class _ReorderableGroupState<T> extends State<ReorderableGroup<T>> {
  /// Identifies this group's drags, so its drop targets ignore foreign ones.
  final Object _tag = Object();

  /// Index of the row currently lifted, or null when idle.
  int? _dragIndex;

  /// Where the dashed placeholder sits: "before item [_insertIndex]", with
  /// `items.length` meaning "after the last item".
  int _insertIndex = 0;

  /// The lifted row's measured size, so the placeholder and the floating proxy
  /// match it exactly.
  Size _dragSize = Size.zero;

  /// One key per row, used to measure the lifted row.
  List<GlobalKey> _keys = const [];

  /// Drives continuous edge autoscroll: a repeating timer while the finger
  /// rests in the edge margin, and the per-tick delta (0 = outside the margin).
  Timer? _autoscrollTimer;
  double _autoscrollDelta = 0;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant ReorderableGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A drag computes its move against the list it started on. If the data
    // changes underneath a live drag — a background refresh, an Undo firing, a
    // store mutation — cancel it and commit nothing: any move now would be
    // against a stale list. Element identity (not deep equality) is the right
    // test: a plain rebuild hands back the same instances in the same order, so
    // it does not trip; a reorder, insert or delete does.
    if (_dragIndex != null && !_sameItems(oldWidget.items, widget.items)) {
      _cancelDrag();
    }
    if (widget.items.length != _keys.length) _syncKeys();
  }

  bool _sameItems(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _autoscrollTimer?.cancel();
    super.dispose();
  }

  void _syncKeys() {
    _keys = List.generate(widget.items.length, (_) => GlobalKey());
  }

  int get _count => widget.items.length;

  void _startDrag(int index) {
    final box = _keys[index].currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _dragIndex = index;
      _insertIndex = index;
      _dragSize = box?.size ?? Size.zero;
    });
    HapticFeedback.lightImpact();
    widget.onDragStart?.call(widget.items[index]);
  }

  void _updateInsert(int target) {
    final clamped = target.clamp(0, _count);
    if (clamped == _insertIndex) return;
    setState(() => _insertIndex = clamped);
    // Each reorder step ticks, matching the app's light-impact convention.
    HapticFeedback.lightImpact();
  }

  void _endDrag() {
    final from = _dragIndex;
    final to = _insertIndex;
    _stopAutoscroll();
    setState(() {
      _dragIndex = null;
      _dragSize = Size.zero;
    });
    widget.onDragEnd?.call();
    if (from == null) return;
    // The list may have shrunk since the lift (guard against a stale index).
    if (from >= _count) return;
    // Dropping just above or just below the origin is a no-op.
    if (to == from || to == from + 1) return;
    // A completed move that actually changes the order gets a firmer landing
    // haptic; no-ops above stay silent.
    HapticFeedback.mediumImpact();
    widget.onReorder(widget.items[from], to);
  }

  /// Abandons an in-flight drag without committing: clears the lift so the
  /// natural `onDragEnd` from the gesture becomes a no-op, stops autoscroll and
  /// resets the parent's dimming. `onDragEnd` is deferred a frame because this
  /// runs inside `didUpdateWidget` (mid-build) and it drives parent setState.
  void _cancelDrag() {
    _dragIndex = null;
    _dragSize = Size.zero;
    _stopAutoscroll();
    final cb = widget.onDragEnd;
    if (cb != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cb());
    }
  }

  // ── Autoscroll ────────────────────────────────────────────────────────────
  // A timer, not a per-move nudge: while the finger rests inside the edge
  // margin — even held perfectly still — the parent keeps scrolling, clamped to
  // the scroll extent. The group is one contiguous block, so scrolling past it
  // is harmless; the drop target still clamps to the group.

  void _updateAutoscroll(Offset globalPointer) {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      _stopAutoscroll();
      return;
    }
    final scrollBox =
        controller.position.context.storageContext.findRenderObject();
    if (scrollBox is! RenderBox) {
      _stopAutoscroll();
      return;
    }
    final top = scrollBox.localToGlobal(Offset.zero).dy;
    final bottom = top + scrollBox.size.height;
    const margin = 64.0;
    const step = 14.0;

    double delta = 0;
    if (globalPointer.dy < top + margin) {
      delta = -step;
    } else if (globalPointer.dy > bottom - margin) {
      delta = step;
    }
    _autoscrollDelta = delta;
    if (delta == 0) {
      _stopAutoscroll();
      return;
    }
    _autoscrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickAutoscroll(),
    );
  }

  void _tickAutoscroll() {
    final controller = widget.scrollController;
    if (_dragIndex == null ||
        _autoscrollDelta == 0 ||
        controller == null ||
        !controller.hasClients) {
      _stopAutoscroll();
      return;
    }
    final next = (controller.offset + _autoscrollDelta)
        .clamp(0.0, controller.position.maxScrollExtent);
    if (next != controller.offset) controller.jumpTo(next);
  }

  void _stopAutoscroll() {
    _autoscrollTimer?.cancel();
    _autoscrollTimer = null;
    _autoscrollDelta = 0;
  }

  // ── Rotor (non-gesture) moves ─────────────────────────────────────────────

  void _rotorMove(int index, int delta) {
    // Move up: land before the previous row. Move down: land after the next row
    // (i.e. before the row two ahead, or at the end).
    final target = delta < 0 ? index - 1 : index + 2;
    widget.onReorder(widget.items[index], target.clamp(0, _count));
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _count; i++) {
      if (_dragIndex != null && _insertIndex == i) children.add(_placeholder());
      children.add(_row(i));
    }
    if (_dragIndex != null && _insertIndex == _count) {
      children.add(_placeholder());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _placeholder() => _DashedPlaceholder(
        // A stable key so inserting/moving it never re-matches a keyed row.
        key: const ValueKey('reorder-placeholder'),
        height: _dragSize.height,
        width: _dragSize.width,
      );

  Widget _row(int index) {
    final item = widget.items[index];

    // No rotor moves when dragging is disabled (an active search): the gesture
    // affordance and its accessible equivalent go together.
    final actions = <CustomSemanticsAction, VoidCallback>{};
    if (widget.enabled && index > 0) {
      actions[const CustomSemanticsAction(label: 'Move up')] =
          () => _rotorMove(index, -1);
    }
    if (widget.enabled && index < _count - 1) {
      actions[const CustomSemanticsAction(label: 'Move down')] =
          () => _rotorMove(index, 1);
    }

    // The GlobalKey sits on the whole row so its element (and the live
    // LongPressDraggable inside it) stays mounted as the placeholder is inserted
    // and moved around it — a rebuild here must never cancel the drag.
    return Semantics(
      key: _keys[index],
      container: true,
      label: widget.semanticLabel(item, index, _count),
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: DragTarget<_ReorderToken>(
        // Only react to this group's own drags, never a nested/sibling group's.
        onWillAcceptWithDetails: (d) => d.data.tag == _tag,
        onMove: (details) {
          _updateAutoscroll(details.offset);
          final box = _keys[index].currentContext?.findRenderObject();
          if (box is! RenderBox) return;
          final localY = box.globalToLocal(details.offset).dy;
          _updateInsert(localY < box.size.height / 2 ? index : index + 1);
        },
        builder: (context, _, _) => LongPressDraggable<_ReorderToken>(
          data: _ReorderToken(_tag, index),
          axis: Axis.vertical,
          delay: widget.delay,
          // 0 disables the lift entirely (search active) without rebuilding the
          // subtree, so the row's own tap/scroll gestures win untouched.
          maxSimultaneousDrags: widget.enabled ? null : 0,
          // The delay is what lets a fast vertical flick scroll instead of lift.
          feedback: _proxy(context, item),
          // The origin collapses; the dashed placeholder carries the position.
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () => _startDrag(index),
          onDragUpdate: (d) => _updateAutoscroll(d.globalPosition),
          onDragEnd: (_) => _endDrag(),
          child: widget.itemBuilder(context, item),
        ),
      ),
    );
  }

  Widget _proxy(BuildContext context, T item) {
    final child = widget.itemBuilder(context, item);
    return Transform.scale(
      scale: 1.02,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: _dragSize.width == 0 ? null : _dragSize.width,
          decoration: BoxDecoration(
            color: AppColors.dragLifted,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The dashed outline left in a lifted row's slot. 1.5pt dashed accent @ 60%,
/// a faint accent fill, radius 9 — sized to the row it replaced.
class _DashedPlaceholder extends StatelessWidget {
  const _DashedPlaceholder({
    super.key,
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height == 0 ? null : height,
      width: width == 0 ? null : width,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.accent.withValues(alpha: 0.6),
          fill: AppColors.accent.withValues(alpha: 0.06),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(9),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          stroke,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
