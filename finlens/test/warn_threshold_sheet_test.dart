import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/edit_budget_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// Task 22 — the warn-threshold picker gains a sixth, Custom row. These pin the
/// behaviours the spec's Done-means list calls for: a custom percentage stored
/// as a fraction, a typed preset marking the preset (never Custom), reopening
/// on a stored custom value seeding the field, and — the invariant the image is
/// really about — exactly one check mark in every state.
///
/// The MaterialApp carries the real localization delegates pinned to English so
/// the labels read `Warn me at`, `80%`, `Custom`.

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF30D158),
    );

Budget _budget(String catId, {double limit = 500, double warn = 0.8}) => Budget(
      id: 'b-$catId',
      name: catId,
      scope: BudgetScope.categories,
      targets: {catId},
      limit: limit,
      anchor: DateTime(2026, 1, 1),
      warnThreshold: warn,
    );

AppStore _store({double warn = 0.8}) {
  final cat = _cat('c1', 'Eating out');
  return AppStore(
    accounts: [
      Account(
        id: 'a1',
        name: 'Main',
        group: AccountGroup.spendable,
        currency: 'USD',
        startingBalance: 1000,
      ),
    ],
    categories: [cat],
    budgets: [_budget(cat.id, warn: warn)],
    txns: const <Txn>[],
    goals: const <Goal>[],
    tasks: const <Task>[],
  );
}

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: const EditBudgetScreen(categoryId: 'c1'),
      ),
    );

final _field = find.byKey(const Key('warnThresholdCustomField'));
Finder get _checks => find.byIcon(Icons.check_rounded);

/// The check mark that is the trailing of the preset row titled [label].
Finder _checkOnPreset(String label) => find.descendant(
      of: find.widgetWithText(ListTile, label),
      matching: find.byIcon(Icons.check_rounded),
    );

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Warn me at')); // the row; sheet not yet open
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('opens with exactly one mark, on the stored preset (80%)',
      (tester) async {
    await tester.pumpWidget(_host(_store(warn: 0.8)));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    expect(_checks, findsOneWidget);
    expect(_checkOnPreset('80%'), findsOneWidget);
    expect(_fieldText(tester), ''); // a preset value leaves the field empty
  });

  testWidgets('typing 73 marks Custom (not a preset), field reads 73, and Save '
      'writes 0.73', (tester) async {
    final store = _store(warn: 0.8);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.enterText(_field, '73');
    await tester.pumpAndSettle();

    // Field keeps what was typed; exactly one mark, and it is NOT on any preset.
    expect(_fieldText(tester), '73');
    expect(_checks, findsOneWidget);
    for (final p in const ['50%', '70%', '80%', '90%', '100%']) {
      expect(_checkOnPreset(p), findsNothing);
    }

    // Close the sheet, then Save the screen: the fraction is written.
    await tester.tapAt(const Offset(10, 10)); // dismiss the modal barrier
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.warnThresholdOf(store.categoryById('c1')!), closeTo(0.73, 1e-9));
  });

  testWidgets('typing a preset value (90) moves the mark to the 90% row, not '
      'Custom; the field still shows 90', (tester) async {
    await tester.pumpWidget(_host(_store(warn: 0.8)));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.enterText(_field, '90');
    await tester.pumpAndSettle();

    expect(_fieldText(tester), '90'); // not cleared under the user's fingers
    expect(_checks, findsOneWidget);
    expect(_checkOnPreset('90%'), findsOneWidget);
  });

  testWidgets('reopening on a stored 73% seeds the field and marks Custom',
      (tester) async {
    await tester.pumpWidget(_host(_store(warn: 0.73)));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    expect(_fieldText(tester), '73');
    expect(_checks, findsOneWidget);
    for (final p in const ['50%', '70%', '80%', '90%', '100%']) {
      expect(_checkOnPreset(p), findsNothing);
    }
  });

  testWidgets('tapping 80% while the field reads 73 clears the field and moves '
      'the single mark to 80%', (tester) async {
    await tester.pumpWidget(_host(_store(warn: 0.73)));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    // Starts custom: field 73, mark off the presets.
    expect(_fieldText(tester), '73');

    await tester.tap(find.widgetWithText(ListTile, '80%'));
    await tester.pumpAndSettle();

    expect(_fieldText(tester), ''); // cleared
    expect(_checks, findsOneWidget);
    expect(_checkOnPreset('80%'), findsOneWidget);
  });

  testWidgets('emptying the field on a stored custom value leaves no mark and '
      'never writes a zero', (tester) async {
    final store = _store(warn: 0.73);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await tester.enterText(_field, '');
    await tester.pumpAndSettle();

    expect(_checks, findsNothing); // no preset to fall back to → no mark

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The stored value is untouched — not overwritten with 0.
    expect(store.warnThresholdOf(store.categoryById('c1')!), closeTo(0.73, 1e-9));
  });
}
