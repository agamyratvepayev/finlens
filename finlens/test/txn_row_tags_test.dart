import 'package:flutter/material.dart';
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
      tags: tags,
    );

// ── Ledger-tab TxnRow harness ────────────────────────────────────────────────

Future<void> _pumpTxnRow(
  WidgetTester tester,
  AppStore store,
  Txn txn, {
  double width = 390,
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
            child: TxnRow(
              txn: txn,
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
    tags: spec.tags,
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
                  final s = MediaQuery.textScalerOf(context);
                  return TitleTagRow(
                    title: const Text('Groceries',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: titleStyle),
                    titleWidth:
                        TitleTagRow.measure('Groceries', titleStyle, s),
                    tags: tags,
                    tagStyle: tagStyle,
                    buildTag: (run) => Text(run, style: tagStyle),
                    trailing: const Text(r'$120', style: amountStyle),
                    trailingWidth:
                        TitleTagRow.measure(r'$120', amountStyle, s),
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
      const scaler = TextScaler.noScaling;
      final titleW = TitleTagRow.measure('Groceries', titleStyle, scaler);
      final trailW = TitleTagRow.measure(r'$120', amountStyle, scaler);
      final fullW =
          TitleTagRow.measure('#fun #weekend #split', tagStyle, scaler);
      final collapsedW = TitleTagRow.measure('#fun +2', tagStyle, scaler);
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
}
