import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/quick_add/date_time_sheet.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/l10n/app_localizations_tr.dart';
import 'package:finlens/theme/app_theme.dart';

/// The reference clock the app pins its data to.
final _now = DateTime(2026, 8, 9, 14, 32);

/// Pumps a host whose single button opens [showDateTimeSheet], and returns a
/// getter for the committed value. [use24] and [textScale] override the
/// MediaQuery the sheet reads; [locale] drives month/weekday names and the
/// first day of the week.
Future<DateTime? Function()> _openSheet(
  WidgetTester tester, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
  Locale locale = const Locale('en'),
  bool use24 = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  DateTime? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        alwaysUse24HourFormat: use24,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showDateTimeSheet(
                context,
                initial: initial,
                firstDate: firstDate ?? DateTime(2020),
                lastDate: lastDate ?? DateTime(2035),
                now: _now,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  // ── The row (regression) ───────────────────────────────────────────────────

  testWidgets('the Date row shows a real date, never a relative word',
      (tester) async {
    // The fresh-expense default is AppStore.today; before this change the row
    // read "Today, 14:32". This assertion is the regression guard.
    await tester.pumpWidget(StoreScope(
      store: buildSeedStore(),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('9 Aug'), findsWidgets);
    expect(find.textContaining('Today'), findsNothing);
    expect(find.textContaining('Tomorrow'), findsNothing);
    expect(find.textContaining('Yesterday'), findsNothing);
  });

  test('dateAbsolute drops the year within the current year, keeps it outside',
      () {
    final l = AppLocalizationsEn();
    // Same year → no year.
    expect(dateAbsolute(DateTime(2026, 8, 9), l, now: _now), '9 Aug');
    expect(dateAbsolute(DateTime(2026, 8, 10), l, now: _now), '10 Aug');
    // Never a relative word, even for today/tomorrow.
    expect(dateAbsolute(DateTime(2026, 8, 9), l, now: _now), isNot(contains('Today')));
    // Previous and future years include the year.
    expect(dateAbsolute(DateTime(2025, 8, 9), l, now: _now), '9 Aug 2025');
    expect(dateAbsolute(DateTime(2027, 8, 9), l, now: _now), '9 Aug 2027');
  });

  // ── The sheet ──────────────────────────────────────────────────────────────

  testWidgets('opening the sheet finds no DatePickerDialog', (tester) async {
    await _openSheet(tester, initial: _now);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('the sheet opens with the date half active (calendar showing)',
      (tester) async {
    await _openSheet(tester, initial: _now);
    // Date active ⇒ the calendar is up and no wheels are built.
    expect(find.byKey(const ValueKey('dt-weekdays')), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNothing);
  });

  testWidgets('tapping the time half swaps to wheels without changing height',
      (tester) async {
    await _openSheet(tester, initial: _now);
    final area = find.byKey(const ValueKey('dt-area'));
    final before = tester.getSize(area);

    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsWidgets);
    expect(tester.getSize(area), before);
  });

  testWidgets('selecting a day leaves the time unchanged', (tester) async {
    await _openSheet(tester, initial: _now); // 14:32 → "2:32 PM"
    expect(find.text('2:32 PM'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    // Date moved to the 15th, but the time is untouched.
    expect(find.textContaining('15 Aug'), findsWidgets);
    expect(find.text('2:32 PM'), findsOneWidget);
  });

  testWidgets('changing the hour wheel leaves the date unchanged',
      (tester) async {
    await _openSheet(tester, initial: _now);
    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -34));
    await tester.pumpAndSettle();

    // The summary date half is still the 9th.
    expect(find.textContaining('9 Aug'), findsWidgets);
  });

  testWidgets('Now sets the time to the clock and leaves the date alone',
      (tester) async {
    await _openSheet(tester, initial: DateTime(2026, 8, 9, 10, 15));
    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();
    expect(find.text('10:15 AM'), findsOneWidget);

    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();

    // Time becomes the injected clock (14:32 → 2:32 PM); date stays the 9th.
    expect(find.text('2:32 PM'), findsOneWidget);
    expect(find.textContaining('9 Aug'), findsWidgets);
  });

  testWidgets('Cancel discards; the sheet returns nothing', (tester) async {
    final value = await _openSheet(tester, initial: _now);
    await tester.tap(find.text('15')); // change the selection
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(value(), isNull);
  });

  testWidgets('Done commits the edited value', (tester) async {
    final value = await _openSheet(tester, initial: _now);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(value(), DateTime(2026, 8, 15, 14, 32));
  });

  testWidgets('24-hour renders two wheels; 12-hour renders three',
      (tester) async {
    await _openSheet(tester, initial: _now, use24: true);
    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('14:32'), findsWidgets); // 00:00 style, not 24:00
  });

  testWidgets('12-hour renders three wheels', (tester) async {
    await _openSheet(tester, initial: _now, use24: false);
    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
  });

  testWidgets('a day beyond lastDate is not selectable', (tester) async {
    // Bound the picker to the 9th; the 15th is out of range.
    await _openSheet(tester, initial: _now, lastDate: DateTime(2026, 8, 9));
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    // Selection did not move off the 9th.
    expect(find.textContaining('9 Aug'), findsWidgets);
    expect(find.textContaining('15 Aug'), findsNothing);
  });

  testWidgets('in tr the weekday columns run Monday-first', (tester) async {
    await _openSheet(tester, initial: _now, locale: const Locale('tr'));
    final tr = AppLocalizationsTr();
    final expected = [for (var iso = 1; iso <= 7; iso++) weekdayNarrow(iso, tr)];

    final headers = tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(const ValueKey('dt-weekdays')),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();

    expect(headers, expected); // Mon…Sun
  });

  // ── Layout robustness ──────────────────────────────────────────────────────

  for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
    testWidgets('no overflow at ${size.width.toInt()}pt (calendar + wheels)',
        (tester) async {
      await _openSheet(tester, initial: _now, size: size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('dt-time-half')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no overflow at 130% text scale', (tester) async {
    await _openSheet(tester, initial: _now, size: const Size(320, 568), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('dt-time-half')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('tr'), Locale('ru')]) {
    testWidgets('no overflow in ${locale.languageCode} at 320pt',
        (tester) async {
      await _openSheet(tester,
          initial: _now, locale: locale, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the month header opens a month-and-year selector',
      (tester) async {
    await _openSheet(tester, initial: _now);
    // "August 2026" header → tap → year stepper + month grid.
    await tester.tap(find.textContaining('2026'));
    await tester.pumpAndSettle();
    // A different month is now pickable; pick March and confirm we return.
    final l = AppLocalizationsEn();
    await tester.tap(find.text(monthShort(3, l)));
    await tester.pumpAndSettle();
    expect(find.textContaining(monthLong(3, l)), findsWidgets);
    // Selection intact — still the 9th of the (new) month.
    expect(find.textContaining('9 Aug'), findsWidgets);
  });
}
