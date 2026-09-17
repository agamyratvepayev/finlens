import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/enums.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/balance/balance_screen.dart' show BalanceScreen;
import 'package:finlens/features/ledger/ledger_screen.dart' show LedgerScreen;
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';
import 'package:finlens/theme/app_typography.dart';

/// Task 038 — a temporary lens must not move the screen.
///
/// A custom range on the Ledger and a past "as of" date on Balance are *modes*.
/// Before this task each announced itself by adding a second line inside the
/// header (a `{n} days` subtitle / an `as of …` line), which grew the header and
/// pushed the `+` and everything under it down. The fix moves the Ledger's day
/// count into the transactions-count row (present in both modes at a fixed
/// height) and deletes Balance's `as of …` line, tinting the date pill instead.
/// These tests pin that nothing below the mode-signal moves.
void main() {
  // Balance fires off preference writes; give them a mock backing store.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // The clock's day is 17 Sep 2026 — matches the approved design's screenshots.
  AppStore bareStore() => AppStore(
        clock: Clock.fixed(DateTime(2026, 9, 17, 10, 0)),
        baseCurrency: 'USD',
        accounts: const [],
        categories: const [],
        txns: const [],
        goals: const [],
        tasks: const [],
      );

  /// A Ledger with one recorded expense on 16 Sep, so `everRecorded` is true and
  /// the count row + metrics strip render in both modes.
  AppStore ledgerStore() {
    final s = bareStore();
    final wallet = s.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 100,
    );
    final food = s.addCategory(
      name: 'Food',
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: AppColors.accent,
      monthlyBudget: 50,
    );
    s.addTxn(
      type: TxnType.expense,
      amount: 12,
      currency: 'USD',
      fromRef: wallet.id,
      toRef: food.id,
      date: DateTime(2026, 9, 16, 12),
    );
    return s;
  }

  /// A 2-day lens over 16–17 Sep. `days` == 2, label == "16–17 Sep".
  void applyLens(AppStore s) => s.applyRangeLens(
        DateRange(DateTime(2026, 9, 16), DateTime(2026, 9, 17, 23, 59, 59, 999)),
      );

  /// A Balance with one asset account whose balance is constant across the dates
  /// these tests use (opened well before them, no transactions), so the hero
  /// width — and thus its font size and height — is identical today and as-of.
  AppStore balanceStore() {
    final s = bareStore();
    final acc = s.addAccount(
      name: 'Wallet',
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 2500,
    );
    acc.openingDate = DateTime(2025, 1, 1);
    return s;
  }

  Widget host(
    AppStore store,
    Widget screen, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
  }) =>
      StoreScope(
        store: store,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
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

  void setSize(WidgetTester t, double w, double h) {
    t.view.physicalSize = Size(w, h);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  /// The topmost `+` (the header control, never the first-run hint's inline +).
  double plusTop(WidgetTester t) {
    final f = find.byIcon(Icons.add_rounded);
    final tops = <double>[
      for (var i = 0; i < f.evaluate().length; i++) t.getRect(f.at(i)).top,
    ]..sort();
    return tops.first;
  }

  /// The Ledger's tool-row `Text.rich` — the one whose plain text names the
  /// transaction count. Its child span is the accent "· N days" suffix (or none).
  Text countRow(WidgetTester t) => t.widget<Text>(find.byWidgetPredicate((w) =>
      w is Text &&
      w.textSpan != null &&
      (w.textSpan!.toPlainText()).contains('transactions')));

  void ignoreLocaleDelegateWarning() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception
          .toString()
          .startsWith("Warning: This application's locale")) {
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  /// Drains *only* the pre-existing populated-header RenderFlex overflow that
  /// `plus_button_alignment_test.dart` documents (Balance's row-1 / the Ledger's
  /// metrics strip overflow at 360/320 and 130% on untouched `main`). Anything
  /// else still fails.
  void drainKnownOverflow(WidgetTester t) {
    final e = t.takeException();
    if (e == null) return;
    expect(e.toString(), contains('A RenderFlex overflowed'),
        reason: 'only the known pre-existing header overflow may be drained');
  }

  // ── Ledger: the header does not grow, and nothing below it moves ────────────

  testWidgets('Ledger: the + and the metrics strip hold their dy month↔lens',
      (t) async {
    setSize(t, 390, 844);

    await t.pumpWidget(host(ledgerStore(), const LedgerScreen()));
    await t.pumpAndSettle();
    final plusMonth = plusTop(t);
    final inMonth = t.getRect(find.text('IN')).top;

    final lensed = ledgerStore();
    applyLens(lensed);
    await t.pumpWidget(host(lensed, const LedgerScreen()));
    await t.pumpAndSettle();

    // The title is purple, one line — the lens is on.
    expect(find.text('16–17 Sep'), findsOneWidget);
    // Header height parity: the + keeps its dy (red before §3 — the subtitle
    // used to push it ~4.5pt down), and the strip below it does not move.
    expect(plusTop(t), moreOrLessEquals(plusMonth, epsilon: 0.5));
    expect(t.getRect(find.text('IN')).top,
        moreOrLessEquals(inMonth, epsilon: 0.5));
    expect(t.takeException(), isNull);
  });

  testWidgets('Ledger: the count row appends an accent "· N days" only in a lens',
      (t) async {
    setSize(t, 390, 844);

    // Month mode — no day suffix, no accent child span.
    await t.pumpWidget(host(ledgerStore(), const LedgerScreen()));
    await t.pumpAndSettle();
    final month = countRow(t).textSpan! as TextSpan;
    expect(month.children, anyOf(isNull, isEmpty));
    expect(month.toPlainText(), isNot(contains('days')));

    // Lens mode — the suffix rides here now, in accentLight.
    final lensed = ledgerStore();
    applyLens(lensed);
    await t.pumpWidget(host(lensed, const LedgerScreen()));
    await t.pumpAndSettle();

    final l = AppLocalizations.of(t.element(find.byType(LedgerScreen)));
    final lens = countRow(t).textSpan! as TextSpan;
    expect(lens.toPlainText(), contains('· ${l.countDays(2)}'));
    final suffix = lens.children!.single as TextSpan;
    expect(suffix.text, ' · ${l.countDays(2)}');
    expect(suffix.style?.color, AppColors.accentLight);
  });

  testWidgets('Ledger: the title semantics still carry the day count', (t) async {
    setSize(t, 390, 844);
    final lensed = ledgerStore();
    applyLens(lensed);
    await t.pumpWidget(host(lensed, const LedgerScreen()));
    await t.pumpAndSettle();

    final l = AppLocalizations.of(t.element(find.byType(LedgerScreen)));
    // The count left the sighted layout but not the screen reader (§3).
    expect(
      find.byWidgetPredicate((w) =>
          w is Semantics &&
          (w.properties.label?.contains(l.countDays(2)) ?? false)),
      findsWidgets,
    );
  });

  // ── Balance: the hero stays one line, and the pill carries the mode ─────────

  testWidgets('Balance: the + and ASSETS hold their dy today↔as-of', (t) async {
    setSize(t, 390, 844);

    await t.pumpWidget(host(balanceStore(), const BalanceScreen()));
    await t.pumpAndSettle();
    final plusToday = plusTop(t);
    final assetsToday = t.getRect(find.text('ASSETS')).top;

    final past = balanceStore()..setAsOf(DateTime(2026, 9, 10));
    await t.pumpWidget(host(past, const BalanceScreen()));
    await t.pumpAndSettle();

    // The hero is one line in both states (red before §5 — the `as of` line used
    // to add a second, pushing ASSETS and the list down).
    expect(plusTop(t), moreOrLessEquals(plusToday, epsilon: 0.5));
    expect(t.getRect(find.text('ASSETS')).top,
        moreOrLessEquals(assetsToday, epsilon: 0.5));
    expect(t.takeException(), isNull);
  });

  testWidgets('Balance: "as of" appears nowhere with a past date selected',
      (t) async {
    setSize(t, 390, 844);
    final past = balanceStore()..setAsOf(DateTime(2026, 9, 10));
    await t.pumpWidget(host(past, const BalanceScreen()));
    await t.pumpAndSettle();

    expect(find.textContaining('as of'), findsNothing);
  });

  testWidgets('Balance: the date pill — label and colour across three dates',
      (t) async {
    setSize(t, 390, 844);

    Color pillBg(String label) => (t
            .widget<Container>(find
                .ancestor(of: find.text(label), matching: find.byType(Container))
                .first)
            .decoration as BoxDecoration)
        .color!;
    Color pillText(String label) => t.widget<Text>(find.text(label)).style!.color!;

    // Today — surfaceAlt, default text.
    await t.pumpWidget(host(balanceStore(), const BalanceScreen()));
    await t.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(pillBg('Today'), AppColors.surfaceAlt);
    expect(pillText('Today'), AppText.datePill.color);
    expect(pillText('Today'), isNot(AppColors.accentLight));

    // A date this year — "10 Sep", accent tint, accent text.
    final thisYear = balanceStore()..setAsOf(DateTime(2026, 9, 10));
    await t.pumpWidget(host(thisYear, const BalanceScreen()));
    await t.pumpAndSettle();
    expect(find.text('10 Sep'), findsOneWidget);
    expect(pillBg('10 Sep'), AppColors.accent.withValues(alpha: 0.22));
    expect(pillText('10 Sep'), AppColors.accentLight);

    // A date in a previous year — carries the year (the one thing the deleted
    // `as of` line said that the pill did not).
    final prevYear = balanceStore()..setAsOf(DateTime(2024, 9, 10));
    await t.pumpWidget(host(prevYear, const BalanceScreen()));
    await t.pumpAndSettle();
    expect(find.text('10 Sep 2024'), findsOneWidget);
    expect(pillText('10 Sep 2024'), AppColors.accentLight);
  });

  // ── No overflow at the tightest boxes, lens and search combined ─────────────
  // The Ledger is the screen this task widens (the count row / title). Sweep the
  // three widths, two scales, three locales, with the lens on and search both
  // off and on. Pre-existing populated-header overflows are drained (see
  // plus_button_alignment_test.dart); this asserts no *other* exception appears.
  for (final locale in const [Locale('en'), Locale('ru'), Locale('tk')]) {
    for (final size in const [Size(390, 844), Size(360, 640), Size(320, 568)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final searching in const [false, true]) {
          testWidgets(
            'Ledger lens: no unexpected exception in ${locale.languageCode} at '
            '${size.width.toInt()}×${size.height.toInt()} / '
            '${(scale * 100).toInt()}%, search ${searching ? 'on' : 'off'}',
            (t) async {
              setSize(t, size.width, size.height);
              ignoreLocaleDelegateWarning();

              final s = ledgerStore();
              applyLens(s);
              await t.pumpWidget(
                host(s, const LedgerScreen(), locale: locale, textScale: scale),
              );
              await t.pumpAndSettle();

              if (searching) {
                await t.tap(find.byIcon(Icons.search_rounded));
                await t.pumpAndSettle();
                await t.enterText(
                    find.byType(TextField), 'a very long query string zzzz');
                await t.pump(const Duration(milliseconds: 250));
              }

              drainKnownOverflow(t);
              expect(t.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
