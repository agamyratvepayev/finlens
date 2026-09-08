import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locale parity for the four ARB files.
///
/// The non-English files were already short of `en` before this change; that
/// gap is pinned, not fixed here, so a *new* key that lands in one file and not
/// the others fails immediately instead of shipping as a silent English
/// fallback.
void main() {
  Map<String, dynamic> arb(String locale) => (jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map).cast<String, dynamic>();

  Set<String> keys(String locale) =>
      arb(locale).keys.where((k) => !k.startsWith('@')).toSet();

  test('every key this change touches exists in all four locales', () {
    const touched = [
      'ldgFirstRunHintA11y',
      'insEmptyNoAccountsBody',
      'insA11yEmptyNoAccounts',
      'ldgFirstRunHint',
    ];
    for (final locale in ['en', 'ru', 'tr', 'tk']) {
      final k = keys(locale);
      for (final key in touched) {
        expect(k, contains(key), reason: '$key missing from $locale');
      }
    }
  });

  test('the retired keys are gone from all four locales', () {
    for (final locale in ['en', 'ru', 'tr', 'tk']) {
      final k = keys(locale);
      for (final key in [
        'insStartInBalance',
        'insStartInLedger',
        'balAddAccount',
      ]) {
        expect(k, isNot(contains(key)), reason: '$key still in $locale');
      }
    }
  });

  test('the pre-existing shortfall is unchanged at 35 keys per locale', () {
    final en = keys('en');
    for (final locale in ['ru', 'tr', 'tk']) {
      expect(en.difference(keys(locale)).length, 35,
          reason: '$locale drifted from the pinned pre-existing gap');
    }
  });

  test('no locale carries a key en does not', () {
    final en = keys('en');
    for (final locale in ['ru', 'tr', 'tk']) {
      expect(keys(locale).difference(en), isEmpty);
    }
  });
}
