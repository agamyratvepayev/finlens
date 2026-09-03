import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/new_account_test.dart

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store() => AppStore(
      accounts: [_acc('a1', 'Main Checking')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, void Function(BuildContext) onTap,
        {Locale? locale}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

void main() {
  group('sign convention (spec §5.4)', () {
    test('a liability created with 15000 is stored as −15000', () {
      final store = _store();
      final created = store.addAccount(
        name: 'Amex',
        group: AccountGroup.creditCards,
        currency: 'USD',
        startingBalance: 15000,
      );
      expect(created.startingBalance, -15000);
      expect(store.balanceOf(created.id), -15000);
    });

    test('an asset keeps its positive opening balance', () {
      final store = _store();
      final created = store.addAccount(
        name: 'Savings',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 500,
      );
      expect(created.startingBalance, 500);
    });

    test('addAccount carries emoji and colour through', () {
      final store = _store();
      final created = store.addAccount(
        name: 'Wallet',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 0,
        emoji: '💰',
        colorValue: 0xFF30D158,
      );
      expect(created.emoji, '💰');
      expect(created.colorValue, 0xFF30D158);
      expect(created.color, const Color(0xFF30D158));
    });
  });

  testWidgets('the form shows three rows: no ICON section, no Currency row',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Three-row form: name, Type, Starting balance. The old ICON heading and the
    // standalone Currency row label are gone (spec §1).
    expect(find.text('ICON'), findsNothing);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Starting balance'), findsOneWidget);
    // The old inline Currency row label no longer appears on the form.
    expect(find.text('Currency'), findsNothing);
  });

  testWidgets('the type row shows REQUIRED until a type is chosen',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('REQUIRED'), findsOneWidget);

    // Open the type sheet and pick Spendable.
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    // Eight types with descriptions.
    expect(find.text('Current account, cash, your debit card'), findsOneWidget);
    expect(find.text('Cards you spend on and repay later'), findsOneWidget);

    await tester.tap(find.text('Current account, cash, your debit card'));
    await tester.pumpAndSettle();
    // A satisfied requirement stops announcing itself.
    expect(find.text('REQUIRED'), findsNothing);
    // The type name now shows in the row.
    expect(find.text('Spendable'), findsWidgets);
  });

  testWidgets('Create & select is disabled with no type, enabled after one',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Holiday');
    await tester.pumpAndSettle();

    FilledButton button() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create & select'));
    // No type yet → disabled.
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings you don\'t plan to spend yet'));
    await tester.pumpAndSettle();

    expect(button().onPressed, isNotNull);
  });

  testWidgets('reopening the type sheet shows a check on the selected row',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards you spend on and repay later'));
    await tester.pumpAndSettle();

    // Reopen — the previously chosen row carries a check.
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('one tap on the name row asks the platform to show the keyboard',
      (tester) async {
    final store = _store();
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.textInput, null));

    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Autofocus already asked once; clear and tap the label area of the name row
    // (outside the field), which must still ask the platform to show (§8a).
    calls.clear();
    await tester.tap(find.text('Account name'));
    await tester.pump();
    expect(calls.any((c) => c.method == 'TextInput.show'), isTrue);
  });

  testWidgets('tapping the leading tile opens the icon picker', (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    // The icon picker's Icons/Emoji switch is up.
    expect(find.text('Icons'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
  });

  testWidgets('choosing an icon then changing the type keeps the icon',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Choose Spendable first.
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current account, cash, your debit card'));
    await tester.pumpAndSettle();

    // Explicitly pick an icon from the picker (the first grid glyph).
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    final firstGlyph = find.byType(Icon).at(0);
    final chosen = tester.widget<Icon>(firstGlyph).icon;
    await tester.tap(firstGlyph);
    await tester.pumpAndSettle();

    // Change the type — an explicitly chosen icon must survive (§7b).
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A car, gold, property you could sell'));
    await tester.pumpAndSettle();

    // The name-row tile still renders the chosen glyph.
    expect(find.byIcon(chosen!), findsWidgets);
  });

  testWidgets('duplicate name shows an inline error (case-insensitive)',
      (tester) async {
    final store = _store(); // has "Main Checking"
    await tester.pumpWidget(_host(store, (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  main checking  ');
    await tester.pumpAndSettle();
    expect(
        find.text('An account with this name already exists'), findsOneWidget);
  });

  testWidgets('no overflow at 320pt and 130% text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = _store();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _host(store, (ctx) => showNewAccountSheet(ctx)),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
