import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/shared/widgets/swipe_back_route.dart';
import 'package:finlens/theme/app_theme.dart';

// NOTE: these gesture tests exercise the hold-then-drag arena against the row
// swipe. They are timing/velocity-sensitive; the feel itself (haptic, follow,
// snap-back curve) must still be verified on a device. Surface is 800x600, so
// 40% of width = 320px.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<String> pumpDetail(WidgetTester tester) async {
    final store = buildSeedStore();
    final acct = store.accounts.firstWhere((a) => a.name == 'Main Checking');
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        navigatorKey: nav,
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('BALANCE'))),
      ),
    ));
    nav.currentState!.push(SwipeBackPageRoute(
      builder: (_) => ScopedLedgerScreen(initialScope: AccountScope(acct.id)),
    ));
    await tester.pumpAndSettle();
    return acct.id;
  }

  // Hold to arm, then drag `dx` left in slow steps so release velocity ~0 and
  // the commit/cancel decision is purely distance-based.
  Future<void> holdDrag(WidgetTester tester, Offset from, double dx) async {
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 350)); // hold -> arm
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await g.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 120)); // let velocity decay
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a quick left drag opens the row menu and does not pop',
      (tester) async {
    await pumpDetail(tester);
    expect(find.byType(SwipeActions), findsWidgets);

    await tester.drag(find.byType(SwipeActions).first, const Offset(-140, 0));
    await tester.pumpAndSettle();

    // Menu opened (an action label is revealed) and the screen is still here.
    expect(find.text('Edit'), findsWidgets);
    expect(find.byType(ScopedLedgerScreen), findsOneWidget);
    expect(find.text('BALANCE'), findsNothing);
  });

  testWidgets('a held drag past 40% pops and the row menu never opens',
      (tester) async {
    await pumpDetail(tester);
    final center = tester.getCenter(find.byType(SwipeActions).first);

    await holdDrag(tester, center, -500); // > 40% of 800

    expect(find.text('BALANCE'), findsOneWidget); // popped back to Balance
    expect(find.byType(ScopedLedgerScreen), findsNothing);
  });

  testWidgets('released at 20% snaps back (no pop); at 60% it pops',
      (tester) async {
    await pumpDetail(tester);
    final center = tester.getCenter(find.byType(SwipeActions).first);

    await holdDrag(tester, center, -160); // 20% -> value 0.8 -> cancel
    expect(find.byType(ScopedLedgerScreen), findsOneWidget);
    expect(find.text('BALANCE'), findsNothing);

    await holdDrag(tester, tester.getCenter(find.byType(SwipeActions).first),
        -480); // 60% -> value 0.4 -> commit
    expect(find.text('BALANCE'), findsOneWidget);
  });

  testWidgets('with a row menu open, the first held drag closes it, no pop',
      (tester) async {
    await pumpDetail(tester);

    // Open a row's menu with a quick drag.
    await tester.drag(find.byType(SwipeActions).first, const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(anySwipeRowOpen, isTrue);

    // First held drag: closes the menu, does not pop.
    await holdDrag(tester, tester.getCenter(find.byType(SwipeActions).first),
        -500);
    expect(find.byType(ScopedLedgerScreen), findsOneWidget,
        reason: 'closing the menu must not also pop the screen');
    expect(anySwipeRowOpen, isFalse);
    expect(find.text('BALANCE'), findsNothing);

    // Second held drag: now it pops.
    await holdDrag(tester, tester.getCenter(find.byType(SwipeActions).first),
        -500);
    expect(find.text('BALANCE'), findsOneWidget);
  });

  testWidgets('a vertical drag scrolls and never arms the back gesture',
      (tester) async {
    await pumpDetail(tester);

    // A plain vertical fling must not pop.
    await tester.drag(find.byType(ScopedLedgerScreen), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(ScopedLedgerScreen), findsOneWidget);
    expect(find.text('BALANCE'), findsNothing);
  });
}
