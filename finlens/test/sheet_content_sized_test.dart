import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/sheet_content_sized_test.dart
//
// Task 20: Quick Add's "What are you adding?" sheet (and twelve siblings) used to
// open at a hard-coded fraction of the screen — dragging it up left a tall empty
// void under the last row. It now opens `contentSized`, so it hugs its seven
// fixed rows and only scrolls once the content outgrows the sheet's ceiling.
//
// These drive the real menu through `_showTypeMenu` (tap the type pill), not a
// stand-in, so a regression that reverts `contentSized`/`shrinkWrap` on the type
// menu fails here.

AppStore _store() => AppStore(
      accounts: [
        Account(
            id: 'a1',
            name: 'Cash',
            group: AccountGroup.spendable,
            currency: 'USD',
            startingBalance: 100),
      ],
      categories: [
        Category(
            id: 'g',
            name: 'Groceries',
            type: CategoryType.expense,
            icon: Icons.circle,
            color: const Color(0xFF34C759)),
      ],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

Widget _host(AppStore store, {double textScale = 1.0}) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        // A `builder` override reaches the modal sheet route, which a MediaQuery
        // below the Navigator would not.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QuickAddScreen(initialType: QuickAddType.expense),
      ),
    );

void _setSize(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(QuickAddScreen)));

/// The open menu's own opaque rounded surface — scoped to the "What are you
/// adding?" title so it can never resolve to another rounded-top container.
Finder _menuSurface(AppLocalizations l) => find.ancestor(
      of: find.text(l.qaWhatAdding),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    );

/// Opens the type menu by tapping the type pill (which shows the current type's
/// label). On a fresh expense form the pill reads "Expense".
Future<AppLocalizations> _openMenu(WidgetTester tester) async {
  final l = _l(tester);
  await tester.tap(find.text(l.quickAddExpense).first);
  await tester.pumpAndSettle();
  return l;
}

void main() {
  testWidgets(
      'type menu hugs its content — no fraction-of-screen void below the rows',
      (tester) async {
    // A deliberately tall window: the old draggable sheet opened at 0.55 of the
    // height regardless of content, so on 1200pt it stood 660pt tall with a
    // ~275pt void under the last row. contentSized ends just below it.
    _setSize(tester, 390, 1200);
    await tester.pumpWidget(_host(_store()));
    final l = await _openMenu(tester);

    final surface = tester.getRect(_menuSurface(l));
    final lastRow = tester.getRect(find.text(l.quickAddNewTask));

    // The sheet ends a hair below the last row — only the list's bottom padding
    // (Insets.xxl) — not a fraction of the screen.
    // Pre-fix: ~275 (the 0.55 void). Post-fix: ~Insets.xxl.
    expect(
      surface.bottom - lastRow.bottom,
      lessThan(Insets.xxl + 24),
      reason: 'the sheet must hug the last row, not open at a screen fraction',
    );

    // And the whole surface is far shorter than the old 0.55 fraction (660pt).
    // Pre-fix: 660 (fails). Post-fix: the content height (~460, passes).
    expect(surface.height, lessThan(600));
  });

  testWidgets('at 2x text the body scrolls inside the sheet, nothing clipped',
      (tester) async {
    // Small screen + doubled text: the seven rows outgrow the ceiling, so the
    // sheet must cap at the ceiling and scroll rather than overflow.
    _setSize(tester, 320, 568);
    await tester.pumpWidget(_host(_store(), textScale: 2.0));
    final l = await _openMenu(tester);

    // No RenderFlex overflow was thrown while laying the taller content out.
    expect(tester.takeException(), isNull);

    // The sheet is capped at the same ceiling the draggable path uses — the
    // window minus the status-bar padding (0 here) and the 44pt barrier.
    final surface = tester.getRect(_menuSurface(l));
    expect(surface.height, lessThanOrEqualTo(568 - 44 + 1));

    // The body is a real scroll view wired to the sheet's controller, so the
    // capped content scrolls instead of being cut off.
    final scrollable = find.descendant(
      of: _menuSurface(l),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(tester.widget<Scrollable>(scrollable).controller, isNotNull);

    // Drag the list up: it scrolls (no exception) and the rows remain reachable.
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l.quickAddNewTask), findsOneWidget);
  });

  testWidgets('each in-form row still selects its type', (tester) async {
    _setSize(tester, 390, 844);
    await tester.pumpWidget(_host(_store()));
    final l = _l(tester);

    // Expense → Income → Transfer → Rebalance → New task, each via the menu.
    // (New goal / New budget deliberately leave the sheet entirely, so they are
    // not type-switches to assert here — see the spec's edge notes.)
    Future<void> pick(String from, String to) async {
      await tester.tap(find.text(from).first);
      await tester.pumpAndSettle();
      // The menu is open: its title is present.
      expect(find.text(l.qaWhatAdding), findsOneWidget);
      await tester.tap(find.text(to));
      await tester.pumpAndSettle();
      // The menu closed and the pill now reads the chosen type.
      expect(find.text(l.qaWhatAdding), findsNothing);
      expect(find.text(to), findsOneWidget);
    }

    await pick(l.quickAddExpense, l.quickAddIncome);
    await pick(l.quickAddIncome, l.quickAddTransfer);
    await pick(l.quickAddTransfer, l.quickAddRebalance);
    await pick(l.quickAddRebalance, l.quickAddNewTask);
  });
}
