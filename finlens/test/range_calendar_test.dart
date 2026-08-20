import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/shared/widgets/range_calendar.dart';
import 'package:finlens/theme/app_theme.dart';

/// The shared FROM/TO calendar, exercised in isolation with stubbed data.
/// `today` is pinned to 9 Aug 2026 to match the app's reference date.

final _today = DateTime(2026, 8, 9);

Widget _host({
  DateTime? initialFrom,
  DateTime? initialTo,
  bool applyEnabledAtZero = false,
  bool disableFuture = false,
  int count = 3,
  void Function(DateTime, DateTime)? onApply,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        child: RangeCalendar(
          today: _today,
          initialFrom: initialFrom,
          initialTo: initialTo,
          applyEnabledAtZero: applyEnabledAtZero,
          disableFuture: disableFuture,
          hasData: (_) => true,
          countBetween: (_, _) => count,
          onApply: onApply ?? (_, _) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens seeded with FROM/TO and a live count', (tester) async {
    await tester.pumpWidget(_host(
      initialFrom: DateTime(2026, 8, 6),
      initialTo: DateTime(2026, 8, 9),
      count: 4,
    ));
    await tester.pumpAndSettle();

    expect(find.text('6 Aug'), findsOneWidget); // FROM
    expect(find.text('9 Aug'), findsOneWidget); // TO
    expect(find.text('Apply · 4 transactions'), findsOneWidget);
  });

  testWidgets('a single-day range (FROM == TO) is valid', (tester) async {
    DateTime? from, to;
    await tester.pumpWidget(_host(
      initialFrom: DateTime(2026, 8, 6),
      initialTo: DateTime(2026, 8, 9),
      count: 1,
      onApply: (f, t) {
        from = f;
        to = t;
      },
    ));
    await tester.pumpAndSettle();

    // Seeded aiming at FROM: first tap sets FROM, second (same day) sets TO.
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();

    expect(find.text('4 Aug'), findsNWidgets(2)); // both fields read 4 Aug
    expect(find.text('Apply · 1 transaction'), findsOneWidget);

    await tester.tap(find.text('Apply · 1 transaction'));
    expect(from, DateTime(2026, 8, 4));
    expect(to, DateTime(2026, 8, 4));
  });

  testWidgets('tapping before FROM restarts the window there', (tester) async {
    await tester.pumpWidget(_host(
      initialFrom: DateTime(2026, 8, 6),
      initialTo: DateTime(2026, 8, 9),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5')); // FROM = 5 Aug (editing → TO)
    await tester.pump();
    await tester.tap(find.text('2')); // earlier than FROM → restart at 2 Aug
    await tester.pump();
    await tester.tap(find.text('8')); // TO = 8 Aug
    await tester.pump();

    expect(find.text('2 Aug'), findsOneWidget);
    expect(find.text('8 Aug'), findsOneWidget);
  });

  testWidgets('future days are inert when disableFuture is set', (tester) async {
    await tester.pumpWidget(_host(
      initialFrom: DateTime(2026, 8, 6),
      initialTo: DateTime(2026, 8, 9),
      disableFuture: true,
    ));
    await tester.pumpAndSettle();

    // 15 Aug is after today (9 Aug) — tapping must not move FROM off 6 Aug.
    await tester.tap(find.text('15'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('6 Aug'), findsOneWidget);
    expect(find.text('9 Aug'), findsOneWidget);
  });

  testWidgets('Apply stays enabled at zero when applyEnabledAtZero is set',
      (tester) async {
    var applied = false;
    await tester.pumpWidget(_host(
      initialFrom: DateTime(2026, 8, 6),
      initialTo: DateTime(2026, 8, 9),
      count: 0,
      applyEnabledAtZero: true,
      onApply: (_, _) => applied = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apply · 0 transactions'), findsOneWidget);
    await tester.tap(find.text('Apply · 0 transactions'));
    expect(applied, isTrue);
  });
}
