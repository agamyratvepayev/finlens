import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/features/balance/same_transactions.dart';
import 'package:finlens/features/balance/same_transactions_screen.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/shared/widgets/swipe_actions.dart';
import 'package:finlens/theme/app_theme.dart';

/// Spec §1/§2/§3 — "the tapped transaction comes first". These cover the new
/// detail card, the range control promoted to the section header, and the
/// resulting block order.
///
/// The MaterialApp carries the real localization delegates pinned to English so
/// `AppLocalizations.of` resolves and the caps labels read NOTE/WHEN/PAID
/// WITH/TAGS.

Txn _tx(
  String id,
  TxnType type,
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
      type: type,
      amount: amount,
      currency: currency,
      fromRef: from,
      toRef: to,
      date: date ?? DateTime(2026, 8, 9, 8, 12),
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

AppStore _store({
  required List<Account> accounts,
  required List<Category> categories,
  required List<Txn> txns,
}) =>
    AppStore(
      accounts: accounts,
      categories: categories,
      txns: txns,
      goals: const <Goal>[],
      tasks: const <Task>[],
    );

Widget _host(AppStore store, Widget child) => StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ── Block order ────────────────────────────────────────────────────────────

  testWidgets(
      'blocks stack header → detail card → range header → summary → list '
      '(spec §2/§3)', (tester) async {
    final store = _store(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Eating out')],
      txns: [
        for (var i = 0; i < 15; i++)
          _tx('e$i', TxnType.expense, 'a1', 'c1',
              date: DateTime(2026, 8, 1, 8, 12).add(Duration(days: i))),
      ],
    );

    await tester
        .pumpWidget(_host(store, const SameTransactionsScreen(originTxnId: 'e0')));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    double top(Finder f) => tester.getTopLeft(f.first).dy;

    final headerDy = top(find.text('Eating out')); // 21pt title, header only
    final detailDy = top(find.text('WHEN')); // detail-card caps label only
    final rangeDy =
        top(find.byIcon(Icons.keyboard_arrow_down_rounded)); // range header
    final summaryDy = top(find.text('COUNT 15')); // summary metric band
    final listDy = top(find.byType(SwipeActions)); // first list row

    expect(headerDy, lessThan(detailDy), reason: 'header above the detail card');
    expect(detailDy, lessThan(rangeDy),
        reason: 'detail card above the range header');
    expect(rangeDy, lessThan(summaryDy),
        reason: 'range header above the summary');
    expect(summaryDy, lessThan(listDy), reason: 'summary above the list');
  });

  // ── COUNT reflects the range while the list shows five rows ─────────────────

  testWidgets('COUNT is the range count (15) above a five-row list (spec §3)',
      (tester) async {
    final store = _store(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Eating out')],
      txns: [
        for (var i = 0; i < 15; i++)
          _tx('e$i', TxnType.expense, 'a1', 'c1',
              date: DateTime(2026, 8, 1, 8, 12).add(Duration(days: i))),
      ],
    );

    await tester
        .pumpWidget(_host(store, const SameTransactionsScreen(originTxnId: 'e0')));
    store.setSameListRange(
        const SameRangeChoice.preset(SameRangePreset.allTime));
    await tester.pumpAndSettle();

    // COUNT counts the whole range…
    expect(find.text('COUNT 15'), findsOneWidget);
    // …while the (non-showAll) list renders exactly five rows under it.
    expect(find.byType(SwipeActions), findsNWidgets(5));
    // The "See all 15" footer confirms the truncation the summary describes.
    expect(find.text(AppLocalizations.of(tester.element(find.byType(SwipeActions).first)).balSeeAll(15)),
        findsOneWidget);
  });

  // ── Detail card: rows present / absent ──────────────────────────────────────

  testWidgets('a note-less, tag-less transaction omits the NOTE and TAGS rows '
      '(spec §5)', (tester) async {
    final store = _store(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Eating out')],
      txns: [_tx('e1', TxnType.expense, 'a1', 'c1')],
    );

    await tester.pumpWidget(
        _host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    await tester.pumpAndSettle();

    // Two rows only — WHEN and PAID WITH.
    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('PAID WITH'), findsOneWidget);
    expect(find.text('NOTE'), findsNothing);
    expect(find.text('TAGS'), findsNothing);
  });

  testWidgets('WHEN prints the time of day, and note/tags render when present '
      '(spec §1)', (tester) async {
    final store = _store(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Eating out')],
      txns: [
        _tx('e1', TxnType.expense, 'a1', 'c1',
            date: DateTime(2026, 8, 9, 8, 12),
            note: 'Team lunch',
            tags: ['fun', 'work']),
      ],
    );

    await tester.pumpWidget(
        _host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    await tester.pumpAndSettle();

    // The time is the fact the list row cannot show — WHEN carries it.
    expect(find.textContaining('08:12'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('#fun #work'), findsOneWidget);
  });

  // ── Range header: tappable and ≥ 44pt ──────────────────────────────────────

  testWidgets('the range header is ≥44pt tall and opens the range sheet '
      '(spec §2)', (tester) async {
    final store = _store(
      accounts: [_acc('a1', 'Main Checking')],
      categories: [_cat('c1', 'Eating out')],
      txns: [_tx('e1', TxnType.expense, 'a1', 'c1')],
    );

    await tester.pumpWidget(
        _host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    await tester.pumpAndSettle();

    final headerInk = find.ancestor(
      of: find.byIcon(Icons.keyboard_arrow_down_rounded),
      matching: find.byType(InkWell),
    );
    expect(headerInk, findsOneWidget);

    // The tap target is ≥44pt from padding, not the 10.5pt glyph.
    expect(tester.getSize(headerInk).height, greaterThanOrEqualTo(44.0));
    // It is genuinely tappable.
    expect(tester.widget<InkWell>(headerInk).onTap, isNotNull);

    // Tapping opens the existing range sheet.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  // ── Balance-after currency ──────────────────────────────────────────────────

  testWidgets('PAID WITH prints the balance-after in the account currency '
      '(spec §1/§5)', (tester) async {
    // EUR account, starting €1,000, one €200 expense → €800 after.
    final store = _store(
      accounts: [_acc('a1', 'EUR Wallet', currency: 'EUR', startingBalance: 1000)],
      categories: [_cat('c1', 'Eating out')],
      txns: [
        _tx('e1', TxnType.expense, 'a1', 'c1',
            currency: 'EUR', amount: 200, date: DateTime(2026, 8, 9, 8, 12)),
      ],
    );

    await tester.pumpWidget(
        _host(store, const SameTransactionsScreen(originTxnId: 'e1')));
    await tester.pumpAndSettle();

    // The balance-after reads in €, not the $ base currency.
    expect(find.text('€800'), findsOneWidget);
  });
}
