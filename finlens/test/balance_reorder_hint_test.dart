import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/main.dart';

/// The section-header discoverability hint (§2): it shows on both section
/// headers until the first successful drop, then never again — across a
/// relaunch.
void main() {
  const hint = 'Hold an account to arrange';

  testWidgets('both section headers show the hint until it is dismissed',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = buildSeedStore();
    await tester.pumpWidget(FinLensApp(store: store));
    await tester.pumpAndSettle();

    // ASSETS and LIABILITIES both carry it on the Net-worth (All) view.
    expect(find.text(hint), findsNWidgets(2));

    // A successful drop dismisses it forever.
    store.markBalanceReorderHintDone();
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });

  testWidgets('the dismissal persists across a relaunch', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = buildSeedStore();
    first.markBalanceReorderHintDone();
    // Let the fire-and-forget setBool land in the mock store.
    await tester.pumpAndSettle();

    // A fresh launch restores the flag before the first frame (as `main` does).
    final relaunched = buildSeedStore();
    await relaunched.loadBalanceReorderHint();
    expect(relaunched.balanceReorderHintDone, isTrue);

    await tester.pumpWidget(FinLensApp(store: relaunched));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });
}
