import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart' show EmptyState;
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart' show ProgressBar;
import 'package:finlens/shared/widgets/section_header.dart' show ToolCluster;
import 'package:finlens/theme/app_theme.dart';

/// A store with no data of any kind — a genuine fresh install: `store.txns` is
/// empty, so §1's `everRecorded` is false and the whole instrument panel is
/// meant to go quiet.
AppStore _emptyStore() => AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

/// The Ledger tab under a real `Localizations`, at a chosen locale/size.
Widget _app(AppStore store, {Locale locale = const Locale('en')}) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LedgerScreen()),
      ),
    );

void main() {
  // The default period is August 2026; a July row is "recorded elsewhere".
  final currentMonth = DateTime(2026, 8, 15);
  final pastMonth = DateTime(2026, 7, 15);

  testWidgets(
      'empty store: no eye, no ratio bar, no metrics strip, no tool row — but the + is present',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    // The instrument panel is gone from the tree, not merely dimmed.
    expect(find.byType(ToolCluster), findsNothing);
    expect(find.byType(ProgressBar), findsNothing);
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    // The metrics strip's keys (rendered uppercased) are absent.
    expect(find.text('IN'), findsNothing);
    expect(find.text('OUT'), findsNothing);
    expect(find.text('LEFT'), findsNothing);
    // The chevron is gone with tap-to-pick.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

    // The + stays: the header's accent add plus the empty state's own button.
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty store: the new title and message render', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Every transaction lives here'), findsOneWidget);
    expect(
      find.text(
          'Record what you spend and receive. Balances, budgets and goals all read from this list.'),
      findsOneWidget,
    );
    expect(find.text('Add an entry'), findsOneWidget);
    // Not the old empty-month notice, and not a filter branch.
    expect(find.text('Clear filter'), findsNothing);
  });

  testWidgets(
      'one entry in a past month, viewing an empty current month → full header + single-line notice, not the EmptyState',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: pastMonth,
    );

    await tester.pumpWidget(_app(store));
    await tester.pump();

    // The full header is back: something has been recorded.
    expect(find.byType(ToolCluster), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

    // The empty current month gets the light line, not the heavy EmptyState.
    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Nothing recorded in August'), findsOneWidget);
  });

  testWidgets('adding the first transaction brings the tool row back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byType(ToolCluster), findsNothing);

    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: currentMonth,
    );
    await tester.pump();

    expect(find.byType(ToolCluster), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter state cannot strand a first run: empty store shows the '
      'first-run state, never Clear filter', (tester) async {
    // The filter tool is itself hidden on an empty store, so a filter can never
    // be *set* over nothing; and even a filter left active by deleting the last
    // entry loses to the `!everRecorded` branch, which is checked first. Either
    // way the reachable outcome is the first-run state, never "Clear filter".
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    expect(find.text('Every transaction lives here'), findsOneWidget);
    expect(find.text('Clear filter'), findsNothing);
    expect(find.text('No transactions match your filter'), findsNothing);
    // The filter tool that would set a filter is not even in the tree.
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);
  });

  testWidgets('320 pt in tr: the empty state does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore(), locale: const Locale('tr')));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
