import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show NumericKeypad;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/shared/widgets/category_cell.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/split_category_dedup_test.dart
//
// Task 006: a split is a set of categories (spec §1), the sheet opens ready to
// type (spec §2), and Done never leaves the screen (spec §3).

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store({List<Category>? categories}) => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [
        Account(
          id: 'a1',
          name: 'Cash',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: categories ??
          [_cat('c1', 'Groceries'), _cat('c2', 'Household'), _cat('c3', 'Fuel')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

const _delegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  TkMaterialLocalizationsDelegate(),
  TkCupertinoLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

SplitLine _line(String cat, double? amt) =>
    SplitLine(categoryId: cat, amount: amt);

/// Opens the split sheet and hands back a getter for the popped result.
Future<List<SplitLine>? Function()> _openSheet(
  WidgetTester tester, {
  required double total,
  required List<SplitLine> initial,
  AppStore? store,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  List<SplitLine>? result;
  var popped = false;

  await tester.pumpWidget(StoreScope(
    store: store ?? _store(),
    child: MaterialApp(
      localizationsDelegates: _delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await showSplitSheet(
                    ctx,
                    total: total,
                    currency: 'USD',
                    accountName: 'Cash',
                    categoryType: CategoryType.expense,
                    initial: initial,
                  );
                  result = r;
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => popped ? result : null;
}

Future<void> _key(WidgetTester tester, String k) async {
  await tester.tap(find.descendant(
    of: find.byType(NumericKeypad),
    matching: find.text(k),
  ));
  await tester.pump();
}

FilledButton _done(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));

Finder _cellFor(String id) =>
    find.byWidgetPredicate((w) => w is CategoryCell && w.category.id == id);

void main() {
  // ── §2 · opens ready to type ────────────────────────────────────────────────
  group('a fresh split opens on line 0 with the keypad up (§2)', () {
    testWidgets('the keypad is open and line 0 is active', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      // The production shape of a fresh split: one line carrying the txn's own
      // category, amount blank.
      await _openSheet(tester, total: 1200, initial: [SplitLine(categoryId: 'c1')]);

      expect(find.byType(NumericKeypad), findsOneWidget);
      // Line 0's row reports itself selected while it is the active line — its
      // a11y label is the "active line" phrasing, not the "name, amount" one.
      final l = AppLocalizations.of(tester.element(find.byType(NumericKeypad)));
      expect(find.bySemanticsLabel(l.ssActiveLineA11y('Groceries')),
          findsOneWidget);
    });

    testWidgets('a digit pressed immediately lands on line 0', (tester) async {
      await _openSheet(tester, total: 1200, initial: [SplitLine(categoryId: 'c1')]);

      // No row tap first — straight to a key.
      await _key(tester, '5');
      expect(find.text(r'$5.00'), findsOneWidget);
    });

    testWidgets('re-opening a two-line split lands in list mode', (tester) async {
      await _openSheet(tester,
          total: 100, initial: [_line('c1', 60), _line('c2', 40)]);

      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.text('Split evenly'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  // ── §3 · Done never leaves the screen ───────────────────────────────────────
  group('Done is present in both modes (§3)', () {
    testWidgets('Done shows with the keypad open, dim until balanced, then pops',
        (tester) async {
      final result = await _openSheet(tester,
          total: 100, initial: [_line('c1', 30), _line('c2', 20)]);

      // Open the keypad on the first line.
      await tester.tap(find.text(r'$30.00'));
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsOneWidget);

      // Done is on screen but disabled while the sum is short.
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
      expect(_done(tester).onPressed, isNull);

      // Balance it from the keypad: clear the active line's 30 and type 80, so
      // line 0 = 80 + line 1 = 20 = the 100 total.
      await _key(tester, 'back'); // "30" → "3"
      await _key(tester, 'back'); // "3"  → blank
      await _key(tester, '8');
      await _key(tester, '0'); // 80 → remainder 0, both categorised
      expect(_done(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      final popped = result();
      expect(popped, isNotNull);
      expect(popped!.length, 2);
    });

    testWidgets('Split evenly is absent in entry mode and returns on close',
        (tester) async {
      await _openSheet(tester,
          total: 100, initial: [_line('c1', 50), _line('c2', 50)]);
      expect(find.text('Split evenly'), findsOneWidget);

      await tester.tap(find.text(r'$50.00').first);
      await tester.pumpAndSettle();
      expect(find.text('Split evenly'), findsNothing);

      // Tapping the active line again closes the keypad → list mode again.
      await tester.tap(find.text(r'$50.00').first);
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsNothing);
      expect(find.text('Split evenly'), findsOneWidget);
    });
  });

  // ── §1 · a category is spent once ───────────────────────────────────────────
  group('the picker excludes categories already on other lines (§1)', () {
    testWidgets('+ Add a line dims the other lines\' categories; a dim tap is a '
        'no-op', (tester) async {
      await _openSheet(tester,
          total: 100, initial: [_line('c1', 60), _line('c2', 40)]);

      await tester.tap(find.text('Add a line'));
      await tester.pumpAndSettle();

      // Both existing categories are shown chosen-but-unavailable; the free one
      // is offered.
      final c1 = tester.widget<CategoryCell>(_cellFor('c1'));
      final c2 = tester.widget<CategoryCell>(_cellFor('c2'));
      final c3 = tester.widget<CategoryCell>(_cellFor('c3'));
      expect(c1.enabled, isFalse);
      expect(c1.selected, isTrue);
      expect(c2.enabled, isFalse);
      expect(c3.enabled, isTrue);

      // Tapping the dimmed one does nothing: the picker stays open and no line
      // is added.
      await tester.tap(_cellFor('c1'));
      await tester.pumpAndSettle();
      expect(_cellFor('c3'), findsOneWidget, reason: 'the picker is still open');
    });

    testWidgets('a line\'s own category shows selected and is still selectable',
        (tester) async {
      await _openSheet(tester,
          total: 100, initial: [_line('c1', 60), _line('c2', 40)]);

      // Tap line 0's category name.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      final c1 = tester.widget<CategoryCell>(_cellFor('c1'));
      final c2 = tester.widget<CategoryCell>(_cellFor('c2'));
      expect(c1.selected, isTrue);
      expect(c1.enabled, isTrue, reason: 'its own category re-picks as a no-op');
      expect(c2.enabled, isFalse, reason: 'the other line owns c2');

      // Re-pick it: the picker closes and the line is unchanged.
      await tester.tap(_cellFor('c1'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryCell), findsNothing, reason: 'picker closed');
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text(r'$60.00'), findsOneWidget);
    });

    testWidgets('with every category taken the picker still opens with + New',
        (tester) async {
      final store = _store(
          categories: [_cat('c1', 'Groceries'), _cat('c2', 'Household')]);
      await _openSheet(tester,
          total: 100,
          initial: [_line('c1', 60), _line('c2', 40)],
          store: store);

      await tester.tap(find.text('Add a line'));
      await tester.pumpAndSettle();

      // Both categories present but dimmed, and the header + New is still there.
      expect(tester.widget<CategoryCell>(_cellFor('c1')).enabled, isFalse);
      expect(tester.widget<CategoryCell>(_cellFor('c2')).enabled, isFalse);
      expect(find.text('New'), findsOneWidget);
    });
  });

  // ── §1 · the pure helper ────────────────────────────────────────────────────
  group('splitUsedCategoryIds (§1c)', () {
    final lines = [
      SplitLine(categoryId: null, amount: 5), // category-less
      SplitLine(categoryId: 'a', amount: 1), // duplicate pair …
      SplitLine(categoryId: 'a', amount: 2), // … with the one above
      SplitLine(categoryId: 'b', amount: 3),
      SplitLine(categoryId: 'c', amount: 4),
    ];

    test('collapses to the distinct set, ignoring the category-less line', () {
      expect(splitUsedCategoryIds(lines), {'a', 'b', 'c'});
    });

    test('exceptIndex drops that line, but a duplicate keeps the id alive', () {
      // Excluding one of the two "a" lines still leaves "a" used by the other.
      expect(splitUsedCategoryIds(lines, exceptIndex: 1), {'a', 'b', 'c'});
    });

    test('excluding a unique line removes its id', () {
      expect(splitUsedCategoryIds(lines, exceptIndex: 3), {'a', 'c'});
    });
  });

  // ── §1b · CategoryCell.enabled ──────────────────────────────────────────────
  group('CategoryCell.enabled (§1b)', () {
    Widget host(Widget child) => MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('disabled reports enabled:false and never fires onTap',
        (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      var taps = 0;
      await tester.pumpWidget(host(CategoryCell(
        category: _cat('c1', 'Groceries'),
        selected: true,
        enabled: false,
        onTap: () => taps++,
      )));

      expect(
        tester.getSemantics(find.byType(CategoryCell)),
        isSemantics(
            hasEnabledState: true, isEnabled: false, isSelected: true),
      );

      await tester.tap(find.byType(CategoryCell));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('an enabled cell keeps its old semantics and fires onTap',
        (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      var taps = 0;
      await tester.pumpWidget(host(CategoryCell(
        category: _cat('c1', 'Groceries'),
        selected: false,
        onTap: () => taps++,
      )));

      // Unchanged from before this field existed: no enabled state is advertised.
      expect(
        tester.getSemantics(find.byType(CategoryCell)),
        isSemantics(hasEnabledState: false),
      );

      await tester.tap(find.byType(CategoryCell));
      await tester.pump();
      expect(taps, 1);
    });
  });

  // ── §4 · layout budget ──────────────────────────────────────────────────────
  testWidgets('320×568 · 130% · three lines · keypad open: no overflow',
      (tester) async {
    await _openSheet(tester,
        total: 100,
        initial: [_line('c1', 40), _line('c2', 30), _line('c3', null)],
        size: const Size(320, 568),
        textScale: 1.3);

    await tester.tap(find.text(r'$40.00'));
    await tester.pumpAndSettle();

    expect(find.byType(NumericKeypad), findsOneWidget);
    // Done and the status verdict both stay on screen above the keypad.
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.text('Left to assign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
