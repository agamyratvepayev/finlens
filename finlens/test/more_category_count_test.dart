import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/data/seed_data.dart';
import 'package:finlens/core/models/models.dart';

/// The §2 defect written as an assertion (more-screen-settings spec §11):
/// the More screen's Categories count must equal what the pickers would list
/// across BOTH types — never the expense-only slice the old picker exposed.
///
/// Note: `flutter test` hangs on the dev machine; written but not run there.
void main() {
  test('categoryCount equals expense + income categories', () {
    final store = buildSeedStore();

    final expense = store.categoriesOfType(CategoryType.expense).length;
    final income = store.categoriesOfType(CategoryType.income).length;

    // The count the split row shows.
    expect(store.categoryCount, expense + income);
    // And it is exactly the public (archived-excluded) list's length.
    expect(store.categoryCount, store.categories.length);
  });

  test('the expense-only picker under-counts — the old subtitle bug', () {
    final store = buildSeedStore();
    // The picker is pinned to expense, so it lists fewer than the true total
    // whenever income categories exist. That gap is the defect §2 names.
    expect(
      store.categoriesOfType(CategoryType.expense).length,
      lessThan(store.categoryCount),
    );
  });
}
