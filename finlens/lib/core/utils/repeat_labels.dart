import '../../l10n/app_localizations.dart';
import '../models/enums.dart';
import 'formatters.dart';

/// ISO weekdays in display order, Monday-first. No `weekStartsOn` preference
/// exists yet; when one lands, seed both the chip layout and this order from it.
const List<int> kWeekOrderMonFirst = [1, 2, 3, 4, 5, 6, 7];

/// A day-aware cadence label, e.g. "Tue & Thu", "1st & 15th",
/// "Every month on the 12th", "Weekdays", "Every day", "Every 2 weeks".
///
/// Collapse rules (a wording decision — reviewed, not buried):
///  • Weekly, all 7 days → "Every day".
///  • Weekly, exactly Mon–Fri → "Weekdays".
///  • Weekly / monthly, 4+ days → "N days a week" / "N days a month".
///  • Otherwise (1–3 days) the days are listed: weekdays as short names,
///    month-days as ordinals, joined "a & b" or "a, b & c".
///  • A single month-day reads "Every month on the 12th".
///
/// [seedDate] supplies the implied day when the relevant set is empty (existing
/// tasks and quarterly/yearly, which carry no grid).
String repeatCadenceLabel(
  RepeatFrequency freq,
  Set<int> weekdays,
  Set<int> daysOfMonth,
  DateTime seedDate,
  AppLocalizations l,
) {
  switch (freq) {
    case RepeatFrequency.none:
      return l.repeatNever;
    case RepeatFrequency.biweekly:
      return l.rsEvery2Weeks;
    case RepeatFrequency.quarterly:
      return l.rsEveryQuarter;
    case RepeatFrequency.yearly:
      return l.rsEveryYear;
    case RepeatFrequency.weekly:
      final days = (weekdays.isEmpty ? {seedDate.weekday} : weekdays).toList()
        ..sort();
      if (days.length == 7) return l.rsEveryDay;
      if (days.length == 5 && days.every((d) => d <= 5)) return l.rsWeekdays;
      if (days.length > 3) return l.rsNDaysWeek(days.length);
      return _joinList([for (final d in days) weekdayShort(d, l)], l);
    case RepeatFrequency.monthly:
      final days = (daysOfMonth.isEmpty ? {seedDate.day} : daysOfMonth).toList()
        ..sort();
      if (days.length == 1) return l.rsMonthlyOnDay(ordinalDay(days.first, l));
      if (days.length > 3) return l.rsNDaysMonth(days.length);
      return _joinList([for (final d in days) ordinalDay(d, l)], l);
  }
}

/// The row-sized cadence: the frequency alone, no day detail.
///
/// `repeatCadenceLabel` answers "when exactly" ("Every month on the 7th") and
/// belongs on a form row that owns its whole line; a task row has a date, a
/// relative label and an account to print first, so it gets the frequency word
/// and nothing else. The day detail is not lost — it lives on the Task detail
/// screen's subtitle. See the Schedule spec §4.2.
String repeatShortLabel(RepeatFrequency freq, AppLocalizations l) {
  switch (freq) {
    case RepeatFrequency.none:
      return l.repeatNever;
    case RepeatFrequency.weekly:
      return l.rsShortWeekly;
    case RepeatFrequency.biweekly:
      return l.rsShortBiweekly;
    case RepeatFrequency.monthly:
      return l.rsShortMonthly;
    case RepeatFrequency.quarterly:
      return l.rsShortQuarterly;
    case RepeatFrequency.yearly:
      return l.rsShortYearly;
  }
}

/// The Repeat button's short label — the day-aware cadence, or "Repeat" when
/// the frequency is off.
String repeatButtonLabel(
  RepeatFrequency freq,
  Set<int> weekdays,
  Set<int> daysOfMonth,
  DateTime date,
  AppLocalizations l,
) =>
    freq == RepeatFrequency.none
        ? l.rsRepeat
        : repeatCadenceLabel(freq, weekdays, daysOfMonth, date, l);

/// Joins 1–3 items as "a", "a & b" or "a, b & c" (last pair via a localized
/// conjunction; earlier items with a plain comma).
String _joinList(List<String> items, AppLocalizations l) {
  if (items.length == 1) return items.first;
  final head = items.sublist(0, items.length - 1).join(', ');
  return l.rsDaysJoin(head, items.last);
}

/// One preview date as it reads in the sheet's "Next …" line: weekly cadences
/// carry the weekday ("Tue 25 Aug"), the rest just the date ("1 Sep").
String repeatPreviewDate(DateTime d, RepeatFrequency freq, AppLocalizations l) {
  final base = dayMonth(d, l);
  final showsWeekday =
      freq == RepeatFrequency.weekly || freq == RepeatFrequency.biweekly;
  return showsWeekday ? '${weekdayShort(d.weekday, l)} $base' : base;
}

/// The full "Next  Tue 25 Aug · Thu 27 Aug · Tue 1 Sep" preview line.
String repeatPreviewLine(
  List<DateTime> dates,
  RepeatFrequency freq,
  AppLocalizations l,
) =>
    '${l.rsNext}  ${dates.map((d) => repeatPreviewDate(d, freq, l)).join(' · ')}';
