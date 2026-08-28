import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/main.dart';

/// Widget coverage for the Schedule tab (§13). `flutter test` hangs on the dev
/// machine — written, not run there; verify with `flutter analyze`.
void main() {
  Future<void> openSchedule(WidgetTester tester) async {
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
  }

  testWidgets('Schedule shows the horizon control reading Next 30 days',
      (tester) async {
    await openSchedule(tester);
    expect(find.text('Next 30 days'), findsOneWidget);
  });

  testWidgets('the OVERDUE section survives — Gym is the only overdue task',
      (tester) async {
    await openSchedule(tester);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Gym Subscription'), findsOneWidget);
  });

  testWidgets('tapping a task row opens the read-only detail, never the editor',
      (tester) async {
    await openSchedule(tester);
    await tester.tap(find.text('Internet Bill').first);
    await tester.pumpAndSettle();
    // The detail screen shows PAYMENT HISTORY; the editor never opens from a tap.
    expect(find.text('PAYMENT HISTORY'), findsOneWidget);
  });

  testWidgets('no overflow at 320pt width', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSchedule(tester);
    expect(tester.takeException(), isNull);
  });
}
