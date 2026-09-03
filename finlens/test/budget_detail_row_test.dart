import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/planner/budget_detail_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/detail_row.dart';
import 'package:finlens/theme/app_theme.dart';

/// Spec §1–§5 — a budget-detail transaction row opens in place to reveal
/// WHEN · PAID WITH · TAGS, and closes again, with no navigation. These pin the
/// reveal, the closed-row invariance, the row-omission rules, masking, multiple
/// open rows, and the 320pt overflow guard.
///
/// The MaterialApp carries the real localization delegates pinned to English so
/// the caps labels read WHEN / PAID WITH / TAGS.

Txn _tx(
  String id,
  String from,
  String to, {
  DateTime? date,
  double amount = 10,
  String currency = 'USD',
  String note = '',
  List<String> tags = const [],
}) =>
    Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: currency,
      fromRef: from,
      toRef: to,
      date: date ?? DateTime(2026, 8, 9, 20, 14),
      note: note,
      tagIds: tags,
    );

Account _acc(String id, String name,
        {String currency = 'USD', double startingBalance = 1000}) =>
    Account(
      id: id,
      name: name,
      group: AccountGroup.spendable,
      currency: currency,
      startingBalance: startingBalance,
    );

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      icon: Icons.restaurant_rounded,
      color: const Color(0xFF30D158),
    );

/// A monthly category budget (budgets-as-object spec §A) — the field the
/// category used to carry.
Budget _budget(String catId, {double limit = 500}) => Budget(
      id: 'b-$catId',
      name: catId,
      scope: BudgetScope.categories,
      targets: {catId},
      limit: limit,
      anchor: DateTime(2026, 1, 1),
    );

AppStore _store(List<Txn> txns,
        {List<Account>? accounts, List<Category>? categories}) {
  final cats = categories ?? [_cat('c1', 'Eating out')];
  return AppStore(
    accounts: accounts ?? [_acc('a1', 'Main Checking')],
    categories: cats,
    budgets: [for (final c in cats) _budget(c.id)],
    txns: txns,
    goals: const <Goal>[],
    tasks: const <Task>[],
  );
}

Widget _host(AppStore store) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: BudgetDetailScreen(
          categoryId: 'c1',
          month: _august,
        ),
      ),
    );

final _august = DateTime(2026, 8);

/// The title Text of the row for [note] (or the category name when note-less).
Finder _titleText(String s) => find.text(s);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ── Reveal / hide on tap ────────────────────────────────────────────────────

  testWidgets('tapping a row reveals WHEN·PAID WITH·TAGS; tapping again hides '
      '(spec §5)', (tester) async {
    final store = _store([
      _tx('e1', 'a1', 'c1', note: 'Team lunch', tags: ['fun']),
    ]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    // Closed: none of the three detail labels are on screen.
    expect(find.text('WHEN'), findsNothing);
    expect(find.text('PAID WITH'), findsNothing);
    expect(find.text('TAGS'), findsNothing);

    await tester.tap(_titleText('Team lunch'));
    await tester.pumpAndSettle();

    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('PAID WITH'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);

    await tester.tap(_titleText('Team lunch'));
    await tester.pumpAndSettle();

    expect(find.text('WHEN'), findsNothing);
    expect(find.text('PAID WITH'), findsNothing);
    expect(find.text('TAGS'), findsNothing);
  });

  // ── Closed row unchanged: same height whether or not the note is long ────────

  testWidgets('a closed row keeps a single-line title regardless of note length '
      '(spec §5)', (tester) async {
    const longNote =
        'A very long note that would wrap across several lines if the '
        'title clamp ever lifted while the row is still closed';
    final store = _store([_tx('e1', 'a1', 'c1', note: longNote)]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    // Closed → the note Text is clamped to exactly one line.
    final closed = tester.widget<Text>(_titleText(longNote));
    expect(closed.maxLines, 1);

    // Open → the clamp lifts (maxLines null = unbounded), so it can wrap in full.
    await tester.tap(_titleText(longNote));
    await tester.pumpAndSettle();
    final open = tester.widget<Text>(_titleText(longNote));
    expect(open.maxLines, isNull);
  });

  // ── Row-omission rules ──────────────────────────────────────────────────────

  testWidgets('a tag-less transaction opens to two DetailRows, not three '
      '(spec §3/§4)', (tester) async {
    final store = _store([_tx('e1', 'a1', 'c1', note: 'Lunch')]); // no tags
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(_titleText('Lunch'));
    await tester.pumpAndSettle();

    // WHEN + PAID WITH only. No TAGS. No NOTE row (the title above is the note).
    expect(find.byType(DetailRow), findsNWidgets(2));
    expect(find.text('TAGS'), findsNothing);
    expect(find.text('NOTE'), findsNothing);
  });

  testWidgets('an unresolvable account omits PAID WITH but still shows WHEN '
      '(spec §4)', (tester) async {
    // fromRef points at no account.
    final store = _store([_tx('e1', 'ghost', 'c1', note: 'Cash lunch')]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(_titleText('Cash lunch'));
    await tester.pumpAndSettle();

    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('PAID WITH'), findsNothing);
    expect(find.byType(DetailRow), findsOneWidget);
  });

  // ── PAID WITH: balance-after, in account currency, masking ──────────────────

  testWidgets('PAID WITH shows the balance-after in the account currency and '
      'masks with the privacy eye (spec §5)', (tester) async {
    // EUR wallet, €1,000 start, one €200 expense → €800 after.
    final store = _store(
      [
        _tx('e1', 'a1', 'c1',
            currency: 'EUR', amount: 200, date: DateTime(2026, 8, 9, 20, 14)),
      ],
      accounts: [_acc('a1', 'EUR Wallet', currency: 'EUR')],
    );
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EUR Wallet'));
    await tester.pumpAndSettle();

    // Balance-after reads in €, not $ base.
    expect(find.text('€800'), findsOneWidget);

    // Eye on → the figure masks; the plain €800 disappears. Toggling the eye
    // must not close the open row.
    store.toggleMasked();
    await tester.pumpAndSettle();
    expect(find.text('€800'), findsNothing);
    expect(find.text('PAID WITH'), findsOneWidget); // still open
  });

  // ── Two rows open at once ───────────────────────────────────────────────────

  testWidgets('two rows can be open simultaneously (spec §1)', (tester) async {
    final store = _store([
      _tx('e1', 'a1', 'c1', note: 'Alpha'),
      _tx('e2', 'a1', 'c1', note: 'Beta', date: DateTime(2026, 8, 10, 9, 0)),
    ]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(_titleText('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(_titleText('Beta'));
    await tester.pumpAndSettle();

    // Both detail blocks are open — two WHEN labels, no accordion auto-close.
    expect(find.text('WHEN'), findsNWidgets(2));
  });

  // ── 320pt with a long account name: no overflow ─────────────────────────────

  testWidgets('320pt: a long account name in PAID WITH does not overflow '
      '(spec §4)', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _store(
      [_tx('e1', 'a1', 'c1', note: 'Groceries at the far side of town')],
      accounts: [
        _acc('a1',
            'Joint Everyday Spending Current Account — Household'),
      ],
    );
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    await tester.tap(_titleText('Groceries at the far side of town'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PAID WITH'), findsOneWidget);
  });
}
