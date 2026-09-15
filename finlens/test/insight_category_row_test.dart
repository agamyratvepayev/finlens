import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/features/insight/category_detail_screen.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 008: on Insight's category detail screen, a tap must REVEAL (push the
// read-only SameTransactionsScreen) and the swipe strip must ACT (Edit · Copy ·
// Delete). This mirrors every other transaction row in the app.

Widget _app(AppStore store, Widget home, {Locale locale = const Locale('en')}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: home,
      ),
    );

DateRange _augustMonth() => RangePreset.thisMonth.resolve(DateTime(2026, 8, 9));

AppStore _seed() => buildSeedStore()..setInsightWindow(_augustMonth());

// c-housing carries two August movements: 'August rent' (t-rent) and
// 'Water bill' (t-water).
const _housing = 'c-housing';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpDetail(WidgetTester tester, AppStore store) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        _app(store, const CategoryDetailScreen(categoryId: _housing)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a tap reveals the read-only screen and opens no editor',
      (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    final row = find.text('August rent');
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(SameTransactionsScreen), findsOneWidget);
    expect(find.byType(QuickAddScreen), findsNothing);
  });

  testWidgets('the back label reads the category name', (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    await tester.ensureVisible(find.text('August rent'));
    await tester.pump();
    await tester.tap(find.text('August rent'));
    await tester.pumpAndSettle();

    final pushed = tester.widget<SameTransactionsScreen>(
        find.byType(SameTransactionsScreen));
    expect(pushed.backLabel, store.categoryById(_housing)!.name);
  });

  testWidgets('with a strip open, the first tap only closes it', (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    final rows = find.byType(SwipeActions);
    expect(rows, findsNWidgets(2));

    // Open the first row's strip.
    await tester.ensureVisible(rows.first);
    await tester.pump();
    await tester.drag(rows.first, const Offset(-204, 0));
    await tester.pumpAndSettle();
    expect(anySwipeRowOpen, isTrue);

    // Tapping the second row must dismiss the strip and navigate nowhere.
    await tester.tap(find.text('Water bill'));
    await tester.pumpAndSettle();

    expect(anySwipeRowOpen, isFalse);
    expect(find.byType(SameTransactionsScreen), findsNothing);
  });

  testWidgets('the strip shows Edit · Copy · Delete, in that order',
      (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    final rows = find.byType(SwipeActions);
    await tester.ensureVisible(rows.first);
    await tester.pump();
    await tester.drag(rows.first, const Offset(-204, 0));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    final editX = tester.getCenter(find.text('Edit')).dx;
    final copyX = tester.getCenter(find.text('Copy')).dx;
    final deleteX = tester.getCenter(find.text('Delete')).dx;
    expect(editX, lessThan(copyX));
    expect(copyX, lessThan(deleteX));
  });

  testWidgets('Delete confirms: cancel keeps, confirm removes', (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    final rows = find.byType(SwipeActions);
    await tester.ensureVisible(rows.first);
    await tester.pump();

    // Open, tap Delete, then cancel ("Keep it") — the txn survives.
    await tester.drag(rows.first, const Offset(-204, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(store.txnById('t-rent'), isNotNull);

    // Open again, tap Delete, confirm ("Delete entry") — the txn is gone.
    await tester.drag(rows.first, const Offset(-204, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    expect(store.txnById('t-rent'), isNull);
  });

  testWidgets('the row body is unchanged: title, subtitle and amount',
      (tester) async {
    final store = _seed();
    await pumpDetail(tester, store);

    // Title is the note when present.
    expect(find.text('August rent'), findsOneWidget);
    // Subtitle: "d MMM · account".
    expect(find.textContaining('Main Checking'), findsWidgets);
    // Amount renders on the row.
    expect(find.text('\$1,100'), findsWidgets);
  });

  // §4 — the RIGHT-OVERFLOWED band came from the current (partial) bar's dashed
  // top (_DashedTop), whose Row rounded its dash count up and appended a
  // trailing gap. today = 9 Aug 2026, so the August window is partial and the
  // dashed top is drawn. Red before the fix; green after.
  const sizes = <Size>[Size(390, 844), Size(360, 640), Size(320, 568)];
  for (final size in sizes) {
    for (final scale in const [1.0, 1.3]) {
      for (final locale in const [
        Locale('en'),
        Locale('tr'),
        Locale('tk'),
        Locale('ru')
      ]) {
        testWidgets(
            'no overflow band · ${size.width.toInt()}x${size.height.toInt()} '
            '· ${scale}x · ${locale.languageCode}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(StoreScope(
            store: _seed(),
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.dark,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: const CategoryDetailScreen(categoryId: _housing),
                ),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
