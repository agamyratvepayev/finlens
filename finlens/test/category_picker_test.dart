import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/icon_picker_sheet.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/category_cell.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/category_picker_test.dart
//
// Covers the reworked category picker (category-picker spec §1–§9):
//   1 · no categories        2 · 1–9 categories (no search)
//   3 · 10+ categories       4 · query with no match
// plus the new-category form (§7) and the shared icon picker's §6 extensions.
//
// The header create action renders "+ New": a leading '+' the empty-state (which
// has NO body button) does not otherwise draw, and the label from qaNewShort.

Category _cat(
  String id,
  String name, {
  CategoryType type = CategoryType.expense,
  Color color = const Color(0xFF34C759),
  String? emoji,
  DateTime? createdAt,
}) =>
    Category(
      id: id,
      name: name,
      type: type,
      icon: Icons.shopping_basket_rounded,
      color: color,
      emoji: emoji,
      createdAt: createdAt,
    );

List<Category> _n(int n, {CategoryType type = CategoryType.expense}) => [
      for (var i = 0; i < n; i++) _cat('c$i', 'Cat $i', type: type),
    ];

AppStore _store(List<Category> cats, {List<Txn> txns = const []}) => AppStore(
      accounts: [
        Account(
          id: 'a1',
          name: 'Checking',
          group: AccountGroup.spendable,
          currency: 'USD',
          startingBalance: 1000,
        ),
      ],
      categories: cats,
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, void Function(BuildContext) onTap,
        {Locale locale = const Locale('en'), double textScale = 1.0}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onTap(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openPicker(
  WidgetTester tester,
  AppStore store, {
  CategoryType type = CategoryType.expense,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(_host(
    store,
    (ctx) => pickCategory(ctx, type: type),
    locale: locale,
    textScale: textScale,
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void _setSize(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

Iterable<String> _allText(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(
          (t) => t.data ?? t.textSpan?.toPlainText() ?? '',
        );

void main() {
  // ── State 1 · no categories ───────────────────────────────────────────────
  group('state 1 · no categories', () {
    testWidgets('empty state: header + New, no search, no body button (§1)',
        (tester) async {
      await _openPicker(tester, _store(const []));
      expect(find.text('No categories yet'), findsOneWidget);
      // Header action present (its '+' and its label); no body FilledButton.
      expect(find.text('+'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // No search field with nothing to filter.
      expect(find.byType(TextField), findsNothing);
      // No create tile in a (non-existent) grid.
      expect(find.byType(NewCategoryCell), findsNothing);
    });

    testWidgets('renders no empty pair of quotation marks (§8)', (tester) async {
      await _openPicker(tester, _store(const []));
      for (final s in _allText(tester)) {
        expect(s.contains('""'), isFalse, reason: 'stray quotes in: "$s"');
      }
    });
  });

  // ── State 2 · 1–9 categories ──────────────────────────────────────────────
  group('state 2 · 1–9 categories', () {
    testWidgets('exactly 9 → no search field (§4/§9)', (tester) async {
      await _openPicker(tester, _store(_n(9)));
      expect(find.byType(TextField), findsNothing);
      expect(find.text('+'), findsOneWidget);
      expect(find.byType(CategoryCell), findsNWidgets(9));
      expect(find.byType(NewCategoryCell), findsNothing);
    });
  });

  // ── State 3 · 10+ categories ──────────────────────────────────────────────
  group('state 3 · 10+ categories', () {
    testWidgets('exactly 10 → search field appears (§4/§9)', (tester) async {
      await _openPicker(tester, _store(_n(10)));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('whitespace-only query is treated as no query (§9)',
        (tester) async {
      await _openPicker(tester, _store(_n(10)));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      // State 3 stays; state 4 is never reached on a blank query.
      expect(find.textContaining('No category matches'), findsNothing);
      expect(find.byType(CategoryCell), findsNWidgets(10));
    });
  });

  // ── State 4 · query with no match ─────────────────────────────────────────
  group('state 4 · no match', () {
    testWidgets('one message, trimmed query, no quotes, no create tile (§4)',
        (tester) async {
      await _openPicker(tester, _store(_n(10)));
      await tester.enterText(find.byType(TextField), '  zzzz  ');
      await tester.pumpAndSettle();
      expect(find.textContaining('No category matches'), findsOneWidget);
      expect(find.textContaining('zzzz'), findsOneWidget);
      for (final s in _allText(tester)) {
        expect(s.contains('""'), isFalse);
      }
      expect(find.byType(CategoryCell), findsNothing);
      expect(find.byType(NewCategoryCell), findsNothing);
      // Header create action still present, exactly once.
      expect(find.text('+'), findsOneWidget);
    });

    testWidgets('a 200-char query stays on one line without exception',
        (tester) async {
      _setSize(tester, 390, 844);
      await _openPicker(tester, _store(_n(10)));
      await tester.enterText(find.byType(TextField), 'z' * 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rich = find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('No category matches'));
      expect(rich, findsOneWidget);
      expect(tester.widget<RichText>(rich).maxLines, 1);
    });
  });

  // ── Header stability & no create tile ─────────────────────────────────────
  testWidgets('header + New holds its position across states 2→3→4 (§1)',
      (tester) async {
    _setSize(tester, 390, 844);
    await _openPicker(tester, _store(_n(10)));
    final noQuery = tester.getTopLeft(find.text('New'));
    await tester.enterText(find.byType(TextField), 'Cat 1'); // matches → state 3
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('New')), noQuery);
    await tester.enterText(find.byType(TextField), 'zzzz'); // no match → state 4
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('New')), noQuery);
  });

  testWidgets('no create tile exists inside the grid in any state (§1)',
      (tester) async {
    await _openPicker(tester, _store(_n(3)));
    expect(find.byType(NewCategoryCell), findsNothing);
    await _openPicker(tester, _store(_n(12)));
    expect(find.byType(NewCategoryCell), findsNothing);
  });

  // ── Grid geometry (§2) ────────────────────────────────────────────────────
  testWidgets('five per row: the sixth cell drops to the next row (§2)',
      (tester) async {
    _setSize(tester, 390, 844);
    await _openPicker(tester, _store(_n(6)));
    final ys = [for (var i = 0; i < 5; i++) tester.getTopLeft(find.text('Cat $i')).dy];
    for (final y in ys) {
      expect(y, ys.first); // first five share a row
    }
    expect(tester.getTopLeft(find.text('Cat 5')).dy, greaterThan(ys.first));
  });

  // ── Ordering (§3) ─────────────────────────────────────────────────────────
  testWidgets('order is usage-descending, ties broken by newest first (§3)',
      (tester) async {
    _setSize(tester, 390, 844);
    final used = _cat('used', 'Used', createdAt: DateTime(2026, 1, 1));
    final newer = _cat('newer', 'Newer', createdAt: DateTime(2026, 8, 1));
    final older = _cat('older', 'Older', createdAt: DateTime(2026, 2, 1));
    final store = _store(
      [older, newer, used], // deliberately not in display order
      txns: [
        Txn(
          id: 't1',
          type: TxnType.expense,
          amount: 10,
          currency: 'USD',
          fromRef: 'a1',
          toRef: 'used',
          date: DateTime(2026, 8, 5),
        ),
      ],
    );
    await _openPicker(tester, store);
    // Row 0, left→right: Used (1 use) < Newer (0 use, newer) < Older (0, older).
    final xUsed = tester.getTopLeft(find.text('Used')).dx;
    final xNewer = tester.getTopLeft(find.text('Newer')).dx;
    final xOlder = tester.getTopLeft(find.text('Older')).dx;
    expect(xUsed, lessThan(xNewer));
    expect(xNewer, lessThan(xOlder));
  });

  // ── Selection by label (§2) ───────────────────────────────────────────────
  testWidgets('tapping the label (not the tile) selects and pops', (tester) async {
    final store = _store([_cat('c0', 'Groceries')]);
    Category? result;
    await tester.pumpWidget(_host(
      store,
      (ctx) async => result = await pickCategory(ctx, type: CategoryType.expense),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries')); // the label
    await tester.pumpAndSettle();
    expect(result?.id, 'c0');
    expect(find.byType(CategoryCell), findsNothing); // sheet popped
  });

  // ── Per-category colour (§5) ──────────────────────────────────────────────
  testWidgets('a category renders its own stored colour, not a forced red (§5)',
      (tester) async {
    const green = Color(0xFF34C759);
    await _openPicker(tester, _store([_cat('c0', 'Groceries', color: green)]));
    final icon = tester.widget<Icon>(
      find.descendant(of: find.byType(CategoryCell), matching: find.byType(Icon)),
    );
    expect(icon.color, green);
  });

  // ── Income direction shares the widget (§9) ───────────────────────────────
  testWidgets('income direction: income title + list, same widget type',
      (tester) async {
    await _openPicker(
      tester,
      _store([_cat('i0', 'Salary', type: CategoryType.income)]),
      type: CategoryType.income,
    );
    expect(find.text('Income category'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.byType(CategoryCell), findsWidgets);
  });

  // ── New-category form (§7) ────────────────────────────────────────────────
  group('new-category form', () {
    Future<void> openForm(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(_host(
          store, (ctx) => showNewCategorySheet(ctx, type: CategoryType.expense)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('button disabled for empty and duplicate name, enabled for new',
        (tester) async {
      final store = _store([_cat('c0', 'Groceries')]);
      await openForm(tester, store);
      final button =
          find.widgetWithText(FilledButton, 'Create & select');
      // Empty name → disabled.
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      // Duplicate (same direction) → still disabled.
      await tester.enterText(find.byType(TextField), 'Groceries');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('already exists'), findsOneWidget);
      // Unique name → enabled.
      await tester.enterText(find.byType(TextField), 'Fuel');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });
  });

  // ── Shared icon picker §6 extensions ──────────────────────────────────────
  group('shared icon picker (§6)', () {
    Future<void> openIconPicker(WidgetTester tester) async {
      await tester.pumpWidget(_host(
        _store(const []),
        (ctx) => showIconPicker(ctx, typeColor: const Color(0xFF5E5CE6)),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('group headings carry a count', (tester) async {
      await openIconPicker(tester);
      // e.g. "BANKING & CASH · 9" — a heading with the · count separator.
      expect(find.textContaining(' · '), findsWidgets);
    });

    testWidgets('no icon match offers Try emoji and carries the query across',
        (tester) async {
      await openIconPicker(tester);
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No icon matches'), findsOneWidget);
      expect(find.text('Try emoji instead'), findsOneWidget);
      await tester.tap(find.text('Try emoji instead'));
      await tester.pumpAndSettle();
      // Landed on the Emoji tab with the query intact → the emoji search also
      // finds nothing, which only happens if 'zzzzz' carried across.
      expect(find.text('No emoji match'), findsOneWidget);
    });

    testWidgets('the colour row stays pinned while the grid scrolls',
        (tester) async {
      _setSize(tester, 390, 844);
      await openIconPicker(tester);
      expect(find.text('COLOUR'), findsOneWidget);
      await tester.fling(
          find.byType(AccountGlyphTile).first, const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('COLOUR'), findsOneWidget);
    });
  });

  // ── No overflow across widths, scale and locales (§9/§10) ─────────────────
  group('layout: no overflow', () {
    Future<void> exercise(WidgetTester tester,
        {required Locale locale, required double textScale}) async {
      // State 1
      await _openPicker(tester, _store(const []),
          locale: locale, textScale: textScale);
      expect(tester.takeException(), isNull);
      // State 3 → 4
      await _openPicker(tester, _store(_n(12)),
          locale: locale, textScale: textScale);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (final w in const [390.0, 360.0, 320.0]) {
      testWidgets('en @ ${w.toInt()}pt, 1.0x', (tester) async {
        _setSize(tester, w, 844);
        await exercise(tester, locale: const Locale('en'), textScale: 1.0);
      });
      testWidgets('en @ ${w.toInt()}pt, 1.3x', (tester) async {
        _setSize(tester, w, 844);
        await exercise(tester, locale: const Locale('en'), textScale: 1.3);
      });
    }

    for (final loc in const [Locale('tr'), Locale('ru')]) {
      testWidgets('${loc.languageCode} @ 320pt', (tester) async {
        _setSize(tester, 320, 568);
        await exercise(tester, locale: loc, textScale: 1.0);
      });
    }
  });
}
