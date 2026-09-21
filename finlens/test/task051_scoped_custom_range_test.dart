import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/l10n/enum_labels.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/ledger/widgets/period_row.dart';
import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/shared/widgets/range_calendar.dart';
import 'package:finlens/theme/app_theme.dart';

final _today = DateTime(2026, 8, 9); // the seed store's pinned clock
final _en = AppLocalizationsEn();
final _thisMonth =
    RangePreset.thisMonth.resolve(_today).label(_today, _en); // '1–31 Aug'

Widget _host(AppStore store, String accountId, {double textScale = 1.0}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        // Applied to every route, so the sheet scales too.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ScopedLedgerScreen(initialScope: AccountScope(accountId)),
      ),
    );

Finder _chip(String label) => find.descendant(
    of: find.byType(PeriodRow), matching: find.text(label));

Finder _day(int d) => find.descendant(
    of: find.byType(RangeCalendar), matching: find.text('$d'));

Future<void> _openSheet(WidgetTester tester, String chipLabel) async {
  await tester.tap(_chip(chipLabel));
  await tester.pumpAndSettle();
}

Future<void> _openCalendar(WidgetTester tester) async {
  final row = find.text('${_en.ldgCustomRange}…');
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _pickDays(WidgetTester tester, int from, int to) async {
  await tester.tap(_day(from));
  await tester.pump();
  await tester.tap(_day(to));
  await tester.pump();
}

Future<void> _apply(WidgetTester tester) async {
  final apply = find.textContaining(_en.actionApply);
  await tester.ensureVisible(apply);
  await tester.pumpAndSettle();
  await tester.tap(apply);
  await tester.pumpAndSettle();
}

int _count(AppStore store, String id, DateTime from, DateTime to) =>
    LedgerQuery(
      store: store,
      scope: AccountScope(id),
      start: DateTime(from.year, from.month, from.day),
      end: DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
    ).rows().length;

void main() {
  late AppStore store;
  late String acctId;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = buildSeedStore();
    acctId = store.accounts.firstWhere((a) => a.name == 'Main Checking').id;
  });

  testWidgets('Custom range… sits below the presets and opens the calendar; '
      '‹ Period goes back', (tester) async {
    await tester.pumpWidget(_host(store, acctId));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);

    final custom = find.text('${_en.ldgCustomRange}…');
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    expect(custom, findsOneWidget);
    expect(
      tester.getTopLeft(custom).dy,
      greaterThan(
          tester.getTopLeft(find.text(RangePreset.allTime.label(_en))).dy),
    );

    await _openCalendar(tester);
    expect(find.text(_en.ldgCustomRange.toUpperCase()), findsOneWidget);
    expect(find.byType(RangeCalendar), findsOneWidget);
    // Opened from a preset: nothing seeded.
    expect(
      find.descendant(
          of: find.byType(RangeCalendar), matching: find.text('—')),
      findsNWidgets(2),
    );

    await tester.tap(find.text(_en.ldgPeriod));
    await tester.pumpAndSettle();
    expect(find.byType(RangeCalendar), findsNothing);
    expect(find.text('${_en.ldgCustomRange}…'), findsOneWidget);
  });

  testWidgets('Apply narrows chip, count and list — and saves no unit',
      (tester) async {
    final unitBefore = store.accountPeriodUnit;
    await tester.pumpWidget(_host(store, acctId));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);
    await _openCalendar(tester);
    await _pickDays(tester, 3, 7);

    final n = _count(store, acctId, DateTime(2026, 8, 3), DateTime(2026, 8, 7));
    expect(find.text('${_en.actionApply} · ${_en.countTransactions(n)}'),
        findsOneWidget);
    await _apply(tester);

    expect(find.byType(RangeCalendar), findsNothing);
    expect(_chip('3–7 Aug'), findsOneWidget);
    expect(find.text('$n transactions', findRichText: true), findsOneWidget);
    expect(store.accountPeriodUnit, unitBefore);
  });

  testWidgets('reopened, only Custom range is checked — even when the dates '
      'equal a preset', (tester) async {
    expect(RangePreset.thisWeek.resolve(_today).label(_today, _en), '3–9 Aug');
    await tester.pumpWidget(_host(store, acctId));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);
    await _openCalendar(tester);
    await _pickDays(tester, 3, 9);
    await _apply(tester);

    await _openSheet(tester, '3–9 Aug');
    final check = find.byIcon(Icons.check_rounded);
    await tester.ensureVisible(check);
    await tester.pumpAndSettle();
    expect(check, findsOneWidget);
    final row = find.ancestor(of: check, matching: find.byType(ListTile));
    expect(find.descendant(of: row, matching: find.text(_en.ldgCustomRange)),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('3–9 Aug')),
        findsOneWidget);
  });

  testWidgets('‹ steps a custom range back by its own width', (tester) async {
    await tester.pumpWidget(_host(store, acctId));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);
    await _openCalendar(tester);
    await _pickDays(tester, 3, 7);
    await _apply(tester);

    await tester.tap(find.descendant(
        of: find.byType(PeriodRow),
        matching: find.byIcon(Icons.chevron_left_rounded)));
    await tester.pumpAndSettle();
    expect(_chip('29 Jul – 2 Aug'), findsOneWidget);
  });

  testWidgets('All time names the first month this account has data — on '
      'the sheet and on the chip', (tester) async {
    DateTime? earliest;
    for (final t in store.txnsForAccounts({acctId})) {
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
    }
    final od = store.accountById(acctId)!.openingDate;
    if (od != null && (earliest == null || od.isBefore(earliest))) {
      earliest = od;
    }
    final expected = RangePreset.allTime
        .resolve(_today)
        .label(_today, _en, firstEver: earliest ?? _today);
    expect(expected, isNot('Since Jan 2000'));

    await tester.pumpWidget(_host(store, acctId));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);

    final allTime = find.text(RangePreset.allTime.label(_en));
    await tester.ensureVisible(allTime);
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
    expect(find.text('Since Jan 2000'), findsNothing);

    await tester.tap(allTime);
    await tester.pumpAndSettle();
    expect(_chip(expected), findsOneWidget);
    expect(find.text('Since Jan 2000'), findsNothing);
  });

  testWidgets('the calendar page does not overflow at 320×568 and 130%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(store, acctId, textScale: 1.3));
    await tester.pumpAndSettle();
    await _openSheet(tester, _thisMonth);
    await _openCalendar(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(RangeCalendar), findsOneWidget);
  });
}
