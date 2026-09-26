import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Task 061 §5 — the guard: `Enter amount` cannot come back.
///
/// An empty amount field shows a dim 0 in its currency — a zero in a unit,
/// never a sentence. The ARB key `emptyEnterAmount` deliberately stays in all
/// four locales (task 061 non-goal), but nothing in `lib/` may read it, and no
/// literal may reintroduce the sentence.
void main() {
  Iterable<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      // The generated localizations legitimately carry the key and its string.
      .where((f) => !f.path.replaceAll('\\', '/').startsWith('lib/l10n/'));

  /// Every (file, line-number, line) triple in lib/ (minus l10n) whose line
  /// contains [needle].
  List<String> occurrences(String needle) {
    final hits = <String>[];
    for (final f in libDartFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(needle)) {
          hits.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    return hits;
  }

  test('no reader of emptyEnterAmount remains in lib/', () {
    expect(occurrences('emptyEnterAmount'), isEmpty,
        reason: 'An empty amount reads 0 in its currency (task 061). '
            'Do not use a sentence.');
  });

  test("no string literal equals 'Enter amount' in lib/", () {
    final literal = [...occurrences("'Enter amount'"), ...occurrences('"Enter amount"')];
    expect(literal, isEmpty,
        reason: 'An empty amount reads 0 in its currency (task 061). '
            'Do not use a sentence.');
  });
}
