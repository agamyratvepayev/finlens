import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/category_picker_test.dart

Category _cat(String id, String name, {double? budget}) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
      monthlyBudget: budget,
    );

AppStore _store({int count = 3, bool budgets = false}) => AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'Checking',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: [
        for (var i = 0; i < count; i++)
          _cat('c$i', i == 0 ? 'Transportation' : 'Cat $i',
              budget: budgets ? 1000 : null),
      ],
      txns: budgets
          ? [
              Txn(
                id: 't1',
                type: TxnType.expense,
                amount: 650,
                currency: 'USD',
                fromRef: 'a1',
                toRef: 'c0',
                date: DateTime(2026, 8, 5),
              ),
            ]
          : const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Future<Category?> _openPicker(WidgetTester tester, AppStore store) async {
  Category? result;
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  result = await pickCategory(ctx, type: CategoryType.expense),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  // The controller closure captures `result` after the sheet pops.
  return result;
}

void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1125, 2436); // 375 × 812 @3x
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('the category picker shows no currency strings (§2)',
      (tester) async {
    _portrait(tester);
    await _openPicker(tester, _store(count: 3, budgets: true));
    // Previously each row read "$650 / $1,000"; the grid shows names only.
    expect(
      find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains(r'$')),
      findsNothing,
    );
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('categories render in a 3-column grid (§3)', (tester) async {
    _portrait(tester);
    await _openPicker(tester, _store(count: 6));
    // First three cells share a row; the fourth drops to the next.
    final y0 = tester.getTopLeft(find.text('Transportation')).dy;
    final y1 = tester.getTopLeft(find.text('Cat 1')).dy;
    final y2 = tester.getTopLeft(find.text('Cat 2')).dy;
    final y3 = tester.getTopLeft(find.text('Cat 3')).dy;
    expect(y0, y1);
    expect(y1, y2);
    expect(y3, greaterThan(y2));
    // Long name wraps rather than the tile shrinking.
    final label = tester.widget<Text>(find.text('Transportation'));
    expect(label.maxLines, 2);
  });

  testWidgets('a 13-category set is 5 rows, last row left-aligned (§5)',
      (tester) async {
    _portrait(tester);
    await _openPicker(tester, _store(count: 13));
    // 13 cats + the New cell = 14 cells across 3 columns = 5 rows.
    final rows = <double>{};
    for (var i = 0; i < 13; i++) {
      final finder = i == 0 ? find.text('Transportation') : find.text('Cat $i');
      rows.add(tester.getTopLeft(finder).dy.roundToDouble());
    }
    rows.add(tester.getTopLeft(find.text('New')).dy.roundToDouble());
    expect(rows.length, 5);
    // Last row (13th category + New) starts at the left column.
    final firstColX = tester.getTopLeft(find.text('Transportation')).dx;
    expect(tester.getTopLeft(find.text('Cat 12')).dx, closeTo(firstColX, 0.5));
  });

  testWidgets('the New cell stays when a search matches nothing (§5)',
      (tester) async {
    _portrait(tester);
    await _openPicker(tester, _store(count: 3));
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('No category matches'), findsOneWidget);
  });

  testWidgets('tapping a cell returns that category and pops', (tester) async {
    _portrait(tester);
    final store = _store(count: 3);
    Category? result;
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result =
                    await pickCategory(ctx, type: CategoryType.expense),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transportation'));
    await tester.pumpAndSettle();

    expect(result?.id, 'c0');
    expect(find.text('Search categories'), findsNothing); // sheet popped
  });

  group('dismiss on tap outside, at every height (§1)', () {
    testWidgets('tap above pops at the default height', (tester) async {
      _portrait(tester);
      await _openPicker(tester, _store(count: 3));
      expect(find.text('Search categories'), findsOneWidget);
      await tester.tapAt(const Offset(187, 120)); // above the sheet body
      await tester.pumpAndSettle();
      expect(find.text('Search categories'), findsNothing);
    });

    testWidgets('tap above pops at full height', (tester) async {
      _portrait(tester);
      await _openPicker(tester, _store(count: 30));
      // Expand toward the max extent.
      await tester.fling(
          find.byType(SingleChildScrollView), const Offset(0, -700), 1200);
      await tester.pumpAndSettle();
      // A tap within the 44pt barrier that must remain above the sheet.
      await tester.tapAt(const Offset(187, 30));
      await tester.pumpAndSettle();
      expect(find.text('Search categories'), findsNothing);
    });

    testWidgets('a downward fling from full pops in one gesture',
        (tester) async {
      _portrait(tester);
      await _openPicker(tester, _store(count: 30));
      await tester.fling(
          find.byType(SingleChildScrollView), const Offset(0, -700), 1200);
      await tester.pumpAndSettle();
      await tester.fling(
          find.byType(SingleChildScrollView), const Offset(0, 900), 1400);
      await tester.pumpAndSettle();
      expect(find.text('Search categories'), findsNothing);
    });
  });
}
