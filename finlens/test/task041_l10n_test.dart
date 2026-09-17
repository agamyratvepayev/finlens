import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finlens/l10n/app_localizations_en.dart';
import 'package:finlens/l10n/app_localizations_ru.dart';
import 'package:finlens/l10n/app_localizations_tk.dart';
import 'package:finlens/l10n/app_localizations_tr.dart';

/// Task 041 §9 — the note hint carries the label ("Add a note"), and the
/// now-orphaned `goalDoneOnceReachedDesc` is gone from every ARB.
void main() {
  test('goalNoteHint reads "Add a note" in en', () {
    expect(AppLocalizationsEn().goalNoteHint, 'Add a note');
  });

  test('goalNoteHint is translated, not "Optional", in every locale', () {
    expect(AppLocalizationsRu().goalNoteHint, 'Добавить заметку');
    expect(AppLocalizationsTk().goalNoteHint, 'Bellik goşuň');
    expect(AppLocalizationsTr().goalNoteHint, 'Not ekle');
  });

  test('goalDoneOnceReachedDesc is absent from all four ARBs', () {
    for (final code in const ['en', 'ru', 'tk', 'tr']) {
      final arb = File('lib/l10n/app_$code.arb').readAsStringSync();
      expect(arb.contains('goalDoneOnceReachedDesc'), isFalse,
          reason: 'app_$code.arb still declares goalDoneOnceReachedDesc');
    }
  });
}
