import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_colors.dart';

/// The goal editor (`EditGoalScreen`) and its source picker. `flutter test`
/// hangs on the dev machine, so these are written, not run here; verify with
/// `flutter analyze` and run the file yourself.
void main() {
  Widget wrap(AppStore store, {Locale? locale}) => StoreScope(
        store: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditGoalScreen(),
        ),
      );

  void phone(WidgetTester tester, {double w = 393, double h = 852}) {
    tester.view.physicalSize = Size(w * 3, h * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // The 48pt row wrapping a labelled field, by its label.
  Finder rowByLabel(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;

  Finder fieldInRow(String label) =>
      find.descendant(of: rowByLabel(label), matching: find.byType(TextField));

  // The name field lives in a TextFieldRow (two-line, no InkWell), so it is
  // scoped by that widget rather than by rowByLabel.
  Finder nameFieldRow() =>
      find.ancestor(of: find.text('Goal name'), matching: find.byType(TextFieldRow));
  Finder nameField() =>
      find.descendant(of: nameFieldRow(), matching: find.byType(TextField));

  // The value text of a row (the one that is not the label itself).
  Text valueTextOf(WidgetTester tester, String label) {
    final texts = tester
        .widgetList<Text>(find.descendant(
            of: rowByLabel(label), matching: find.byType(Text)))
        .where((t) => t.data != null && t.data != label)
        .toList();
    return texts.first;
  }

  AppStore storeWithOneAccount(String currency, AccountGroup group) {
    final s = AppStore.empty();
    s.addAccount(
      name: 'Vault',
      group: group,
      currency: currency,
      startingBalance: 0,
    );
    return s;
  }

  testWidgets(
      'typing a monthly amount derives the date, dims that row, and switches '
      'the caption', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    // Untouched: both halves read "Not set" and the caption is the "either" line.
    expect(find.text('Set either one — the other follows.'), findsOneWidget);

    await tester.enterText(fieldInRow('Target amount'), '12000');
    await tester.enterText(fieldInRow('Monthly'), '500');
    await tester.pump();

    // The date is now derived: its value is no longer "Not set", and the caption
    // flipped to the monthly-drives-date wording.
    expect(find.text('The date follows the monthly amount.'), findsOneWidget);
    final dateVal = valueTextOf(tester, 'Target date');
    expect(dateVal.data, isNot('Not set'));
    // The derived row is dimmed (label + value in the secondary tone).
    expect(dateVal.style?.color, AppColors.textSecondary);
  });

  testWidgets(
      'the reverse — picking a date derives the monthly figure and switches '
      'the caption', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    await tester.enterText(fieldInRow('Target amount'), '12000');
    await tester.pump();

    // Open the platform date picker and accept its initial date.
    await tester.tap(find.text('Target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly follows the target date.'), findsOneWidget);
    // The monthly field now carries the derived figure, dimmed.
    final monthlyField = tester.widget<TextField>(fieldInRow('Monthly'));
    expect(monthlyField.controller!.text, isNotEmpty);
    expect(monthlyField.style?.color, AppColors.textSecondary);
  });

  testWidgets('the name clear button appears only when filled and keeps focus',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    // Empty name → no clear button, but its slot is reserved.
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.enterText(nameField(), 'Holiday');
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    // Cleared…
    expect(tester.widget<TextField>(nameField()).controller!.text, isEmpty);
    // …and still focused.
    final editable = tester.widget<EditableText>(
        find.descendant(of: nameFieldRow(), matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('Watching and Monthly read "Not set" and no instruction leaks in',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    // None of the retired instruction strings render as a value anywhere.
    expect(find.text('Choose what to watch'), findsNothing);
    expect(find.text('Set a monthly amount'), findsNothing);
    expect(find.text('Set a date, or a monthly amount'), findsNothing);

    // Watching shows "Not set"…
    expect(find.descendant(of: rowByLabel('Watching'), matching: find.text('Not set')),
        findsOneWidget);
    // …and so does Monthly (as its placeholder).
    expect(
        find.descendant(of: rowByLabel('Monthly'), matching: find.text('Not set')),
        findsOneWidget);
  });

  testWidgets('Target amount, Target date, Monthly and Watching are equal height',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    final h = {
      for (final label in ['Watching', 'Target amount', 'Target date', 'Monthly'])
        label: tester.getSize(rowByLabel(label)).height,
    };
    expect(h['Watching'], closeTo(48, 0.5));
    expect(h['Target amount'], closeTo(48, 0.5));
    expect(h['Target date'], closeTo(48, 0.5));
    expect(h['Monthly'], closeTo(48, 0.5));
    // …and equal to one another.
    expect(h.values.toSet().length <= 1 || (h.values.reduce((a, b) => a > b ? a : b) - h.values.reduce((a, b) => a < b ? a : b)) < 0.5, isTrue);
  });

  testWidgets('the chip and the plain code share a right edge with the values',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    // The locked chip (Target amount) — a Tooltip wraps it.
    final chipRight = tester.getRect(find.byType(Tooltip)).right;

    // The plain code on Monthly: a tertiary-toned "USD".
    final codeRight = tester
        .getRect(find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'USD' &&
            w.style?.color == AppColors.textTertiary))
        .right;

    // The Target date value ("Not set") — right-aligned to the same edge.
    final dateValRight = tester
        .getRect(find.descendant(
            of: rowByLabel('Target date'), matching: find.text('Not set')))
        .right;

    expect(codeRight, closeTo(chipRight, 0.5));
    expect(dateValRight, closeTo(chipRight, 0.5));
  });

  testWidgets('picking a source changes the currency symbol, not the digits',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(
        wrap(storeWithOneAccount('TMT', AccountGroup.setAside)));

    await tester.enterText(fieldInRow('Target amount'), '1000');
    await tester.pump();
    // Before a source: the base currency.
    expect(find.byWidgetPredicate((w) =>
        w is Text && w.data == 'USD' && w.style?.color == AppColors.textTertiary),
        findsOneWidget);

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();

    // Symbol changed to the source's currency…
    expect(find.byWidgetPredicate((w) =>
        w is Text && w.data == 'TMT' && w.style?.color == AppColors.textTertiary),
        findsOneWidget);
    // …and the digits are untouched (no silent conversion).
    expect(tester.widget<TextField>(fieldInRow('Target amount')).controller!.text,
        '1000');
  });

  testWidgets('New account renders in full at 320pt with its description below',
      (tester) async {
    narrow(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();

    // The title is not truncated…
    final title = find.text('New account');
    expect(title, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(title).didExceedMaxLines, isFalse);

    // …and the description sits on its own line, below the title.
    final desc = find.text('A set-aside account, named from the goal');
    expect(desc, findsOneWidget);
    expect(tester.getTopLeft(desc).dy,
        greaterThan(tester.getBottomLeft(title).dy - 1));
  });

  testWidgets('the picker shows an empty state with no sources', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();

    // The create row stays; below it, the empty state.
    expect(find.text('New account'), findsOneWidget);
    expect(find.text('Nothing to watch yet'), findsOneWidget);
    expect(find.text('A goal follows one account or one income category.'),
        findsOneWidget);
  });

  testWidgets(
      'the picker empty state renders in all four locales', (tester) async {
    const cases = {
      'en': 'Nothing to watch yet',
      'ru': 'Пока нечего отслеживать',
      'tr': 'İzlenecek bir şey yok',
      'tk': 'Yzarlamaga zat ýok',
    };
    for (final entry in cases.entries) {
      phone(tester);
      await tester.pumpWidget(wrap(AppStore.empty(), locale: Locale(entry.key)));
      await tester.tap(find.text('Watching').first);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget,
          reason: 'empty-state title in ${entry.key}');
      // Close the sheet before the next locale.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'regression (§7): entering a monthly value then disposing throws no '
      'FlutterError', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    await tester.enterText(fieldInRow('Target amount'), '6000');
    await tester.enterText(fieldInRow('Monthly'), '250');
    await tester.pump();

    // Tear the screen down — the old dialog disposed its controller mid-route
    // and tripped `_dependents.isEmpty`; the inline field must dispose cleanly.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  // ── The Watching row's value, three states (§1) ─────────────────────────────

  testWidgets('Watching · nothing picked → "Not set", no chip', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    final row = rowByLabel('Watching');
    expect(find.descendant(of: row, matching: find.text('Not set')),
        findsOneWidget);
    // No account chip before a source is chosen.
    expect(
        find.descendant(
            of: row,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(6))),
        findsNothing);
  });

  testWidgets(
      'Watching · New account picked → value is exactly "New account", no chip, '
      'no goal name', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    // Name the goal first — the row must not echo it.
    await tester.enterText(nameField(), 'Macbook Pro M4');
    await tester.pump();

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    // The sheet's create row (its title is also "New account"); tap it.
    await tester.tap(find.text('New account').last);
    await tester.pumpAndSettle();

    final row = rowByLabel('Watching');
    // The value is exactly "New account" — no "New ·" prefix, no goal name.
    expect(find.descendant(of: row, matching: find.text('New account')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Macbook Pro M4')),
        findsNothing);
    expect(find.descendant(of: row, matching: find.textContaining('New ·')),
        findsNothing);
    // No chip for a not-yet-created account.
    expect(
        find.descendant(
            of: row,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(6))),
        findsNothing);
  });

  testWidgets(
      'Watching · existing account picked → name preceded by its coloured chip',
      (tester) async {
    phone(tester);
    final store = AppStore.empty();
    final acc = store.addAccount(
      name: 'USD Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 500,
    );
    await tester.pumpWidget(wrap(store));

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD Wallet'));
    await tester.pumpAndSettle();

    final row = rowByLabel('Watching');
    // The name is the value…
    expect(find.descendant(of: row, matching: find.text('USD Wallet')),
        findsOneWidget);
    // …preceded by a 20pt chip tinted with the account's own colour.
    expect(
        find.descendant(
            of: row,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    AppColors.tint(acc.color, 0.18))),
        findsOneWidget);
  });

  testWidgets(
      'renaming the goal does not change the Watching row (New account)',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New account').last);
    await tester.pumpAndSettle();

    final row = rowByLabel('Watching');
    expect(find.descendant(of: row, matching: find.text('New account')),
        findsOneWidget);

    // Rename the goal — the row is unaffected because it never showed the name.
    await tester.enterText(nameField(), 'A completely different name');
    await tester.pump();
    expect(find.descendant(of: row, matching: find.text('New account')),
        findsOneWidget);
    expect(
        find.descendant(
            of: row, matching: find.text('A completely different name')),
        findsNothing);
  });

  testWidgets(
      'row heights: the single-line Watching row is shorter than the two-line '
      '"Done once reached" row', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(AppStore.empty()));

    final single = tester.getSize(rowByLabel('Watching')).height;
    final twoLine = tester.getSize(rowByLabel('Done once reached')).height;
    // The single-line row is the shared 48pt _LineRow…
    expect(single, closeTo(48, 0.5));
    // …and the two-line switch row grows past it to fit its subtitle.
    expect(twoLine, greaterThan(single));
  });
}
