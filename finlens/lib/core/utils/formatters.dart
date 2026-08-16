/// Currency + date formatting. Kept dependency-free (no intl) so the money
/// rendering matches the mockups exactly: grouped thousands, sign in front of
/// the symbol ("−$31,200"), and a true minus glyph rather than a hyphen.
library;

const _symbols = <String, String>{
  'USD': r'$',
  'EUR': '€',
  'TRY': '₺',
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

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthShort(int m) => _months[m - 1];

/// "9 Aug"
String dayMonth(DateTime d) => '${d.day} ${monthShort(d.month)}';

/// "9 Aug 2026"
String dayMonthYear(DateTime d) => '${d.day} ${monthShort(d.month)} ${d.year}';

/// "Nov 2026"
String monthYear(DateTime d) => '${monthShort(d.month)} ${d.year}';

/// "August 2026" — Planner and Ledger period headers.
String monthYearLong(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Today, 14:32" / "Tomorrow, 09:00" / "9 Aug, 14:32" / "9 Aug 2025, 14:32".
///
/// [now] exists because the app pins its reference date rather than reading the
/// wall clock — comparing against `DateTime.now()` made a transaction dated
/// "today" render as an absolute date whenever the two disagreed.
String dateTimeLabel(DateTime d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final base = DateTime(today.year, today.month, today.day);
  final delta = day.difference(base).inDays;

  // Only the three nearest days get a name; past that a relative label stops
  // being easier to read than the date itself.
  final relative = switch (delta) {
    0 => 'Today',
    -1 => 'Yesterday',
    1 => 'Tomorrow',
    _ => null,
  };
  if (relative != null) return '$relative, ${hhmm(d)}';

  final sameYear = d.year == today.year;
  return sameYear
      ? '${dayMonth(d)}, ${hhmm(d)}'
      : '${dayMonthYear(d)}, ${hhmm(d)}';
}

/// Ledger date-group headings: "Today", "Yesterday · 8 Aug", "7 Aug".
String dateGroupLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday · ${dayMonth(d)}';
  return dayMonth(d);
}

/// Relative due wording used by Payables and Schedule ("in 3 days").
String dueLabel(int days) {
  if (days < 0) {
    final n = days.abs();
    return n == 1 ? '1 day late' : '$n days late';
  }
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

String ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
