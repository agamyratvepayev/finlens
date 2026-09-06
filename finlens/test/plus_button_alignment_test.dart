import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/balance_screen.dart'
    show BalanceScreen;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/features/planner/planner_screen.dart'
    show PlannerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/screen_header.dart'
    show HeaderCircleButton;
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// The cross-screen guarantee nothing pinned before: the `+` occupies the *same
/// rectangle* on Balance, the Ledger and all three Planner tabs.
///
/// It is one affordance — same glyph, same colour, same destination — so a user
/// who switches tabs must find it under the same thumb. Three private
/// `_CircleButton` copies had drifted to 34pt and 36pt and to two different
/// gutters, and the `+` visibly jumped: Balance's sat 8pt high and 2pt small,
/// the Ledger's 4pt too far right. `first_run_alignment_test.dart` pins the
/// empty-state *icon* across five screens and `balance_empty_state_test.dart`
/// pins the `+` across Balance's own two states — but nothing compared the `+`
/// *between* screens, which is why the drift both happened and survived.
///
/// The probe is [WidgetTester.getRect], not `getTopLeft`: the size is half the
/// bug, and a top-left-only assertion passes on two circles of different
/// diameters that happen to share a corner. Because the glyph sits in a tightly
/// constrained `SizedBox`, the icon's rect *is* the circle's rect — so one
/// measurement pins both position and diameter.
void main() {
  // Balance fires off preference writes; give them a mock backing store.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
    accounts: const [],
    categories: const [],
    txns: const [],
    goals: const [],
    tasks: const [],
  );

  /// Deliberately *not* `buildSeedStore`: the seed fixture's five-figure sums
  /// overflow the Ledger's metrics strip at 390pt (a pre-existing defect,
  /// unrelated to the `+`), and an unhandled framework exception would fail
  /// these tests for the wrong reason. One account, one budgeted category and
  /// one small expense is all the invariant needs — it lights up every branch
  /// the headers switch on: Balance's `hasAccounts`, the Ledger's
  /// `everRecorded` eye, and the Planner's ••• trailing.
  AppStore populatedStore() {
    final store = emptyStore();
    final wallet = store.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    final food = store.addCategory(
      name: 'Food',
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: AppColors.accent,
      monthlyBudget: 50,
    );
    store.addTxn(
      type: TxnType.expense,
      amount: 12,
      currency: 'USD',
      fromRef: wallet.id,
      toRef: food.id,
      date: DateTime.now(),
    );
    return store;
  }

  // Every screen pumped in the *same* bare harness as first_run_alignment_test:
  // identical Scaffold body, so the only variable is each screen's own chrome.
  Widget host(
    AppStore store,
    Widget screen, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
  }) => StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: screen),
    ),
  );

  /// The app ships no MaterialLocalizations/CupertinoLocalizations for `tk`
  /// (a pre-existing gap — `first_run_alignment_test.dart`'s tk cases fail on it
  /// too). Flutter reports it as a framework error on every pump, which would
  /// fail each tk case for a reason that has nothing to do with the `+`. Swallow
  /// exactly that one message; every other error still fails the test.
  void ignoreLocaleDelegateWarning() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().startsWith(
        "Warning: This application's locale",
      )) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  AppLocalizations l10nOf(WidgetTester tester, Type screen) =>
      AppLocalizations.of(tester.element(find.byType(screen)));

  /// The header `+`'s rect — the *topmost* `add_rounded` on the screen, not
  /// `find.…first`. The first-run hint renders "Start with + above" with its own
  /// inline 13pt `+` glyph, and on several of these screens that one comes first
  /// in the tree; `.first` silently measures the hint instead of the button. The
  /// header control is always the highest `+` on any of the five.
  Rect plusRect(WidgetTester tester) {
    final f = find.byIcon(Icons.add_rounded);
    expect(f, findsWidgets, reason: 'every one of the five keeps its +');
    final rects = <Rect>[
      for (var i = 0; i < f.evaluate().length; i++) tester.getRect(f.at(i)),
    ]..sort((a, b) => a.top.compareTo(b.top));
    return rects.first;
  }

  /// The `+` rect on each of the five screens, pumped one after another in the
  /// same viewport. The Planner's three tabs are reached by tapping the
  /// segmented control.
  Future<Map<String, Rect>> plusRects(
    WidgetTester tester, {
    required AppStore Function() store,
    Locale locale = const Locale('en'),
    double scale = 1.0,
    bool masked = false,
    bool rangeLens = false,
  }) async {
    final out = <String, Rect>{};

    final balanceStore = store();
    if (masked) balanceStore.toggleMasked();
    await tester.pumpWidget(
      host(
        balanceStore,
        const BalanceScreen(),
        locale: locale,
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    out['balance'] = plusRect(tester);

    final ledgerStore = store();
    if (masked) ledgerStore.toggleMasked();
    if (rangeLens) {
      // A custom window puts the lens's × in the row beside the eye — three
      // circles instead of two. The + must not care.
      ledgerStore.applyRangeLens(
        DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 15)),
      );
    }
    await tester.pumpWidget(
      host(ledgerStore, const LedgerScreen(), locale: locale, textScale: scale),
    );
    await tester.pumpAndSettle();
    out['ledger'] = plusRect(tester);

    await tester.pumpWidget(
      host(store(), const PlannerScreen(), locale: locale, textScale: scale),
    );
    await tester.pumpAndSettle();
    out['budgets'] = plusRect(tester);

    final l = l10nOf(tester, PlannerScreen);
    await tester.tap(find.text(l.plTabGoals));
    await tester.pumpAndSettle();
    out['goals'] = plusRect(tester);

    await tester.tap(find.text(l.plTabSchedule));
    await tester.pumpAndSettle();
    out['schedule'] = plusRect(tester);

    return out;
  }

  void expectSameRect(Map<String, Rect> rects, List<String> keys, String ref) {
    final r0 = rects[ref]!;
    for (final k in keys) {
      final r = rects[k]!;
      expect(
        <double>[r.left, r.top, r.width, r.height],
        <Matcher>[
          moreOrLessEquals(r0.left, epsilon: 0.5),
          moreOrLessEquals(r0.top, epsilon: 0.5),
          moreOrLessEquals(r0.width, epsilon: 0.5),
          moreOrLessEquals(r0.height, epsilon: 0.5),
        ],
        reason: '$k + rect ${rects[k]} ≠ $ref ${rects[ref]}',
      );
    }
  }

  const allFive = ['balance', 'ledger', 'budgets', 'goals', 'schedule'];

  // ── The invariant, on the approved first-run screens ────────────────────────
  // This is the state §0's measurements were taken in, and the one the design
  // signs off: all five agree exactly, the Planner being the reference.
  for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        'first run: the + occupies one rect on all five screens — '
        '${size.width.toInt()}×${size.height.toInt()}, '
        '${(scale * 100).toInt()}% text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final rects = await plusRects(
            tester,
            store: emptyStore,
            scale: scale,
          );
          expectSameRect(rects, allFive, 'budgets');
        },
      );
    }
  }

  // The Planner's title widget differs per tab and per locale; the + must not
  // care. Turkmen is the shipping locale, English the development one.
  for (final locale in const [Locale('en'), Locale('tk')]) {
    testWidgets(
      'first run: the + holds its rect in ${locale.languageCode} at 320×568',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        ignoreLocaleDelegateWarning();

        final rects = await plusRects(
          tester,
          store: emptyStore,
          locale: locale,
        );
        expectSameRect(rects, allFive, 'budgets');
      },
    );
  }

  // ── Populated screens ───────────────────────────────────────────────────────
  // Only 390×844 at 100%: a *populated* Balance header already overflows its row
  // at 360pt, at 320pt and at 390pt/130% — 25, 65 and 47 pixels respectively on
  // untouched `main`, before any of this task's edits (the section indicator,
  // date pill, eye and the +'s reserved footprint do not fit). That is a
  // pre-existing defect this task does not own; asserting over it would either
  // fail for the wrong reason or require swallowing a real rendering error. The
  // first-run sweep above covers all three widths, which is the state §0
  // measured and the design approved.
  testWidgets(
    'populated: Balance and the Ledger share the + rect, and the three Planner '
    'tabs share theirs — 390×844, 100% text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final rects = await plusRects(tester, store: populatedStore);
      expectSameRect(rects, ['balance', 'ledger'], 'ledger');
      expectSameRect(rects, ['budgets', 'goals', 'schedule'], 'budgets');
    },
  );

  // A populated Planner's title widget (the month / scope control) is 40pt tall,
  // and ScreenHeader's Row centres the 36pt circle against it — so the + rides
  // 2pt lower there than on Balance and the Ledger, whose populated titles are
  // no taller than the circle. That is a property of the Planner's title, not of
  // the button, and §0 signs the Planner off unchanged. Pinned so that if that
  // title's height ever moves, this test says what moved with it.
  testWidgets('populated: the Planner + sits 2pt below Balance and the Ledger, '
      'because its title widget is taller than the circle', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rects = await plusRects(tester, store: populatedStore);
    expect(rects['budgets']!.top - rects['balance']!.top, 2.0);
    expect(rects['budgets']!.left, rects['balance']!.left);
    expect(rects['budgets']!.size, rects['balance']!.size);
  });

  // ── The per-screen edge cases (§6) ──────────────────────────────────────────

  /// Drains *only* a pre-existing populated-header overflow of the kind
  /// described on the populated sweep above, so a test about the `+` is not
  /// failed by a defect it does not own. Anything else still fails.
  void drainKnownHeaderOverflow(WidgetTester tester) {
    final e = tester.takeException();
    if (e == null) return;
    expect(
      e.toString(),
      contains('A RenderFlex overflowed'),
      reason: 'only the known pre-existing header overflow may be drained',
    );
  }

  testWidgets('the Ledger range lens adds a third circle without moving the + '
      'horizontally', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(populatedStore(), const LedgerScreen()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    final monthMode = plusRect(tester);

    final lensed = populatedStore()
      ..applyRangeLens(DateRange(DateTime(2026, 1, 1), DateTime(2026, 1, 15)));
    await tester.pumpWidget(host(lensed, const LedgerScreen()));
    await tester.pumpAndSettle();

    // Three circles in the row now — the lens's × joins the eye and the +.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    final lensMode = plusRect(tester);

    // The gutter this task fixes: the + holds its column and its diameter, so
    // the × and the eye shift left around it rather than pushing it.
    expect(lensMode.left, monthMode.left);
    expect(lensMode.right, monthMode.right);
    expect(lensMode.size, monthMode.size);

    // Vertically it does drop 4.5pt — the lens's range title is taller than the
    // month title, and ScreenHeader's Row centres the circle against it. That
    // is pre-existing (identical on untouched `main`, where the + sat at the
    // same 12.5 with the lens on and 8.0 with it off) and is a property of the
    // title, not the button. Pinned so the day it changes, it changes visibly.
    expect(monthMode.top, 8.0);
    expect(lensMode.top, 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy state does not move the + on Balance or the Ledger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(populatedStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    final balancePlain = plusRect(tester);

    await tester.pumpWidget(
      host(populatedStore()..toggleMasked(), const BalanceScreen()),
    );
    await tester.pumpAndSettle();
    expect(plusRect(tester), balancePlain);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(populatedStore(), const LedgerScreen()));
    await tester.pumpAndSettle();
    final ledgerPlain = plusRect(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      host(populatedStore()..toggleMasked(), const LedgerScreen()),
    );
    await tester.pumpAndSettle();
    expect(plusRect(tester), ledgerPlain);
    // Masked, the Ledger's metrics strip overflows its row — 9.7px on untouched
    // `main`, 18px once this task moves the strip in to the 20pt page gutter.
    // Pre-existing, worsened, reported, and deliberately not compensated for
    // (§3). It does not move the +.
    drainKnownHeaderOverflow(tester);
  });

  testWidgets(
    'the Ledger + is at the same rect with the eye absent (first run) as with '
    'it present (populated)',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_rounded), findsNothing);
      final firstRun = plusRect(tester);

      await tester.pumpWidget(host(populatedStore(), const LedgerScreen()));
      await tester.pumpAndSettle();
      expect(plusRect(tester), firstRun);
    },
  );

  testWidgets('Balance holds the + rect from empty to first account (§6)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    final empty = plusRect(tester);

    await tester.pumpWidget(host(populatedStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    expect(plusRect(tester), empty);
  });

  // ── No overflow at the tightest box (§6) ────────────────────────────────────
  // Adding 2pt to three circles, and 4pt of gutter to each side of the Ledger's
  // header, is the classic way to fail 320pt / 130%. This sweeps the approved
  // first-run screens, which stay clean. The *populated* Balance and Ledger
  // headers already overflowed at these sizes before this task (see the note on
  // the populated sweep above); this task widens the Ledger's block by 4pt a
  // side and Balance's row-1 reservation by 4pt, so those pre-existing overflows
  // grow rather than appear. That is reported, not compensated for here.
  for (final locale in const [Locale('en'), Locale('ru'), Locale('tk')]) {
    for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
      testWidgets(
        'first run: no header overflow in ${locale.languageCode} at '
        '${size.width.toInt()}×${size.height.toInt()} / 130%',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          ignoreLocaleDelegateWarning();

          await plusRects(
            tester,
            store: emptyStore,
            locale: locale,
            scale: 1.3,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // ── The component itself ────────────────────────────────────────────────────
  testWidgets('HeaderCircleButton renders a 36×36 box with a 22pt accent glyph',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: HeaderCircleButton(icon: Icons.add_rounded, accent: true),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(HeaderCircleButton)), const Size(36, 36));
    expect(HeaderCircleButton.diameter, 36);
    expect(tester.widget<Icon>(find.byIcon(Icons.add_rounded)).size, 22);
  });

  testWidgets('HeaderCircleButton is 36×36 with a 19pt plain glyph too', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: HeaderCircleButton(icon: Icons.visibility_rounded),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(HeaderCircleButton)), const Size(36, 36));
    expect(tester.widget<Icon>(find.byIcon(Icons.visibility_rounded)).size, 19);
  });
}
