import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/clock.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/overdraw_warning_test.dart
//
// Task 011 §3 — the overdraft warning. It warns, never blocks. The projection
// lives in the store (balanceIfSaved) and the draft the form checks is built by
// the pure buildDraftTxn, so the warning asks about the same figures the write
// uses.

Account _acc(
  String id, {
  double starting = 0,
  AccountGroup group = AccountGroup.spendable,
}) =>
    Account(
      id: id,
      name: id,
      group: group,
      currency: 'USD',
      startingBalance: starting,
    );

Category _cat(String id, CategoryType type) => Category(
      id: id,
      name: id,
      type: type,
      icon: Icons.circle,
      color: const Color(0xFF34C759),
    );

AppStore _store({List<Account>? accounts, List<Txn> txns = const []}) =>
    AppStore(
      clock: Clock.fixed(DateTime(2026, 8, 9, 14, 32)),
      baseCurrency: 'USD',
      accounts: accounts ??
          [_acc('a', starting: 500), _acc('b', starting: 0)],
      categories: [_cat('exp', CategoryType.expense), _cat('inc', CategoryType.income)],
      txns: txns,
      goals: const [],
      tasks: const [],
    );

Txn _expense(String id, String from, double amount) => Txn(
      id: id,
      type: TxnType.expense,
      amount: amount,
      currency: 'USD',
      fromRef: from,
      toRef: 'exp',
      date: DateTime(2026, 8, 8),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // ── balanceIfSaved — the read-only projection (§3.1) ───────────────────────
  group('balanceIfSaved', () {
    test('expense drains the source', () {
      final store = _store();
      final draft = buildDraftTxn(store,
          type: QuickAddType.expense,
          amount: 100,
          fromRef: 'a',
          toRef: 'exp',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.balanceIfSaved('a', draft), 400);
    });

    test('income raises the destination', () {
      final store = _store();
      final draft = buildDraftTxn(store,
          type: QuickAddType.income,
          amount: 100,
          fromRef: 'inc',
          toRef: 'a',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.balanceIfSaved('a', draft), 600);
    });

    test('transfer without a fee moves net between the two', () {
      final store = _store();
      final draft = buildDraftTxn(store,
          type: QuickAddType.transfer,
          amount: 100,
          fromRef: 'a',
          toRef: 'b',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.balanceIfSaved('a', draft), 400);
      expect(store.balanceIfSaved('b', draft), 100);
    });

    test('transfer with a source fee drains the source by amount+fee', () {
      final store = _store();
      final draft = buildDraftTxn(store,
          type: QuickAddType.transfer,
          amount: 100,
          feeAmount: 10,
          fromRef: 'a',
          toRef: 'b',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      // Source loses net (90) + fee (10) = 100; destination receives net (90).
      expect(store.balanceIfSaved('a', draft), 400);
      expect(store.balanceIfSaved('b', draft), 90);
    });

    test('replacing an edited entry takes it out of the base first', () {
      final store = _store(txns: [_expense('t0', 'a', 50)]); // a = 450
      final t0 = store.txns.firstWhere((t) => t.id == 't0');
      final draft = buildDraftTxn(store,
          type: QuickAddType.expense,
          amount: 200,
          fromRef: 'a',
          toRef: 'exp',
          currency: 'USD',
          date: DateTime(2026, 8, 9),
          editing: t0)!;
      // Base without t0 is 500; the new 200 expense leaves 300.
      expect(store.balanceIfSaved('a', draft, replacing: t0), 300);
    });

    test('rebalance lands the asset on the typed target', () {
      final store = _store(accounts: [
        _acc('inv', starting: 1000, group: AccountGroup.investments),
      ]);
      // A revaluation down to 700.
      final draft = buildDraftTxn(store,
          type: QuickAddType.rebalance,
          amount: 700,
          toRef: 'inv',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.balanceIfSaved('inv', draft), 700);
    });
  });

  // ── Draft parity — the draft's effect equals the real write's (§3.2/§6) ─────
  //
  // buildDraftTxn is the single definition; here we assert its per-ref effect is
  // what the ledger rules produce, type by type. The transfer-with-fee case
  // folds the fee back in, so the draft's source effect equals the sum of the
  // written transfer and its linked fee expense.
  group('draft parity — effectOfTxnOn matches the write', () {
    test('expense', () {
      final store = _store();
      final d = buildDraftTxn(store,
          type: QuickAddType.expense,
          amount: 100,
          fromRef: 'a',
          toRef: 'exp',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.effectOfTxnOn(d, 'a'), -100);
    });

    test('income', () {
      final store = _store();
      final d = buildDraftTxn(store,
          type: QuickAddType.income,
          amount: 100,
          fromRef: 'inc',
          toRef: 'a',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.effectOfTxnOn(d, 'a'), 100);
    });

    test('transfer without fee — both refs', () {
      final store = _store();
      final d = buildDraftTxn(store,
          type: QuickAddType.transfer,
          amount: 100,
          fromRef: 'a',
          toRef: 'b',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      expect(store.effectOfTxnOn(d, 'a'), -100);
      expect(store.effectOfTxnOn(d, 'b'), 100);
    });

    test('transfer with fee — source effect equals transfer+fee together', () {
      final store = _store();
      final d = buildDraftTxn(store,
          type: QuickAddType.transfer,
          amount: 100,
          feeAmount: 10,
          fromRef: 'a',
          toRef: 'b',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      // The real write is a transfer of net (−90 on source) plus a fee expense
      // (−10 on source); the draft folds both into one −100.
      expect(store.effectOfTxnOn(d, 'a'), -100);
      expect(store.effectOfTxnOn(d, 'b'), 90);
    });

    test('rebalance — asset effect is the delta', () {
      final store = _store(accounts: [
        _acc('inv', starting: 1000, group: AccountGroup.investments),
      ]);
      final d = buildDraftTxn(store,
          type: QuickAddType.rebalance,
          amount: 700,
          toRef: 'inv',
          currency: 'USD',
          date: DateTime(2026, 8, 9))!;
      // delta = 700 − 1000 = −300.
      expect(store.effectOfTxnOn(d, 'inv'), -300);
    });
  });

  // ── The sheet, driven through the real save path ───────────────────────────

  // A complete new expense pre-filled via `copyOf`, pushed onto a navigator so a
  // successful save's pop has somewhere to return to.
  Future<AppStore> openCopy(WidgetTester tester, AppStore store, Txn template,
      {QuickAddType type = QuickAddType.expense}) async {
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      QuickAddScreen(initialType: type, copyOf: template),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return store;
  }

  Txn template(String from, double amount) => Txn(
        id: 'template',
        type: TxnType.expense,
        amount: amount,
        currency: 'USD',
        fromRef: from,
        toRef: 'exp',
        date: DateTime(2026, 8, 9),
      );

  testWidgets('an expense that takes a 0 asset below zero shows the sheet',
      (tester) async {
    final store = _store(accounts: [_acc('a', starting: 0)]);
    await openCopy(tester, store, template('a', 100));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This overdraws a'), findsOneWidget);
    expect(find.text('Save anyway'), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);
    expect(store.txns, isEmpty); // nothing written yet
  });

  testWidgets('Go back writes nothing', (tester) async {
    final store = _store(accounts: [_acc('a', starting: 0)]);
    await openCopy(tester, store, template('a', 100));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();

    expect(store.txns, isEmpty);
  });

  testWidgets('Save anyway writes exactly one entry', (tester) async {
    final store = _store(accounts: [_acc('a', starting: 0)]);
    await openCopy(tester, store, template('a', 100));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();

    expect(store.txns.length, 1);
    expect(store.balanceOf('a'), -100);
  });

  testWidgets('no sheet for a liability source', (tester) async {
    final store = _store(accounts: [
      _acc('card', starting: 0, group: AccountGroup.creditCards),
    ]);
    await openCopy(tester, store, template('card', 100));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('overdraws'), findsNothing);
    expect(store.txns.length, 1); // written straight through
  });

  testWidgets('no sheet when the balance never crosses zero', (tester) async {
    final store = _store(accounts: [_acc('a', starting: 500)]);
    await openCopy(tester, store, template('a', 100));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('overdraws'), findsNothing);
    expect(store.txns.length, 1);
  });

  testWidgets('no sheet for an entry that raises an already-negative balance',
      (tester) async {
    // Account already at −100; an income of 50 lifts it to −50 — below zero but
    // not lower than before, so the third condition holds it back.
    final store = _store(
      accounts: [_acc('a', starting: 0)],
      txns: [_expense('t0', 'a', 100)],
    );
    final incomeTemplate = Txn(
      id: 'template',
      type: TxnType.income,
      amount: 50,
      currency: 'USD',
      fromRef: 'inc',
      toRef: 'a',
      date: DateTime(2026, 8, 9),
    );
    await openCopy(tester, store, incomeTemplate, type: QuickAddType.income);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('overdraws'), findsNothing);
    expect(store.txns.length, 2); // the income was written
  });

  // ── Draft ↔ write parity, end to end ───────────────────────────────────────
  //
  // The real save path moves the source by exactly what buildDraftTxn predicts.
  // This is what stops the draft rotting away from the write.
  testWidgets('the write moves the source by the drafted amount (expense)',
      (tester) async {
    final store = _store(accounts: [_acc('a', starting: 500)]);
    final predicted = store.balanceOf('a') +
        store.effectOfTxnOn(
          buildDraftTxn(store,
              type: QuickAddType.expense,
              amount: 100,
              fromRef: 'a',
              toRef: 'exp',
              currency: 'USD',
              date: DateTime(2026, 8, 9))!,
          'a',
        );
    await openCopy(tester, store, template('a', 100));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.balanceOf('a'), predicted); // 400
  });
}
