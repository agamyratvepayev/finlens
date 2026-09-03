import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart' show monthYearLong;
import 'package:finlens/features/balance/balance_screen.dart' show EmptyState;
import 'package:finlens/features/ledger/ledger_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/amount_text.dart' show ProgressBar;
import 'package:finlens/shared/widgets/section_header.dart' show ToolCluster;
import 'package:finlens/theme/app_colors.dart';
import 'package:finlens/theme/app_theme.dart';

/// A store with no data of any kind — a genuine fresh install: `store.txns` is
/// empty, so §1's `everRecorded` is false and the whole instrument panel is
/// meant to go quiet.
AppStore _emptyStore() => AppStore(
      accounts: const [],
      categories: const [],
      txns: const [],
      goals: const [],
      tasks: const [],
    );

/// The Ledger tab under a real `Localizations`, at a chosen locale/size and text
/// scale. The scale is injected via MaterialApp's builder so it reaches every
/// descendant (MaterialApp otherwise rebuilds MediaQuery from the test view).
Widget _app(
  AppStore store, {
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
        home: const Scaffold(body: LedgerScreen()),
      ),
    );

void main() {
  // The default period is August 2026; a July row is "recorded elsewhere".
  final currentMonth = DateTime(2026, 8, 15);
  final pastMonth = DateTime(2026, 7, 15);

  testWidgets(
      'empty store: no eye, no ratio bar, no metrics strip, no tool row — but the + is present',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    // The instrument panel is gone from the tree, not merely dimmed.
    expect(find.byType(ToolCluster), findsNothing);
    expect(find.byType(ProgressBar), findsNothing);
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    // The metrics strip's keys (rendered uppercased) are absent.
    expect(find.text('IN'), findsNothing);
    expect(find.text('OUT'), findsNothing);
    expect(find.text('LEFT'), findsNothing);
    // The chevron is gone with tap-to-pick.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

    // The pill is gone (§2.1): there is no longer a second primary add control.
    expect(find.byType(FilledButton), findsNothing);

    // The + stays. `Icons.add_rounded` now appears exactly twice: the header's
    // accent + circle, and the inline glyph in the hint that names it (§4). The
    // old count included the empty state's own add button, which is deleted.
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty store: the title and message render; the pill does not',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Every transaction lives here'), findsOneWidget);
    expect(
      find.text(
          'Record what you spend and receive. Balances, budgets and goals all read from this list.'),
      findsOneWidget,
    );
    // The duplicate primary control is gone (§2.1).
    expect(find.text('Add an entry'), findsNothing);
    // Not the old empty-month notice, and not a filter branch.
    expect(find.text('Clear filter'), findsNothing);
  });

  testWidgets('empty store: no month string and no chevron are in the tree',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    // Assert against the formatter's output for the pinned period, not a
    // hard-coded "August 2026", so a change to the default period keeps the
    // test honest.
    final l = AppLocalizations.of(tester.element(find.byType(LedgerScreen)));
    expect(find.text(monthYearLong(store.period, l)), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets(
      'empty store: the hint line renders and is gone once a transaction exists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    // The hint is a rich line ("Start with + above"), so search rich text.
    expect(find.textContaining('Start with', findRichText: true),
        findsOneWidget);
    // Two add glyphs on first run: the header + and the hint's inline glyph.
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));

    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: currentMonth,
    );
    await tester.pump();

    // The hint leaves with the block; only the header + remains.
    expect(find.textContaining('Start with', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(1));
  });

  testWidgets(
      'empty store: the restore line renders and is gone once a transaction exists',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('Restore from a backup'), findsOneWidget);

    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: currentMonth,
    );
    await tester.pump();

    expect(find.text('Restore from a backup'), findsNothing);
  });

  testWidgets(
      'one entry in a past month, viewing an empty current month → full header + single-line notice, not the EmptyState',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: pastMonth,
    );

    await tester.pumpWidget(_app(store));
    await tester.pump();

    // The full header is back: something has been recorded.
    expect(find.byType(ToolCluster), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

    // The empty current month gets the light line, not the heavy EmptyState —
    // and no first-run hint or restore line.
    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Nothing recorded in August'), findsOneWidget);
    expect(find.textContaining('Start with', findRichText: true), findsNothing);
    expect(find.text('Restore from a backup'), findsNothing);
  });

  testWidgets('adding the first transaction brings the tool row back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byType(ToolCluster), findsNothing);

    store.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: currentMonth,
    );
    // Pump past the header's AnimatedSize growth (§6, 180ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ToolCluster), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter state cannot strand a first run: empty store shows the '
      'first-run state, never Clear filter', (tester) async {
    // The filter tool is itself hidden on an empty store, so a filter can never
    // be *set* over nothing; and even a filter left active by deleting the last
    // entry loses to the `!everRecorded` branch, which is checked first. Either
    // way the reachable outcome is the first-run state, never "Clear filter".
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore()));
    await tester.pump();

    expect(find.text('Every transaction lives here'), findsOneWidget);
    expect(find.text('Clear filter'), findsNothing);
    expect(find.text('No transactions match your filter'), findsNothing);
    // The filter tool that would set a filter is not even in the tree.
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);
  });

  testWidgets('320 pt in tr: the empty state does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_emptyStore(), locale: const Locale('tr')));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '130% text scale at 320x568 (tr): the block scrolls, the restore line '
      'stays reachable, nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        _app(_emptyStore(), locale: const Locale('tr'), textScale: 1.3));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    // The pinned restore line survives the largest supported text at 320pt.
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ── EmptyState regression guard (§2.4) ──────────────────────────────────────

  testWidgets(
      'EmptyState with default parameters renders a bare 40pt icon and an '
      'unconstrained message — the guard for the other seven call sites',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.star_rounded,
            title: 'T',
            message: 'M',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
    expect(icon.size, 40); // bare, not the 24pt backdrop glyph
    expect(icon.color, AppColors.textTertiary);
    // No message width cap by default.
    expect(
      find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 205),
      findsNothing,
    );
  });

  testWidgets(
      'EmptyState opt-ins: iconBackdrop gives a 24pt glyph and messageMaxWidth '
      'caps the message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.star_rounded,
            title: 'T',
            message: 'M',
            iconBackdrop: true,
            messageMaxWidth: 205,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
    expect(icon.size, 24);
    expect(
      find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 205),
      findsOneWidget,
    );
  });

  // ── First-run hint fallback (§4.1) ──────────────────────────────────────────

  testWidgets('the hint falls back to plain text when the placeholder is lost',
      (tester) async {
    final sentinel = String.fromCharCode(0);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: buildFirstRunHint('No placeholder here', sentinel),
          ),
        ),
      ),
    );

    expect(find.text('No placeholder here'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hint renders the glyph when the placeholder is present',
      (tester) async {
    final sentinel = String.fromCharCode(0);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: buildFirstRunHint('before${sentinel}after', sentinel),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.textContaining('before', findRichText: true), findsOneWidget);
  });

  // ── Restore line behaviour (§5) ─────────────────────────────────────────────

  testWidgets(
      'tapping the restore line opens the picker; a cancelled pick leaves the '
      'screen unchanged', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Fake the picker at the method-channel boundary: returning null is a
    // cancelled pick, so runRestoreFlow must be a no-op.
    var pickerOpened = false;
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      pickerOpened = true;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();

    expect(pickerOpened, isTrue);
    // Cancelled → nothing changed: still the first-run screen.
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Every transaction lives here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'after loadFrom the first-run screen is replaced by the populated one, '
      'with no exception', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _emptyStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();
    expect(find.byType(EmptyState), findsOneWidget);

    final source = _emptyStore();
    source.addTxn(
      type: TxnType.income,
      amount: 10,
      currency: 'USD',
      fromRef: 'x',
      toRef: 'y',
      date: currentMonth,
    );
    store.loadFrom(source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(EmptyState), findsNothing);
    expect(find.byType(ToolCluster), findsOneWidget);
    expect(find.text('Restore from a backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
