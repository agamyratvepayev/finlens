import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/balance/widgets/reorderable_group.dart';

/// Gesture-level tests for [ReorderableGroup]. These simulate *real* drags —
/// startGesture → pump past the long-press delay → moveBy in steps → up — and
/// assert on what `onReorder` captures and where the dashed placeholder lands.
/// The earlier tests never moved the finger, which is exactly why the
/// "placeholder frozen at origin" bug slipped through; every reorder assertion
/// below fails against the pre-fix (feedback-corner / hit-test) tracking.
void main() {
  // Each row is 40pt tall; the group is [A, B, C, D] unless overridden.
  const rowHeight = 40.0;

  // A record of the moves committed, as (movedItem, visibleTargetIndex).
  late List<(String, int)> moved;

  Widget host({
    required ValueListenable<List<String>> items,
    bool enabled = true,
    // Widgets placed above / below the group inside the same scroll view, so a
    // drag can wander over "foreign" content and prove the clamp-to-end rule.
    Widget? above,
    Widget? below,
  }) {
    final controller = ScrollController();
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?above,
              ValueListenableBuilder<List<String>>(
                valueListenable: items,
                builder: (_, list, _) => ReorderableGroup<String>(
                  items: list,
                  enabled: enabled,
                  scrollController: controller,
                  semanticLabel: (s, i, n) => '$s ${i + 1}/$n',
                  onReorder: (m, target) => moved.add((m, target)),
                  itemBuilder: (_, s) => SizedBox(
                    height: rowHeight,
                    width: double.infinity,
                    child: Text(s),
                  ),
                ),
              ),
              ?below,
            ],
          ),
        ),
      ),
    );
  }

  setUp(() => moved = []);

  /// Lifts [label]'s row (holds past the delay) and returns the live gesture,
  /// left mid-drag for the caller to move and release.
  Future<TestGesture> lift(WidgetTester tester, String label) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text(label)));
    await tester.pump(const Duration(milliseconds: 600));
    // A first tiny move so the drag is unambiguously active before the caller's
    // real move; keeps us at the origin (no-op) so far.
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    return gesture;
  }

  testWidgets('one slot down commits (C → after D)', (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(host(items: items));

    final gesture = await lift(tester, 'C');
    // Push the finger down past D's *lower* half — D's upper half is the origin
    // slot (no-op), so one-slot-down is only reachable below D's midpoint.
    await gesture.moveBy(const Offset(0, rowHeight * 1.5));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // C dropped at the end of the visible list (index 4) → A B D C.
    expect(moved, [('C', 4)]);
  });

  testWidgets('one slot up commits (C → before B)', (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(host(items: items));

    final gesture = await lift(tester, 'C');
    // Up into B's upper half → placeholder before B → A C B D.
    await gesture.moveBy(const Offset(0, -rowHeight * 1.5));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, [('C', 1)]);
  });

  testWidgets('drag above the group clamps to index 0 and commits',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(
      host(items: items, above: const SizedBox(height: 120, child: Text('HDR'))),
    );

    final gesture = await lift(tester, 'C');
    // Far up, over the foreign header — insert clamps to the group's top.
    await gesture.moveBy(const Offset(0, -400));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Before A → C A B D.
    expect(moved, [('C', 0)]);
  });

  testWidgets('drag far below over foreign widgets clamps to the end',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(
      host(items: items, below: const SizedBox(height: 400, child: Text('FTR'))),
    );

    final gesture = await lift(tester, 'C');
    // Far down, over the foreign footer — insert clamps to the group's end.
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // After D → A B D C.
    expect(moved, [('C', 4)]);
  });

  testWidgets('release at the origin visual position commits nothing',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(host(items: items));

    final gesture = await lift(tester, 'C');
    // Nudge within the origin gap (not past D's midpoint) — stays a no-op.
    await gesture.moveBy(const Offset(0, rowHeight * 0.3));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, isEmpty);
  });

  testWidgets('a long press does not lift while disabled (search active)',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C', 'D']);
    addTearDown(items.dispose);
    await tester.pumpWidget(host(items: items, enabled: false));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('C')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, rowHeight * 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, isEmpty);
  });

  testWidgets('a mid-drag items change cancels without reordering',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C']);
    addTearDown(items.dispose);
    await tester.pumpWidget(host(items: items));

    // Lift row A: hold past the long-press delay, then drag down into B/C.
    final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();

    // The data changes underneath the live drag (new list identity + order).
    items.value = ['A', 'C', 'B'];
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    // A move computed against the stale list must never commit.
    expect(moved, isEmpty);
  });
}
