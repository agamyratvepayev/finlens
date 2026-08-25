/// Currency + date formatting.
///
/// Money rendering stays hand-rolled (no intl) so it matches the mockups
/// exactly: grouped thousands, sign in front of the symbol ("−$31,200"), and a
/// true minus glyph rather than a hyphen. Date labels, by contrast, ARE
/// locale-aware: the month/weekday names and relative words come from the ARB
/// catalog, so every date formatter takes an [AppLocalizations]. The layout
/// (day-then-month order, the compression rules) is kept here rather than
/// delegated to intl's DateFormat — partly to preserve the exact mockup styling,
/// partly because intl ships no Turkmen date symbols.
library;

import '../../l10n/app_localizations.dart';

const _symbols = <String, String>{
  'USD': r'$',
  'EUR': '€',
  'TRY': '₺',
  'TMT': 'm', // Turkmen manat
  'GBP': '£',
  'JPY': '¥',
};

const _minus = '−';

String currencySymbol(String code) => _symbols[code] ?? '$code ';

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Formats money the way the design does. Decimals are dropped when the value
/// is whole ($14,500) and kept otherwise ($15.99).
String money(
  double value, {
  String currency = 'USD',
  bool showSign = false,
  bool forceDecimals = false,
  bool masked = false,
  bool signless = false,
}) {
  final symbol = currencySymbol(currency);
  if (masked) return '$symbol••••';

  final negative = value < 0;
  final abs = value.abs();

  // The mockups print cents only on small, precise amounts ($15.99) and keep
  // headline figures whole ($185,700) — anything from 1,000 up is rounded, so
  // FX conversion never leaves a stray ".70" on a net-worth total.
  final fractional = (abs - abs.truncateToDouble()).abs() > 0.004;
  final needsDecimals = forceDecimals || (fractional && abs < 1000);

  final rounded = needsDecimals ? abs : abs.roundToDouble();
  final whole = _group(rounded.truncate().toString());
  final text = needsDecimals
      ? '$whole.${(rounded * 100).round().remainder(100).toString().padLeft(2, '0')}'
      : whole;

  // Balances render unsigned: colour already says asset vs debt, and a leading
  // minus shifts every digit one place and breaks column alignment. Ledger
  // amounts pass signless: false, because there direction is the whole point
  // and the sign is the only cue a colourblind reader gets.
  final sign = signless ? '' : (negative ? _minus : (showSign ? '+' : ''));
  return '$sign$symbol$text';
}

/// Compact form for dense captions ("$8.4K/yr").
String moneyCompact(double value, {String currency = 'USD'}) {
  final symbol = currencySymbol(currency);
  final abs = value.abs();
  final sign = value < 0 ? _minus : '';
  if (abs >= 1000000) {
    return '$sign$symbol${(abs / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    final v = abs / 1000;
    final s = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$sign$symbol${s}K';
  }
  return '$sign$symbol${abs.toStringAsFixed(0)}';
}

String percent(double fraction, {int decimals = 1}) =>
    '${(fraction * 100).toStringAsFixed(decimals)}%';

/// Signed percentage used by the delta chips (▲ 2.4%).
String signedPercent(double fraction, {int decimals = 1}) {
  final v = (fraction * 100).abs().toStringAsFixed(decimals);
  return '$v%';
}

/// Abbreviated month name ("Aug" / "авг." / "Ağu"), sourced from the catalog.
String monthShort(int m, AppLocalizations l) => l.monthShort('$m');

/// Full month name ("August" / "Август").
String monthLong(int m, AppLocalizations l) => l.monthLong('$m');

/// Full weekday name from an ISO weekday (1 = Mon … 7 = Sun).
String weekdayLong(DateTime d, AppLocalizations l) => l.weekdayLong('${d.weekday}');

/// "9 Aug"
String dayMonth(DateTime d, AppLocalizations l) => '${d.day} ${monthShort(d.month, l)}';

/// "9 Aug 2026"
String dayMonthYear(DateTime d, AppLocalizations l) =>
    '${d.day} ${monthShort(d.month, l)} ${d.year}';

