import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';
import 'package:finlens/features/quick_add/account_icons.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/account_icons_test.dart

void main() {
  final total = accountIconGroups.values.fold<int>(0, (s, l) => s + l.length);

  test('the catalog has 189 icons across 13 groups of a multiple of seven', () {
    expect(accountIconGroups.length, 13);
    expect(total, 189);
    for (final entry in accountIconGroups.entries) {
      expect(entry.value.length % 7, 0, reason: entry.key);
    }
    // Receivables & payables sits right after Cards, three full rows.
    final names = accountIconGroups.keys.toList();
    expect(names[1], 'Cards');
    expect(names[2], 'Receivables & payables');
    expect(accountIconGroups['Receivables & payables']!.length, 21);
  });

  test('no glyph appears twice and every name is unique', () {
    final all = accountIconGroups.values.expand((l) => l).toList();
    final icons = all.map((e) => e.icon).toSet();
    final names = all.map((e) => e.name).toSet();
    expect(icons.length, total);
    expect(names.length, total);
  });

  test('none of the removed look-alike glyphs is in the catalog', () {
    const removed = <IconData>[
      Icons.payment_rounded,
      Icons.redeem_rounded,
      Icons.local_grocery_store_rounded,
      Icons.account_balance_wallet_outlined,
      Icons.business_center_rounded,
      Icons.directions_car_filled_rounded,
      Icons.local_mall_rounded,
      Icons.laptop_chromebook_rounded,
      Icons.laptop_mac_rounded,
      Icons.chair_alt_rounded,
      Icons.stacked_line_chart_rounded,
    ];
    final icons =
        accountIconGroups.values.expand((l) => l).map((e) => e.icon).toSet();
    for (final r in removed) {
      expect(icons.contains(r), isFalse, reason: r.toString());
    }
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
    // altın now finds Coins (toll), not the diploma glyph.
    expect(finds('altın', Icons.toll_rounded), isTrue);
    expect(finds('altın', Icons.workspace_premium_rounded), isFalse);
    expect(finds('kart', Icons.credit_card_rounded), isTrue); // card
  });

  test('receivables & payables search finds the new icons in four languages',
      () {
    bool finds(String q, IconData icon) =>
        searchAccountIcons(q).any((e) => e.icon == icon);
    // Debt in en/ru/tk.
    for (final q in const ['borç', 'долг', 'bergi']) {
      expect(finds(q, Icons.money_off_rounded), isTrue, reason: q);
    }
    // The cross-cutting "cari" term reaches the whole receivables block.
    for (final icon in const [
      Icons.money_off_rounded,
      Icons.call_received_rounded,
      Icons.call_made_rounded,
      Icons.balance_rounded,
      Icons.business_rounded,
    ]) {
      expect(finds('cari', icon), isTrue, reason: icon.toString());
    }
    expect(finds('tedarikçi', Icons.local_shipping_rounded), isTrue);
    expect(finds('vade', Icons.event_rounded), isTrue);
  });

  test('an empty query returns the whole catalog', () {
    expect(searchAccountIcons('').length, total);
  });

  test('every catalog entry has ru/tk terms reachable through search', () {
    // The private _ruTkIconTerms map keys on the English name; we assert it
    // indirectly: searching each entry's first ru term returns that entry.
    // (This also guards against a name that lost its ru/tk row.)
    for (final e in accountIconGroups.values.expand((l) => l)) {
      final hits = searchAccountIcons(e.name);
      expect(hits.any((h) => h.icon == e.icon), isTrue, reason: e.name);
    }
    // And a spot-check that a purely-ru term (no en/tr overlap) resolves,
    // proving _ruTkIconTerms is actually folded in.
    expect(searchAccountIcons('деньги').any((e) => e.icon == Icons.attach_money_rounded),
        isTrue);
  });

  test('every group has six suggestions and a default equal to the first', () {
    for (final g in AccountGroup.values) {
      final s = iconSuggestionsFor(g);
      expect(s.length, 6, reason: g.name);
      expect(defaultIconFor(g), s.first);
    }
  });

  test('every suggestion is a catalog glyph and no group repeats one', () {
    final catalog =
        accountIconGroups.values.expand((l) => l).map((e) => e.icon).toSet();
    for (final g in AccountGroup.values) {
      final s = iconSuggestionsFor(g);
      expect(s.toSet().length, s.length, reason: '${g.name} repeats a glyph');
      for (final icon in s) {
        expect(catalog.contains(icon), isTrue,
            reason: '${g.name}: ${icon.toString()} not in catalog');
      }
    }
  });
}
