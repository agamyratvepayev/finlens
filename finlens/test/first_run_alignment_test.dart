import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart'
    show
        BalanceScreen,
        EmptyState,
        firstRunTextBlockHeight,
        firstRunActionHeight;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/features/planner/planner_screen.dart'
    show PlannerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';
import 'package:finlens/theme/app_typography.dart';

/// The one placement guarantee (spec §1/§7): the first-run block's icon lands on
/// the same y on Balance, the Ledger, and all three Planner tabs, in every
/// locale and text scale, and none of the five overflows. The block is laid
/// against the whole tab body behind each screen's own chrome, so five screens
/// with different headers still centre the icon on one line.
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

  const balanceIcon = Icons.account_balance_wallet_rounded;
  const ledgerIcon = Icons.receipt_long_rounded;
  const budgetsIcon = Icons.pie_chart_outline_rounded;
  const goalsIcon = Icons.outlined_flag_rounded;
  const scheduleIcon = Icons.event_available_rounded;

  AppLocalizations l10nOf(WidgetTester tester, Type screen) =>
      AppLocalizations.of(tester.element(find.byType(screen)));

  /// The icon-centre y of each of the five first-run screens, pumped one after
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

  testWidgets('the icon lands on the same y on all five screens (390×844)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester));
  });

  testWidgets('the icon lands on the same y on all five at 130% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester, scale: 1.3));
  });

  testWidgets('the icon lands on the same y on all five at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expectAllEqual(await iconDys(tester, scale: 2.0));
  });

  // The tallest locale's message sets the box for every screen; the icons still
  // agree. This is also the "a longer message grows the box on all five, not
  // one" guarantee: whichever locale runs a message long, all five move together.
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

  // ── Overflow sweep: five screens × four locales × three text scales ──────────
  for (final locale in const [
    Locale('en'),
    Locale('tr'),
    Locale('ru'),
    Locale('tk'),
  ]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('no overflow on any of the five in ${locale.languageCode} at '
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

    final shared = firstRunTextBlockHeight(l, width, scaler);

    final titleStyle = AppText.rowTitle.copyWith(fontSize: 16);
    const messageStyle = AppText.caption;
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
    ]) {
      expect(shared, greaterThanOrEqualTo(p - 0.01));
    }

    // The reserved fourth-row height clears the link's 44pt tap-target floor.
    expect(
      firstRunActionHeight(l, width, scaler),
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
    // rather than falling into the block behind.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
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
