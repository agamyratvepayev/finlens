import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/core/utils/formatters.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/features/balance/widgets/account_rows.dart';
import 'package:finlens/main.dart';
import 'package:finlens/theme/app_colors.dart';

/// Covers the Balance resolution redesign: the share moved into the subtitle,
/// the bar's duplicate label row is gone, the section headers carry coloured
/// totals, the tool row shows a counter, and the rows are denser.
void main() {
  // setBalanceFilter persists through SharedPreferences; the in-memory mock
  // lets that fire-and-forget write succeed silently under test.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  void size390(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder counter(String text) => find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      );

  testWidgets('the group subtitle carries "N accounts · P%" in one block',
      (tester) async {
    size390(tester);
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.pumpAndSettle();

    // Spendable is expanded on load; its share is 10.0% of assets, and the
    // count and share now share the one subtitle line.
    expect(find.text('4 accounts · 10.0%'), findsOneWidget);
    // The share is gone as a standalone token — it only exists in the subtitle.
    expect(find.text('10.0%'), findsNothing);
  });

  testWidgets('the filtered subtitle shows the recomputed count and share',
      (tester) async {
    size390(tester);
    final store = buildSeedStore();
    store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.valuables));

    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Investments jumps to 65.1% against the filtered section total; the count
    // (5) rides the same line.
    expect(find.text('5 accounts · 65.1%'), findsOneWidget);
  });

  testWidgets('the bar label row is gone and the total prints once, in colour',
      (tester) async {
    size390(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // The old ratio caption ("Assets $…" / "Liabilities $…") no longer exists.
    expect(find.text('Assets '), findsNothing);
    expect(find.text('Liabilities '), findsNothing);

    // The assets total prints exactly once — only on the ASSETS header — and
    // is green.
    final assets = find.text(r'$223,305');
    expect(assets, findsOneWidget);
    expect(tester.widget<Text>(assets).style!.color, AppColors.positive);

    // The liabilities total (computed from the store so the figure never goes
    // stale here) is red on its header.
    final liabStr =
        money(store.balanceFilter.sectionTotal(store, assets: false).abs());
    final liabs = find.text(liabStr);
    expect(liabs, findsOneWidget);
    expect(tester.widget<Text>(liabs).style!.color, AppColors.negative);
  });

  testWidgets('the counter reads visible items and switches to the "of" form',
      (tester) async {
    size390(tester);
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Nothing hidden: both halves stay short.
    expect(counter('7 groups · 24 accounts'), findsOneWidget);

    // Hide six accounts across four groups, emptying none: only the accounts
    // half switches to the "of" form.
    final hidden = <String>{
      store.accountsIn(AccountGroup.spendable).first.id,
      store.accountsIn(AccountGroup.receivables).first.id,
      ...store.accountsIn(AccountGroup.investments).take(2).map((a) => a.id),
      ...store.accountsIn(AccountGroup.valuables).take(2).map((a) => a.id),
    };
    expect(hidden.length, 6);
    store.setBalanceFilter(BalanceFilter(hiddenAccountIds: hidden));
    await tester.pumpAndSettle();

    expect(counter('7 groups · 18 of 24 accounts'), findsOneWidget);
  });

  testWidgets('group rows are ~44pt and account rows ~32pt', (tester) async {
    size390(tester);
    await tester.pumpWidget(FinLensApp(store: buildSeedStore()));
    await tester.pumpAndSettle();

    // Group rows dropped from ~56pt to ~45pt; the 44pt tap floor still holds.
    final groupH = tester.getSize(find.byType(GroupRow).first).height;
    expect(groupH, greaterThan(42));
    expect(groupH, lessThan(50));

    // Account (child) rows sit ~27pt — dense secondary drill rows, well under
    // the group floor by design (they carry a single line).
    final accountH = tester.getSize(find.byType(AccountRow).first).height;
    expect(accountH, greaterThan(24));
    expect(accountH, lessThan(34));
  });
}
