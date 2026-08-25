import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/models/models.dart';

// flutter test hangs on the author's machine — run these yourself:
//   flutter test test/task_next_occurrence_test.dart

Task _task(
  RepeatFrequency freq,
  DateTime due, {
  Set<int> weekdays = const {},
  Set<int> daysOfMonth = const {},
}) =>
    Task(
      id: 'k',
      title: 't',
      linkedAccountId: 'a',
      expectedAmount: -10,
      dueDate: due,
      icon: Icons.repeat_rounded,
      repeats: freq,
      weekdays: weekdays,
      daysOfMonth: daysOfMonth,
    );

DateTime _d(int y, int m, int day, [int h = 9, int min = 0]) =>
    DateTime(y, m, day, h, min);

/// Walks a series [steps] times from its due date, returning every landing.
List<DateTime> _walk(Task t, int steps) {
  final out = <DateTime>[];
  var d = t.dueDate;
  for (var i = 0; i < steps; i++) {
    d = t.nextOccurrence(d);
    out.add(d);
  }
  return out;
}

void main() {
  group('weekly', () {
    test('one weekday steps 7 days and preserves time', () {
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 25), weekdays: {2});
      // 25 Aug 2026 is a Tuesday.
      expect(t.dueDate.weekday, DateTime.tuesday);
      final next = t.nextOccurrence(t.dueDate);
      expect(next, _d(2026, 9, 1)); // next Tuesday
      expect(next.hour, 9);
    });

    test('two weekdays (Tue & Thu) alternate in order', () {
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 25),
          weekdays: {DateTime.tuesday, DateTime.thursday});
      expect(_walk(t, 3), [
        _d(2026, 8, 27), // Thu
        _d(2026, 9, 1), // Tue
        _d(2026, 9, 3), // Thu
      ]);
    });

    test('all seven weekdays fire daily', () {
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 25),
          weekdays: {1, 2, 3, 4, 5, 6, 7});
      expect(_walk(t, 3), [
        _d(2026, 8, 26),
        _d(2026, 8, 27),
        _d(2026, 8, 28),
      ]);
    });

    test('a chosen weekday different from the seed moves the series to it', () {
      // Seed is Monday; chosen is Friday.
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 24),
          weekdays: {DateTime.friday});
      expect(t.dueDate.weekday, DateTime.monday);
      expect(t.nextOccurrence(t.dueDate), _d(2026, 8, 28)); // that Friday
    });

    test('empty set steps 7 days (legacy behaviour)', () {
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 25));
      expect(t.nextOccurrence(t.dueDate), _d(2026, 9, 1));
    });
  });

  group('biweekly', () {
    test('steps exactly 14 days, no drift', () {
      final t = _task(RepeatFrequency.biweekly, _d(2026, 8, 25));
      expect(_walk(t, 3), [
        _d(2026, 9, 8),
        _d(2026, 9, 22),
        _d(2026, 10, 6),
      ]);
    });
  });

  group('monthly clamps, never rolls', () {
    test('day 31 across Aug → Sep → Oct returns to the 31st', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 8, 31),
          daysOfMonth: {31});
      expect(_walk(t, 2), [
        _d(2026, 9, 30), // Sep has 30 days → clamp
        _d(2026, 10, 31), // returns to the chosen 31st
      ]);
    });

    test('never yields a 1st walking ten steps from Jan 31', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 1, 31),
          daysOfMonth: {31});
      for (final d in _walk(t, 10)) {
        expect(d.day == 1, isFalse, reason: 'drifted to the 1st at $d');
      }
    });

    test('day 30 across Jan → Feb → Mar, non-leap year', () {
      final t = _task(RepeatFrequency.monthly, _d(2027, 1, 30),
          daysOfMonth: {30});
      expect(_walk(t, 2), [
        _d(2027, 2, 28), // 2027 is not a leap year
        _d(2027, 3, 30),
      ]);
    });

    test('day 30 across Jan → Feb → Mar, leap year', () {
      final t = _task(RepeatFrequency.monthly, _d(2028, 1, 30),
          daysOfMonth: {30});
      expect(_walk(t, 2), [
        _d(2028, 2, 29), // 2028 is a leap year
        _d(2028, 3, 30),
      ]);
    });

    test('two days (1 & 15) give two occurrences a month, ascending', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 9, 1),
          daysOfMonth: {1, 15});
      expect(_walk(t, 3), [
        _d(2026, 9, 15),
        _d(2026, 10, 1),
        _d(2026, 10, 15),
      ]);
    });

    test('day 31 and day 1 both fire, ascending within the month', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 8, 1),
          daysOfMonth: {1, 31});
      expect(_walk(t, 3), [
        _d(2026, 8, 31),
        _d(2026, 9, 1),
        _d(2026, 9, 30), // Sep clamps 31 → 30
      ]);
    });

    test('empty set uses the seed day (legacy behaviour)', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 8, 22));
      expect(_walk(t, 2), [_d(2026, 9, 22), _d(2026, 10, 22)]);
    });
  });

  group('quarterly', () {
    test('seeded on 31 Jan: 31 Jan → 30 Apr → 31 Jul (clamp without a grid)',
        () {
      final t = _task(RepeatFrequency.quarterly, _d(2026, 1, 31),
          daysOfMonth: {31});
      expect(_walk(t, 2), [
        _d(2026, 4, 30),
        _d(2026, 7, 31),
      ]);
    });

    test('empty set steps 3 months on the seed day', () {
      final t = _task(RepeatFrequency.quarterly, _d(2026, 1, 15));
      expect(_walk(t, 2), [_d(2026, 4, 15), _d(2026, 7, 15)]);
    });
  });

  group('yearly', () {
    test('29 Feb: non-leap years fire on the 28th, leap years return to 29', () {
      final t = _task(RepeatFrequency.yearly, _d(2024, 2, 29),
          daysOfMonth: {29});
      expect(_walk(t, 4), [
        _d(2025, 2, 28),
        _d(2026, 2, 28),
        _d(2027, 2, 28),
        _d(2028, 2, 29), // 2028 is a leap year — returns to the 29th
      ]);
    });

    test('empty set steps 1 year on the seed day', () {
      final t = _task(RepeatFrequency.yearly, _d(2026, 6, 10));
      expect(_walk(t, 2), [_d(2027, 6, 10), _d(2028, 6, 10)]);
    });
  });

  group('none', () {
    test('returns the same date', () {
      final t = _task(RepeatFrequency.none, _d(2026, 8, 25));
      expect(t.nextOccurrence(t.dueDate), t.dueDate);
    });
  });

  group('upcomingPreview is left correct for free', () {
    test('weekly Tue & Thu previews three dates', () {
      final t = _task(RepeatFrequency.weekly, _d(2026, 8, 25),
          weekdays: {DateTime.tuesday, DateTime.thursday});
      expect(t.upcomingPreview(3), [
        _d(2026, 8, 25), // the seed itself is the first
        _d(2026, 8, 27),
        _d(2026, 9, 1),
      ]);
    });

    test('monthly 31 previews 31 Aug · 30 Sep · 31 Oct', () {
      final t = _task(RepeatFrequency.monthly, _d(2026, 8, 31),
          daysOfMonth: {31});
      expect(t.upcomingPreview(3), [
        _d(2026, 8, 31),
        _d(2026, 9, 30),
        _d(2026, 10, 31),
      ]);
    });
  });
}
