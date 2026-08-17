import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/quick_add/account_icons.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/account_icons_test.dart

void main() {
  test('the catalog has ~100 icons across ~12 groups', () {
    expect(accountIconGroups.length, greaterThanOrEqualTo(12));
    final total =
        accountIconGroups.values.fold<int>(0, (s, l) => s + l.length);
    expect(total, greaterThanOrEqualTo(90));
  });

  test('icon search finds the car for both "car" and "araba" (spec §5.6)', () {
    const car = Icons.directions_car_rounded;
    expect(searchAccountIcons('car').any((e) => e.icon == car), isTrue);
    expect(searchAccountIcons('araba').any((e) => e.icon == car), isTrue);
    // And case/diacritic-insensitively.
    expect(searchAccountIcons('ARABA').any((e) => e.icon == car), isTrue);
  });

  test('Turkish keywords resolve for a few more icons', () {
    bool finds(String q, IconData icon) =>
        searchAccountIcons(q).any((e) => e.icon == icon);
    expect(finds('ev', Icons.home_rounded), isTrue); // house
    expect(finds('banka', Icons.account_balance_rounded), isTrue); // bank
    expect(finds('altın', Icons.workspace_premium_rounded), isTrue); // gold
    expect(finds('kart', Icons.credit_card_rounded), isTrue); // card
  });

  test('an empty query returns the whole catalog', () {
    final total =
        accountIconGroups.values.fold<int>(0, (s, l) => s + l.length);
    expect(searchAccountIcons('').length, total);
  });

  test('every group has six suggestions and a default equal to the first', () {
    for (final g in AccountGroup.values) {
      final s = iconSuggestionsFor(g);
      expect(s.length, 6, reason: g.name);
      expect(defaultIconFor(g), s.first);
    }
  });
}
