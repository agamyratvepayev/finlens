import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/features/planner/widgets/percent_input_formatter.dart';

/// Task 22, spec §1b + §6 (the guard) — the custom warn-threshold field is
/// bound to 1–100, digits only. The bound is load-bearing: the warning only
/// fires while a budget is *not* yet over, so >100% could never fire and 0%
/// would fire the instant a budget exists.
///
/// A keystroke that would leave the range is *refused*, not clamped: type `120`
/// and the field still reads `12`. These pin exactly that.

/// One edit: propose [newText] over [oldText], return what the field keeps and
/// how many keystrokes were refused.
({String text, int rejects}) _apply(String oldText, String newText) {
  var rejects = 0;
  final f = PercentInputFormatter(() => rejects++);
  final res = f.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    ),
  );
  return (text: res.text, rejects: rejects);
}

/// Type [chars] one character at a time from empty, digit by digit.
({String text, int rejects}) _type(String chars) {
  var rejects = 0;
  final f = PercentInputFormatter(() => rejects++);
  var value = TextEditingValue.empty;
  for (final ch in chars.split('')) {
    final proposed = value.text + ch;
    value = f.formatEditUpdate(
      value,
      TextEditingValue(
        text: proposed,
        selection: TextSelection.collapsed(offset: proposed.length),
      ),
    );
  }
  return (text: value.text, rejects: rejects);
}

void main() {
  group('PercentInputFormatter accepts in-range digits', () {
    test('1', () {
      final r = _apply('', '1');
      expect(r.text, '1');
      expect(r.rejects, 0);
    });
    test('73', () {
      final r = _apply('7', '73');
      expect(r.text, '73');
      expect(r.rejects, 0);
    });
    test('100 — the ceiling is in range', () {
      final r = _apply('10', '100');
      expect(r.text, '100');
      expect(r.rejects, 0);
    });
  });

  group('PercentInputFormatter refuses out-of-range or non-digit', () {
    test('0 alone is refused — it would warn the instant a budget exists', () {
      final r = _apply('', '0');
      expect(r.text, '');
      expect(r.rejects, 1);
    });
    test('101 is refused', () {
      final r = _apply('10', '101');
      expect(r.text, '10');
      expect(r.rejects, 1);
    });
    test('120 is refused, not clamped to 100', () {
      final r = _apply('12', '120');
      expect(r.text, '12'); // never rewritten to 100
      expect(r.rejects, 1);
    });
    test('1.5 — a decimal point is refused', () {
      final r = _apply('1', '1.5');
      expect(r.text, '1');
      expect(r.rejects, 1);
    });
    test('-5 — a sign is refused', () {
      final r = _apply('', '-5');
      expect(r.text, '');
      expect(r.rejects, 1);
    });
  });

  test('typing 1, 2, 0 leaves the field reading 12 with one refusal (spec §4)',
      () {
    final r = _type('120');
    expect(r.text, '12');
    expect(r.rejects, 1);
  });

  test('clearing the field is always allowed', () {
    final r = _apply('73', '');
    expect(r.text, '');
    expect(r.rejects, 0);
  });
}