/// "Nov 2026"
String monthYear(DateTime d, AppLocalizations l) =>
    '${monthShort(d.month, l)} ${d.year}';

/// "August 2026" — Planner and Ledger period headers.
String monthYearLong(DateTime d, AppLocalizations l) =>
    '${monthLong(d.month, l)} ${d.year}';

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Today, 14:32" / "Tomorrow, 09:00" / "9 Aug, 14:32" / "9 Aug 2025, 14:32".
///
/// [now] exists because the app pins its reference date rather than reading the
/// wall clock — comparing against `DateTime.now()` made a transaction dated
/// "today" render as an absolute date whenever the two disagreed.
String dateTimeLabel(DateTime d, AppLocalizations l, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final base = DateTime(today.year, today.month, today.day);
  final delta = day.difference(base).inDays;

  // Only the three nearest days get a name; past that a relative label stops
  // being easier to read than the date itself.
  final relative = switch (delta) {
    0 => l.dateToday,
    -1 => l.dateYesterday,
    1 => l.dateTomorrow,
    _ => null,
  };
  if (relative != null) return l.dateWithTime(relative, hhmm(d));

  final sameYear = d.year == today.year;
  return sameYear
      ? l.dateWithTime(dayMonth(d, l), hhmm(d))
      : l.dateWithTime(dayMonthYear(d, l), hhmm(d));
}

/// Ledger date-group headings: "Today", "Yesterday · 8 Aug", "7 Aug".
String dateGroupLabel(DateTime d, AppLocalizations l) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.dateToday;
  if (diff == 1) return l.dateGroupYesterday(dayMonth(d, l));
  return dayMonth(d, l);
}

/// Relative due wording used by Payables and Schedule ("in 3 days").
String dueLabel(int days, AppLocalizations l) {
  if (days < 0) return l.dueDaysLate(-days);
  if (days == 0) return l.dueToday;
  if (days == 1) return l.dueTomorrow;
  return l.dueInDays(days);
}

/// Ordinal day-of-month ("5th" / "5-го" / "5."). English grammar can't be
/// expressed in an ARB `plural` (it lacks the ordinal categories and gen-l10n
/// has no `selectordinal`), so the per-locale forms live here. Turkmen/Russian
/// forms are approximate and flagged for native review.
String ordinalDay(int n, AppLocalizations l) {
  switch (l.localeName) {
    case 'ru':
      return '$n-го';
    case 'tr':
      return '$n.';
    case 'tk':
      return '$n-i';
    default:
      if (n >= 11 && n <= 13) return '${n}th';
      return switch (n % 10) {
        1 => '${n}st',
        2 => '${n}nd',
        3 => '${n}rd',
        _ => '${n}th',
      };
  }
}

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

// ── Tags ───────────────────────────────────────────────────────────────────
//
// A transaction's tag run is formatted in exactly one place so the two ledger
// rows (the Ledger-tab `TxnRow` and the scoped `LedgerTxnRow`) can never drift
// apart again — before this, one rendered `#fun +2` and the other a bare `fun`.

/// The tag run as it appears on a row's title line: [full] is every tag
/// (`#fun #weekend #split`); [collapsed] is the first tag plus an overflow
/// count (`#fun +2`). Callers pick between them by whether the full run fits.
/// Call only when [tags] is non-empty.
({String full, String collapsed}) tagRunText(List<String> tags) {
  final full = tags.map((t) => '#$t').join(' ');
  final collapsed =
      '#${tags.first}${tags.length > 1 ? ' +${tags.length - 1}' : ''}';
  return (full: full, collapsed: collapsed);
}

/// How a screen reader names a row's tags: `tag fun` for one, `tags fun,
/// weekend, split` for many. Every tag is named — the visual `+N` collapse is a
/// width truncation, and a reader has no width limit. Empty when there are no
/// tags. The `tag`/`tags` words are intentionally not localised (matching the
/// prior hard-coded `tag $tag`); a future l10n pass owns that.
String tagSemanticsLabel(List<String> tags) {
  if (tags.isEmpty) return '';
  if (tags.length == 1) return 'tag ${tags.first}';
  return 'tags ${tags.join(', ')}';
}
