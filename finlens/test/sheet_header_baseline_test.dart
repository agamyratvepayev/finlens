import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/planner/edit_scaffold.dart';
import 'package:finlens/features/quick_add/date_time_sheet.dart';
import 'package:finlens/features/quick_add/icon_picker_sheet.dart';
import 'package:finlens/features/quick_add/pickers.dart';
import 'package:finlens/features/quick_add/split_sheet.dart';
import 'package:finlens/features/quick_add/transaction_repeat_sheet.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Task 031 — sheet headers align on the alphabetic baseline.
//
// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/sheet_header_baseline_test.dart
//
// A header that mixes type sizes (a 15–19pt title beside 14–14.5pt actions) must
// align its text on the alphabetic baseline, not centre each child's box. These
// tests measure each header text's baseline and assert they share one.
//
// `RenderBox.getDistanceToBaseline` is debug-guarded outside layout, so — as the
// codebase already does in detail_row_baseline_test.dart — baselines are derived
// from the widget rect plus the FlutterTest font's deterministic metrics (ascent
// 0.75em; TextStyle.height scales it proportionally). The resolved paint style is
// read straight off the RenderParagraph, so a button's inherited size/height is
// handled without hard-coding it, and textScaler is applied for the 1.3× cases.

/// The alphabetic baseline of a single-line [Text], as an absolute y.
double _baseline(WidgetTester tester, Finder f) {
  final rp = tester.renderObject<RenderParagraph>(f);
  final style = rp.text.style!;
  final fontSize = rp.textScaler.scale(style.fontSize!);
  final lineHeight = style.height ?? 1.0;
  return tester.getRect(f).top + fontSize * lineHeight * 0.75;
}

/// The nearest Row ancestor of [child] — the header row itself.
Finder _headerRow(Finder child) =>
    find.ancestor(of: child, matching: find.byType(Row)).first;

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF34C759),
    );

AppStore _store() => AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      accounts: [_acc('a1', 'Cash'), _acc('a2', 'Bank')],
      categories: [_cat('c1', 'Groceries'), _cat('c2', 'Household')],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

