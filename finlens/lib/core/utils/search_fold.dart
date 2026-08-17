/// Case- and diacritic-insensitive folding for search.
///
/// Dart's default `toLowerCase()` maps Turkish `İ` to `i` + a combining dot
/// (length 2), so `İstanbul` would not match `istanbul`. This folds locale-
/// aware and **1:1 per rune** — every character maps to exactly one character —
/// so folded offsets line up with the original string and a match can be
/// highlighted in place without re-mapping indices.
library;

// Turkish letters and a few accented Latin vowels, folded to an ASCII base.
// Both cases of the dotted/dotless i collapse to a plain `i`.
const Map<String, String> _fold = {
  'İ': 'i', 'I': 'i', 'ı': 'i', 'i': 'i',
  'Ş': 's', 'ş': 's',
  'Ğ': 'g', 'ğ': 'g',
  'Ö': 'o', 'ö': 'o',
  'Ü': 'u', 'ü': 'u',
  'Ç': 'c', 'ç': 'c',
  'Â': 'a', 'â': 'a',
  'Î': 'i', 'î': 'i',
  'Û': 'u', 'û': 'u',
};

/// Folds [input] for case/diacritic-insensitive comparison. Length in code
/// units is preserved for all BMP text (the only kind these fields carry), so
/// `foldSearch(s).indexOf(foldSearch(q))` is a valid offset into `s` itself.
String foldSearch(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = _fold[ch];
    if (mapped != null) {
      buf.write(mapped);
      continue;
    }
    final lower = ch.toLowerCase();
    // Guard the one-to-many folds (e.g. a stray İ not caught above) so offsets
    // never drift; keep the original rune rather than lengthen the string.
    buf.write(lower.length == 1 ? lower : ch);
  }
  return buf.toString();
}
