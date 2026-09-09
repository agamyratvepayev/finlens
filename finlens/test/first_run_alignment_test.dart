import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart'
    show
        BalanceScreen,
        EmptyState,
        firstRunTextBlockHeight,
        firstRunActionHeight;
import 'package:finlens/features/insight/insight_screen.dart'
    show InsightScreen;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/features/planner/planner_screen.dart'
    show PlannerScreen;
import 'package:finlens/features/quick_add/quick_add_sheet.dart'
    show QuickAddScreen;
import 'package:finlens/features/shell/app_shell.dart'
    show AppShell, AppShellScope;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/l10n/fallback_localizations.dart';
import 'package:finlens/shared/widgets/app_bottom_nav.dart' show NavTab;
import 'package:finlens/theme/app_theme.dart';
import 'package:finlens/theme/app_typography.dart';

/// The one placement guarantee (spec §1/§7): the first-run block's icon lands on
/// the same y on Balance, the Ledger, all three Planner tabs, and Insight, in
/// every locale and text scale, and none of the six overflows. The block is laid
/// against the whole tab body behind each screen's own chrome, so six screens
/// with different headers still centre the icon on one line — both in a bare
/// Scaffold and inside the real [AppShell], bottom nav and safe-area insets
/// included.
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

  // The delegate list the real app installs (main.dart): the tk shims must
  // precede the Global* delegates, or a tk pump warns that the locale is
  // unsupported and the warning surfaces as a test exception.
  const appDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    TkMaterialLocalizationsDelegate(),
    TkCupertinoLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  // Every screen pumped in the *same* bare harness: identical Scaffold body, so
  // the only variable is each screen's own chrome. Equal icon dy ⇒ the chrome no
  // longer decides where the block sits.
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
      localizationsDelegates: appDelegates,
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

  const balanceIcon = Icons.account_balance_wallet_rounded;
  const ledgerIcon = Icons.receipt_long_rounded;
  const budgetsIcon = Icons.pie_chart_outline_rounded;
  const goalsIcon = Icons.outlined_flag_rounded;
  const scheduleIcon = Icons.event_available_rounded;
  const insightIcon = Icons.bar_chart_rounded;

  AppLocalizations l10nOf(WidgetTester tester, Type screen) =>
      AppLocalizations.of(tester.element(find.byType(screen)));

  /// The icon-centre y of each of the six first-run screens, pumped one after
  /// another in the same viewport. The Planner's three tabs are reached by
  /// tapping the segmented control — which also proves the tabs stay tappable
  /// through the Stack.
  Future<Map<String, double>> iconDys(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double scale = 1.0,
  }) async {
    final out = <String, double>{};

    await tester.pumpWidget(
      host(
        emptyStore(),
        const BalanceScreen(),
        locale: locale,
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    out['balance'] = tester.getCenter(find.byIcon(balanceIcon)).dy;

    await tester.pumpWidget(
      host(
        emptyStore(),
        const LedgerScreen(),
        locale: locale,
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    out['ledger'] = tester.getCenter(find.byIcon(ledgerIcon)).dy;

    await tester.pumpWidget(
      host(
        emptyStore(),
        const PlannerScreen(),
        locale: locale,
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    out['budgets'] = tester.getCenter(find.byIcon(budgetsIcon)).dy;

    final l = l10nOf(tester, PlannerScreen);
    await tester.tap(find.text(l.plTabGoals));
    await tester.pumpAndSettle();
    out['goals'] = tester.getCenter(find.byIcon(goalsIcon)).dy;

    await tester.tap(find.text(l.plTabSchedule));
    await tester.pumpAndSettle();
    out['schedule'] = tester.getCenter(find.byIcon(scheduleIcon)).dy;

    await tester.pumpWidget(
      host(
        emptyStore(),
        const InsightScreen(),
        locale: locale,
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
    out['insight'] = tester.getCenter(find.byIcon(insightIcon)).dy;

    return out;
  }

  void expectAllEqual(Map<String, double> dys) {
    final ref = dys['balance']!;
    for (final entry in dys.entries) {
      expect(
        entry.value,
        moreOrLessEquals(ref, epsilon: 0.5),
        reason: '${entry.key} icon centre ${entry.value} ≠ balance $ref',
      );
    }
  }

  testWidgets('the icon lands on the same y on all six screens (390×844)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester));
  });

  testWidgets('the icon lands on the same y on all six at 130% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester, scale: 1.3));
  });

  testWidgets('the icon lands on the same y on all six at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester, scale: 2.0));
  });

  // The tallest locale's message sets the box for every screen; the icons still
  // agree. This is also the "a longer message grows the box on all six, not
  // one" guarantee: whichever locale runs a message long, all six move together.
  for (final locale in const [Locale('tr'), Locale('ru'), Locale('tk')]) {
    testWidgets('icons stay aligned in ${locale.languageCode} at 320×568', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expectAllEqual(await iconDys(tester, locale: locale));
    });
  }

  // ── Overflow sweep: six screens × four locales × three text scales ───────────
  for (final locale in const [
    Locale('en'),
    Locale('tr'),
    Locale('ru'),
    Locale('tk'),
  ]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('no overflow on any of the six in ${locale.languageCode} at '
          '320×568 / ${(scale * 100).toInt()}%', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            emptyStore(),
            const BalanceScreen(),
            locale: locale,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'balance');

        await tester.pumpWidget(
          host(
            emptyStore(),
            const LedgerScreen(),
            locale: locale,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'ledger');

        await tester.pumpWidget(
          host(
            emptyStore(),
            const PlannerScreen(),
            locale: locale,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'planner/budgets');

        final l = l10nOf(tester, PlannerScreen);
        await tester.tap(find.text(l.plTabGoals));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'planner/goals');

        await tester.tap(find.text(l.plTabSchedule));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'planner/schedule');

        await tester.pumpWidget(
          host(
            emptyStore(),
            const InsightScreen(),
            locale: locale,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'insight');
      });
    }
  }

  // ── The shared derivation (§2/§4) ────────────────────────────────────────────
  testWidgets('the text-block height is one figure ≥ every screen\'s own pair', (
    tester,
  ) async {
    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    final l = l10nOf(tester, BalanceScreen);
    const scaler = TextScaler.noScaling;
    const width =
        390.0 - 28 * 2; // block width less EmptyState's Insets.xxl gutter

    // The ambient DefaultTextStyle the block's Texts resolve against — the
    // derivation must measure with it merged in, or the floor under-reserves
    // whatever the theme's line height adds over the font's own (§7).
    final ambient =
        DefaultTextStyle.of(tester.element(find.byType(EmptyState))).style;
    final shared = firstRunTextBlockHeight(l, width, scaler, ambient: ambient);

    final titleStyle = ambient.merge(AppText.rowTitle.copyWith(fontSize: 16));
    final messageStyle = ambient.merge(AppText.caption);
    double pair(String title, String message) {
      double h(String t, TextStyle s) => (TextPainter(
        text: TextSpan(text: t, style: s),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textScaler: scaler,
      )..layout(maxWidth: width)).height;
      return h(title, titleStyle) +
          4 /* Insets.xs */ +
          h(message, messageStyle);
    }

    // Every individual screen's title+message fits inside the shared figure, so
    // no screen's block is taller than another's — the icons can agree.
    for (final p in <double>[
      pair(l.balNoAccountsYet, l.balEmptyBenefit),
      pair(l.ldgNothingHere, l.ldgNothingHereMsg),
      pair(l.plNoBudgetsYet, l.plNoBudgetsMsg),
      pair(l.plNoGoalsYet, l.plNoGoalsMsg),
      pair(l.plNothingScheduled, l.plNothingSchedMsg),
      pair(l.insEmptyNoAccountsTitle, l.insEmptyNoAccountsBody),
    ]) {
      expect(shared, greaterThanOrEqualTo(p - 0.01));
    }

    // The reserved fourth-row height clears 44. That figure was Balance's
    // "Add an account" tap target; no screen renders a link any more, and the
    // 44 is now an explicit calibration constant with no live control behind it
    // — the blocks' icon-centre lines are set by it. See _firstRunActionBox.
    expect(
      firstRunActionHeight(l, width, scaler, ambient: ambient),
      greaterThanOrEqualTo(44 - 0.01),
    );
  });

  // ── Chrome fires through the Stack (§5) ──────────────────────────────────────
  testWidgets('the Balance + is tappable through the first-run Stack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // The header + sits over the block; a tap must reach it and open Quick Add
    // rather than falling into the block behind. Bounded pumps, not
    // pumpAndSettle: the opened sheet focuses a field whose cursor blinks
    // forever, so settling never completes.
    //
    // The *topmost* add glyph, not `.first`: Balance's fourth row is now the
    // same "Start with + above" hint the Ledger and Planner carry, and that
    // sentence contains its own inline 13pt add_rounded. `.first` matches the
    // hint's glyph, which is a label, not a button.
    final adds = find.byIcon(Icons.add_rounded);
    final rects = <(double, int)>[
      for (var i = 0; i < adds.evaluate().length; i++)
        (tester.getRect(adds.at(i)).top, i),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    await tester.tap(adds.at(rects.first.$2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the Ledger restore line is tappable through the first-run Stack',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var pickerOpened = false;
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        pickerOpened = true;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
      await tester.pumpAndSettle();

      final l = l10nOf(tester, LedgerScreen);
      await tester.tap(find.text(l.ldgRestoreFromBackup));
      await tester.pumpAndSettle();
      expect(
        pickerOpened,
        isTrue,
        reason: 'the restore line, pinned over the block, must take the tap',
      );
    },
  );

  // Re-baselined: the Insight signpost is gone. The fourth row names what
  // fills the screen, and Insight creates nothing — it reads what the other
  // three tabs record — so it has no fourth row at all. The signpost sent the
  // reader to another tab, where adding an account still left Insight empty and
  // only changed the label from "Start in Balance" to "Start in Ledger".
  //
  // What replaces the old assertion is the guarantee that took its place: the
  // block keeps its reserved box (so the icon stays on the shared line) but
  // offers nothing to tap in it.
  testWidgets(
    'Insight offers no tappable node in its fourth row',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      NavTab? got;
      await tester.pumpWidget(
        host(
          emptyStore(),
          AppShellScope(goToTab: (t) => got = t, child: const InsightScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing,
          reason: 'Insight creates nothing, so it has no fourth-row action');
      expect(got, isNull, reason: 'nothing in the block asks the shell to move');

      // …and the icon still lands on the line the other five share, which is
      // what the reserved-but-empty box is for.
      final insight =
          tester.getCenter(find.byIcon(Icons.bar_chart_rounded)).dy;
      await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
      await tester.pumpAndSettle();
      final ledger = tester.getCenter(find.byIcon(ledgerIcon)).dy;
      expect(insight, moreOrLessEquals(ledger, epsilon: 0.5),
          reason: 'the empty fourth row still reserves its height');
    },
  );

  // ── The real shell (§8B): bottom nav + non-zero safe-area insets ─────────────
  // The bare harness proves the six screens agree in isolation; this one proves
  // they agree inside [AppShell] — IndexedStack, bottom navigation bar, and a
  // phone-like MediaQuery.padding. This is the tree a device renders, and the
  // harness the bare Scaffold could not stand in for.
  Widget shellHost(AppStore store, {double textScale = 1.0}) => StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: appDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          // Phone-like insets: a status bar above, a home indicator below.
          padding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );

  /// The six icon dys inside the real shell, reached through the bottom nav —
  /// which also proves the nav stays tappable with every tab on its first run.
  Future<Map<String, double>> shellIconDys(
    WidgetTester tester, {
    double scale = 1.0,
  }) async {
    final out = <String, double>{};
    await tester.pumpWidget(shellHost(emptyStore(), textScale: scale));
    await tester.pumpAndSettle();
    out['balance'] = tester.getCenter(find.byIcon(balanceIcon)).dy;

    final l = l10nOf(tester, AppShell);
    await tester.tap(find.text(l.navLedger));
    await tester.pumpAndSettle();
    out['ledger'] = tester.getCenter(find.byIcon(ledgerIcon)).dy;

    await tester.tap(find.text(l.navPlanner));
    await tester.pumpAndSettle();
    out['budgets'] = tester.getCenter(find.byIcon(budgetsIcon)).dy;

    await tester.tap(find.text(l.plTabGoals));
    await tester.pumpAndSettle();
    out['goals'] = tester.getCenter(find.byIcon(goalsIcon)).dy;

    await tester.tap(find.text(l.plTabSchedule));
    await tester.pumpAndSettle();
    out['schedule'] = tester.getCenter(find.byIcon(scheduleIcon)).dy;

    await tester.tap(find.text(l.navInsight));
    await tester.pumpAndSettle();
    out['insight'] = tester.getCenter(find.byIcon(insightIcon)).dy;

    return out;
  }

  testWidgets(
    'inside the real AppShell the icon lands on the same y on all six tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expectAllEqual(await shellIconDys(tester));
    },
  );

  testWidgets(
    'inside the real AppShell the icons still agree at 130% text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      expectAllEqual(await shellIconDys(tester, scale: 1.3));
    },
  );

  // ── The null path is untouched for out-of-scope call sites (§3) ──────────────
  testWidgets('EmptyState with textBlockHeight/actionHeight null renders its '
      'text and action directly — no reservation box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: EmptyState(
            icon: Icons.star_rounded,
            title: 'T',
            message: 'M',
            action: TextButton(onPressed: () {}, child: const Text('Act')),
          ),
        ),
      ),
    );

    // The bare 40pt icon (not the 24pt backdrop) confirms the default rendering
    // path, and the title, message and action all render with no reservation box
    // wrapping them — the guard for the out-of-scope call sites.
    final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
    expect(icon.size, 40);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Act'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
