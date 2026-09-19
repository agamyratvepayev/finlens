import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/core/utils/date_entry.dart';
import 'package:finlens/shared/widgets/typed_date_field.dart';

/// Task 25 — the typed `dd.mm.yyyy` field.
///
/// Pure logic only ([DateEntry]) plus the [DateTextInputFormatter] adapter,
/// which is exercised over raw [TextEditingValue] pairs and needs no widget, so
/// it runs under the plain unit harness (the widget test runner hangs here).
///
/// Before this task there was no typed field at all: the goal editor opened
/// Flutter's stock `showDatePicker`, whose `parseCompactDate` needs the user to
/// type the separators, so `01042027` never parsed. These tests would not even
/// compile against that state — the fix is the field they exercise.
void main() {
  // ── §1b · the keystroke sequence, checked at every intermediate step ───────
  group('DateEntry.typeDigit sequence', () {
    test('0,1,0,4,2,0,2,7 formats itself at every step', () {
      // The exact case that failed in the goal editor.
      const keys = ['0', '1', '0', '4', '2', '0', '2', '7'];
      const expected = [
        '0',
        '01.',
        '01.0',
        '01.04.',
        '01.04.2',
        '01.04.20',
        '01.04.202',
        '01.04.2027',
      ];
      var entry = DateEntry.empty;
      for (var i = 0; i < keys.length; i++) {
        entry = entry.typeDigit(keys[i]);
        expect(entry.text, expected[i], reason: 'after key ${i + 1}');
      }
      expect(
        entry.dateWithin(DateTime(2020), DateTime(2040)),
        DateTime(2027, 4, 1),
      );
    });

    test('a first digit of 4–9 becomes the whole day at once', () {
      expect(DateEntry.empty.typeDigit('4').text, '04.');
      expect(DateEntry.empty.typeDigit('9').text, '09.');
    });

    test('0 and 1 stay ambiguous and wait', () {
      expect(DateEntry.empty.typeDigit('1').text, '1');
      expect(DateEntry.empty.typeDigit('0').text, '0');
    });

    test('a first month digit of 2–9 becomes the whole month', () {
      expect(DateEntry('01').typeDigit('5').text, '01.05.');
      expect(DateEntry('01').typeDigit('2').text, '01.02.');
    });

    test('0 and 1 stay ambiguous in the month position', () {
      expect(DateEntry('01').typeDigit('0').text, '01.0');
      expect(DateEntry('01').typeDigit('1').text, '01.1');
    });

    test('a typed . or / is a no-op', () {
      expect(DateEntry('01').typeDigit('.'), DateEntry('01'));
      expect(DateEntry('01').typeDigit('/'), DateEntry('01'));
      expect(DateEntry.empty.typeDigit('.'), DateEntry.empty);
    });

    test('never grows past eight digits', () {
      final full = DateEntry('01042027');
      expect(full.typeDigit('9'), full);
    });
  });

  // ── §1c · deleting ─────────────────────────────────────────────────────────
  group('DateEntry.backspace', () {
    test('from 01. yields 0 in one press', () {
      expect(DateEntry('01').backspace(), DateEntry('0'));
      expect(DateEntry('01').backspace().text, '0');
    });

    test('crossing an auto-inserted dot removes the digit before it', () {
      // "01.04." -> one press -> "01.0"
      expect(DateEntry('0104').backspace().text, '01.0');
    });

    test('empty stays empty', () {
      expect(DateEntry.empty.backspace(), DateEntry.empty);
    });
  });

  // ── §1f · pasting ──────────────────────────────────────────────────────────
  group('DateEntry.paste', () {
    test('strips non-digits, caps at eight, no clever separators', () {
      // "1/4/2027" -> digits "142027" -> "14.20.27" (which validation refuses).
      expect(DateEntry.paste('1/4/2027').text, '14.20.27');
      expect(DateEntry.paste('0104202799').text, '01.04.2027');
    });
  });

  // ── §1e · validation, in order ─────────────────────────────────────────────
  group('DateEntry.validate', () {
    final wideFirst = DateTime(2000);
    final wideLast = DateTime(2040);

    test('nothing is judged until eight digits are in', () {
      expect(
        DateEntry('0104202').validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.incomplete,
      );
    });

    test('31.02.2027 is not a real date', () {
      expect(
        DateEntry(
          '31022027',
        ).validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.notReal,
      );
    });

    test('29.02.2028 is accepted — 2028 is a leap year', () {
      expect(
        DateEntry(
          '29022028',
        ).validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.ok,
      );
    });

    test('29.02.2027 is refused — 2027 is not a leap year', () {
      expect(
        DateEntry(
          '29022027',
        ).validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.notReal,
      );
    });

    test('00 and month 13 are not real', () {
      expect(
        DateEntry(
          '00042027',
        ).validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.notReal,
      );
      expect(
        DateEntry(
          '01132027',
        ).validate(firstDate: wideFirst, lastDate: wideLast),
        DateEntryError.notReal,
      );
    });

    // One day outside each of the five screens' bounds fails with the RANGE
    // message, not the calendar one (§4, §5).
    test('a real date one day outside each bound is out of range', () {
      final bounds = <String, List<DateTime>>{
        'goal': [DateTime(2026, 9, 19), DateTime(2040)],
        'task': [DateTime(2024), DateTime(2035)],
        'markPaid': [DateTime(2024), DateTime(2035)],
        'history': [DateTime(2024), DateTime(2026, 9, 19)],
        'opening': [DateTime(2015), DateTime(2026, 9, 19)],
      };
      for (final entry in bounds.entries) {
        final first = entry.value[0], last = entry.value[1];
        final dayBefore = first.subtract(const Duration(days: 1));
        final dayAfter = last.add(const Duration(days: 1));
        expect(
          DateEntry.fromDate(
            dayBefore,
          ).validate(firstDate: first, lastDate: last),
          DateEntryError.outOfRange,
          reason: '${entry.key}: day before firstDate',
        );
        expect(
          DateEntry.fromDate(
            dayAfter,
          ).validate(firstDate: first, lastDate: last),
          DateEntryError.outOfRange,
          reason: '${entry.key}: day after lastDate',
        );
        // The bounds themselves are inclusive.
        expect(
          DateEntry.fromDate(first).validate(firstDate: first, lastDate: last),
          DateEntryError.ok,
          reason: '${entry.key}: firstDate itself',
        );
      }
    });
  });

  // ── the input formatter adapter (framework edits → DateEntry ops) ──────────
  group('DateTextInputFormatter', () {
    const f = DateTextInputFormatter();

    TextEditingValue v(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    String type(String oldText, String typed) =>
        f.formatEditUpdate(v(oldText), v(oldText + typed)).text;

    test('typing a digit auto-inserts separators', () {
      expect(type('', '0'), '0');
      expect(type('0', '1'), '01.');
      expect(type('01.', '0'), '01.0');
      expect(type('01.0', '4'), '01.04.');
    });

    test('typing 4 first jumps to 04.', () {
      expect(type('', '4'), '04.');
    });

    test('a typed . or / is swallowed, never doubled', () {
      expect(type('01.', '.'), '01.');
      expect(type('01.', '/'), '01.');
    });

    test('backspacing an auto dot removes it and the digit in one press', () {
      // Delete the trailing "." of "01." -> the framework hands us "01".
      final r = f.formatEditUpdate(v('01.'), v('01'));
      expect(r.text, '0');
      // The caret is always at the end (§1d).
      expect(r.selection, TextSelection.collapsed(offset: 1));
    });

    test('backspacing a bare digit just drops it', () {
      // "01.0" -> delete "0" -> framework "01." -> stays "01."
      expect(f.formatEditUpdate(v('01.0'), v('01.')).text, '01.');
    });

    test('pasting keeps digits only, capped at eight', () {
      expect(f.formatEditUpdate(v(''), v('1/4/2027')).text, '14.20.27');
    });

    test('the caret is pinned to the end', () {
      final r = f.formatEditUpdate(v('0'), v('01'));
      expect(r.selection, TextSelection.collapsed(offset: r.text.length));
    });
  });
}
