import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/section_header.dart';

// The Balance section carousel advances on a right-to-left (leftward) swipe,
// the platform carousel convention: Net Worth -> Assets -> Liabilities. A
// rightward swipe steps back. Physics (55px threshold, 1.6x dominance) is
// unchanged; only which drag direction advances flips.
void main() {
  Future<void> pump(WidgetTester tester,
      {required VoidCallback onNext, required VoidCallback onPrevious}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HorizontalSectionSwipe(
          onNext: onNext,
          onPrevious: onPrevious,
          child: const SizedBox.expand(child: ColoredBox(color: Colors.black)),
        ),
      ),
    ));
  }

  testWidgets('right-to-left (leftward) swipe advances -> onNext',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(find.byType(HorizontalSectionSwipe), const Offset(-120, 0));
    await tester.pump();

    expect(next, 1);
    expect(prev, 0);
  });

  testWidgets('left-to-right (rightward) swipe goes back -> onPrevious',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(find.byType(HorizontalSectionSwipe), const Offset(120, 0));
    await tester.pump();

    expect(prev, 1);
    expect(next, 0);
  });

  testWidgets('a short drag below the 55px threshold does nothing',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(find.byType(HorizontalSectionSwipe), const Offset(-40, 0));
    await tester.pump();

    expect(next, 0);
    expect(prev, 0);
  });

  testWidgets('a mostly-vertical drag is not claimed as a section swipe',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    // Horizontal component (60) is below 1.6x the vertical (200) -> ignored.
    await tester.drag(find.byType(HorizontalSectionSwipe), const Offset(-60, 200));
    await tester.pump();

    expect(next, 0);
    expect(prev, 0);
  });
}
