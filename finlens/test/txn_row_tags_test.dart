import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/ledger/ledger_scope.dart';
import 'package:finlens/features/ledger/widgets/ledger_txn_row.dart';
import 'package:finlens/shared/widgets/title_tag_row.dart';
import 'package:finlens/shared/widgets/txn_row.dart';
import 'package:finlens/theme/app_theme.dart';

// The tag moved from the meta line onto the title line, in one shared format on
// both the Ledger-tab TxnRow and the scoped LedgerTxnRow (spec §1/§2). These
// tests pin: the single formatter, the "title wins" yield order, that a tagged
// account-scope row gains no extra line, that the scoped row no longer drops
// extra tags, and that a screen reader names every tag regardless of the visual
// `+N` collapse.
//
// Widths are chosen against the test environment's fixed-metric font (each glyph
// is one em wide), so the collapse/drop thresholds are deterministic.

Category _cat(String name) => Category(
      id: 'c-cat',
      name: name,
      type: CategoryType.expense,
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFF30D158),
    );

Account _acc(String id, String name) => Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: 'USD',
      startingBalance: 1000,
    );

AppStore _store({String category = 'Groceries'}) => AppStore(
      accounts: [_acc('a1', 'Main Checking'), _acc('a2', 'Cash Wallet')],
      categories: [_cat(category)],
      txns: const <Txn>[],
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Txn _expense({String note = '', List<String> tags = const []}) => Txn(
      id: 'e1',
      type: TxnType.expense,
      amount: 120,
      currency: 'USD',
      fromRef: 'a1',
      toRef: 'c-cat',
      date: DateTime(2026, 8, 5),
      note: note,
      // Authored as names for readability; reified to real Tag ids (and the
      // Tag entities created in the store) by the pump harnesses below.
      tagIds: tags,
    );

/// Create a Tag per name in [store] and return the matching ids. createTag
/// returns an existing tag on a folded-name collision, so repeats are safe.
List<String> _reify(AppStore store, List<String> names) =>
    [for (final n in names) store.createTag(n)!.id];

// ── Ledger-tab TxnRow harness ────────────────────────────────────────────────

Future<void> _pumpTxnRow(
  WidgetTester tester,
  AppStore store,
  Txn txn, {
  double width = 390,
  String? searchQuery,
}) async {
  // The row resolves tag ids → names through the store; reify the authored
  // names into real tags so the ids resolve.
  txn.tagIds = _reify(store, txn.tagIds);
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TxnRow(
              txn: txn,
              searchQuery: searchQuery,
              onTap: () {},
              onEdit: () {},
              onCopy: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

// ── Scoped LedgerTxnRow harness ──────────────────────────────────────────────

ScopedTxn _scopedRow(AppStore store, Txn spec, LedgerScope scope) {
  final added = store.addTxn(
    type: spec.type,
    amount: spec.amount,
    currency: spec.currency,
    fromRef: spec.fromRef,
    toRef: spec.toRef,
    date: spec.date,
    note: spec.note,
    tagIds: _reify(store, spec.tagIds),
  );
  final q = LedgerQuery(
      store: store, scope: scope, start: DateTime(2020), end: DateTime(2030));
  return q.rows().firstWhere((r) => r.txn.id == added.id);
}

Future<double> _pumpScopedRow(
  WidgetTester tester,
  AppStore store,
  ScopedTxn row,
  LedgerScope scope, {
  double width = 360,
  bool showBalance = false,
  bool showDescription = true,
}) async {
  await tester.pumpWidget(StoreScope(
    store: store,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: LedgerTxnRow(
              row: row,
              scope: scope,
              showBalance: showBalance,
              showDescription: showDescription,
              onOpen: () {},
              onEdit: () {},
              onCopy: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return tester.getSize(find.byType(LedgerTxnRow)).height;
}

void main() {
  // ── The one shared formatter ───────────────────────────────────────────────
  group('tag formatter (single source of truth)', () {
    test('full run is every tag; collapsed is "#first +n"', () {
      expect(tagRunText(const ['fun']).full, '#fun');
      expect(tagRunText(const ['fun']).collapsed, '#fun');

      final three = tagRunText(const ['fun', 'weekend', 'split']);
      expect(three.full, '#fun #weekend #split');
      expect(three.collapsed, '#fun +2');
    });

    test('semantics names every tag — never the visual +N', () {
      expect(tagSemanticsLabel(const []), '');
      expect(tagSemanticsLabel(const ['fun']), 'tag fun');
      expect(tagSemanticsLabel(const ['fun', 'weekend', 'split']),
          'tags fun, weekend, split');
    });
  });

  // ── TitleTagRow: the yield order, in isolation ─────────────────────────────
  group('TitleTagRow — the title wins', () {
    const titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    const tagStyle = TextStyle(fontSize: 10.5, color: Color(0xFFBF5AF2));
    const amountStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const tags = ['fun', 'weekend', 'split'];

    Widget harness(double width, {TextScaler scaler = TextScaler.noScaling}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Builder(builder: (context) {
                  return TitleTagRow(
                    title: const Text('Groceries',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: titleStyle),
                    titleWidth:
                        TitleTagRow.measure(context, 'Groceries', titleStyle),
                    tags: tags,
                    tagStyle: tagStyle,
                    buildTag: (run) => Text(run, style: tagStyle),
                    trailing: const Text(r'$120', style: amountStyle),
                    trailingWidth:
                        TitleTagRow.measure(context, r'$120', amountStyle),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the full run when it fits', (tester) async {
      await tester.pumpWidget(harness(600));
      expect(find.text('#fun #weekend #split'), findsOneWidget);
      expect(find.text('#fun +2'), findsNothing);
    });

    testWidgets('collapses to "#first +n" when tight, and the title keeps its '
        'full natural width', (tester) async {
      // Measure against a real element so the ambient DefaultTextStyle — which
      // the widget merges into its own style before rendering — is the one the
      // measurement sees too. A first pump at a comfortable width provides that
      // context; measured widths do not depend on the constraint, so we then
      // re-pump at the derived boundary width.
      await tester.pumpWidget(harness(600));
      final ctx = tester.element(find.byType(TitleTagRow));
      final titleW = TitleTagRow.measure(ctx, 'Groceries', titleStyle);
      final trailW = TitleTagRow.measure(ctx, r'$120', amountStyle);
      final fullW =
          TitleTagRow.measure(ctx, '#fun #weekend #split', tagStyle);
      final collapsedW = TitleTagRow.measure(ctx, '#fun +2', tagStyle);
      // Pick a budget squarely between the two runs, then back out the width
      // (SizedBox width == avail here; no icon/padding around it).
      final budget = (collapsedW + fullW) / 2;
      // region = avail - (trailW + 2) - trailingGap(8); budget = region - titleW - tagGap(6)
      final width = budget + titleW + 6 + (trailW + 2) + 8;

      await tester.pumpWidget(harness(width));
      expect(find.text('#fun +2'), findsOneWidget);
      expect(find.text('#fun #weekend #split'), findsNothing);

      // The title was given its whole natural width — it is not squeezed to
      // make room for the tag (the opposite of the meta line's order).
      expect(tester.getSize(find.text('Groceries')).width,
          closeTo(titleW, 1.0));
      // And it did not ellipsize: the box holding a whole title must never clip
      // its glyphs to fit a tag beside it. This is the assertion that the old
      // box-width-only check missed — it measured the cage, not the bird.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Groceries'))
            .didExceedMaxLines,
        isFalse,
        reason: 'the title must never ellipsize to make room for a tag',
      );
    });

    testWidgets('drops the tag entirely rather than truncating the title',
        (tester) async {
      // A width too small for even the collapsed tag beside a whole title.
      await tester.pumpWidget(harness(180));
      expect(find.text('#fun +2'), findsNothing);
      expect(find.text('#fun #weekend #split'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
    });
  });

  // ── Both rows format the tag the same way ──────────────────────────────────
  group('both rows use the shared format', () {
    testWidgets('Ledger-tab TxnRow shows the full run of three tags when wide',
        (tester) async {
      await _pumpTxnRow(
          tester, _store(), _expense(tags: const ['fun', 'weekend', 'split']),
          width: 560);
      expect(find.text('#fun #weekend #split'), findsOneWidget);
    });

    testWidgets('scoped LedgerTxnRow shows the full run — no bare tag, no '
        'dropped extras (the regression)', (tester) async {
      final store = _store(category: 'Food');
      final row = _scopedRow(store, _expense(tags: const ['fun', 'weekend', 'split']),
          const GroupScope(AccountGroup.spendable));
      await _pumpScopedRow(
          tester, store, row, const GroupScope(AccountGroup.spendable),
          width: 560);
      // The old scoped row rendered a bare `fun` and discarded the rest.
      expect(find.text('#fun #weekend #split'), findsOneWidget);
      expect(find.text('fun'), findsNothing);
    });

    testWidgets('scoped LedgerTxnRow collapses three tags to "#fun +2" when '
        'tight', (tester) async {
      final store = _store(category: 'Food');
      final row = _scopedRow(store, _expense(tags: const ['fun', 'weekend', 'split']),
          const GroupScope(AccountGroup.spendable));
      await _pumpScopedRow(
          tester, store, row, const GroupScope(AccountGroup.spendable),
          width: 340);
      expect(find.text('#fun +2'), findsOneWidget);
      expect(find.text('#fun #weekend #split'), findsNothing);
    });
  });

  // ── The core fix: a tag no longer costs a line under account scope ──────────
  group('account scope — the tag adds no line', () {
    testWidgets('a tagged, note-less row is the same height as an untagged one',
        (tester) async {
      final store = _store(category: 'Food');
      final tagged = _scopedRow(
          store, _expense(tags: const ['side']), const AccountScope('a1'));
      final taggedH = await _pumpScopedRow(
          tester, store, tagged, const AccountScope('a1'));

      final store2 = _store(category: 'Food');
      final plain =
          _scopedRow(store2, _expense(), const AccountScope('a1'));
      final plainH = await _pumpScopedRow(
          tester, store2, plain, const AccountScope('a1'));

      expect(taggedH, closeTo(plainH, 0.5));
    });

    testWidgets('a tagged, noted row is two lines (not three); the tag rides '
        'the title line', (tester) async {
      final store = _store(category: 'Food');
      final tagged = _scopedRow(store,
          _expense(note: 'Bakery & fruit', tags: const ['side']),
          const AccountScope('a1'));
      final taggedH = await _pumpScopedRow(
          tester, store, tagged, const AccountScope('a1'));

      final store2 = _store(category: 'Food');
      final noted = _scopedRow(
          store2, _expense(note: 'Bakery & fruit'), const AccountScope('a1'));
      final notedH = await _pumpScopedRow(
          tester, store2, noted, const AccountScope('a1'));

      // Two lines (title + description) — the tag did not open a third line.
      expect(taggedH, lessThan(60));
      expect(taggedH, closeTo(notedH, 0.5));
      // The tag is present, on the title line, in the shared "#tag" format.
      expect(find.text('#side'), findsOneWidget);
    });
  });

  // ── Semantics name every tag, the same on both rows ────────────────────────
  group('semantics name every tag', () {
    testWidgets('scoped LedgerTxnRow announces all three tags, not "+2"',
        (tester) async {
      final handle = tester.ensureSemantics();
      final store = _store(category: 'Food');
      final row = _scopedRow(store, _expense(tags: const ['fun', 'weekend', 'split']),
          const GroupScope(AccountGroup.spendable));
      await _pumpScopedRow(
          tester, store, row, const GroupScope(AccountGroup.spendable));
      expect(find.bySemanticsLabel(RegExp('tags fun, weekend, split')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('Ledger-tab TxnRow announces all three tags', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpTxnRow(tester, _store(),
          _expense(tags: const ['fun', 'weekend', 'split']));
      expect(find.bySemanticsLabel(RegExp('tags fun, weekend, split')),
          findsOneWidget);
      handle.dispose();
    });
  });

  // ── The regression: a tagged title truncated while slack sat before the
  //    amount. The title must render whole whenever the tag fits beside it; the
  //    tag must drop before the title ellipsizes; an untagged row is untouched.
  //    Repeated at 130% text scale, where the metrics differ but the order holds.
  group('tagged title renders in full (the truncation fix)', () {
    const titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    const tagStyle = TextStyle(fontSize: 10.5, color: Color(0xFFBF5AF2));
    const amountStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

    Widget harness(
      double width, {
      required String title,
      required List<String> tags,
      TextScaler scaler = TextScaler.noScaling,
      String amount = r'$28',
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Builder(builder: (context) {
                  return TitleTagRow(
                    title: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle),
                    titleWidth: TitleTagRow.measure(context, title, titleStyle),
                    tags: tags,
                    tagStyle: tagStyle,
                    buildTag: (run) => Text(run, style: tagStyle),
                    trailing: Text(amount, style: amountStyle),
                    trailingWidth:
                        TitleTagRow.measure(context, amount, amountStyle),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    }

    // Whether the (single-span) title Text actually ellipsized when rendered.
    bool ellipsized(WidgetTester tester, String text) =>
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

    // ── No scaling ─────────────────────────────────────────────────────────
    testWidgets('a tagged title that fits is not truncated', (tester) async {
      await tester.pumpWidget(
          harness(400, title: 'Entertainment', tags: const ['fun']));
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('#fun'), findsOneWidget);
      expect(ellipsized(tester, 'Entertainment'), isFalse);
      // Rendered at its full natural width — not pinned short by a measurement.
      // Measured against the row's own element, so the ambient style the render
      // merges in is the one the measurement sees.
      final ctx = tester.element(find.byType(TitleTagRow));
      final natural = TitleTagRow.measure(ctx, 'Entertainment', titleStyle);
      expect(tester.getSize(find.text('Entertainment')).width,
          closeTo(natural, 1.0));
    });

    testWidgets('the tag drops before a long title truncates', (tester) async {
      // 355 holds the whole name but not the name + even a collapsed tag.
      const title = 'US Stocks (S&P 500)';
      await tester.pumpWidget(harness(355,
          title: title, tags: const ['dividends-reinvested']));
      expect(find.text(title), findsOneWidget);
      expect(ellipsized(tester, title), isFalse);
      // The tag dropped rather than the name being cut.
      expect(find.textContaining('#dividends'), findsNothing);
    });

    testWidgets('an untagged title lays out unchanged', (tester) async {
      await tester.pumpWidget(
          harness(400, title: 'Entertainment', tags: const []));
      expect(find.text('Entertainment'), findsOneWidget);
      expect(ellipsized(tester, 'Entertainment'), isFalse);
    });

    // ── 130% text scale ────────────────────────────────────────────────────
    const scale = TextScaler.linear(1.3);

    testWidgets('130%: a tagged title that fits is not truncated',
        (tester) async {
      await tester.pumpWidget(harness(500,
          title: 'Entertainment', tags: const ['fun'], scaler: scale));
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('#fun'), findsOneWidget);
      expect(ellipsized(tester, 'Entertainment'), isFalse);
      // The scaler now rides on the widget's own context (MediaQuery 1.3x), so
      // measuring against that element scales exactly as the render does.
      final ctx = tester.element(find.byType(TitleTagRow));
      final natural = TitleTagRow.measure(ctx, 'Entertainment', titleStyle);
      expect(tester.getSize(find.text('Entertainment')).width,
          closeTo(natural, 1.0));
    });

    testWidgets('130%: the tag drops before a long title truncates',
        (tester) async {
      const title = 'US Stocks (S&P 500)';
      await tester.pumpWidget(harness(450,
          title: title, tags: const ['dividends-reinvested'], scaler: scale));
      expect(find.text(title), findsOneWidget);
      expect(ellipsized(tester, title), isFalse);
      expect(find.textContaining('#dividends'), findsNothing);
    });

    testWidgets('130%: an untagged title lays out unchanged', (tester) async {
      await tester.pumpWidget(harness(500,
          title: 'Entertainment', tags: const [], scaler: scale));
      expect(find.text('Entertainment'), findsOneWidget);
      expect(ellipsized(tester, 'Entertainment'), isFalse);
    });
  });

  // ── The reported bug, exercised through a real TxnRow under AppTheme.dark —
  //    where the ambient bodyMedium letter-spacing that the render adds (and
  //    the old bare measurement missed) actually applies. ─────────────────────
  group('the reported bug — a tagged title renders whole (AppTheme.dark)', () {
    testWidgets('"Entertainment" + #fun is not truncated at 390pt',
        (tester) async {
      await _pumpTxnRow(tester, _store(category: 'Entertainment'),
          _expense(tags: const ['fun']), width: 390);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('#fun'), findsOneWidget);
      final para =
          tester.renderObject<RenderParagraph>(find.text('Entertainment'));
      expect(para.didExceedMaxLines, isFalse,
          reason:
              'a category name must never ellipsize to make room for a tag');
    });

    testWidgets('a search-highlighted tagged title (Text.rich) is not truncated',
        (tester) async {
      await _pumpTxnRow(tester, _store(category: 'Entertainment'),
          _expense(tags: const ['fun']),
          width: 390, searchQuery: 'enter');
      // Highlighting swaps the plain Text for a Text.rich of spans with the same
      // base style, so the merged measurement still governs. It must not clip.
      final title = find.textContaining('Entertainment');
      expect(title, findsOneWidget);
      expect(find.text('#fun'), findsOneWidget);
      expect(tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
          isFalse);
    });
  });

  // ── The unit test of the fix itself: a merged measurement is wider than a
  //    bare one whenever the ambient style contributes letter-spacing. This is
  //    the exact defect — the old bare TextPainter under-measured the title. ──
  group('measure resolves the ambient DefaultTextStyle', () {
    testWidgets('merged width exceeds the bare width under ambient '
        'letter-spacing', (tester) async {
      const ambient = TextStyle(fontSize: 14, letterSpacing: 4);
      const local = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
      late BuildContext ctx;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: DefaultTextStyle(
            style: ambient,
            child: Builder(builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            }),
          ),
        ),
      ));
      // measure merges the ambient (letterSpacing 4) into `local`, as Text does.
      final merged = TitleTagRow.measure(ctx, 'Entertainment', local);
      // The old path: the bare style alone, no ambient — narrower by the
      // letter-spacing the render adds to every glyph.
      final bare = (TextPainter(
        text: const TextSpan(text: 'Entertainment', style: local),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout())
          .size
          .width;
      expect(merged, greaterThan(bare));
    });
  });
}
