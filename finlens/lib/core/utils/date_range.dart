import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
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
        // A whole 3-month block: steps move the block by three months, not one
        // (1 Jun–31 Aug → 1 Mar–31 May).
        final ns = DateTime(start.year, start.month + 3 * steps, 1);
        return DateRange(
          ns,
          _endOfMonth(DateTime(ns.year, ns.month + 2)),
          preset: preset,
        );
      case RangePreset.thisYear:
        // Whole years, never clamped to today.
        final y = start.year + steps;
        return DateRange(
          DateTime(y, 1, 1),
          _endOfDay(DateTime(y, 12, 31)),
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
  String label(DateTime today, AppLocalizations l, {DateTime? firstEver}) {
    if (preset == RangePreset.allTime) {
      final from = firstEver ?? start;
      return l.rangeSince('${monthShort(from.month, l)} ${from.year}');
    }

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final sameMonth = start.year == end.year && start.month == end.month;
    final inThisYear = start.year == today.year && end.year == today.year;

    String tail(DateTime d) => inThisYear
        ? monthShort(d.month, l)
        : '${monthShort(d.month, l)} ${d.year}';

    if (sameDay) return '${start.day} ${tail(start)}';
    if (sameMonth) return '${start.day}–${end.day} ${tail(end)}';
    return '${start.day} ${tail(start)} – ${end.day} ${tail(end)}';
  }
}

/// Labels localized — see `RangePresetL10n.label` in `core/l10n/enum_labels.dart`.
enum RangePreset {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  allTime;

  DateRange resolve(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    switch (this) {
      case RangePreset.thisWeek:
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return DateRange(
            monday, _endOfDay(monday.add(const Duration(days: 6))),
            preset: this);
      case RangePreset.lastWeek:
        final monday = day
            .subtract(Duration(days: day.weekday - 1))
            .subtract(const Duration(days: 7));
        return DateRange(
            monday, _endOfDay(monday.add(const Duration(days: 6))),
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
        // Whole year — 1 Jan – 31 Dec — not clamped to today.
        return DateRange(
          DateTime(day.year, 1, 1),
          _endOfDay(DateTime(day.year, 12, 31)),
          preset: this,
        );
      case RangePreset.allTime:
        return DateRange(DateTime(2000), day, preset: this);
    }
  }
}

/// The seven range presets in the app's canonical display order — the single
/// list both the calendar-shaped range picker (Insight) and the scoped ledger's
/// preset-only sheet read, so the two can never disagree about what "Last 3
/// months" means or where "All time" sits (spec §1.4). The two sheets stay
/// separate widgets; only this list is shared.
const rangePresetOrder = <RangePreset>[
  RangePreset.thisMonth,
  RangePreset.lastMonth,
  RangePreset.thisWeek,
  RangePreset.lastWeek,
  RangePreset.last3Months,
  RangePreset.thisYear,
  RangePreset.allTime,
];

/// The unit `‹` / `›` steps by. A preset belongs to exactly one unit; [allTime]
/// has none. Only the unit is persisted per screen — the cursor always resets
/// to the period containing today on launch.
enum PeriodUnit { week, month, quarter, year }

extension RangePresetUnit on RangePreset {
  PeriodUnit? get unit => switch (this) {
        RangePreset.thisWeek || RangePreset.lastWeek => PeriodUnit.week,
        RangePreset.thisMonth || RangePreset.lastMonth => PeriodUnit.month,
        RangePreset.last3Months => PeriodUnit.quarter,
        RangePreset.thisYear => PeriodUnit.year,
        RangePreset.allTime => null,
      };
}

/// The "current period" preset for a unit — the launch landing spot, cursor on
/// the period containing today.
RangePreset currentPresetFor(PeriodUnit unit) => switch (unit) {
      PeriodUnit.week => RangePreset.thisWeek,
      PeriodUnit.month => RangePreset.thisMonth,
      PeriodUnit.quarter => RangePreset.last3Months,
      PeriodUnit.year => RangePreset.thisYear,
    };

Future<void> savePeriodUnit(String key, PeriodUnit unit) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, unit.name);
}

Future<PeriodUnit> loadPeriodUnit(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(key);
  for (final u in PeriodUnit.values) {
    if (u.name == raw) return u;
  }
  return PeriodUnit.month;
}

/// Persist a [DateRange] chosen from the shared range-picker sheet. A preset
/// range is stored as its **preset name** so `This month` re-resolves against a
/// later today (never freezing into a stale window); a custom range is stored as
/// its two dates. Mirrors `SameRangeChoice`'s shape (spec Part B §B3).
Future<void> saveScheduleCompletedRange(String key, DateRange range) async {
  final prefs = await SharedPreferences.getInstance();
  final json = range.preset != null
      ? {'preset': range.preset!.name}
      : {
          'from': range.start.toIso8601String(),
          'to': range.end.toIso8601String(),
        };
  await prefs.setString(key, jsonEncode(json));
}

/// Restore what [saveScheduleCompletedRange] wrote, re-resolving a preset
/// against [today]. Returns null when nothing is stored or the value is corrupt,
/// so the caller keeps its default.
Future<DateRange?> loadScheduleCompletedRange(String key, DateTime today) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is Map) {
      final from = json['from'], to = json['to'];
      if (from is String && to is String) {
        final start = DateTime.tryParse(from), end = DateTime.tryParse(to);
        if (start != null && end != null) return DateRange(start, end);
      }
      final presetName = json['preset'];
      for (final p in RangePreset.values) {
        if (p.name == presetName) return p.resolve(today);
      }
    }
  } on FormatException {
    // Corrupt preference: fall back to the default.
  }
  return null;
}

DateTime _endOfMonth(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
