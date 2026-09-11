import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/section_header.dart';

// Task-14 regression coverage: the swipe must work over a section that has an
// empty list (the Liabilities-with-no-accounts case), and over the header.
//
// Before the fix, HorizontalSectionSwipe used a bare GestureDetector
// (deferToChild). On an empty section nothing sits under the finger, so the
// detector never received the drag and the swipe was dead — exactly the
// reported bug. `behavior: HitTestBehavior.opaque` is what makes the empty area
// hit-testable. Run this file against the pre-fix widget to see it fail, then
// against the fixed widget to see it pass.
void main() {
  testWidgets(
      'a horizontal drag over a section with an empty list changes section',
      (tester) async {
    var next = 0, prev = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HorizontalSectionSwipe(
          onNext: () => next++,
          onPrevious: () => prev++,
          // An empty section renders as a scroll view with no rows: there is
          // nothing under the finger in the body area. This is the shape
          // Balance's _list returns when a section has no accounts.
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: SizedBox(width: double.infinity, height: 0),
          ),
        ),
      ),
    ));

    // Drag across the empty black area, not over any row.
    await tester.dragFrom(const Offset(200, 400), const Offset(-160, 0));
    await tester.pump();

    expect(next, 1, reason: 'leftward drag over an empty section advances');
    expect(prev, 0);
  });

  testWidgets('a drag starting in the header changes section', (tester) async {
    var next = 0, prev = 0;
    var addTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // Mirrors the Balance layout: the swipe wraps a Column of header + list
        // so a drag over the header (not just the list) changes section.
        body: HorizontalSectionSwipe(
          onNext: () => next++,
          onPrevious: () => prev++,
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: Row(
                  children: [
                    const Expanded(child: Text('NET WORTH')),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => addTaps++,
                    ),
                  ],
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ));

    // Drag beginning over the header label.
    await tester.dragFrom(const Offset(60, 40), const Offset(-160, 0));
    await tester.pump();
    expect(next, 1, reason: 'a drag over the header changes section');

    // The + still takes its tap; the drag recognizer does not swallow taps.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(addTaps, 1);
  });
}
