import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/section_header.dart';

// The Balance section carousel advances on a right-to-left (leftward) swipe,
// the platform carousel convention: Net Worth -> Assets -> Liabilities. A
// rightward swipe steps back.
//
// Physics changed with the Task-14 fix: the hand-rolled 55px / 1.6x-dominance
// test is gone. Commit now takes distance >= 40 OR a fling >= 250px/s, and the
// gesture arena — not a dominance ratio — keeps vertical scrolls with the list.
void main() {
  // A bare swipe with no scrollable underneath: the horizontal recognizer is
  // the only arena member, so it claims any drag it is handed.
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

  // A swipe wrapping a real vertical scrollable, so the arena has both a
  // horizontal and a vertical drag recognizer to choose between — the real
  // Balance layout.
  Future<void> pumpOverList(WidgetTester tester,
      {required VoidCallback onNext, required VoidCallback onPrevious}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HorizontalSectionSwipe(
          onNext: onNext,
          onPrevious: onPrevious,
          child: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 40, child: Text('row $i')),
            ],
          ),
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

  // RE-BASELINED: the pinned distance floor moved 55 -> 40 (velocity now carries
  // the short-but-fast case), so a "too short" drag must be < 40. tester.drag
  // releases at ~0 velocity, so this exercises the distance floor alone.
  testWidgets('a short slow drag below the 40px threshold does nothing',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(find.byType(HorizontalSectionSwipe), const Offset(-30, 0));
    await tester.pump();

    expect(next, 0);
    expect(prev, 0);
  });

  // A short flick that barely moves but is fast still commits, via velocity.
  testWidgets('a short fast fling changes section', (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    // ~30px of travel — under the distance floor — but flung at 600px/s.
    await tester.fling(
        find.byType(HorizontalSectionSwipe), const Offset(-30, 0), 600);
    await tester.pump();

    expect(next, 1);
    expect(prev, 0);
  });

  // A deliberate slow drag with finger tremor (vertical wobble) still commits.
  // The old dominance test summed |dy| across the path and would reject this;
  // net horizontal travel is what matters now.
  testWidgets('a slow drag with vertical jitter still changes section',
      (tester) async {
    var next = 0, prev = 0;
    await pump(tester, onNext: () => next++, onPrevious: () => prev++);

    final start = tester.getCenter(find.byType(HorizontalSectionSwipe));
    final g = await tester.startGesture(start);
    // Ten small leftward steps (net -80) with alternating ±6 vertical wobble,
    // pumped apart so it reads as a slow, deliberate drag.
    for (var i = 0; i < 10; i++) {
      await g.moveBy(Offset(-8, i.isEven ? 6 : -6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();

    expect(next, 1);
    expect(prev, 0);
  });

  // RE-BASELINED: the old test asserted a (-60, 200) drag was rejected by the
  // 1.6x dominance ratio. That ratio is gone; a mostly-vertical drag is now kept
  // off the carousel by the gesture arena instead — the enclosing scrollable
  // wins it. Verified against a real ListView, which is what Balance wraps.
  testWidgets('a mostly-vertical drag scrolls the list, no section change',
      (tester) async {
    var next = 0, prev = 0;
    await pumpOverList(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(
        find.byType(HorizontalSectionSwipe), const Offset(-60, -200));
    await tester.pump();

    expect(next, 0);
    expect(prev, 0);
  });

  // The complement: a clearly horizontal drag over that same list still changes
  // section — the arena hands it to the horizontal recognizer.
  testWidgets('a horizontal drag over a list still changes section',
      (tester) async {
    var next = 0, prev = 0;
    await pumpOverList(tester, onNext: () => next++, onPrevious: () => prev++);

    await tester.drag(
        find.byType(HorizontalSectionSwipe), const Offset(-160, 0));
    await tester.pump();

    expect(next, 1);
    expect(prev, 0);
  });
}
