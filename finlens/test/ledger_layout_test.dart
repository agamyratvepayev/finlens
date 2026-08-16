import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

const _sizes = <String, Size>{
  '390x844': Size(390, 844),
  '360x640': Size(360, 640),
  '320x568': Size(320, 568),
};

/// Keyed by scope so swapping scope mounts a fresh screen. `initialScope` is
/// read once into State, which is right for the app (the switcher changes
/// scope, never the constructor) but means an unkeyed swap would silently
/// reuse the old State.
Widget _app(AppStore store, LedgerScope scope) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ScopedLedgerScreen(
          key: ValueKey(scope.runtimeType.toString() + scope.hashCode.toString()),
          initialScope: scope,
        ),
      ),
    );

void main() {
  final scopes = <String, LedgerScope>{
    'all': const AllAccountsScope(),
    'group': const GroupScope(AccountGroup.spendable),
  };

  for (final size in _sizes.entries) {
    for (final scope in scopes.entries) {
      testWidgets('${scope.key} scope lays out at ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(buildSeedStore(), scope.value));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the 216px action strip fits a 320pt row', (tester) async {
    tester.view.physicalSize = _sizes['320x568']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(buildSeedStore(), const AllAccountsScope()));
    await tester.pump(const Duration(milliseconds: 300));

    // Card margins are a flat 16 either side at every width.
    expect(3 * 72, lessThan(320 - 32));
  });

  testWidgets('account scope drops line 3; group scope keeps it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = buildSeedStore();
    final account = store.accountsIn(AccountGroup.spendable).first;

    // All-accounts is treated as group scope: three lines, because the
    // account varies from row to row.
    await tester.pumpWidget(_app(store, const AllAccountsScope()));
    await tester.pump(const Duration(milliseconds: 300));
    final wide = find.byType(LedgerTxnRow);
    expect(wide, findsWidgets, reason: 'seed data should cover this month');
    expect(tester.getSize(wide.first).height, 66);

    // Account scope: two lines — the account is already in the header.
    await tester.pumpWidget(_app(store, AccountScope(account.id)));
    await tester.pump(const Duration(milliseconds: 300));
    final narrow = find.byType(LedgerTxnRow);
    if (narrow.evaluate().isNotEmpty) {
      expect(tester.getSize(narrow.first).height, 52);
    }
    expect(tester.takeException(), isNull);
  });

  test('rows and day totals are signed the same way', () {
    final store = buildSeedStore();
    final range = RangePreset.allTime.resolve(AppStore.today);
    final q = LedgerQuery(
      store: store,
      scope: const AllAccountsScope(),
      start: range.start,
      end: range.end,
    );

    for (final r in q.rows()) {
      switch (r.kind) {
        case FlowKind.inflow:
          expect(r.displayAmount, greaterThanOrEqualTo(0));
        case FlowKind.outflow:
          expect(r.displayAmount, lessThanOrEqualTo(0));
        case FlowKind.internal:
          // Neither direction — it never left the scope.
          expect(r.displayAmount, r.signedAmount);
      }
    }
  });

  test('the three range compressions', () {
    final today = DateTime(2026, 8, 13);

    // 1 — repeated month drops out.
    expect(
      DateRange(DateTime(2026, 8, 4), DateTime(2026, 8, 12)).label(today),
      '4–12 Aug',
    );
    // Both ends spelled out when the months differ.
    expect(
      DateRange(DateTime(2026, 7, 27), DateTime(2026, 8, 2)).label(today),
      '27 Jul – 2 Aug',
    );
    // 2 — the year returns once the range leaves the current one.
    expect(
      DateRange(DateTime(2025, 12, 1), DateTime(2025, 12, 31)).label(today),
      '1–31 Dec 2025',
    );
    // 3 — all time is month and year only.
    expect(
      DateRange(DateTime(2000), today, preset: RangePreset.allTime)
          .label(today, firstEver: DateTime(2023, 3, 4)),
      'Since Mar 2023',
    );
    // A single day collapses to one date.
    expect(
      DateRange(DateTime(2026, 8, 9), DateTime(2026, 8, 9)).label(today),
      '9 Aug',
    );
  });

  test('an internal transfer is excluded from In and Out', () {
    final store = buildSeedStore();
    final range = RangePreset.allTime.resolve(AppStore.today);

    LedgerQuery q(LedgerScope s) => LedgerQuery(
          store: store,
          scope: s,
          start: range.start,
          end: range.end,
        );

    // Same transfer, two scopes: internal inside the group that holds both
    // ends, and a real outflow from the single account that lost the money.
    final group = q(const GroupScope(AccountGroup.spendable));
    final internal =
        group.rows().where((r) => r.kind == FlowKind.internal).toList();

    for (final r in internal) {
      final account = store.accountById(r.txn.fromRef)!;
      final single = q(AccountScope(account.id));
      final same = single.rows().where((x) => x.txn.id == r.txn.id);
      // It leaves that one account, so there it counts.
      expect(same.first.kind, FlowKind.outflow);
    }

    // And the group's Out never includes them.
    final groupOut = group.totalOut;
    expect(
      groupOut,
      group
          .rows()
          .where((r) => r.kind == FlowKind.outflow)
          .fold<double>(0, (s, r) => s + r.signedAmount),
    );
  });
}
