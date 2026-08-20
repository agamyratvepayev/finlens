import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/balance/widgets/reorderable_group.dart';

/// Gesture-level tests for the two behaviours §4a and §5 add: a mid-drag data
/// change must cancel and commit nothing, and a disabled group must not lift.
/// (The placeholder/proxy/haptic visuals are verified on device.)
void main() {
  Widget host({
    required ValueListenable<List<String>> items,
    required void Function(String moved, int target) onReorder,
    bool enabled = true,
  }) {
    final controller = ScrollController();
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: ValueListenableBuilder<List<String>>(
            valueListenable: items,
            builder: (_, list, _) => ReorderableGroup<String>(
              items: list,
              enabled: enabled,
              scrollController: controller,
              semanticLabel: (s, i, n) => '$s ${i + 1}/$n',
              onReorder: onReorder,
              itemBuilder: (_, s) => SizedBox(
                height: 40,
                width: double.infinity,
                child: Text(s),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a mid-drag items change cancels without reordering',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C']);
    addTearDown(items.dispose);
    final moved = <int>[];

    await tester.pumpWidget(
      host(items: items, onReorder: (_, target) => moved.add(target)),
    );

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

  testWidgets('a long press does not lift while disabled (search active)',
      (tester) async {
    final items = ValueNotifier<List<String>>(['A', 'B', 'C']);
    addTearDown(items.dispose);
    final moved = <int>[];

    await tester.pumpWidget(
      host(
        items: items,
        enabled: false,
        onReorder: (_, target) => moved.add(target),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved, isEmpty);
  });
}
