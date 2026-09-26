import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/more/more_screen.dart' show MoreScreen;
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 041 — one row height, one switch, one baseline.
///
/// `flutter test` hangs on the dev machine, so these are written, not run here;
/// verify with `flutter analyze` and run the file yourself. Where a number is an
/// acceptance criterion the spec asked to be *measured*, the assertion carries
/// the expected value so a failure prints the real one.
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

  void phone(WidgetTester tester, {double w = 393, double h = 852}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // The 48pt row wrapping a labelled field, by its label (its InkWell ancestor).
  Finder rowByLabel(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;

  // ── Switch parity: every FormSwitch is 40 × 24, and all three are equal ──────
  //
  // RED before §3: the goal editor's bare Switch.adaptive laid out at ~48pt, the
  // budget editor's shrinkWrap variant smaller, and only More was boxed to 40×24.

  Future<Size> onlySwitchSize(WidgetTester tester) async {
    final f = find.byType(FormSwitch);
    expect(f, findsWidgets, reason: 'the screen has at least one FormSwitch');
    return tester.getSize(f.first);
  }

  testWidgets('goal editor switch is 40 × 24', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();
    expect(await onlySwitchSize(tester), const Size(40, 24));
  });

  testWidgets('budget editor switch is 40 × 24', (tester) async {
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
    // A fresh monthly budget repeats by default, so the roll-over switch shows.
    expect(await onlySwitchSize(tester), const Size(40, 24));
  });

  testWidgets('More mask switch is 40 × 24, and all three match', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Goal.
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();
    final goalSwitch = tester.getSize(find.byType(FormSwitch).first);

    // Budget.
    final store = emptyStore();
    final cat = store.addCategory(
      name: 'Food',
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF5E5CE6),
    );
    await tester.pumpWidget(wrap(store, EditBudgetScreen(categoryId: cat.id)));
    await tester.pumpAndSettle();
    final budgetSwitch = tester.getSize(find.byType(FormSwitch).first);

    // More.
    await tester.pumpWidget(wrap(emptyStore(), const MoreScreen()));
    await tester.pumpAndSettle();
    final moreSwitch = tester.getSize(find.byType(FormSwitch).first);

    expect(goalSwitch, const Size(40, 24));
    expect(budgetSwitch, const Size(40, 24));
    expect(moreSwitch, const Size(40, 24));
    expect(goalSwitch, budgetSwitch);
    expect(budgetSwitch, moreSwitch);
  });

  // ── Tap target: the switch shrinks, the touch target does not ────────────────

  testWidgets('the goal switch row keeps a tap target ≥ 44pt tall',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();
    // The whole row is the InkWell hit target, not the 24pt control.
    final rowHeight = tester.getSize(rowByLabel('Done once reached')).height;
    expect(rowHeight, greaterThanOrEqualTo(44));
  });

  // ── The note: one line, hint carries the label, height stable ────────────────

  testWidgets('note row shows "Add a note", typing updates it, height is stable',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    final noteRow = find.byType(NoteRow);
    expect(noteRow, findsOneWidget);
    // The hint (which now carries the label's job) renders, and there is no
    // "Note" caption above it.
    expect(find.descendant(of: noteRow, matching: find.text('Add a note')),
        findsOneWidget);
    expect(find.descendant(of: noteRow, matching: find.text('Note')),
        findsNothing);

    final field = find.descendant(of: noteRow, matching: find.byType(TextField));
    final emptyH = tester.getSize(noteRow).height;

    await tester.enterText(field, 'Buy on payday');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'Buy on payday');
    final shortH = tester.getSize(noteRow).height;

    await tester.enterText(
        field,
        'A very long note that would wrap onto a second line if the row let it '
        'grow past a single line of text instead of ellipsising the overflow');
    await tester.pump();
    final longH = tester.getSize(noteRow).height;

    // Empty, short and long all measure the same — the note never wraps taller.
    expect((shortH - emptyH).abs(), lessThan(0.5));
    expect((longH - emptyH).abs(), lessThan(0.5));
  });

  // ── Even pitch of the three target rows (§8) ─────────────────────────────────
  //
  // RED before §7/§8, when the surveyed card ran 49px between rows 1–2 and 34px
  // between 2–3. This is the test that catches baseline alignment applied at the
  // wrong level: it would re-open the uneven pitch it exists to close.

  testWidgets('the three target rows are evenly pitched, centre to centre',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    // Measure the *value content* in each row, not the (trivially even) 48pt row
    // boxes: baseline alignment applied at the wrong level shifts the content
    // inside the box while leaving the box itself where it was.
    final c1 = tester
        .getRect(find.descendant(
            of: rowByLabel('Target amount'), matching: find.byType(TextField)))
        .center
        .dy;
    final c2 = tester
        .getRect(find.descendant(
            of: rowByLabel('Target date'), matching: find.text('Pick a date')))
        .center
        .dy;
    final c3 = tester
        .getRect(find.descendant(
            of: rowByLabel('Monthly'), matching: find.byType(TextField)))
        .center
        .dy;

    final pitchA = c2 - c1;
    final pitchB = c3 - c2;
    expect((pitchA - pitchB).abs(), lessThan(0.5),
        reason: 'centre-to-centre pitch must be equal: $pitchA vs $pitchB');
  });

  testWidgets('the Monthly row content is centred in its row (gap top ≈ bottom)',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    final row = tester.getRect(rowByLabel('Monthly'));
    // The row's content is its currency token ("USD") — the rightmost glyph.
    final token = tester.getRect(find.descendant(
        of: rowByLabel('Monthly'), matching: find.text('USD')));
    final gapTop = token.top - row.top;
    final gapBottom = row.bottom - token.bottom;
    expect((gapTop - gapBottom).abs(), lessThan(2.0),
        reason: 'content centred: top $gapTop vs bottom $gapBottom');
  });

  // ── Baseline: the token sits on the number's baseline (§7) ───────────────────
  //
  // RED before §7, when the inner Row used CrossAxisAlignment.center and the
  // 11.5pt token's glyphs landed below the ~15pt figure's optical centre.

  double baselineDy(WidgetTester tester, Finder f) {
    final box = tester.renderObject<RenderBox>(f);
    final d = box.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: false);
    return tester.getTopLeft(f).dy + (d ?? 0);
  }

  testWidgets('Monthly: the token sits on the same baseline as the value',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore(), const EditGoalScreen()));
    await tester.pumpAndSettle();

    final monthly = rowByLabel('Monthly');
    // The token ("USD") and the value's hint ("0", task 061) share the Monthly
    // row.
    final tokenBase = baselineDy(
        tester, find.descendant(of: monthly, matching: find.text('USD')));
    final valueBase = baselineDy(
        tester, find.descendant(of: monthly, matching: find.text('0')));

    expect((tokenBase - valueBase).abs(), lessThan(1.0),
        reason: 'token baseline $tokenBase vs value baseline $valueBase');
  });

  // ── The account editor's ToggleRow keeps its subtitle (Hard boundary) ────────

  testWidgets('account editor "hide from balance" still shows its subtitle and '
      'runs two lines', (tester) async {
    phone(tester);
    final store = emptyStore();
    final acc = store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    await tester.pumpWidget(wrap(store, EditAccountScreen(accountId: acc.id)));
    await tester.pumpAndSettle();

    expect(find.text('Hide from Balance'), findsOneWidget);
    // The subtitle stays — this row is the one place a two-line switch is right.
    expect(find.text('Kept in totals, hidden from lists'), findsOneWidget);
    // …so its row is taller than the single-line 48pt rows.
    final h = tester.getSize(rowByLabel('Hide from Balance')).height;
    expect(h, greaterThan(48));
  });

  // ── Layout survives 320/360/390 at 1.0/1.3 in all four locales ───────────────

  testWidgets('goal editor: no overflow across widths, scales and locales',
      (tester) async {
    for (final locale in const ['en', 'ru', 'tr', 'tk']) {
      for (final width in const [320.0, 360.0, 390.0]) {
        for (final scale in const [1.0, 1.3]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
              wrap(emptyStore(), const EditGoalScreen(), locale: Locale(locale)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$locale @ ${width}pt × $scale');
        }
      }
    }
  });
}
