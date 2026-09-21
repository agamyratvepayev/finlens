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
import 'package:finlens/shared/widgets/rate_missing.dart';
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

/// The ratio bar — a private widget, matched by its runtime type name.
Finder _ratioBar() =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RatioBar');

/// The amount+tools row (`_headerRow2`'s populated child) — also private.
Finder _amountRowBox() =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BalanceAmountRow');

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

    testWidgets('gap below: amount → ASSETS label composes to 45',
        (tester) async {
      // On NET WORTH the chain is amount(30) →14→ ratio bar(3) →14 (header
      // bottom pad) → list → 14 (section-header top pad) → "ASSETS". The bar
      // now sits 14 above and 14 below — equal gaps that read it as a line of
      // its own between the two sections, not the tail of the number (task
      // 032). The 14pt header-bottom pad — the header-ends/list-begins
      // boundary — is still load-bearing.
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      final amountBottom = tester.getRect(_headerAmount().first).bottom;
      final labelTop = tester.getRect(find.text('ASSETS')).top;
      expect(labelTop - amountBottom, closeTo(14 + 3 + 14 + 14, 2.0));
    });
  });

  group('Task 3 — the ladder never truncates and never drops below 22', () {
    // (value, currency/base, screen width) — the full string must render and the
    // resolved size must stay in [22, 30] at every width.
    final cases = <(double, String, double)>[
      (2000, 'USD', 390),
      (1248300, 'USD', 390),
      (20000000000, 'USD', 390),
      (-20000000000, 'USD', 390), // net worth below zero → signed (task 011)
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

        // Net worth is asset-side: unsigned while >= 0, signed once it drops
        // below zero (task 011). The hero's `_display` renders exactly this.
        final nw = store.balanceFilter.netWorth(store)!;
        final expected = money(
          nw,
          currency: cur,
          signless: nw >= 0,
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

  group('Task 032 — the ratio bar sits between its neighbours', () {
    // A store with no accounts → the bare-+ first-run header.
    AppStore emptyStore() => AppStore(
          clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
          baseCurrency: 'USD',
          accounts: const [],
          categories: const [],
          txns: const [],
          goals: const [],
          tasks: const [],
        );

    testWidgets('row2 → bar is 14 and bar → header bottom edge is 14',
        (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store()));
      await tester.pumpAndSettle();

      final row2Bottom = tester.getRect(_amountRowBox()).bottom;
      final bar = tester.getRect(_ratioBar());
      // Above the bar: the gap this task raised from 8 to 14.
      expect(bar.top - row2Bottom, closeTo(14, 1.5));

      // Below the bar: the header's own 14pt bottom pad, then the section
      // header's 14pt top pad, before "ASSETS". bar→edge = 14 is proved by
      // bar-bottom → label-top composing to 28.
      final labelTop = tester.getRect(find.text('ASSETS')).top;
      expect(labelTop - bar.bottom, closeTo(14 + 14, 2.0));
    });

    testWidgets('with a missing rate: bar → card is 8 and card → edge is 14',
        (tester) async {
      _setSize(tester, 390, 844);
      // A spendable account in an unrated currency (CHF is not in Fx.seedRates)
      // silences the total and raises the rate-missing card under the bar.
      final store = _store(extra: [
        Account(
          id: 'chf',
          name: 'Zurich',
          group: AccountGroup.spendable,
          currency: 'CHF',
          startingBalance: 500,
        ),
      ]);
      expect(store.hasMissingRate, isTrue);
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final barBottom = tester.getRect(_ratioBar()).bottom;
      final card = tester.getRect(find.byType(RateMissingCard));
      // The 8 below the bar stays 8 when the card follows it — the equal 14s
      // are the bar's relationship with the header edge, not a blanket rule.
      expect(card.top - barBottom, closeTo(8, 1.5));

      // card → edge is 14, proved by card-bottom → "ASSETS" composing to 28.
      final labelTop = tester.getRect(find.text('ASSETS')).top;
      expect(labelTop - card.bottom, closeTo(14 + 14, 2.0));
    });

    testWidgets('first-run header height is unchanged (56)', (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(emptyStore()));
      await tester.pumpAndSettle();

      // The bare-+ header: 6 (top pad) + 36 (+ footprint) + 14 (bottom pad).
      // No bar here, so this task cannot move it.
      expect(_ratioBar(), findsNothing);
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(tester.getRect(find.byType(AnimatedSize)).height, closeTo(56, 0.5));
    });

    testWidgets('all-filtered header height is unchanged (92)', (tester) async {
      _setSize(tester, 390, 844);
      final store = _store();
      // Hide the only group that owns accounts → the all-filtered state:
      // reduced tool row, no hero, no bar.
      store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.spendable),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      // 6 + row1(36) + 8 + reduced tool row(28) + 14 = 92. No bar here either.
      expect(_ratioBar(), findsNothing);
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(tester.getRect(find.byType(AnimatedSize)).height, closeTo(92, 0.5));
    });

    testWidgets('bar segment widths for assets 4,998 / liabilities 800 hold',
        (tester) async {
      _setSize(tester, 390, 844);
      // Assets 4,998 (spendable) and liabilities 800 (payables, held negative).
      final store = _store(
        wallet: 4998,
        extra: [
          Account(
            id: 'pay',
            name: 'Card',
            group: AccountGroup.payables,
            currency: 'USD',
            startingBalance: -800,
          ),
        ],
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final pos = tester
          .getRect(find.descendant(
            of: _ratioBar(),
            matching: find.byWidgetPredicate((w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).color == AppColors.positive),
          ))
          .width;
      final neg = tester
          .getRect(find.descendant(
            of: _ratioBar(),
            matching: find.byWidgetPredicate((w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).color == AppColors.negative),
          ))
          .width;

      // ratio = 800 / 5798 ≈ 0.138, so the negative segment is ~138/1000 of the
      // drawn span. A purely vertical gap change cannot move this.
      expect(neg / (pos + neg), closeTo(800 / 5798, 0.02));
    });

    testWidgets('at 1.3 text scale the header lays out with no overflow',
        (tester) async {
      for (final width in const [390.0, 360.0, 320.0]) {
        _setSize(tester, width, 844);
        await tester.pumpWidget(_host(_store(), textScale: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow at $width pt');
        expect(_ratioBar(), findsOneWidget);
      }
    });
  });

  group('Task 050 — the ratio bar spans the full width on one side too', () {
    // Header content width on a 390pt screen: 390 − 2 × Insets.gutter (20).
    const contentWidth = 390.0 - 2 * 20.0;

    Finder seg(Color c) => find.descendant(
          of: _ratioBar(),
          matching: find.byWidgetPredicate((w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == c),
        );

    testWidgets('assets only: one full-width green segment', (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store(wallet: 28596)));
      await tester.pumpAndSettle();

      expect(tester.getRect(_ratioBar()).width, closeTo(contentWidth, 0.5));
      expect(seg(AppColors.positive), findsOneWidget);
      expect(seg(AppColors.negative), findsNothing);
      final r = tester.getRect(seg(AppColors.positive));
      expect(r.width, closeTo(contentWidth, 0.5));
      expect(r.height, closeTo(3, 0.01));
    });

    testWidgets('liabilities only: one full-width red segment', (tester) async {
      _setSize(tester, 390, 844);
      // Both spendable accounts at 0, one credit card owing 1,200.
      final store = _store(
        wallet: 0,
        extra: [
          Account(
            id: 'cc',
            name: 'Card',
            group: AccountGroup.creditCards,
            currency: 'USD',
            startingBalance: -1200,
          ),
        ],
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(seg(AppColors.negative), findsOneWidget);
      expect(seg(AppColors.positive), findsNothing);
      final r = tester.getRect(seg(AppColors.negative));
      expect(r.width, closeTo(contentWidth, 0.5));
      expect(r.height, closeTo(3, 0.01));
    });

    testWidgets('zero total: one full-width neutral track', (tester) async {
      _setSize(tester, 390, 844);
      await tester.pumpWidget(_host(_store(wallet: 0)));
      await tester.pumpAndSettle();

      expect(seg(AppColors.positive), findsNothing);
      expect(seg(AppColors.negative), findsNothing);
      final r = tester.getRect(seg(AppColors.surfaceHigh));
      expect(r.width, closeTo(contentWidth, 0.5));
      expect(r.height, closeTo(3, 0.01));
    });

    testWidgets('both sides: the split still fills the full width',
        (tester) async {
      _setSize(tester, 390, 844);
      final store = _store(
        wallet: 4998,
        extra: [
          Account(
            id: 'pay',
            name: 'Card',
            group: AccountGroup.payables,
            currency: 'USD',
            startingBalance: -800,
          ),
        ],
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final pos = tester.getRect(seg(AppColors.positive)).width;
      final neg = tester.getRect(seg(AppColors.negative)).width;
      expect(pos + 1.5 + neg, closeTo(contentWidth, 0.5));
    });
  });
}
