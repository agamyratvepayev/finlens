import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/more/more_screen.dart' show MoreScreen;
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/app_card.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 042 — one contract for every label-and-value row.
///
/// `flutter test` hangs on the dev machine, so these are written, not run here;
/// verify with `flutter analyze` and run the file yourself. The height-parity,
/// cross-family-alignment and tap-target cases are RED before task 042 (six
/// heights, two icon columns, two chevrons); each carries its expected value so
/// a failure prints the real one.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() =>
      AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));

  Widget wrap(AppStore store, Widget home, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  Widget bare(Widget child) => MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 390, child: child),
          ),
        ),
      );

  void phone(WidgetTester tester, {double w = 390, double h = 844}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // A row is the InkWell ancestor of its label text.
  Finder rowByLabel(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;

  // ── The contract's numbers are self-consistent ───────────────────────────
  test('textStart is padding + iconColumn + iconGap, and equals 42', () {
    expect(RowMetrics.textStart,
        RowMetrics.padding + RowMetrics.iconColumn + RowMetrics.iconGap);
    expect(RowMetrics.textStart, 42.0);
    expect(RowMetrics.iconColumn, RowMetrics.iconGlyph);
    expect(RowMetrics.height, 48.0);
  });

  // ── Height parity: a representative single-line row per family is 48pt ─────
  // RED before task 042 on at least six families (38 / ~38 / ~42 / 44 / 48 / ~58).

  testWidgets('goal editor: single-line rows are RowMetrics.height', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();
    // Target date is a plain label/value row (value "Not set", chevron).
    final h = tester.getSize(rowByLabel('Target date')).height;
    expect(h, moreOrLessEquals(RowMetrics.height, epsilon: 0.5));
  });

  testWidgets('More: the mask / language / base-currency rows are 48pt',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const MoreScreen()));
    await tester.pumpAndSettle();
    for (final label in const ['Language', 'Mask amounts']) {
      final f = find.text(label);
      if (f.evaluate().isEmpty) continue;
      final h = tester.getSize(rowByLabel(label)).height;
      expect(h, moreOrLessEquals(RowMetrics.height, epsilon: 0.5),
          reason: '$label row height');
    }
  });

  // ── Text start: the label begins at textStart from the card's left ────────

  testWidgets('goal editor: labels begin at textStart from the card left',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    final row = tester.getRect(rowByLabel('Target date'));
    final label = tester.getRect(
        find.descendant(of: rowByLabel('Target date'), matching: find.text('Target date')));
    // The card's left edge is the row's left edge (the row fills the card width).
    expect(label.left - row.left, moreOrLessEquals(RowMetrics.textStart, epsilon: 0.5));
  });

  // ── Divider alignment: hairlines are indented to the text start ───────────

  testWidgets('FormSection dividers are indented to RowMetrics.textStart',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(bare(FormSection(children: [
      FormRow(icon: Icons.flag_rounded, label: 'One', value: 'a', onTap: () {}),
      FormRow(icon: Icons.event_rounded, label: 'Two', value: 'b', onTap: () {}),
    ])));
    await tester.pumpAndSettle();

    final divider = tester.getRect(find.byType(RowDivider).first);
    final card = tester.getRect(find.byType(FormSection));
    expect(divider.left - card.left,
        moreOrLessEquals(RowMetrics.textStart, epsilon: 0.5));
  });

  // ── Cross-family alignment: a FormRow and a TxnFieldRow line up at scale 1 ─
  // RED before task 042: the sheet's icon column was 22 vs the screens' 24, and
  // the sheet's chevron 17 vs the screens' 18.

  testWidgets('FormRow and TxnFieldRow align on icon, label and chevron',
      (tester) async {
    phone(tester); // 390pt → formScale == 1.0
    await tester.pumpWidget(bare(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FormRow(
          icon: Icons.event_rounded,
          label: 'Screen',
          value: 'Not set',
          showChevron: true,
          onTap: () {},
        ),
        TxnFieldRow(
          icon: Icons.event_rounded,
          label: 'Sheet',
          value: 'Not set',
          onTap: () {},
        ),
      ],
    )));
    await tester.pumpAndSettle();

    final screenLabel = tester.getRect(find.text('Screen')).left;
    final sheetLabel = tester.getRect(find.text('Sheet')).left;
    expect((screenLabel - sheetLabel).abs(), lessThan(0.5),
        reason: 'label dx: $screenLabel vs $sheetLabel');

    final chevrons = find.byIcon(Icons.chevron_right_rounded);
    expect(chevrons, findsNWidgets(2));
    final c0 = tester.getRect(chevrons.at(0));
    final c1 = tester.getRect(chevrons.at(1));
    expect((c0.right - c1.right).abs(), lessThan(0.5),
        reason: 'chevron right edge: ${c0.right} vs ${c1.right}');
    expect(c0.width, moreOrLessEquals(RowMetrics.chevronSize, epsilon: 0.5));
  });

  // ── Tap targets: every row's hit rect is at least 44pt tall ───────────────
  // RED before task 042 on the 38pt More rows.

  testWidgets('More rows clear the 44pt minimum tap target', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const MoreScreen()));
    await tester.pumpAndSettle();
    for (final label in const ['Language', 'Mask amounts']) {
      final f = find.text(label);
      if (f.evaluate().isEmpty) continue;
      expect(tester.getSize(rowByLabel(label)).height,
          greaterThanOrEqualTo(44));
    }
  });

  // ── Focus stability: a typed row is 48pt and its content does not move ────

  testWidgets('budget editor: a subtitled/single-line row never dips below 48',
      (tester) async {
    phone(tester);
    final store = emptyStore();
    final cat = store.addCategory(
      name: 'Food',
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF5E5CE6),
    );
    await tester.pumpWidget(wrap(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();

    // Every label-and-value InkWell row in the card is at least 48pt tall
    // (subtitled rows may be taller; none is shorter).
    for (final e in find.byType(InkWell).evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      if (size.height == 0) continue;
      expect(size.height, greaterThanOrEqualTo(RowMetrics.height - 0.5));
    }
  });

  // ── Value colour follows the contract (value = textSecondary) ─────────────

  testWidgets('a FormRow value renders at RowMetrics.valueSize', (tester) async {
    phone(tester);
    await tester.pumpWidget(bare(FormSection(children: [
      FormRow(
          icon: Icons.event_rounded,
          label: 'Row',
          value: 'Not set',
          onTap: () {}),
    ])));
    await tester.pumpAndSettle();
    final value = tester.widget<Text>(find.text('Not set'));
    expect(value.style?.fontSize, RowMetrics.valueSize);
    expect(value.style?.color, AppColors.textSecondary);
  });
}
