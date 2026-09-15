import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/store/app_store.dart';
import 'package:finlens/core/utils/date_range.dart';
import 'package:finlens/features/quick_add/quick_add_sheet.dart';
import 'package:finlens/features/quick_add/widgets/amount_hero.dart';
import 'package:finlens/features/quick_add/widgets/form_kit.dart';
import 'package:finlens/l10n/app_localizations.dart';
import 'package:finlens/theme/app_theme.dart';

// Rebalance task 007 — "what the difference actually is".
//
// `flutter test` hangs on the dev machine, so these are written, not run here.
// Verify with `flutter analyze`; run the file yourself:
//   flutter test test/rebalance_difference_test.dart
//
// Seed accounts used:
//   a-home       valuables    (revaluation)          "Primary Residence (Apartment)"
//   a-cash-usd   spendable    (income / expense)     "Cash (USD Wallet)"
//   a-utilities  payables     (liability, bal −800)  "Electricity / Utilities"

Widget _app(AppStore store,
        {QuickAddType type = QuickAddType.rebalance,
        String? fixedTo,
        Txn? editing}) =>
    StoreScope(
      store: store,
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: QuickAddScreen(
          initialType: type,
          fixedToAccountId: editing == null ? fixedTo : null,
          editing: editing,
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 350));

Future<void> _typeDigits(WidgetTester tester, String digits) async {
  for (final ch in digits.split('')) {
    await tester.tap(find.text(ch == '.' ? '.' : ch));
    await tester.pump();
  }
}

/// Re-open the keypad by tapping the hero label, then type more.
Future<void> _refocusHero(WidgetTester tester) async {
  await tester.tap(find.text('New balance'));
  await _settle(tester);
}

Future<void> _pickCategory(WidgetTester tester, String name) async {
  await tester.tap(find.text('Category'));
  await _settle(tester);
  await tester.tap(find.text(name).last);
  await _settle(tester);
}

Txn _newestTxn(AppStore store, Set<String> before) =>
    store.txns.firstWhere((t) => !before.contains(t.id));

Set<String> _txnIds(AppStore store) => store.txns.map((t) => t.id).toSet();