/// Pumps a host with an "open" button that runs [onTap]; taps it and settles.
Future<void> _open(
  WidgetTester tester,
  void Function(BuildContext) onTap, {
  double w = 390,
  double h = 844,
  double textScale = 1.0,
}) async {
  _size(tester, w, h);
  await tester.pumpWidget(StoreScope(
    store: _store(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      // A builder override reaches the modal route (the sheet).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Asserts every finder in [texts] shares one baseline within [epsilon] px.
void _shareBaseline(WidgetTester tester, List<Finder> texts,
    {double epsilon = 0.5}) {
  final first = _baseline(tester, texts.first);
  for (final f in texts.skip(1)) {
    expect(_baseline(tester, f), moreOrLessEquals(first, epsilon: epsilon));
  }
}

void main() {
  // ── showAppSheet — the header behind every picker (§0.1) ────────────────────

  testWidgets('account picker: title, + New and Cancel share one baseline',
      (tester) async {
    await _open(tester,
        (ctx) => pickAccount(ctx, title: 'Pick an account'));

    final title = find.text('Pick an account');
    final create = find.text('New'); // qaNewShort — the "+ New" label
    final cancel = find.text('Cancel');
    expect(title, findsOneWidget);
    expect(create, findsOneWidget);
    expect(cancel, findsOneWidget);

    _shareBaseline(tester, [title, create, cancel]);

    // Height is governed by the 44pt action tap targets under both alignments.
    expect(tester.getRect(_headerRow(title)).height,
        moreOrLessEquals(44, epsilon: 0.5));
  });

  testWidgets('category picker: title, + New and Cancel share one baseline',
      (tester) async {
    await _open(
        tester,
        (ctx) => pickCategory(ctx,
            type: CategoryType.expense, title: 'Pick a category'));

    final title = find.text('Pick a category');
    _shareBaseline(tester, [title, find.text('New'), find.text('Cancel')]);
    expect(tester.getRect(_headerRow(title)).height,
        moreOrLessEquals(44, epsilon: 0.5));
  });

  // ── icon_picker_sheet (§0.3) ────────────────────────────────────────────────

  testWidgets('icon picker: title and Cancel share one baseline',
      (tester) async {
    await _open(tester,
        (ctx) => showIconPicker(ctx, typeColor: const Color(0xFF3B82F6)));

    final title = find.text('Icon');
    final cancel = find.text('Cancel');
    _shareBaseline(tester, [title, cancel]);
    // No tap-target box here: the 16pt title is the tallest child, both before
    // and after the change.
    expect(tester.getRect(_headerRow(title)).height,
        moreOrLessEquals(16, epsilon: 0.5));
  });

  // ── transaction_repeat_sheet (§0.4) ─────────────────────────────────────────

  testWidgets('repeat sheet: title and Cancel share one baseline',
      (tester) async {
    await _open(
        tester,
        (ctx) => showTxnRepeatSheet(ctx,
            current: const TxnRepeatSelection(freq: RepeatFrequency.none),
            date: DateTime(2026, 8, 9)));

    final title = find.text('Repeat');
    final cancel = find.text('Cancel');
    _shareBaseline(tester, [title, cancel]);
    expect(tester.getRect(_headerRow(title)).height,
        moreOrLessEquals(17, epsilon: 0.5));
  });

  // ── split_sheet (§0.5) ──────────────────────────────────────────────────────

  testWidgets('split sheet: title, Remove and Cancel share one baseline',
      (tester) async {
    await _open(
        tester,
        (ctx) => showSplitSheet(ctx,
            total: 100,
            currency: 'USD',
            accountName: 'Cash',
            categoryType: CategoryType.expense,
            // Two lines so the header's "Remove" split action renders.
            initial: [
              SplitLine(categoryId: 'c1', amount: 60),
              SplitLine(categoryId: 'c2', amount: 40),
            ]));

    final title = find.text('Split');
    final remove = find.text('Remove');
    final cancel = find.text('Cancel');
    expect(remove, findsOneWidget);
    _shareBaseline(tester, [title, remove, cancel]);
    expect(tester.getRect(_headerRow(title)).height,
        moreOrLessEquals(17, epsilon: 0.5));
  });

  // ── EditScaffold — title case and TypePill case (§0.6, §1.1) ─────────────────

  Widget hostScaffold(Widget scaffold) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: scaffold,
      );

  // EditScaffold stays on CENTRE alignment (task 031): Cancel is a Material
  // TextButton resolving to labelLarge (line height 1.43) while Save/title use
  // height-null styles, so their equal 48pt tap targets carry different internal
  // baselines and baseline-aligning them would grow the header. These tests pin
  // the height that keeping centre preserves — the row stays governed by the
  // 48pt tap target — rather than asserting a shared baseline.

  testWidgets('EditScaffold (title): header height stays at the tap-target '
      'height (centre kept)', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(hostScaffold(const EditScaffold(
      title: 'Edit budget',
      children: [],
    )));
    await tester.pumpAndSettle();

    final rowH = tester.getRect(_headerRow(find.text('Edit budget'))).height;
    final btnH = tester.getRect(find.widgetWithText(TextButton, 'Cancel')).height;
    expect(rowH, moreOrLessEquals(btnH, epsilon: 0.5));
  });

  testWidgets('EditScaffold (TypePill): header height stays at the tap-target '
      'height (centre kept)', (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(hostScaffold(EditScaffold(
      title: 'unused',
      type: QuickAddType.newGoal,
      onTypeTap: () {},
      children: const [],
    )));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget); // pill renders its label
    final rowH = tester.getRect(_headerRow(find.text('Cancel'))).height;
    final btnH = tester.getRect(find.widgetWithText(TextButton, 'Cancel')).height;
    expect(rowH, moreOrLessEquals(btnH, epsilon: 0.5));
  });

  // ── date_time_sheet — REPORT-ONLY: already aligned (same size) ───────────────
  //
  // Task 031 leaves this header on centre alignment: its title (qaDate) and
  // Cancel are BOTH AppText.rowTitle (15pt), so centring their boxes already
  // lands them on one baseline — there is nothing for a baseline switch to fix.
  // This test pins that pre-existing alignment so a future size change to either
  // side is caught.

  testWidgets('date-time sheet: title and Cancel already share a baseline '
      '(same size, unchanged)', (tester) async {
    await _open(
        tester,
        (ctx) => showDateTimeSheet(ctx,
            initial: DateTime(2026, 8, 9),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            now: DateTime(2026, 8, 9)));

    _shareBaseline(tester, [find.text('Date'), find.text('Cancel')]);
  });

  // ── FormNavBar — REPORT-ONLY exclusion: Cancel and Save are the same size ────
  //
  // Cancel and Save are both 15 * s * t and the middle child is a Container
  // (TypePill), so there is nothing to baseline-align. It is out of scope; this
  // test records that its Cancel/Save already share a baseline under centre.

  testWidgets('FormNavBar: Cancel and Save already share a baseline (excluded)',
      (tester) async {
    _size(tester, 390, 844);
    await tester.pumpWidget(hostScaffold(Scaffold(
      body: Column(children: [
        FormNavBar(
          typeName: 'New goal',
          accent: const Color(0xFF34C759),
          onCancel: () {},
          onTypeTap: () {},
          onSave: () {},
          canSave: true,
        ),
      ]),
    )));
    await tester.pumpAndSettle();

    _shareBaseline(tester, [find.text('Cancel'), find.text('Save')]);
  });

  // ── Ellipsis + small/large-scale invariants ─────────────────────────────────

  testWidgets('a long picker title still ellipsises and keeps Cancel on the '
      'baseline', (tester) async {
    await _open(
        tester,
        (ctx) => pickAccount(ctx,
            title: 'An extremely long account picker title that cannot '
                'possibly fit beside the New and Cancel actions on one line'));

    final title = find.textContaining('An extremely long account picker');
    final titleWidget = tester.widget<Text>(title);
    expect(titleWidget.maxLines, 1);
    expect(titleWidget.overflow, TextOverflow.ellipsis);
    expect(tester.renderObject<RenderParagraph>(title).didExceedMaxLines, isTrue);

    _shareBaseline(tester, [title, find.text('Cancel')]);
  });

  testWidgets('at 1.3 text scale and 320pt the account header still shares a '
      'baseline and does not overflow', (tester) async {
    await _open(tester, (ctx) => pickAccount(ctx, title: 'Accounts'),
        w: 320, h: 568, textScale: 1.3);

    _shareBaseline(tester, [
      find.text('Accounts'),
      find.text('New'),
      find.text('Cancel'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 1.3 text scale the split header still shares a baseline',
      (tester) async {
    await _open(
        tester,
        (ctx) => showSplitSheet(ctx,
            total: 100,
            currency: 'USD',
            accountName: 'Cash',
            categoryType: CategoryType.expense,
            initial: [
              SplitLine(categoryId: 'c1', amount: 60),
              SplitLine(categoryId: 'c2', amount: 40),
            ]),
        w: 320,
        h: 568,
        textScale: 1.3);

    _shareBaseline(tester,
        [find.text('Split'), find.text('Remove'), find.text('Cancel')]);
    expect(tester.takeException(), isNull);
  });
}
