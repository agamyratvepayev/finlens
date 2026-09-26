import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_goal_screen.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart'
    show CurrencyChip;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/shared/widgets/typed_date_field.dart';
import 'package:finlens/theme/app_colors.dart';

/// The goal editor (`EditGoalScreen`) and its source picker, after task 066:
/// "Progress from", the app's static chip, a pace period, `auto` on the
/// computed half, no caption. `flutter test` hangs on the dev machine, so these
/// are written, not run here; verify with `flutter analyze`.
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

  Finder rowByLabel(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;

  Finder fieldInRow(String label) =>
      find.descendant(of: rowByLabel(label), matching: find.byType(TextField));

  Finder nameFieldRow() => find.byType(NameField);
  Finder nameField() =>
      find.descendant(of: nameFieldRow(), matching: find.byType(TextField));

  Text valueTextOf(WidgetTester tester, String label) {
    final texts = tester
        .widgetList<Text>(find.descendant(
            of: rowByLabel(label), matching: find.byType(Text)))
        .where((t) => t.data != null && t.data != label)
        .toList();
    return texts.first;
  }

  AppStore emptyStore() =>
      AppStore.empty(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)));

  AppStore storeWithOneAccount(String currency, AccountGroup group) {
    final s = emptyStore();
    s.addAccount(
        name: 'Vault', group: group, currency: currency, startingBalance: 0);
    return s;
  }

  // ── §5 · the pace pair, now marked `auto`, no caption ──────────────────────
  testWidgets('typing a pace derives the date, dims it and marks it auto',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    // No pair caption anywhere (task 066 §5e removed it).
    expect(find.text('Set either one — the other follows.'), findsNothing);
    expect(find.text('auto'), findsNothing);

    await tester.enterText(fieldInRow('Target amount'), '12000');
    await tester.enterText(fieldInRow('Monthly'), '500');
    await tester.pump();

    // The date is computed → not the placeholder, dimmed, and wears `auto`.
    final dateVal = valueTextOf(tester, 'Target date');
    expect(dateVal.data, isNot('Pick a date'));
    expect(dateVal.style?.color, AppColors.textSecondary);
    expect(find.text('auto'), findsOneWidget);
  });

  testWidgets('picking a date derives the pace figure and marks it auto',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    await tester.enterText(fieldInRow('Target amount'), '12000');
    await tester.pump();

    await tester.tap(find.text('Target date'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
          of: find.byType(TypedDateField), matching: find.byType(TextField)),
      '15062027',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // The pace figure is computed and dimmed, and the pace row wears `auto`.
    final monthlyField = tester.widget<TextField>(fieldInRow('Monthly'));
    expect(monthlyField.controller!.text, isNotEmpty);
    expect(monthlyField.style?.color, AppColors.textSecondary);
    expect(find.text('auto'), findsOneWidget);
  });

  testWidgets('the name clear button appears only when filled and keeps focus',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await tester.enterText(nameField(), 'Holiday');
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(tester.widget<TextField>(nameField()).controller!.text, isEmpty);
    final editable = tester.widget<EditableText>(find.descendant(
        of: nameFieldRow(), matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  // ── §2 · "Progress from" names its action ──────────────────────────────────
  testWidgets('Progress from reads Choose account; the pace reads Monthly',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    expect(find.text('Choose source'), findsNothing);
    expect(
        find.descendant(
            of: rowByLabel('Progress from'),
            matching: find.text('Choose account')),
        findsOneWidget);
    // The pace row's label is the period.
    expect(find.text('Monthly'), findsOneWidget);
    // An empty pace reads 0 (task 061), not a sentence.
    expect(
        find.descendant(of: rowByLabel('Monthly'), matching: find.text('0')),
        findsOneWidget);
  });

  // ── §3 · both amount rows carry the app's static chip (no padlock) ─────────
  testWidgets('both amounts use CurrencyChip; tapping one shows the hint',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    // Two static chips — Target amount and the pace row — and no padlock.
    expect(find.byType(CurrencyChip), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.tap(find.byType(CurrencyChip).first);
    await tester.pump();
    expect(find.text("Amounts follow the source's currency."), findsOneWidget);
  });

  // ── row parity (task 041) — still 48pt each ─────────────────────────────────
  testWidgets('all goal rows are 48pt and equal', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));

    final heights = [
      for (final label in [
        'Progress from',
        'Target amount',
        'Target date',
        'Monthly',
        'Done once reached',
      ])
        tester.getSize(rowByLabel(label)).height,
      tester.getSize(find.byType(NoteRow)).height,
    ];
    for (final h in heights) {
      expect(h, closeTo(48, 0.5));
    }
    final maxH = heights.reduce((a, b) => a > b ? a : b);
    final minH = heights.reduce((a, b) => a < b ? a : b);
    expect(maxH - minH, lessThan(0.5));
  });

  testWidgets('picking a source changes the chip currency, not the digits',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(storeWithOneAccount('TMT', AccountGroup.setAside)));

    await tester.enterText(fieldInRow('Target amount'), '1000');
    await tester.pump();
    // Before a source: the base currency chips.
    expect(find.widgetWithText(CurrencyChip, 'USD'), findsNWidgets(2));

    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CurrencyChip, 'TMT'), findsNWidgets(2));
    expect(tester.widget<TextField>(fieldInRow('Target amount')).controller!.text,
        '1000');
  });

  // ── §2b · the source sheet ─────────────────────────────────────────────────
  testWidgets('the sheet lists New savings account and one ACCOUNTS section',
      (tester) async {
    phone(tester);
    final store = emptyStore();
    store.addAccount(
        name: 'Vault',
        group: AccountGroup.setAside,
        currency: 'USD',
        startingBalance: 500);
    await tester.pumpWidget(wrap(store));
    await tester.enterText(nameField(), 'iPhone 17 Pro');
    await tester.pump();

    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();

    // The create row, with the goal name quoted beneath it.
    expect(find.text('New savings account'), findsOneWidget);
    expect(find.text('“iPhone 17 Pro”'), findsOneWidget);
    // One ACCOUNTS section, no per-group labels.
    expect(find.text('ACCOUNTS'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
  });

  testWidgets('the New savings account row omits the name while it is empty',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));
    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    expect(find.text('New savings account'), findsOneWidget);
    // No quoted name when the goal has none yet.
    expect(find.textContaining('“'), findsNothing);
  });

  testWidgets('the picker shows an empty state with no sources', (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));
    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    expect(find.text('New savings account'), findsOneWidget);
    expect(find.text('Nothing to watch yet'), findsOneWidget);
  });

  testWidgets('New savings account picked → value is exactly that, no chip',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));
    await tester.enterText(nameField(), 'Macbook Pro M4');
    await tester.pump();

    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New savings account').last);
    await tester.pumpAndSettle();

    final row = rowByLabel('Progress from');
    expect(find.descendant(of: row, matching: find.text('New savings account')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Macbook Pro M4')),
        findsNothing);
  });

  testWidgets('existing account picked → name preceded by its coloured chip',
      (tester) async {
    phone(tester);
    final store = emptyStore();
    final acc = store.addAccount(
        name: 'USD Wallet',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 500);
    await tester.pumpWidget(wrap(store));

    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD Wallet'));
    await tester.pumpAndSettle();

    final row = rowByLabel('Progress from');
    expect(find.descendant(of: row, matching: find.text('USD Wallet')),
        findsOneWidget);
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

  testWidgets('New savings account at 320pt renders in full', (tester) async {
    narrow(tester);
    await tester.pumpWidget(wrap(emptyStore()));
    await tester.tap(find.text('Progress from'));
    await tester.pumpAndSettle();
    expect(find.text('New savings account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering a pace value then disposing throws no FlutterError',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(wrap(emptyStore()));
    await tester.enterText(fieldInRow('Target amount'), '6000');
    await tester.enterText(fieldInRow('Monthly'), '250');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
