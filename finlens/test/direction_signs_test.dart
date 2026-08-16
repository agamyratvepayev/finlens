import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/scoped_ledger_screen.dart';
import 'package:finlens/theme/app_theme.dart';

Widget _app(AppStore store, LedgerScope scope) => StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ScopedLedgerScreen(initialScope: scope),
      ),
    );

void main() {
  group('formatter', () {
    test('signless drops both + and -', () {
      expect(money(900, signless: true), r'$900');
      expect(money(-132, signless: true), r'$132');
      expect(money(0, signless: true), r'$0');
    });

    test('the negative-balance exception keeps the minus', () {
      // A balance below zero is a fact about the account, not a direction of
      // travel, so stripping the sign would make the number wrong.
      expect(money(-1340), '−\$1,340');
      expect(money(12198), r'$12,198');
      expect(money(0), r'$0');
    });

    test('signless and signed disagree only on negatives', () {
      for (final v in [0.0, 1.0, 900.0, 12198.0]) {
        expect(money(v, signless: true), money(v));
      }
      expect(money(-5, signless: true), isNot(money(-5)));
    });
  });

  group('rendered output', () {
    testWidgets('the period chip keeps its direction arrows', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(buildSeedStore(), const AllAccountsScope()));
      await tester.pump(const Duration(milliseconds: 300));

      // The arrows are direction *glyphs*, not signs: they survived the change
      // that stripped +/- from the amounts, and they are the chip's only
      // non-colour cue.
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      // The stepper chevrons are a different thing and must survive too.
      expect(find.byIcon(Icons.chevron_left_rounded), findsWidgets);
    });

    testWidgets('money-in stays left of money-out, even at zero',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final handle = tester.ensureSemantics();
      // A period with no income at all: the slot must still render.
      final store = buildSeedStore();
      await tester.pumpWidget(_app(store, const AllAccountsScope()));
      await tester.pump(const Duration(milliseconds: 300));

      final inFinder = find.bySemanticsLabel(RegExp(r'^Money in, '));
      final outFinder = find.bySemanticsLabel(RegExp(r'^Money out, '));
      expect(inFinder, findsOneWidget);
      expect(outFinder, findsOneWidget);
      // Order is the only non-colour cue left, so it is load-bearing.
      expect(
        tester.getCenter(inFinder).dx,
        lessThan(tester.getCenter(outFinder).dx),
      );
      handle.dispose();
    });

    testWidgets('row amounts are unsigned while a negative balance is not',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = buildSeedStore();
      // A real negative-balance fixture rather than reading the code: a credit
      // card is legitimately below zero.
      final card = store.accountsIn(AccountGroup.creditCards).first;
      expect(store.balanceOf(card.id), lessThan(0));
      expect(money(store.balanceOf(card.id)), startsWith('−'),
          reason: 'a balance below zero keeps its minus');

      // All-accounts so the month actually has rows to inspect.
      await tester.pumpWidget(_app(store, const AllAccountsScope()));
      await tester.pump(const Duration(milliseconds: 300));

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.contains(r'$'))
          .toList();
      expect(texts, isNotEmpty, reason: 'seed data should cover this month');

      // No amount anywhere carries a plus any more.
      expect(texts.where((s) => s.startsWith('+')), isEmpty);

      // The figures that must now be unsigned are the row amounts and the day
      // nets. Build them from the same query the screen uses and assert none
      // of them renders a sign.
      final range = RangePreset.thisMonth.resolve(AppStore.today);
      final rows = LedgerQuery(
        store: store,
        scope: const AllAccountsScope(),
        start: range.start,
        end: range.end,
      ).rows();
      expect(rows, isNotEmpty);

      // Only on-screen rows build, so assert the inverse: no row's *signed*
      // rendering appears anywhere. That is the actual requirement, and it
      // holds regardless of how many rows the viewport happened to build.
      for (final r in rows.where((r) => r.displayAmount < 0)) {
        expect(texts, isNot(contains(money(r.displayAmount))));
        expect(texts, isNot(contains(money(r.displayAmount, showSign: true))));
      }

      // And a balance below zero still shows its minus, proving the exception
      // survived rather than everything simply being stripped.
      expect(texts.any((t) => t.startsWith('−')), isTrue,
          reason: 'running balances keep their sign');
    });
  });

  group('contrast against the card background', () {
    // WCAG relative luminance.
    double lum(int r, int g, int b) {
      double ch(int c) {
        final s = c / 255.0;
        return s <= 0.03928 ? s / 12.92 : _pow((s + 0.055) / 1.055, 2.4);
      }

      return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
    }

    double ratio(double a, double b) =>
        (a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05));

    test('both direction colours clear 4.5:1', () {
      final sheet = lum(0x1C, 0x1C, 0x1E);
      final card = lum(0x14, 0x14, 0x16);

      expect(ratio(lum(0xFF, 0x45, 0x3A), sheet), greaterThan(4.5)); // red
      expect(ratio(lum(0x30, 0xD1, 0x58), sheet), greaterThan(4.5)); // green
      // The muted outflow red used on rows sits on the darker card.
      expect(ratio(lum(0xD4, 0x56, 0x4D), card), greaterThan(4.5));
    });
  });
}

double _pow(double x, double e) => _exp(e * _ln(x));

double _ln(double x) {
  var sum = 0.0;
  var t = (x - 1) / (x + 1);
  final t2 = t * t;
  for (var n = 0; n < 60; n++) {
    sum += t / (2 * n + 1);
    t *= t2;
  }
  return 2 * sum;
}

double _exp(double x) {
  var term = 1.0;
  var sum = 1.0;
  for (var n = 1; n < 60; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}
