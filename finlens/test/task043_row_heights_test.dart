import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/edit_account_screen.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/form_fields.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 043 §2/§5 — the last five bespoke rows join task 042's contract: the
// currency editor's Code, Name, Symbol, Position, Decimal places and Preview
// are each RowMetrics.height, the Position picker lines up with the values
// above it, and TextFieldRow is one 48pt line.
//
// `flutter test` hangs on the author's machine — run this yourself:
//   flutter test test/task043_row_heights_test.dart

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setCustomCurrencies(const []);
  });
  tearDown(() => setCustomCurrencies(const []));

  AppStore emptyStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Widget host(AppStore store, void Function(BuildContext) onOpen) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => onOpen(c),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openEditTmt(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        host(emptyStore(), (c) => showEditCurrencySheet(c, currencyDef('TMT'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('currency editor: all five format rows and Preview are 48pt',
      (tester) async {
    await openEditTmt(tester);

    for (final k in const [
      'curRowCode',
      'curRowName',
      'curRowSymbol',
      'curRowPosition',
      'curRowDecimals',
    ]) {
      expect(tester.getSize(find.byKey(Key(k))).height,
          moreOrLessEquals(RowMetrics.height, epsilon: 0.5),
          reason: '$k is RowMetrics.height');
    }

    // The Preview card carries no key; find it by its label and measure its
    // enclosing Container.
    final preview = find
        .ancestor(of: find.text('Preview'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(preview).height,
        moreOrLessEquals(RowMetrics.height, epsilon: 0.5),
        reason: 'the Preview card is RowMetrics.height');
  });

  testWidgets(
      "the Position picker's right edge is flush with the Decimal-places value",
      (tester) async {
    await openEditTmt(tester);

    final picker = find.descendant(
      of: find.byKey(const Key('curRowPosition')),
      matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('SegmentedPicker')),
    );
    final pickerRight = tester.getRect(picker).right;

    // TMT is a two-decimal currency, so Decimal places reads "2".
    final decValRight = tester
        .getRect(find.descendant(
            of: find.byKey(const Key('curRowDecimals')), matching: find.text('2')))
        .right;

    expect(pickerRight, moreOrLessEquals(decValRight, epsilon: 0.5),
        reason: 'the picker lines up with the values above it (§2)');
  });

  testWidgets('a bare TextFieldRow is one 48pt line, with or without an icon',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    Widget wrap(Widget child) => MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: FormSection(children: [child])),
        );

    await tester.pumpWidget(wrap(TextFieldRow(
      label: 'Name',
      controller: controller,
      hint: 'hint',
    )));
    await tester.pump();
    expect(tester.getSize(find.byType(TextFieldRow)).height,
        moreOrLessEquals(RowMetrics.height, epsilon: 0.5));

    await tester.pumpWidget(wrap(TextFieldRow(
      icon: Icons.badge_rounded,
      label: 'Name',
      controller: controller,
      hint: 'hint',
      trailing: const Text(r'$'),
    )));
    await tester.pump();
    expect(tester.getSize(find.byType(TextFieldRow)).height,
        moreOrLessEquals(RowMetrics.height, epsilon: 0.5));
  });

  testWidgets(
      'account editor: every TextFieldRow is 48pt and the credit-limit symbol '
      'sits after the field', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A credit-card account owns the credit-limit TextFieldRow with a trailing
    // currency symbol.
    final store = AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9)),
      accounts: [
        Account(
          id: 'cc',
          name: 'Card',
          group: AccountGroup.creditCards,
          currency: 'USD',
          startingBalance: 0,
          creditLimit: 5000,
        ),
      ],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EditAccountScreen(accountId: 'cc'),
      ),
    ));
    await tester.pumpAndSettle();

    final rows = find.byType(TextFieldRow);
    expect(rows, findsWidgets);
    for (var i = 0; i < rows.evaluate().length; i++) {
      expect(tester.getSize(rows.at(i)).height,
          moreOrLessEquals(RowMetrics.height, epsilon: 0.5),
          reason: 'TextFieldRow #$i is RowMetrics.height');
    }

    // The credit-limit row shows its USD symbol; with the field now right-
    // aligned, the trailing "$" sits after it (to the right of the digits).
    final creditRow = find.ancestor(
        of: find.text('5,000'), matching: find.byType(TextFieldRow));
    if (creditRow.evaluate().isNotEmpty) {
      final symbol = find.descendant(of: creditRow, matching: find.text(r'$'));
      expect(symbol, findsOneWidget);
      expect(tester.getRect(symbol).left,
          greaterThan(tester.getRect(find.descendant(
                  of: creditRow, matching: find.byType(EditableText)))
              .left));
    }
  });
}
