import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 024 — the empty Ledger names the period the *title* names.
///
/// The bug: with a range lens active over a period that has entries outside the
/// window, the empty line read `Nothing recorded in August` (the month under the
/// lens) while the title read the window itself (`4–7 Aug`). These tests pin the
/// fix: under a lens the line renders the lens's own label, from the same call
/// the title makes, so the two can never drift.

// The clock's day is 9 Aug 2026, so the default period is August 2026 and a lens
// over 4–7 Aug is a window the month contains but does not equal.
AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

/// The Ledger tab under a real `Localizations`, mirroring the sibling empty-state
/// test's harness.
Widget _app(
  AppStore store, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: LedgerScreen()),
      ),
    );

/// An entry so `everRecorded` is true and the instrument panel stays live. Dated
/// 20 Aug 2026 — outside every window these tests apply, so each leaves the list
/// empty under its lens.
void _seedElsewhere(AppStore store, {DateTime? on}) => store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: on ?? DateTime(2026, 8, 20),
    );

/// A custom lens exactly as the ledger period sheet builds one (end extended to
/// end-of-day, `preset == null`).
void _applyLens(AppStore store, DateTime from, DateTime to) => store.applyRangeLens(
      DateRange(
        DateTime(from.year, from.month, from.day),
        DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
      ),
    );

/// The period title's own text — the fontSize-22, −0.4 letter-spacing header in
/// `_PeriodTitle`. Used to prove parity between the title and the empty line.
String _titleText(WidgetTester tester) {
  final finder = find.byWidgetPredicate((w) =>
      w is Text &&
      w.style?.fontSize == 22 &&
      w.style?.letterSpacing == -0.4 &&
      (w.data?.isNotEmpty ?? false));
  return tester.widget<Text>(finder).data!;
}

void main() {
  testWidgets(
      'the reported bug: lens over 4–7 Aug, entries in August but not the window '
      '→ names the window, not the month',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store();
    _seedElsewhere(store, on: DateTime(2026, 8, 9)); // the 9th, per the spec
    _applyLens(store, DateTime(2026, 8, 4), DateTime(2026, 8, 7));

    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('Nothing recorded in 4–7 Aug'), findsOneWidget);
    expect(find.text('Nothing recorded in August'), findsNothing);
  });

  testWidgets('title parity: the empty line contains the title\'s range string',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store();
    _seedElsewhere(store);
    _applyLens(store, DateTime(2026, 8, 4), DateTime(2026, 8, 7));

    await tester.pumpWidget(_app(store));
    await tester.pump();

    // Read the title's text in the same pump and assert the line is exactly it,
    // prefixed. This is the guard that keeps §2's rule true after future edits.
    final title = _titleText(tester);
    expect(find.text('Nothing recorded in $title'), findsOneWidget);
  });

  testWidgets('month mode (no lens) is unchanged — names the month', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store();
    // One entry in July; viewing empty August in month mode.
    _seedElsewhere(store, on: DateTime(2026, 7, 15));

    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('Nothing recorded in August'), findsOneWidget);
  });

  group('boundary windows: title and line are character-identical', () {
    Future<void> check(
      WidgetTester tester,
      DateTime from,
      DateTime to,
      String expectedRange,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _store();
      _seedElsewhere(store); // 20 Aug 2026 — outside all three windows below
      _applyLens(store, from, to);

      await tester.pumpWidget(_app(store));
      await tester.pump();

      expect(_titleText(tester), expectedRange);
      expect(find.text('Nothing recorded in $expectedRange'), findsOneWidget);
    }

    testWidgets('same month → 4–7 Aug', (tester) async {
      await check(tester, DateTime(2026, 8, 4), DateTime(2026, 8, 7), '4–7 Aug');
    });

    testWidgets('crossing a month → 28 Jul – 3 Aug', (tester) async {
      await check(
          tester, DateTime(2026, 7, 28), DateTime(2026, 8, 3), '28 Jul – 3 Aug');
    });

    testWidgets('leaving the current year carries the year', (tester) async {
      await check(tester, DateTime(2025, 12, 28), DateTime(2026, 1, 3),
          '28 Dec 2025 – 3 Jan 2026');
    });
  });

  testWidgets('the searching branch still wins over the period branch with a lens',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store();
    _seedElsewhere(store);
    _applyLens(store, DateTime(2026, 8, 4), DateTime(2026, 8, 7));

    await tester.pumpWidget(_app(store));
    await tester.pump();

    // Open search and type a query that matches nothing.
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzzznomatch');
    // Flush the 200ms search debounce.
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('No results for "zzzznomatch"'), findsOneWidget);
    expect(find.text('Nothing recorded in 4–7 Aug'), findsNothing);
    expect(find.text('Nothing recorded in August'), findsNothing);
  });

  testWidgets('no overflow: longest range form, longest locale, 130% text',
      (tester) async {
    // 320pt is the app's floor; the cross-year range is the longest form.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store();
    _seedElsewhere(store);
    _applyLens(store, DateTime(2025, 12, 28), DateTime(2026, 1, 3));

    await tester.pumpWidget(_app(store, locale: const Locale('tk'), textScale: 1.3));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('l10n — both keys present, month key untouched', () {
    test('en', () {
      final l = lookupAppLocalizations(const Locale('en'));
      expect(l.ldgNothingRecordedInRange('4–7 Aug'), 'Nothing recorded in 4–7 Aug');
      expect(l.ldgNothingRecordedInMonth('August'), 'Nothing recorded in August');
    });
    test('ru', () {
      final l = lookupAppLocalizations(const Locale('ru'));
      expect(l.ldgNothingRecordedInRange('4–7 авг'), contains('4–7 авг'));
      expect(l.ldgNothingRecordedInMonth('август'), 'Нет записей за август');
    });
    test('tr', () {
      final l = lookupAppLocalizations(const Locale('tr'));
      expect(l.ldgNothingRecordedInRange('4–7 Ağu'), '4–7 Ağu aralığında kayıt yok');
      expect(l.ldgNothingRecordedInMonth('Ağustos'), 'Ağustos ayında kayıt yok');
    });
    test('tk', () {
      final l = lookupAppLocalizations(const Locale('tk'));
      expect(
          l.ldgNothingRecordedInRange('4–7 Awg'), '4–7 Awg aralygynda hiç zat ýazylmady');
      expect(l.ldgNothingRecordedInMonth('Awgust'), 'Awgust aýynda hiç zat ýazylmady');
    });
  });
}
