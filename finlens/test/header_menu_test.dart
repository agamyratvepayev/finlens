import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/balance/balance_screen.dart' show BalanceScreen;
import 'package:finlens/features/insight/insight_screen.dart' show InsightScreen;
import 'package:finlens/features/planner/planner_screen.dart'
    show PlannerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/header_menu.dart';
import 'package:finlens/shared/widgets/screen_header.dart'
    show HeaderCircleButton;
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// Header-controls spec: the corner carries at most `••• +`, with no eye. The
/// ••• menu holds only the screen's own secondary action (Archive on Planner,
/// Filter on Insight); masking is not among them — it is a single global
/// preference in More › Preferences (task 028). These pin that no eye appears on
/// any of these screens and that no mask row appears inside the ••• menu.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)), 
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// One account, one budgeted category, one expense — enough to make the
  /// Planner "touched" (its ••• appears) and to give it a figure to mask.
  AppStore touchedStore() {
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

  Widget host(AppStore store, Widget screen, {double textScale = 1.0}) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: screen),
        ),
      );

  Finder eyeIcon() => find.byIcon(Icons.visibility_rounded);
  Finder eyeOffIcon() => find.byIcon(Icons.visibility_off_rounded);
  Finder menuButton() => find.byIcon(Icons.more_horiz_rounded);

  // ── The cluster: at most ••• + , no eye ──────────────────────────────────────

  testWidgets('Planner (touched): cluster is ••• + , with no eye icon',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const PlannerScreen()));
    await tester.pumpAndSettle();

    expect(menuButton(), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets); // the header +
    expect(eyeIcon(), findsNothing);
    expect(eyeOffIcon(), findsNothing);
  });

  testWidgets('Insight (populated): the cluster is ••• alone — no + , no eye',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(menuButton(), findsOneWidget);
    // Insight creates nothing, so it never renders a primary action.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(eyeIcon(), findsNothing);
    expect(eyeOffIcon(), findsNothing);
  });

  // ── The menu holds only the screen's action — no mask row, no divider ─────────

  testWidgets('opening the Planner menu shows Archive alone — no mask row, no '
      'divider (task 028)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const PlannerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(menuButton());
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    // Masking is not a menu control any more: no mask row, no switch, and so no
    // preference/action divider either.
    expect(find.text('Mask all amounts'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('Insight menu: the Filter row alone — no mask row, no switch '
      '(task 028)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(buildSeedStore(), const InsightScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(menuButton());
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(tester.element(find.byType(InsightScreen)));
    expect(find.text(l.insFilterAccounts), findsOneWidget);
    expect(find.text('Mask all amounts'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  // ── Circles are fixed-size across text scale ──────────────────────────────────

  testWidgets('the header circles measure 36×36 at both 100% and 130% text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final scale in const [1.0, 1.3]) {
      await tester.pumpWidget(
          host(touchedStore(), const PlannerScreen(), textScale: scale));
      await tester.pumpAndSettle();
      for (final e in find.byType(HeaderCircleButton).evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)), const Size(36, 36),
            reason: 'circles must not scale with text ($scale×)');
      }
    }
  });

  // ── Semantics: both circles are labelled buttons ──────────────────────────────

  testWidgets('••• and + expose a non-empty label and button:true',
      (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const PlannerScreen()));
    await tester.pumpAndSettle();

    final l = AppLocalizations.of(tester.element(find.byType(PlannerScreen)));
    // A non-empty label on each circle, and both announce as buttons.
    expect(find.bySemanticsLabel(l.a11yMoreActions), findsOneWidget);
    expect(find.bySemanticsLabel(l.a11yAdd), findsOneWidget);
    final moreData =
        tester.getSemantics(find.bySemanticsLabel(l.a11yMoreActions))
            .getSemanticsData();
    final addData = tester
        .getSemantics(find.bySemanticsLabel(l.a11yAdd))
        .getSemanticsData();
    expect(moreData.label, l.a11yMoreActions);
    expect(moreData.flagsCollection.isButton, isTrue);
    expect(addData.label, l.a11yAdd);
    expect(addData.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  // ── Balance has no eye either (task 028) ──────────────────────────────────────

  testWidgets('Balance carries no eye — masking moved to More › Preferences',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(touchedStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // The eye is gone from Balance's header; masking is a single global
    // preference in More › Preferences, so no header carries it.
    expect(eyeIcon(), findsNothing);
    expect(eyeOffIcon(), findsNothing);
  });

  // A HeaderMenuAction is a plain value; guard its defaults so a caller that
  // forgets `danger` gets a non-destructive row.
  test('HeaderMenuAction defaults to non-destructive', () {
    final a = HeaderMenuAction(
        icon: Icons.abc, label: 'x', onSelected: () {});
    expect(a.danger, isFalse);
    expect(a.subtitle, isNull);
  });
}
