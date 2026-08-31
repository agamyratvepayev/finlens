import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/core/utils/fx.dart';
import 'package:finlens/features/insight/insight_screen.dart';

/// The second Insight spec's store additions (§9, §4, §5): the account filter
/// threaded through every windowed getter, `movedAcrossFilterInWindow`, the
/// waterfall residual, and the grid-selection rule. These are the tests that
/// prove the filtered screen still closes both identities and never lies.
void main() {
  final today = AppStore.today; // 2026-08-09
  final august = RangePreset.thisMonth.resolve(today);
  final customJulAug = DateRange(
      DateTime(2026, 7, 15), DateTime(2026, 8, 15, 23, 59, 59, 999));

  Set<String> allIds(AppStore s) => s.accounts.map((a) => a.id).toSet();

  /// The waterfall's `now` anchor — min(window.end, today), matching the screen.
  DateTime nowAnchor(DateRange w) =>
      w.end.isAfter(today) ? today : w.end;

  void expectIdentities(AppStore s, DateRange w, Set<String>? visible,
      {String? label}) {
    final net = s.netWorthChangeInWindow(w, visible: visible);

    // Flow identity, with the MOVED term the filter can add (§9.3):
    // net = in − out + revalued − transferLeak + moved.
    final flow = s.inflowInWindow(w, visible: visible) -
        s.outflowInWindow(w, visible: visible) +
        s.revaluedInWindow(w, visible: visible) -
        s.transferLeakInWindow(w, visible: visible) +
        s.movedAcrossFilterInWindow(w, visible: visible);
    expect((net - flow).abs(), lessThan(1e-6),
        reason: 'flow identity ${label ?? w.start}');

    // Stock identity: net = Σ over groups of groupChange (no MOVED term — the
    // crossing effect lands in a visible account's own group).
    final stock = AccountGroup.values.fold(
        0.0, (sum, g) => sum + s.groupChangeInWindow(g, w, visible: visible));
    expect((net - stock).abs(), lessThan(1e-6),
        reason: 'stock identity ${label ?? w.start}');
  }

  group('empty filter is a no-op (§15)', () {
    test('passing all account ids equals the unfiltered getters', () {
      final s = buildSeedStore();
      final all = allIds(s);
      for (final w in [august, customJulAug]) {
        expect(s.netWorthChangeInWindow(w, visible: all),
            closeTo(s.netWorthChangeInWindow(w), 1e-9));
        expect(s.inflowInWindow(w, visible: all),
            closeTo(s.inflowInWindow(w), 1e-9));
        expect(s.outflowInWindow(w, visible: all),
            closeTo(s.outflowInWindow(w), 1e-9));
        expect(s.revaluedInWindow(w, visible: all),
            closeTo(s.revaluedInWindow(w), 1e-9));
        expect(s.transferLeakInWindow(w, visible: all),
            closeTo(s.transferLeakInWindow(w), 1e-9));
        expect(s.chargedToCardsInWindow(w, visible: all),
            closeTo(s.chargedToCardsInWindow(w), 1e-9));
        expect(s.paidToLiabilitiesInWindow(w, visible: all),
            closeTo(s.paidToLiabilitiesInWindow(w), 1e-9));
        for (final g in AccountGroup.values) {
          expect(s.groupChangeInWindow(g, w, visible: all),
              closeTo(s.groupChangeInWindow(g, w), 1e-9));
        }
      }
    });

    test('August pins are unchanged under the all-ids set', () {
      final s = buildSeedStore();
      final all = allIds(s);
      expect(s.netWorthChangeInWindow(august, visible: all), closeTo(4424.70, 0.01));
      expect(s.inflowInWindow(august, visible: all), closeTo(6100, 0.01));
      expect(s.outflowInWindow(august, visible: all), closeTo(2972, 0.01));
      expect(s.revaluedInWindow(august, visible: all), closeTo(1300, 0.01));
      expect(s.movedAcrossFilterInWindow(august, visible: all), closeTo(0, 1e-9));
    });
  });

  group('filtered identities close (§15)', () {
    test('with one group hidden', () {
      final s = buildSeedStore();
      final all = allIds(s);
      for (final g in AccountGroup.values) {
        final groupIds = s.accountsIn(g).map((a) => a.id).toSet();
        final visible = all.difference(groupIds);
        expectIdentities(s, august, visible, label: 'hide ${g.name}');
        expectIdentities(s, customJulAug, visible, label: 'hide ${g.name} custom');
      }
    });

    test('with one account hidden', () {
      final s = buildSeedStore();
      final all = allIds(s);
      for (final a in s.accounts) {
        final visible = all.difference({a.id});
        expectIdentities(s, august, visible, label: 'hide ${a.id}');
      }
    });

    test('with an account that is one end of a transfer hidden (§9.3)', () {
      final s = buildSeedStore();
      final all = allIds(s);
      final transfers = s.transfersInWindow(august);
      expect(transfers, isNotEmpty);
      for (final t in transfers) {
        final visible = all.difference({t.fromRef});
        expectIdentities(s, august, visible, label: 'hide src of ${t.id}');
        // The whole point: hiding one end makes MOVED carry the crossing.
      }
    });
  });

  group('movedAcrossFilterInWindow (§9.3)', () {
    test('0 empty, the transfer effect with one end hidden, 0 with both', () {
      final s = buildSeedStore();
      final all = allIds(s);
      // The 4 Aug FX transfer sits alone in its day (see insight_store_test).
      final fxDay = DateRange(
          DateTime(2026, 8, 4), DateTime(2026, 8, 4, 23, 59, 59, 999));
      final transfers = s.transfersInWindow(fxDay);
      expect(transfers, hasLength(1));
      final t = transfers.single;
      final dest = s.accountById(t.toRef)!;
      final src = s.accountById(t.fromRef)!;

      // Empty filter → no boundary → 0.
      expect(s.movedAcrossFilterInWindow(fxDay), closeTo(0, 1e-9));
      expect(s.movedAcrossFilterInWindow(fxDay, visible: all), closeTo(0, 1e-9));

      // Hide the source only → money arrives at the visible destination.
      final expectedIn =
          Fx.toBase(s.effectOfTxnOn(t, dest.id), dest.currency);
      expect(
          s.movedAcrossFilterInWindow(fxDay, visible: all.difference({src.id})),
          closeTo(expectedIn, 0.01));

      // Hide the destination only → money leaves the visible source.
      final expectedOut =
          Fx.toBase(s.effectOfTxnOn(t, src.id), src.currency);
      expect(
          s.movedAcrossFilterInWindow(fxDay, visible: all.difference({dest.id})),
          closeTo(expectedOut, 0.01));

      // Hide both ends → not crossing → 0.
      expect(
          s.movedAcrossFilterInWindow(fxDay,
              visible: all.difference({src.id, dest.id})),
          closeTo(0, 1e-9));
    });
  });

  group('the waterfall residual equals the transfer leak (§15)', () {
    void expectResidual(AppStore s, DateRange w, {String? label}) {
      final before = s.netWorthOn(
          DateTime(w.start.year, w.start.month, w.start.day)
              .subtract(const Duration(days: 1)));
      final now = s.netWorthOn(nowAnchor(w));
      final residual = now -
          (before +
              s.inflowInWindow(w) -
              s.outflowInWindow(w) +
              s.revaluedInWindow(w));
      // The residual is the leak the waterfall deliberately does not draw. The
      // sign is negative — `now = before + in − out + revalued − leak` — so
      // residual + leak == 0.
      expect((residual + s.transferLeakInWindow(w)).abs(), lessThan(1e-6),
          reason: 'residual ${label ?? w.start}');
    }

    test('for the six named windows and the custom one', () {
      final s = buildSeedStore();
      for (final p in RangePreset.values) {
        expectResidual(s, p.resolve(today), label: p.name);
      }
      expectResidual(s, customJulAug, label: 'custom');
    });

    test('for twenty pseudo-random windows (fixed seed)', () {
      final s = buildSeedStore();
      final rnd = Random(20260809);
      for (var i = 0; i < 20; i++) {
        final start = DateTime(2025, 7, 1).add(Duration(days: rnd.nextInt(410)));
        final len = 1 + rnd.nextInt(140);
        final end =
            DateTime(start.year, start.month, start.day + len, 23, 59, 59, 999);
        expectResidual(s, DateRange(start, end), label: 'random #$i');
      }
    });

    test("August's leak is 3.30", () {
      final s = buildSeedStore();
      expect(s.transferLeakInWindow(august), closeTo(3.30, 0.01));
    });
  });

  group('grid selection picks the four largest, in declaration order (§5.2)', () {
    // A fixture where declaration order and magnitude order disagree — the
    // regression test for the old `changes.take(3)` bug, which named the first
    // groups in enum order rather than the biggest movers.
    final movers = <(AccountGroup, double)>[
      (AccountGroup.spendable, 40.0), // small, but first in declaration
      (AccountGroup.setAside, 3000.0), // largest
      (AccountGroup.receivables, 10.0),
      (AccountGroup.investments, 2500.0),
      (AccountGroup.valuables, 5.0),
      (AccountGroup.creditCards, -2000.0),
      (AccountGroup.payables, -1500.0),
      (AccountGroup.bankLoans, -20.0),
    ];

    test('collapsed shows the four biggest, still in declaration order', () {
      final sel = insightGridMovers(movers, expanded: false);
      expect(sel.shown.map((e) => e.$1).toList(), [
        AccountGroup.setAside,
        AccountGroup.investments,
        AccountGroup.creditCards,
        AccountGroup.payables,
      ]);
      expect(sel.hidden, 4);
      // It must NOT be the first four in enum order (the old bug).
      expect(sel.shown.first.$1, isNot(AccountGroup.spendable));
    });

    test('expanded shows all eight in declaration order', () {
      final sel = insightGridMovers(movers, expanded: true);
      expect(sel.shown, movers);
      expect(sel.hidden, 0);
    });

    test('five or fewer movers are all shown, no link', () {
      final five = movers.take(5).toList();
      final sel = insightGridMovers(five, expanded: false);
      expect(sel.shown, five);
      expect(sel.hidden, 0);
    });
  });
}
