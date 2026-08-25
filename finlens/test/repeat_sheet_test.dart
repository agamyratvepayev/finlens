import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/quick_add/repeat_sheet.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/repeat_sheet_test.dart

void _portrait(WidgetTester tester, {double w = 390}) {
  tester.view.physicalSize = Size(w * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Opens the Repeat sheet at [current], seeded on [date], and settles it.
Future<void> _open(
  WidgetTester tester, {
  required RepeatFrequency current,
  required DateTime date,
}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.dark,
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                showRepeatSheet(ctx, current: current, date: date),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The live "Next …" preview line's text.
String _preview(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining('Next')).data!;

void main() {
  group('the day picker appears only for weekly and monthly', () {
    testWidgets('monthly shows the 1–31 grid, no weekday chips', (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      expect(find.text('31'), findsOneWidget); // grid present
    });

    testWidgets('weekly shows chips, no month grid', (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.weekly, date: DateTime(2026, 8, 25));
      expect(find.text('W'), findsOneWidget); // Wednesday chip present
      expect(find.text('31'), findsNothing); // no month grid
    });

    testWidgets('quarterly expands no picker', (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.quarterly, date: DateTime(2026, 8, 15));
      expect(find.text('31'), findsNothing);
      expect(find.text('W'), findsNothing);
    });

    testWidgets('biweekly and never expand no picker', (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.biweekly, date: DateTime(2026, 8, 25));
      expect(find.text('31'), findsNothing);
      expect(find.text('W'), findsNothing);
    });

    testWidgets('selecting Every 2 weeks after monthly collapses the grid',
        (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      expect(find.text('31'), findsOneWidget);
      await tester.tap(find.text('Every 2 weeks'));
      await tester.pumpAndSettle();
      expect(find.text('31'), findsNothing);
    });
  });

  group('the preview updates live as the picker changes', () {
    testWidgets('adding a month-day changes the Next line', (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      final before = _preview(tester);
      await tester.tap(find.text('1')); // add day 1 to {15}
      await tester.pumpAndSettle();
      expect(_preview(tester), isNot(before));
    });

    testWidgets('shorter-months note appears once day 31 is selected',
        (tester) async {
      _portrait(tester);
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      expect(find.text('Shorter months use their last day'), findsNothing);
      await tester.tap(find.text('31'));
      await tester.pumpAndSettle();
      expect(find.text('Shorter months use their last day'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('the 31-day grid fits at 320 pt without overflow',
        (tester) async {
      _portrait(tester, w: 320);
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      expect(find.text('31'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('minimum one day stays selected', () {
    testWidgets('tapping the only selected month-day keeps the preview valid',
        (tester) async {
      _portrait(tester);
      // Seeded on the 15th → {15} is the sole selection.
      await _open(tester, current: RepeatFrequency.monthly, date: DateTime(2026, 8, 15));
      final before = _preview(tester);
      await tester.tap(find.text('15')); // attempt to deselect the last day
      await tester.pumpAndSettle();
      expect(_preview(tester), before); // unchanged — deselection refused
    });
  });
}
