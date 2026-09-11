import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/shared/widgets/form_fields.dart';

// Task 15 — the disclosure chevron points the way the tap actually goes.
//
//   chevron_right_rounded        tapping pushes a screen
//   keyboard_arrow_down_rounded  tapping raises a bottom sheet in place
//
// The glyph is chosen per row by `opensSheet`; the default is the rightward
// chevron so an unclassified call site is never silently flipped. These tests
// pin that contract on the shared row widgets.

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: child),
        ),
      ),
    );

const _down = Icons.keyboard_arrow_down_rounded;
const _right = Icons.chevron_right_rounded;

void main() {
  group('FormRow', () {
    testWidgets('opensSheet: true renders the downward chevron',
        (tester) async {
      await tester.pumpWidget(_host(
        FormRow(label: 'Group', onTap: () {}, showChevron: true, opensSheet: true),
      ));
      expect(find.byIcon(_down), findsOneWidget);
      expect(find.byIcon(_right), findsNothing);
    });

    testWidgets('opensSheet: false renders the rightward chevron',
        (tester) async {
      await tester.pumpWidget(_host(
        FormRow(
            label: 'Archive', onTap: () {}, showChevron: true, opensSheet: false),
      ));
      expect(find.byIcon(_right), findsOneWidget);
      expect(find.byIcon(_down), findsNothing);
    });

    testWidgets('the default (unclassified) keeps the rightward chevron — an '
        'undeclared row never silently flips', (tester) async {
      await tester.pumpWidget(_host(
        FormRow(label: 'Something', onTap: () {}, showChevron: true),
      ));
      expect(find.byIcon(_right), findsOneWidget);
      expect(find.byIcon(_down), findsNothing);
    });

    testWidgets('no chevron when showChevron is false', (tester) async {
      await tester.pumpWidget(_host(
        FormRow(label: 'Plain', onTap: () {}, opensSheet: true),
      ));
      expect(find.byIcon(_right), findsNothing);
      expect(find.byIcon(_down), findsNothing);
    });
  });

  group('DestructiveRow', () {
    testWidgets('opensSheet: true renders the downward chevron (its confirm is '
        'a bottom sheet)', (tester) async {
      await tester.pumpWidget(_host(
        DestructiveRow(label: 'Remove', onTap: () {}, opensSheet: true),
      ));
      expect(find.byIcon(_down), findsOneWidget);
      expect(find.byIcon(_right), findsNothing);
    });

    testWidgets('the default keeps the rightward chevron', (tester) async {
      await tester.pumpWidget(_host(
        DestructiveRow(label: 'Remove', onTap: () {}),
      ));
      expect(find.byIcon(_right), findsOneWidget);
      expect(find.byIcon(_down), findsNothing);
    });
  });

  group('TxnFieldRow', () {
    testWidgets('opensSheet: true renders the downward chevron',
        (tester) async {
      await tester.pumpWidget(_host(
        TxnFieldRow(
            icon: Icons.event_rounded,
            label: 'Date',
            opensSheet: true,
            onTap: () {}),
      ));
      expect(find.byIcon(_down), findsOneWidget);
      expect(find.byIcon(_right), findsNothing);
    });

    testWidgets('the default (unclassified) keeps the rightward chevron',
        (tester) async {
      await tester.pumpWidget(_host(
        TxnFieldRow(icon: Icons.event_rounded, label: 'Date', onTap: () {}),
      ));
      expect(find.byIcon(_right), findsOneWidget);
      expect(find.byIcon(_down), findsNothing);
    });

    testWidgets('a null onTap (read-only) renders no chevron at all',
        (tester) async {
      await tester.pumpWidget(_host(
        const TxnFieldRow(
            icon: Icons.event_rounded, label: 'Current', opensSheet: true),
      ));
      expect(find.byIcon(_right), findsNothing);
      expect(find.byIcon(_down), findsNothing);
    });
  });
}
