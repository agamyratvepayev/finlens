import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finlens/core/data/seed_data.dart';

// The descriptions toggle is a lasting view preference (spec §3): it persists
// through SharedPreferences and is restored before first paint, unlike the
// filter/search lens.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to off when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final store = buildSeedStore();
    await store.loadLedgerPrefs();
    expect(store.ledgerShowDescriptions, isFalse);
  });

  test('the choice survives a store re-init (persist → reload)', () async {
    SharedPreferences.setMockInitialValues({});
    final first = buildSeedStore();
    await first.loadLedgerPrefs();
    first.setLedgerShowDescriptions(true);
    // The write is fire-and-forget; let the mock's microtask settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final second = buildSeedStore();
    await second.loadLedgerPrefs();
    expect(second.ledgerShowDescriptions, isTrue);
  });

  test('restores a stored true before first paint', () async {
    SharedPreferences.setMockInitialValues({'ledger_show_descriptions': true});
    final store = buildSeedStore();
    await store.loadLedgerPrefs();
    expect(store.ledgerShowDescriptions, isTrue);
  });
}
