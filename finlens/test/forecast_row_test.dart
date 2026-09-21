import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/planner_screen.dart';
import 'package:finlens/features/planner/widgets/forecast_row.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/rate_missing.dart';
import 'package:finlens/theme/app_colors.dart';

/// Task 057 — the forecast row widget and its place in the Planner.
///
/// `flutter test` hangs on the author's machine — run these yourself:
///   flutter test test/forecast_row_test.dart
void main() {
  Account acc(String id, AccountGroup group, double bal, {String currency = 'USD'}) =>
      Account(id: id, name: id, group: group, currency: currency, startingBalance: bal);

  AppStore store({List<Account>? accounts, Map<String, double>? rates}) => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 12)),
        baseCurrency: 'USD',
        accounts: accounts ??
            [
              acc('a-cash', AccountGroup.spendable, 130),
              acc('a-invest', AccountGroup.investments, 17950),
            ],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
        rates: rates,
      );

  // The row measures against a bounded width; top-align it so it keeps its 36pt
  // height rather than stretching to fill the screen.
  Widget wrap(AppStore s, Widget child) => StoreScope(
        store: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child)),
        ),
      );

  // A full-screen host for PlannerScreen (which needs tight constraints).
  Widget wrapScreen(AppStore s, Widget child) => StoreScope(
        store: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  void sized(WidgetTester tester, double w, {double textScale = 1.0}) {
    tester.view.physicalSize = Size(w * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final date = DateTime(2026, 9, 30);

  group('the row', () {
    testWidgets('renders the date, both labels and both values', (tester) async {
      sized(tester, 390);
      await tester.pumpWidget(wrap(store(), ForecastRow(store: store(), date: date)));
      expect(find.text('Spendable'), findsOneWidget);
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.text('30 Sep'), findsOneWidget);
      // Two values, both carrying the ≈ marker.
      expect(find.textContaining('≈'), findsNWidgets(2));
    });

    testWidgets('lays the four parts with equal gaps (§3c)', (tester) async {
      sized(tester, 390);
      final s = store();
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));

      final divider = find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 1);
      final chevron =
          find.byWidgetPredicate((w) => w is SizedBox && w.width == 22.0);
      final values = find.textContaining('≈');

      final dividerRight = tester.getTopRight(divider).dx;
      final spendLabelLeft = tester.getTopLeft(find.text('Spendable')).dx;
      final spendValueRight = tester.getTopRight(values.at(0)).dx;
      final netLabelLeft = tester.getTopLeft(find.text('Net worth')).dx;
      final netValueRight = tester.getTopRight(values.at(1)).dx;
      final chevronLeft = tester.getTopLeft(chevron).dx;

      final gap1 = spendLabelLeft - dividerRight;
      final gap2 = netLabelLeft - spendValueRight;
      final gap3 = chevronLeft - netValueRight;

      expect(gap2, closeTo(gap1, 1.0));
      expect(gap3, closeTo(gap1, 1.0));
    });

    testWidgets('stays one line and goes compact at 320 × 1.3 with huge figures',
        (tester) async {
      sized(tester, 320, textScale: 1.3);
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 1284300),
        acc('a-invest', AccountGroup.investments, 128400000 - 1284300),
      ]);
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));
      await tester.pumpAndSettle();
      // Compact form: both values abbreviate with M/K, no overflow raised.
      expect(find.textContaining('M'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null lens renders Rate missing, the other value unchanged',
        (tester) async {
      sized(tester, 390);
      // a-recv EUR has no rate → net worth silenced; spendable computes.
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, 130),
        acc('a-recv', AccountGroup.receivables, 500, currency: 'EUR'),
      ], rates: {
        'GBP': 2.0
      });
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));
      expect(find.byType(RateMissingText), findsOneWidget);
      expect(find.text('Spendable'), findsOneWidget);
    });

    testWidgets('a negative value renders in warning with −, never "Short"',
        (tester) async {
      sized(tester, 390);
      // Only spendable goes negative; net worth stays positive so '742' is unique.
      final s = store(accounts: [
        acc('a-cash', AccountGroup.spendable, -742),
        acc('a-invest', AccountGroup.investments, 9450),
      ]);
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));
      final neg = tester.widget<Text>(find.textContaining('742'));
      expect(neg.data, contains('−'));
      expect(neg.style?.color, AppColors.warning);
      expect(find.textContaining('Short'), findsNothing);
    });

    testWidgets('masked state hides both values', (tester) async {
      sized(tester, 390);
      final s = store()..toggleMasked();
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));
      expect(find.textContaining('••••'), findsNWidgets(2));
    });

    testWidgets('has no tap target (058 adds the route)', (tester) async {
      sized(tester, 390);
      final s = store();
      await tester.pumpWidget(wrap(s, ForecastRow(store: s, date: date)));
      expect(
        find.descendant(
            of: find.byType(ForecastRow), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(
            of: find.byType(ForecastRow),
            matching: find.byType(GestureDetector)),
        findsNothing,
      );
    });
  });

  group('the row in the Planner', () {
    testWidgets('renders above the segmented control on a touched Planner',
        (tester) async {
      sized(tester, 390);
      final s = buildSeedStore();
      await tester.pumpWidget(wrapScreen(s, const PlannerScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(ForecastRow), findsOneWidget);
    });

    testWidgets('a never-touched Planner hides the row', (tester) async {
      sized(tester, 390);
      final s = store(); // no budgets, goals, tasks, or archive
      await tester.pumpWidget(wrapScreen(s, const PlannerScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(ForecastRow), findsNothing);
    });

    testWidgets(
        'Schedule summary drops left-after-commitments but keeps the caption',
        (tester) async {
      sized(tester, 390);
      final s = buildSeedStore();
      await tester.pumpWidget(wrapScreen(s, const PlannerScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('left after commitments'), findsNothing);
      expect(find.text('short after commitments'), findsNothing);
      // The row is still there on the Schedule tab.
      expect(find.byType(ForecastRow), findsOneWidget);
    });

    testWidgets('no overflow at 320 and 360 on any tab', (tester) async {
      for (final w in [320.0, 360.0]) {
        sized(tester, w);
        final s = buildSeedStore();
        await tester.pumpWidget(wrapScreen(s, const PlannerScreen()));
        await tester.pumpAndSettle();
        for (final label in ['Budgets', 'Goals', 'Schedule']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
