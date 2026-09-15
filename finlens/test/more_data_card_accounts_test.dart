import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/more/more_screen.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/more_data_card_accounts_test.dart

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store() => AppStore(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)), 
      accounts: [_acc('a1', 'Main Checking')],
      categories: const <Category>[],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _hostMore(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: MoreScreen()),
      ),
    );

Widget _hostSheet(AppStore store, void Function(BuildContext) onTap) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('DATA card is four rows in the §1 order', (tester) async {
    await tester.pumpWidget(_hostMore(_store()));
    await tester.pump();

    final accounts = tester.getCenter(find.text('Accounts'));
    final categories = tester.getCenter(find.text('Categories'));
    final tags = tester.getCenter(find.text('Tags'));
    final currencies = tester.getCenter(find.text('Currencies'));
    final archive = tester.getCenter(find.text('Archive'));
    final backUp = tester.getCenter(find.text('Back up'));
    final restore = tester.getCenter(find.text('Restore'));

    // Row 1: Accounts | Categories — same line, Accounts on the left.
    expect((accounts.dy - categories.dy).abs(), lessThan(1.0));
    expect(accounts.dx, lessThan(categories.dx));

    // Row 2: Tags | Currencies — below row 1, Tags on the left.
    expect((tags.dy - currencies.dy).abs(), lessThan(1.0));
    expect(tags.dx, lessThan(currencies.dx));
    expect(tags.dy, greaterThan(accounts.dy));

    // Row 3: Archive, then Row 4: Back up | Restore.
    expect(archive.dy, greaterThan(tags.dy));
    expect(backUp.dy, greaterThan(archive.dy));
    expect((backUp.dy - restore.dy).abs(), lessThan(1.0));
    expect(backUp.dx, lessThan(restore.dx));
  });

  testWidgets('New account sheet no longer carries the removed helper line',
      (tester) async {
    await tester.pumpWidget(
        _hostSheet(_store(), (ctx) => showNewAccountSheet(ctx)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet is open…
    expect(find.text('New account'), findsWidgets);
    // …and the "Enter this once…" explainer is gone, replaced by nothing.
    expect(find.textContaining('Enter this once'), findsNothing);
    expect(
      find.textContaining('calculated from your transactions'),
      findsNothing,
    );
  });
}
