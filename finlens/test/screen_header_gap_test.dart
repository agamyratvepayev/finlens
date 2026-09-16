import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/screen_header.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 027 · header-controls spec §3 — the double gap uncovered when a screen
/// carries a `trailing` (•••) but no header eye (its eye moved into the •••
/// menu). The gap after `trailing` and the gap before `+` are both drawn by
/// [ScreenHeader]; with the eye between them that is one gap each side, but with
/// the eye gone the two `SizedBox(sm)`s sit together and •••→+ drifts to 2·sm.
///
/// These pin that •••→+ equals a single `Insets.sm`, and equals the eye→+ gap on
/// a screen that still shows its eye. The `+` itself does not move — it is the
/// last child of a `Row` whose leading slot is `Expanded`, so it stays anchored
/// to the right gutter; only the ••• shifts. (`plus_button_alignment_test.dart`
/// pins the `+`'s rect across screens.)
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Widget host(Widget child) => StoreScope(
        store: emptyStore(),
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SafeArea(child: child)),
        ),
      );

  /// Horizontal distance from the right edge of the left circle to the left
  /// edge of the right circle.
  double gap(WidgetTester tester, IconData left, IconData right) {
    final l = tester.getRect(find.byIcon(left));
    final r = tester.getRect(find.byIcon(right));
    return r.left - l.right;
  }

  testWidgets('•••→+ is a single Insets.sm when the eye is hidden (§3)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      ScreenHeader(
        title: 'X',
        showEye: false,
        onAdd: () {},
        trailing: HeaderCircleButton(
          icon: Icons.more_horiz_rounded,
          onTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(
      gap(tester, Icons.more_horiz_rounded, Icons.add_rounded),
      moreOrLessEquals(Insets.sm, epsilon: 0.5),
    );
  });

  testWidgets('eye→+ is the same single Insets.sm when the eye is shown',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      ScreenHeader(title: 'X', onAdd: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    expect(
      gap(tester, Icons.visibility_rounded, Icons.add_rounded),
      moreOrLessEquals(Insets.sm, epsilon: 0.5),
    );
  });

  testWidgets('•••→+ with the eye hidden equals eye→+ with the eye shown',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      ScreenHeader(
        title: 'X',
        showEye: false,
        onAdd: () {},
        trailing: HeaderCircleButton(
          icon: Icons.more_horiz_rounded,
          onTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final eyeless = gap(tester, Icons.more_horiz_rounded, Icons.add_rounded);

    await tester.pumpWidget(host(
      ScreenHeader(title: 'X', onAdd: () {}),
    ));
    await tester.pumpAndSettle();
    final withEye = gap(tester, Icons.visibility_rounded, Icons.add_rounded);

    expect(eyeless, moreOrLessEquals(withEye, epsilon: 0.5));
  });
}
