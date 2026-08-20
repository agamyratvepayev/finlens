import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/main.dart';

/// The SORT sheet's fifth row. Gesture-level behaviour of the drag itself
/// (lift, placeholder, containment, undo) is verified on device; this pins the
/// additive sheet change, which is testable without a pointer drag.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('SORT sheet shows Custom as a fifth option with its subtitle',
      (tester) async {
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    await tester.pumpAndSettle();

    // Four automatic options plus Custom.
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.text('Value — high to low'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // The subtitle is the permanent advertisement of the gesture.
    expect(find.text('Press and hold an account to move it'), findsOneWidget);
  });
}
