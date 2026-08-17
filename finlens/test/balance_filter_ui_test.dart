import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/balance/balance_filter.dart';
import 'package:finlens/main.dart';

/// Widget-level coverage for the Balance filter: the pure logic is tested in
/// balance_filter_test.dart; here we prove the screen actually reflects it.
void main() {
  // setBalanceFilter persists through SharedPreferences; the in-memory mock
  // lets that fire-and-forget write succeed silently under test.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('hiding Valuables moves Net Worth and recomputes percentages',
      (tester) async {
    final store = buildSeedStore();
    store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.valuables));

    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // Net Worth drops from $193,635 to $43,635.
    expect(find.text('\$43,635'), findsWidgets);

    // The hidden group is absent from the tree, not merely collapsed.
    expect(find.text('Valuables'), findsNothing);

    // Percentages recompute against the *filtered* section total:
    // Investments jumps 21.4% → 65.1%.
    expect(find.text('30.6%'), findsOneWidget); // Spendable
    expect(find.text('4.4%'), findsOneWidget); // Receivables
    expect(find.text('65.1%'), findsOneWidget); // Investments
  });

  testWidgets('filter button announces its active state to screen readers',
      (tester) async {
    final store = buildSeedStore();
    store.setBalanceFilter(
        const BalanceFilter().toggleGroup(store, AccountGroup.valuables));

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.bySemanticsLabel('Filter categories'));
    // The glyph is the only visual cue, so the semantics value must carry it.
    expect(node.value, contains('Active'));
    expect(node.value, contains('hidden'));

    handle.dispose();
  });

  testWidgets('with nothing hidden the screen shows the true Net Worth',
      (tester) async {
    final store = buildSeedStore();

    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('\$193,635'), findsWidgets);
    expect(find.text('Valuables'), findsWidgets);
  });
}
