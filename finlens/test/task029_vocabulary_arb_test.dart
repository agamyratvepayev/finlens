import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Task 029 — "One vocabulary for the Schedule".
//
// These read the ARB catalogs on disk directly, so a future translation cannot
// quietly reintroduce a retired word or break the picker↔tab correspondence
// that the whole design rests on. `flutter test` hangs on the dev machine; run
// this file yourself:
//   flutter test test/task029_vocabulary_arb_test.dart
//
// NOTE for the reviewer: before Task 029's ARB edits, the first group ("no
// retired word") is RED — every locale still carried task/görev/tabşyryk/задача.
// It is green only once the twelve strings land. The `{task}` placeholder in
// ctBlockedMsg is a placeholder NAME, not copy, and is excluded by _copyOnly
// (which strips `{identifier}` tokens) so it never trips the check.

const _locales = ['en', 'tr', 'tk', 'ru'];

Map<String, dynamic> _load(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Real (non-metadata) message strings, keyed by ARB key. Skips `@key`
/// descriptions and the `@@locale` header.
Map<String, String> _messages(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@') && e.value is String)
          e.key: e.value as String,
    };

/// A value with its simple ICU placeholder tokens (`{task}`, `{count}`, …)
/// removed, so a placeholder NAME is never mistaken for user-facing copy. The
/// text inside plural branches (e.g. "paused item") is left intact.
String _copyOnly(String value) =>
    value.replaceAll(RegExp(r'\{[A-Za-z]\w*\}'), '');

void main() {
  group('no retired word survives in any locale', () {
    final retired = RegExp(r'task|görev|tabşyryk|задач', caseSensitive: false);
    for (final code in _locales) {
      test(code, () {
        final offenders = <String, String>{};
        _messages(_load(code)).forEach((k, v) {
          if (retired.hasMatch(_copyOnly(v))) offenders[k] = v;
        });
        expect(offenders, isEmpty,
            reason: 'retired vocabulary still in $code: $offenders');
      });
    }
  });

  group('no "New" prefix on any quickAdd* value', () {
    // en "New", tr "Yeni", tk "Täze", ru "Новый/Новая". `\s` (not `\b`) keeps
    // this correct for Cyrillic and leaves "Yeniden dengele" (Rebalance) alone.
    final newPrefix = RegExp(r'^(New|Yeni|Täze|Новый|Новая)\s', caseSensitive: false);
    for (final code in _locales) {
      test(code, () {
        final offenders = <String, String>{};
        _messages(_load(code)).forEach((k, v) {
          if (k.startsWith('quickAdd') && newPrefix.hasMatch(v)) offenders[k] = v;
        });
        expect(offenders, isEmpty,
            reason: 'quickAdd row still prefixed in $code: $offenders');
      });
    }
  });

  group('the last three picker rows are the singular of the Planner tabs', () {
    // §3.1, pinned as data so a future translation cannot silently break the
    // design. [budget, goal, schedule] rows, and the tab names they are the
    // singular of.
    const pickers = {
      'en': ['Budget', 'Goal', 'Schedule'],
      'tr': ['Bütçe', 'Hedef', 'Takvim'],
      'tk': ['Býujet', 'Maksat', 'Meýilnama'],
      'ru': ['Бюджет', 'Цель', 'График'],
    };
    const tabs = {
      'en': ['Budgets', 'Goals', 'Schedule'],
      'tr': ['Bütçeler', 'Hedefler', 'Takvim'],
      'tk': ['Býujetler', 'Maksatlar', 'Meýilnama'],
      'ru': ['Бюджеты', 'Цели', 'График'],
    };
    for (final code in _locales) {
      test(code, () {
        final arb = _load(code);
        expect(
          [arb['quickAddNewBudget'], arb['quickAddNewGoal'], arb['quickAddNewTask']],
          pickers[code],
          reason: 'picker rows drifted from the tab singular in $code',
        );
        expect(
          [arb['plTabBudgets'], arb['plTabGoals'], arb['plTabSchedule']],
          tabs[code],
          reason: 'tab names changed in $code — the correspondence is now unproven',
        );
      });
    }
  });
}