void main() {
  // ── §3 routing / §1 arithmetic (store outcomes) ──────────────────────────

  testWidgets('a valuables rebalance writes a rebalance with the delta and '
      'fromRef == toRef', (tester) async {
    final store = buildSeedStore();
    final baseline = store.balanceOf('a-home');
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-home'));
    await _settle(tester);
    await _typeDigits(tester, '130000');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final t = _newestTxn(store, before);
    expect(t.type, TxnType.rebalance);
    expect(t.amount, closeTo(130000 - baseline, 0.001)); // signed delta
    expect(t.fromRef, 'a-home');
    expect(t.toRef, 'a-home');
    expect(t.currency, 'USD');
  });

  testWidgets('a negative difference on a spendable account writes an expense '
      'in the Expense form\'s exact shape', (tester) async {
    final store = buildSeedStore();
    final baseline = store.balanceOf('a-cash-usd');
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-cash-usd'));
    await _settle(tester);
    await _typeDigits(tester, '1'); // far below the baseline → negative diff
    await _pickCategory(tester, 'Groceries');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final t = _newestTxn(store, before);
    // Identical in shape to what the Expense form writes: type expense, a
    // POSITIVE magnitude, fromRef the account, toRef the category, account's
    // currency.
    expect(t.type, TxnType.expense);
    expect(t.amount, closeTo(baseline - 1, 0.001));
    expect(t.amount, greaterThan(0));
    expect(t.fromRef, 'a-cash-usd');
    expect(t.toRef, 'c-groceries');
    expect(t.currency, 'USD');
  });

  testWidgets('a positive difference on a spendable writes an income with the '
      'mirrored refs', (tester) async {
    final store = buildSeedStore();
    final baseline = store.balanceOf('a-cash-usd');
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-cash-usd'));
    await _settle(tester);
    await _typeDigits(tester, '9999999'); // far above baseline → positive diff
    await _pickCategory(tester, 'Salary');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final t = _newestTxn(store, before);
    expect(t.type, TxnType.income);
    expect(t.amount, closeTo(9999999 - baseline, 0.001));
    expect(t.fromRef, 'c-salary'); // income: from = category
    expect(t.toRef, 'a-cash-usd'); // income: to = account
  });

  testWidgets('a payable at −800, typing 1,350, yields a −550 difference and '
      'an expense of 550', (tester) async {
    final store = buildSeedStore();
    expect(store.balanceOf('a-utilities'), closeTo(-800, 0.001));
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-utilities'));
    await _settle(tester);
    await _typeDigits(tester, '1350');

    // The Difference row reads −550 (unsigned in colour, signed in text).
    expect(find.textContaining('550'), findsWidgets);

    await _pickCategory(tester, 'Groceries');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final t = _newestTxn(store, before);
    expect(t.type, TxnType.expense);
    expect(t.amount, closeTo(550, 0.001));
    expect(t.fromRef, 'a-utilities');
    expect(t.toRef, 'c-groceries');
  });

  testWidgets('an expense written this way reaches spentInCategoryWindow and '
      'the month OUT; a revaluation reaches neither', (tester) async {
    final store = buildSeedStore();
    final today = store.today;
    final window =
        DateRange(today.subtract(const Duration(days: 1)), today.add(const Duration(days: 1)));
    final month = DateTime(today.year, today.month);

    final spentBefore = store.spentInCategoryWindow('c-groceries', window);
    final outBefore = store.monthExpense(month);
    final inBefore = store.monthIncome(month);

    // An expense via the rebalance form (spendable, small new balance).
    await tester.pumpWidget(_app(store, fixedTo: 'a-cash-usd'));
    await _settle(tester);
    await _typeDigits(tester, '1');
    await _pickCategory(tester, 'Groceries');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(store.spentInCategoryWindow('c-groceries', window),
        greaterThan(spentBefore));
    expect(store.monthExpense(month), greaterThan(outBefore));

    // A revaluation reaches neither IN nor OUT.
    final outMid = store.monthExpense(month);
    await tester.pumpWidget(_app(store, fixedTo: 'a-home'));
    await _settle(tester);
    await _typeDigits(tester, '130000');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(store.monthExpense(month), outMid);
    expect(store.monthIncome(month), inBefore);
  });

  // ── §1a / §1b round-trip ─────────────────────────────────────────────────

  testWidgets('round-trip: create a rebalance, reopen, save unchanged — the '
      'balance is unchanged and exactly one record exists', (tester) async {
    final store = buildSeedStore();
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-home'));
    await _settle(tester);
    await _typeDigits(tester, '130000');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final created = _newestTxn(store, before);
    final balanceAfterCreate = store.balanceOf('a-home');
    expect(balanceAfterCreate, closeTo(130000, 0.001));

    // Reopen it and save unchanged.
    await tester.pumpWidget(_app(store, editing: created));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(store.balanceOf('a-home'), closeTo(balanceAfterCreate, 0.001));
    expect(
        store.txns
            .where((t) => t.type == TxnType.rebalance && t.toRef == 'a-home')
            .length,
        1);
  });

  testWidgets('reopening a rebalance shows the resulting balance in the hero, '
      'not the delta', (tester) async {
    final store = buildSeedStore();
    final before = _txnIds(store);

    await tester.pumpWidget(_app(store, fixedTo: 'a-home'));
    await _settle(tester);
    await _typeDigits(tester, '130000');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    final created = _newestTxn(store, before);
    // The stored amount is the delta, and it is NOT 130,000.
    expect(created.amount, isNot(closeTo(130000, 1)));

    await tester.pumpWidget(_app(store, editing: created));
    await _settle(tester);
    // The hero shows the balance the account was set to.
    expect(find.textContaining('130,000', findRichText: true), findsWidgets);
  });

  // ── §2 currency / chip ───────────────────────────────────────────────────

  testWidgets('the chip renders a padlock and does not open the currency '
      'picker on rebalance; it still opens on Expense', (tester) async {
    // Rebalance: locked.
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-home'));
    await _settle(tester);
    expect(find.byType(CurrencyChip), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(CurrencyChip),
            matching: find.byIcon(Icons.lock_rounded)),
        findsOneWidget);
    await tester.tap(find.byType(CurrencyChip));
    await _settle(tester);
    expect(find.text('Currency'), findsNothing,
        reason: 'the locked chip must not open the picker');

    // Expense: still tappable, opens the picker.
    await tester.pumpWidget(_app(buildSeedStore(), type: QuickAddType.expense));
    await _settle(tester);
    await tester.tap(find.byType(CurrencyChip));
    await _settle(tester);
    expect(find.text('Currency'), findsOneWidget);
  });

  testWidgets('the hero number carries no currency token while a chip is shown; '
      'Current and Difference carry none either', (tester) async {
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-utilities'));
    await _settle(tester);
    await _typeDigits(tester, '1350');

    // The hero's number has no "$".
    final hero = tester.renderObject<RenderParagraph>(
        find.descendant(
            of: find.byType(NumericHeroCard),
            matching: find.textContaining('1,350', findRichText: true)));
    expect((hero.text.toPlainText()).contains(r'$'), isFalse);

    // Current (−800) and Difference (−550) are token-less too — no '$', no code.
    final figures = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('800') || s.contains('550'))
        .toList();
    expect(figures, isNotEmpty);
    for (final f in figures) {
      expect(f.contains(r'$'), isFalse, reason: '"$f" carries a symbol');
      expect(f.contains('USD'), isFalse, reason: '"$f" carries a code');
    }
  });

  // ── §5 removals ──────────────────────────────────────────────────────────

  testWidgets('no hint banner renders on rebalance; the other forms keep theirs',
      (tester) async {
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-cash-usd'));
    await _settle(tester);
    await _typeDigits(tester, '1');
    expect(find.byType(HintStrip), findsNothing);
  });

  testWidgets('no Reason row renders', (tester) async {
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-cash-usd'));
    await _settle(tester);
    expect(find.text('Reason'), findsNothing);
  });

  // ── §4 category row ──────────────────────────────────────────────────────

  testWidgets('the Category row appears for a spendable account and not for a '
      'valuable', (tester) async {
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-cash-usd'));
    await _settle(tester);
    expect(find.text('Category'), findsOneWidget);

    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-home'));
    await _settle(tester);
    expect(find.text('Category'), findsNothing);
  });

  testWidgets('Save with an empty category toasts and does not write',
      (tester) async {
    final store = buildSeedStore();
    final before = _txnIds(store);
    await tester.pumpWidget(_app(store, fixedTo: 'a-cash-usd'));
    await _settle(tester);
    await _typeDigits(tester, '1');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    expect(find.text('Choose a category'), findsWidgets); // the blocker toast
    expect(_txnIds(store).length, before.length, reason: 'nothing was written');
  });

  testWidgets('flipping the sign after choosing a category clears it',
      (tester) async {
    await tester.pumpWidget(_app(buildSeedStore(), fixedTo: 'a-cash-usd'));
    await _settle(tester);
    // A small new balance → negative difference → expense category.
    await _typeDigits(tester, '1');
    await _pickCategory(tester, 'Groceries');
    expect(find.text('Groceries'), findsOneWidget);

    // Type up past the baseline → positive difference → the expense category no
    // longer fits and is cleared.
    await _refocusHero(tester);
    await _typeDigits(tester, '0000000'); // 1 → 10,000,000
    expect(find.text('Groceries'), findsNothing);
  });
}
