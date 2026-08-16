import 'formatters.dart';

/// A closed date range plus the label rules the ledger's period strip uses.
class DateRange {
  const DateRange(this.start, this.end, {this.preset});

  final DateTime start;
  final DateTime end;

  /// Null for a custom range.
  final RangePreset? preset;

  int get days => end.difference(start).inDays + 1;

  DateRange copyShifted(int steps) {
    switch (preset) {
      case RangePreset.thisWeek:
      case RangePreset.lastWeek:
        final d = Duration(days: 7 * steps);
        return DateRange(start.add(d), end.add(d), preset: preset);
      case RangePreset.thisMonth:
      case RangePreset.lastMonth:
        return DateRange(
          DateTime(start.year, start.month + steps, 1),
          _endOfMonth(DateTime(start.year, start.month + steps)),
          preset: preset,
        );
      case RangePreset.last3Months:
        return DateRange(
          DateTime(start.year, start.month + steps, start.day),
          DateTime(end.year, end.month + steps, end.day),
          preset: preset,
        );
      case RangePreset.thisYear:
        return DateRange(
          DateTime(start.year + steps, 1, 1),
          DateTime(end.year + steps, end.month, end.day),
          preset: preset,
        );
      case RangePreset.allTime:
        return this;
      case null:
        // A custom range shifts as a whole window of the same width.
        final d = Duration(days: days * steps);
        return DateRange(start.add(d), end.add(d));
    }
  }

  /// Compression rules, in order:
  ///  1. drop the repeated month when both ends share one — `4–12 Aug`;
  ///  2. drop the year while the range sits inside the current year;
  ///  3. All time reads `Since Mar 2023` — month and year only.
  String label(DateTime today, {DateTime? firstEver}) {
    if (preset == RangePreset.allTime) {
      final from = firstEver ?? start;
      return 'Since ${monthShort(from.month)} ${from.year}';
    }

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final sameMonth = start.year == end.year && start.month == end.month;
    final inThisYear = start.year == today.year && end.year == today.year;

    String tail(DateTime d) =>
        inThisYear ? monthShort(d.month) : '${monthShort(d.month)} ${d.year}';

    if (sameDay) return '${start.day} ${tail(start)}';
    if (sameMonth) return '${start.day}–${end.day} ${tail(end)}';
    return '${start.day} ${tail(start)} – ${end.day} ${tail(end)}';
  }
}

enum RangePreset {
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  thisYear('This year'),
  allTime('All time');

  const RangePreset(this.label);

  final String label;

  DateRange resolve(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    switch (this) {
      case RangePreset.thisWeek:
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return DateRange(monday, monday.add(const Duration(days: 6)),
            preset: this);
      case RangePreset.lastWeek:
        final monday = day
            .subtract(Duration(days: day.weekday - 1))
            .subtract(const Duration(days: 7));
        return DateRange(monday, monday.add(const Duration(days: 6)),
            preset: this);
      case RangePreset.thisMonth:
        return DateRange(
          DateTime(day.year, day.month, 1),
          _endOfMonth(day),
          preset: this,
        );
      case RangePreset.lastMonth:
        final prev = DateTime(day.year, day.month - 1);
        return DateRange(prev, _endOfMonth(prev), preset: this);
      case RangePreset.last3Months:
        return DateRange(
          DateTime(day.year, day.month - 2, 1),
          _endOfMonth(day),
          preset: this,
        );
      case RangePreset.thisYear:
        return DateRange(DateTime(day.year, 1, 1), day, preset: this);
      case RangePreset.allTime:
        return DateRange(DateTime(2000), day, preset: this);
    }
  }
}

DateTime _endOfMonth(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);
