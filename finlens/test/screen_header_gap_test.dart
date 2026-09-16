import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/screen_header.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 028 — with the eye gone from [ScreenHeader] entirely, the only gap in
/// the header's action cluster is the single `Insets.sm` the `+` brings. A
/// screen with a `trailing` (•••) must show exactly one `Insets.sm` between •••
/// and `+`, not the doubled gap that the eye's removal could have left (gap
/// option A: the `trailing` branch emits no gap of its own).
///
/// These pin •••→+ == `Insets.sm`, that no eye icon renders in either state, and
/// that a header with no `trailing` keeps its `+` anchored to the right gutter.
/// (`plus_button_alignment_test.dart` pins the `+`'s rect across screens.)
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

  testWidgets('•••→+ is a single Insets.sm, and no eye renders (task 028)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      ScreenHeader(
        title: 'X',
        onAdd: () {},
        trailing: HeaderCircleButton(
          icon: Icons.more_horiz_rounded,
          onTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No eye in either state.
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    expect(
      gap(tester, Icons.more_horiz_rounded, Icons.add_rounded),
      moreOrLessEquals(Insets.sm, epsilon: 0.5),
    );
  });

  testWidgets('a header with no trailing carries no eye, and its + stays at the '
      'right gutter', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      ScreenHeader(title: 'X', onAdd: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    // The + is the last child of a Row whose leading slot is Expanded, so it is
    // flush against the right gutter (390 width − gutter − its 36pt diameter).
    final plus = tester.getRect(find.byIcon(Icons.add_rounded));
    expect(plus.right, moreOrLessEquals(390 - Insets.gutter, epsilon: 0.5));
  });
}
