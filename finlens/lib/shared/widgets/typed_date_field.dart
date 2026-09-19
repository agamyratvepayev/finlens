import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/date_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// A typed `dd.mm.yyyy` date field: digits go in, the separators appear on their
/// own (Task 25 §1). Reusable and self-contained — it owns the formatting and
/// reports a [DateEntry] on every change; validation and calendar-syncing are
/// the caller's job.
///
/// This is a formatted field, not free text: the caret is pinned to the end,
/// there is no mid-string editing and no selection-based insertion (§1d). All of
/// that is enforced by [_DateTextInputFormatter].
class TypedDateField extends StatelessWidget {
  const TypedDateField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.autofocus = false,
  });

  /// Owned by the caller so it can pre-fill the field and, when a calendar day
  /// is tapped, refill it (both via [setText]).
  final TextEditingController controller;

  /// Fires on every user edit with the current normalised entry.
  final ValueChanged<DateEntry> onChanged;

  /// A localised validation message (§1e), or null while the entry is valid or
  /// still incomplete.
  final String? errorText;

  final bool autofocus;

  /// Programmatically set the field from a [DateEntry] (e.g. a tapped calendar
  /// day), keeping the caret at the end. Does not run the input formatter, so it
  /// bypasses the typing shortcuts — the text is already normalised.
  static void setText(TextEditingController controller, DateEntry entry) {
    controller.value = TextEditingValue(
      text: entry.text,
      selection: TextSelection.collapsed(offset: entry.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hint = l.dateFieldHint;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The field's accessible name comes from its hint (`dd.mm.yyyy` in the
        // active locale), which a screen reader announces on focus.
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: const [DateTextInputFormatter()],
          onChanged: (text) => onChanged(DateEntry(_digitsOf(text))),
          style: const TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              borderSide: BorderSide(
                color: hasError ? AppColors.negative : AppColors.divider,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              borderSide: BorderSide(
                color: hasError ? AppColors.negative : AppColors.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        // The pattern (or, when the entry is wrong, why) — announced as a live
        // region so a screen reader speaks a failure the moment it appears.
        Semantics(
          liveRegion: hasError,
          child: Text(
            hasError ? errorText! : hint,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: hasError ? AppColors.negative : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

String _digitsOf(String text) => text.replaceAll(RegExp('[^0-9]'), '');

/// Translates the framework's raw edits into [DateEntry] operations, so the
/// field always shows a normalised `dd.mm.yyyy` with the caret at the end.
///
/// Because the field only ever renders the normalised form, the previous
/// value's digits are the prior buffer, and each edit is classified by how the
/// digits and the raw length changed:
///  * one digit appended  → a typed digit (with the §1b shortcuts);
///  * digits unchanged, text grew  → a separator was typed → swallow it;
///  * digits unchanged, text shrank → an auto-separator was deleted → drop the
///    digit before it in the same press (§1c);
///  * one digit removed  → a backspaced digit;
///  * anything else (paste, select-all replace) → digits only, capped at eight.
class DateTextInputFormatter extends TextInputFormatter {
  const DateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = _digitsOf(oldValue.text);
    final newDigits = _digitsOf(newValue.text);

    DateEntry entry;
    if (newDigits.length == oldDigits.length + 1 &&
        newDigits.startsWith(oldDigits)) {
      entry = DateEntry(oldDigits).typeDigit(newDigits[newDigits.length - 1]);
    } else if (newDigits == oldDigits) {
      entry = newValue.text.length < oldValue.text.length
          ? DateEntry(oldDigits).backspace()
          : DateEntry(oldDigits);
    } else if (newDigits.length == oldDigits.length - 1 &&
        oldDigits.startsWith(newDigits)) {
      entry = DateEntry(newDigits);
    } else {
      entry = DateEntry.paste(newValue.text);
    }

    return TextEditingValue(
      text: entry.text,
      selection: TextSelection.collapsed(offset: entry.text.length),
    );
  }
}
