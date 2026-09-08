import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/balance_screen.dart'
    show BalanceScreen, firstRunActionHeight;
import 'package:finlens/features/insight/insight_screen.dart' show InsightScreen;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/features/planner/planner_screen.dart' show PlannerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

/// The fourth row names what fills the screen.
///
/// Balance, the Ledger and the Planner are filled by the `+` in their own
/// header, so all five of those blocks point at it with one sentence. Insight is
/// filled by the other three — it creates nothing — so it has no fourth row at
/// all, and its message says where its figures come from instead.
///
/// Balance used to carry an "Add an account" text button here: a second create
/// control two rows under the `+` it duplicated. Insight used to carry a
/// cross-tab signpost that changed silently under a reader who had just followed
/// it — tap "Start in Balance", add an account, come back, and Insight is still
/// empty with the label now reading "Start in Ledger".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AppStore emptyStore() => AppStore(
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  Widget host(AppStore store, Widget screen, {double scale = 1.0}) => StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: screen),
        ),
      );

  const sizes = [Size(390, 844), Size(360, 640), Size(320, 568)];

  // ── §1 · Balance's fourth row is the shared hint ──────────────────────────
  testWidgets('Balance shows the hint, not a create button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // The same sentence the Ledger and Planner render, with its inline mark.
    expect(find.textContaining('above'), findsOneWidget);
    expect(find.text('Add an account'), findsNothing);
    // No rival create control anywhere in the block.
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('the hint renders the same mark on Balance as on the Ledger',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    double markSize(WidgetTester t) => t
        .widgetList<Icon>(find.byIcon(Icons.add_rounded))
        .map((i) => i.size!)
        .reduce((a, b) => a < b ? a : b);

    await tester.pumpWidget(host(emptyStore(), const LedgerScreen()));
    await tester.pumpAndSettle();
    final ledgerMark = markSize(tester);

    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();
    expect(markSize(tester), ledgerMark);
    expect(ledgerMark, 13, reason: 'the hint mark stays a bare 13pt glyph');
  });

  // ── §2 · the hint announces one whole sentence ────────────────────────────
  testWidgets('the hint is announced as a sentence naming the add button',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
    await tester.pumpAndSettle();

    // `Text.rich` announces the spans and skips the WidgetSpan, so without a
    // label the reader hears "Start with above" — a broken sentence.
    final sem = tester
        .widgetList<Semantics>(find.ancestor(
          of: find.textContaining('above'),
          matching: find.byType(Semantics),
        ))
        .where((w) => w.properties.label != null);
    expect(sem, isNotEmpty);
    expect(sem.first.properties.label, 'Start with the add button above');
    expect(sem.first.excludeSemantics, isTrue,
        reason: 'the spans must not be announced alongside the label');
    handle.dispose();
  });

  // ── §3 · Insight has no fourth row and nothing tappable ───────────────────
  testWidgets('Insight offers no fourth row and no control', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(emptyStore(), const InsightScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Start in'), findsNothing,
        reason: 'the cross-tab signpost is gone');
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    // And it grows no `+` of its own: Insight owns no creation.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('Insight says where its figures come from', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(emptyStore(), const InsightScreen()));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(InsightScreen)));

    expect(find.text(l.insEmptyNoAccountsBody), findsOneWidget);
    expect(l.insEmptyNoAccountsBody, contains('record'),
        reason: 'the message must name what fills the screen');
    // One message for both states — no branch on noAccounts.
    expect(l.insA11yEmptyNoAccounts, contains(l.insEmptyNoAccountsBody));
  });

  // ── §5 · the reserved box, and the hint inside it ─────────────────────────
  for (final size in sizes) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'the hint fits the reserved box at ${size.width.toInt()} @ '
          '${(scale * 100).toInt()}%', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
            host(emptyStore(), const BalanceScreen(), scale: scale));
        await tester.pumpAndSettle();

        final el = tester.element(find.byType(BalanceScreen));
        // `_measureFirstRun` measures the hint as a plain TextSpan, so the
        // WidgetSpan holding the mark is invisible to it. Confirm the rendered
        // line still sits inside the box rather than assuming it does.
        final reserved = firstRunActionHeight(
          AppLocalizations.of(el),
          size.width - 28 * 2,
          MediaQuery.textScalerOf(el),
        );
        final rendered = tester.getSize(find.textContaining('above')).height;
        expect(rendered, lessThanOrEqualTo(reserved));
        // The box is the calibration constant until a text scale outgrows it.
        expect(reserved, 44.0);
      });
    }
  }

  // ── The hard boundary · Ledger and Planner do not move ────────────────────
  //
  // These are the reference lines the whole change is defined against. The
  // figures are the ones measured before any edit; they must come back exactly.
  const frozen = <String, List<double>>{
    // width|scale → [ledger, budgets, goals, schedule]
    '390|100': [329.0, 336.0, 336.0, 336.0],
    '390|130': [289.5, 312.5, 312.5, 312.5],
    '360|100': [227.0, 234.0, 227.0, 227.0],
    '360|130': [187.5, 201.0, 201.0, 197.0],
    '320|100': [179.5, 190.0, 190.0, 190.0],
    '320|130': [132.5, 146.0, 146.0, 146.0],
  };

  for (final size in sizes) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
          'Ledger and Planner icons are unmoved at ${size.width.toInt()} @ '
          '${(scale * 100).toInt()}%', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final key = '${size.width.toInt()}|${(scale * 100).toInt()}';
        final want = frozen[key]!;

        await tester
            .pumpWidget(host(emptyStore(), const LedgerScreen(), scale: scale));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byIcon(Icons.receipt_long_rounded)).dy,
          moreOrLessEquals(want[0], epsilon: 0.01),
          reason: 'the Ledger is the reference line and must not move',
        );

        await tester
            .pumpWidget(host(emptyStore(), const PlannerScreen(), scale: scale));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byIcon(Icons.pie_chart_outline_rounded)).dy,
          moreOrLessEquals(want[1], epsilon: 0.01),
          reason: 'Budgets must not move',
        );

        final l =
            AppLocalizations.of(tester.element(find.byType(PlannerScreen)));
        await tester.tap(find.text(l.plTabGoals));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byIcon(Icons.outlined_flag_rounded)).dy,
          moreOrLessEquals(want[2], epsilon: 0.01),
          reason: 'Goals must not move',
        );

        await tester.tap(find.text(l.plTabSchedule));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byIcon(Icons.event_available_rounded)).dy,
          moreOrLessEquals(want[3], epsilon: 0.01),
          reason: 'Schedule must not move',
        );
      });
    }
  }

  // Balance swapped its fourth row but reserves the same box, so it does not
  // move either — the link and the hint both sat inside 44pt.
  testWidgets('Balance is unmoved by the swap', (tester) async {
    const want = {'390|100': 336.0, '360|100': 234.0, '320|100': 190.0};
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(emptyStore(), const BalanceScreen()));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byIcon(Icons.account_balance_wallet_rounded)).dy,
        moreOrLessEquals(want['${size.width.toInt()}|100']!, epsilon: 0.01),
      );
    }
  });
}
