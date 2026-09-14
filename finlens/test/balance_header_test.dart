import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/features/balance/balance_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/section_header.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/balance_header_test.dart
//
// Balance-header rebuild: the delta badge ("▲ 0.0% vs yesterday") and the count
// line ("1 group · 2 accounts") are gone; the amount and the four tools now share
// ONE row, optically centred; a three-step ladder shrinks the font (30 → 22),
// then the buttons (28 → 24), then drops the tools below — never truncating,
// abbreviating or rounding the figure, and never below a 22pt floor.
//
// NOTE ON FONTS: the widget-test font renders every glyph as a 1em square, so a
// figure's *pixel* width here is charCount × fontSize, not its real proportional
// width. These tests therefore assert the invariants that hold under any font —
// the full string renders, the size stays in [22, 30], nothing overflows, the
// centres coincide — and never assert an exact on-device size (e.g. "30pt on a
// 390pt screen" is a screenshot check, per the spec).

AppStore _store({
  double wallet = 2000,
  String currency = 'USD',
  String base = 'USD',
  List<Account> extra = const [],
}) =>
    AppStore(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)), 
      baseCurrency: base,
      accounts: [
        Account(
          id: 'w',
          name: 'My Wallet',
          group: AccountGroup.spendable,
          currency: currency,
          startingBalance: wallet,
        ),
        Account(
          id: 'f',
          name: 'Family Cash',
          group: AccountGroup.spendable,
          currency: currency,
          startingBalance: 0,
        ),
        ...extra,
      ],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

Widget _host(AppStore store, {double textScale = 1.0}) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: BalanceScreen()),
      ),
    );

void _setSize(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

/// The header hero amount, scoped to the AnimatedSwitcher's `amount` key so it
/// can never resolve to a group-row or section-total figure of the same value.
Finder _headerAmount() => find.descendant(
      of: find.byKey(const ValueKey('amount')),
      matching: find.byType(Text),
    );

Text _amountWidget(WidgetTester tester) =>
    tester.widget<Text>(_headerAmount().first);

/// The fill of the tool button that carries [icon].
Color _toolFill(WidgetTester tester, IconData icon) {
  final box = tester.widget<Container>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  // setBalanceFilter fire-and-forgets a SharedPreferences write.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Task 1 — badge and count are gone', () {
    testWidgets('no delta badge and no "N groups · M accounts" line',
        (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      // The badge's signature is the DeltaChip's ▲/▼ — unique to it on this
      // screen (the date pill uses keyboard_arrow_down, a different glyph).
      expect(find.byIcon(Icons.arrow_drop_up_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);
      // The header count line said "N group(s) · …". Group ROW subtitles say
      // "N accounts · P%" (list, not header) and group NAMES never contain the
      // literal word "group", so its absence is a clean signal the line is gone.
      expect(find.textContaining('group'), findsNothing);
      expect(find.textContaining('groups'), findsNothing);
    });
  });

  group('Task 2 — one row, optically centred', () {
    testWidgets('amount centre and tool-row centre coincide', (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      final amount = tester.getRect(_headerAmount().first);
      // Each tool glyph is centred in its button, and the buttons are centred
      // against the amount (CrossAxisAlignment.center), so any glyph's centre
      // shares the amount's optical centre.
      for (final icon in const [
        Icons.swap_vert_rounded,
        Icons.filter_alt_outlined,
        Icons.search_rounded,
      ]) {
        final glyph = tester.getRect(find.byIcon(icon));
        expect(
          (glyph.center.dy - amount.center.dy).abs(),
          lessThan(1.5),
          reason: '$icon must be optically centred against the amount',
        );
      }
    });

    testWidgets('gaps: amount sits 6+row1(36)+8 below the safe area',
        (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      // No system padding in the test, so the SafeArea adds 0: the amount box
      // top = 6 (safe→row1) + 36 (row1 height) + 8 (row1→amount) = 50. A wrong
      // top-gap or row1→amount gap shifts this.
      final top = tester.getRect(_headerAmount().first).top;
      expect(top, closeTo(50, 1.5));
    });

    testWidgets('gap below: amount → ASSETS label composes to 39',
        (tester) async {
      // On NET WORTH the chain is amount(30) →8→ ratio bar(3) →14 (header
      // bottom pad) → list → 14 (section-header top pad) → "ASSETS". The 14pt
      // header-bottom pad — the header-ends/list-begins boundary — is the
      // load-bearing value here. (The ratio bar is deliberately kept, per the
      // product decision, so the literal amount→section=14 does not apply.)
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      final amountBottom = tester.getRect(_headerAmount().first).bottom;
      final labelTop = tester.getRect(find.text('ASSETS')).top;
      expect(labelTop - amountBottom, closeTo(8 + 3 + 14 + 14, 2.0));
    });
  });

  group('Task 3 — the ladder never truncates and never drops below 22', () {
    // (value, currency/base, screen width) — the full string must render and the
    // resolved size must stay in [22, 30] at every width.
    final cases = <(double, String, double)>[
      (2000, 'USD', 390),
      (1248300, 'USD', 390),
      (20000000000, 'USD', 390),
      (-20000000000, 'USD', 390), // balances are unsigned → magnitude renders
      (200000000000, 'USD', 320),
      (20000000000, 'TMT', 320), // the wide, non-USD case
    ];

    for (final (value, cur, width) in cases) {
      testWidgets('$value $cur @ ${width.toInt()} renders in full, 22–30pt',
          (tester) async {
        _setSize(tester, width, 844);
        final store = _store(wallet: value, currency: cur, base: cur);
        await tester.pumpWidget(_host(store));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final expected = money(
          store.balanceFilter.netWorth(store),
          currency: cur,
          signless: true,
        );
        final widget = _amountWidget(tester);
        expect(
          widget.data,
          expected,
          reason: 'never truncated, abbreviated or rounded',
        );
        final size = widget.style!.fontSize!;
        expect(size, greaterThanOrEqualTo(22));
        expect(size, lessThanOrEqualTo(30));
      });
    }

    testWidgets('320pt + text scale 1.3: nothing overflows, floor holds',
        (tester) async {
      _setSize(tester, 320, 568);
      final store = _store(wallet: 200000000000);
      await tester.pumpWidget(_host(store, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_amountWidget(tester).style!.fontSize, greaterThanOrEqualTo(22));
    });
  });

  group('Empty list and filter state', () {
    testWidgets('LIABILITIES with none: \$0 and zero tool buttons',
        (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      // all → assets → liabilities.
      await tester.tap(find.byType(SectionIndicator));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SectionIndicator));
      await tester.pumpAndSettle();

      expect(_amountWidget(tester).data, '\$0');
      // No sort / collapse / filter / search — the whole cluster is absent.
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
      expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);
    });

    testWidgets('filter active: the filter button reads differently from siblings',
        (tester) async {
      _setSize(tester, 390, 844);
      final store = _store(extra: [
        Account(
          id: 'inv',
          name: 'Stocks',
          group: AccountGroup.investments,
          currency: 'USD',
          startingBalance: 5000,
        ),
      ]);
      // Hide Investments; Spendable stays visible, so the list is non-empty and
      // the tools remain built.
      store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.investments),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final filterFill = _toolFill(tester, Icons.filter_alt_rounded);
      final searchFill = _toolFill(tester, Icons.search_rounded);
      expect(filterFill, isNot(searchFill));
      expect(filterFill, AppColors.tint(AppColors.accent, 0.20));
      expect(searchFill, AppColors.surfaceAlt);
    });
  });
}
