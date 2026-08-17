import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/utils/search_fold.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/search_fold_test.dart

void main() {
  group('foldSearch — Turkish case/diacritic folding (spec §3)', () {
    test('İ, ı, I all collapse to i', () {
      expect(foldSearch('İstanbul'), 'istanbul');
      expect(foldSearch('istanbul'), 'istanbul');
      expect(foldSearch('İ'), 'i');
      expect(foldSearch('ı'), 'i');
      expect(foldSearch('I'), 'i');
    });

    test('searching İstanbul matches istanbul', () {
      expect(foldSearch('İstanbul').contains(foldSearch('istanbul')), isTrue);
    });

    test('searching sise matches şişe', () {
      expect(foldSearch('şişe').contains(foldSearch('sise')), isTrue);
    });

    test('Ş, ğ, Ö, Ü, Ç fold to their ASCII base', () {
      expect(foldSearch('Şşubat'), 'ssubat');
      expect(foldSearch('ağustos'), 'agustos');
      expect(foldSearch('Öö'), 'oo');
      expect(foldSearch('Üü'), 'uu');
      expect(foldSearch('Çç'), 'cc');
    });

    test('length is preserved so folded offsets slice the original', () {
      for (final s in const [
        'İstanbul',
        'Ağustos kirası',
        'Şubat faturası',
        'Yıllık sigorta ödemesi',
      ]) {
        expect(foldSearch(s).length, s.length, reason: s);
      }
      const original = 'Ağustos kirası';
      final at = foldSearch(original).indexOf(foldSearch('kira'));
      expect(at, greaterThanOrEqualTo(0));
      expect(original.substring(at, at + 4), 'kira');
    });

    test('amount digits are searchable (120 finds a 120-dollar row)', () {
      final haystack = foldSearch('Groceries 120.00 120');
      expect(haystack.contains(foldSearch('120')), isTrue);
    });
  });
}
