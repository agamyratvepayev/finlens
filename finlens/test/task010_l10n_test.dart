import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Task 010 — the six removed lines and their keys. These read the raw `.arb`
/// files from the package root (where `flutter test` runs) so the assertions
/// hold whether or not `app_localizations*.dart` has been regenerated.
///
/// flutter test hangs on the author's machine — run this yourself:
///   flutter test test/task010_l10n_test.dart
void main() {
  const langs = ['en', 'ru', 'tr', 'tk'];

  // Keys deleted from every ARB. (moreVersion only ever lived in en, a
  // pure-placeholder string with nothing to translate — `isNot(contains)`
  // holds trivially for the other three.)
  const deleted = [
    'ldgRestoreFromBackup',
    'moreVersion',
    'catArchiveFootnote',
    'tagArchiveFootnote',
    'arFootnote',
  ];

  Map<String, dynamic> arb(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('every deleted key (and its @-metadata) is gone from all four ARBs', () {
    for (final lang in langs) {
      final keys = arb(lang).keys;
      for (final k in deleted) {
        expect(keys, isNot(contains(k)),
            reason: '$k should be gone from app_$lang.arb');
        expect(keys, isNot(contains('@$k')),
            reason: '@$k metadata should be gone from app_$lang.arb');
      }
    }
  });

  test('qaSplitNeedsAmount survives in all four (semantics still use it)', () {
    for (final lang in langs) {
      expect(arb(lang).keys, contains('qaSplitNeedsAmount'),
          reason: 'app_$lang.arb must keep qaSplitNeedsAmount');
    }
  });

  test('tagArchiveRestoreHint is present in all four ARBs', () {
    for (final lang in langs) {
      expect(arb(lang).keys, contains('tagArchiveRestoreHint'),
          reason: 'app_$lang.arb must add tagArchiveRestoreHint');
    }
  });
}
