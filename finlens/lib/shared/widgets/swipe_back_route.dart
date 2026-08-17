import 'package:flutter/material.dart';

/// A page route that adds an interactive, hold-then-drag-left "back" gesture on
/// top of the standard Material push.
///
/// The forward (push) transition is untouched — it still enters from the right.
/// Only while the user is driving the back gesture does the screen slide *left*
/// with the finger and exit left, so navigation reads as one continuous
/// leftward motion. The gesture itself lives in the screen (see
/// [SwipeBackController]); this route just exposes its animation controller and
/// swaps in the leftward transition while a user gesture is in progress.
class SwipeBackPageRoute<T> extends MaterialPageRoute<T> {
  SwipeBackPageRoute({required super.builder, super.settings});

  AnimationController? _controller;

  /// True only while *this* screen's back gesture is driving the transition.
  /// Gated on this rather than `navigator.userGestureInProgress` so a platform
  /// edge-swipe (which also sets that flag) keeps its own transition.
  bool _swipeBackActive = false;

  /// The route's primary transition controller, so the gesture can drive it
  /// 1 → 0 (exit) and back. Captured from [createAnimationController].
  AnimationController get swipeController => _controller!;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    _controller = controller;
    return controller;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // While the back gesture drives the controller, the screen translates left
    // (begin off-screen-left at value 0, rest at value 1). The push and the
    // back-button pop see `userGestureInProgress == false` and keep the stock
    // Material transition, so only the gesture reads as a leftward exit.
    if (_swipeBackActive) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    }
    return super.buildTransitions(context, animation, secondaryAnimation, child);
  }
}

/// Drives a [SwipeBackPageRoute]'s controller from a hold-then-drag gesture,
/// mirroring Flutter's own interactive-pop controller but leftward and
/// hold-armed. The screen creates one when its back gesture arms.
class SwipeBackController {
  SwipeBackController({required this.route, required this.width}) {
    route._swipeBackActive = true; // switches on the leftward transition
    // Marks a user gesture so the route beneath is painted during the drag and
    // the transition is treated as interactive.
    _navigator.didStartUserGesture();
  }

  final SwipeBackPageRoute route;
  final double width;

  AnimationController get _controller => route.swipeController;
  NavigatorState get _navigator => route.navigator!;

  /// Screen follows the finger 1:1: [dragLeft] is how far the finger has moved
  /// left of the arm point (points, >= 0).
  void update(double dragLeft) {
    _controller.value = (1 - dragLeft / width).clamp(0.0, 1.0);
  }

  /// Release: commit the pop when dragged past 40% of the width, or flung left
  /// faster than 700 pt/s; otherwise snap back to rest over 220 ms.
  void end(double velocityX) {
    final commit = _controller.value < 0.6 || velocityX < -700;
    if (commit) {
      // Pops while the gesture is active, so the controller animates 1 → 0 with
      // the leftward transition and the route is removed at the end.
      _navigator.pop();
    } else {
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.decelerate,
      );
    }
    void finish() {
      _navigator.didStopUserGesture();
      route._swipeBackActive = false;
    }

    if (_controller.isAnimating) {
      late final AnimationStatusListener onDone;
      onDone = (status) {
        finish();
        _controller.removeStatusListener(onDone);
      };
      _controller.addStatusListener(onDone);
    } else {
      finish();
    }
  }

  /// Aborts without committing (e.g. the pointer was cancelled) — snap back.
  void cancel() => end(0);
}
