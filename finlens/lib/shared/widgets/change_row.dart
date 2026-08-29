import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// One row in a CHANGES card — a dated record of a figure the user edited.
///
/// Extracted verbatim from the goal detail screen's private `_ChangeRow` so the
/// budget detail screen can reuse the exact geometry. It renders the three
/// things it is handed — a [date] column, a [label], and a finished [value]
/// line — plus an optional trailing amber flag. Composition of the value string
/// (`from → to`, or just `to`) is the *caller's* knowledge and stays there.
class ChangeRow extends StatelessWidget {
  const ChangeRow({
    super.key,
    required this.date,
    required this.label,
    required this.value,
    this.amber = false,
    this.amberIcon = Icons.schedule_rounded,
    this.semanticsLabel,
  });

  /// The compact date column, e.g. `9.8`. Formatted by the caller.
  final String date;

  /// The localized field label, e.g. `Created` / `Limit`.
  final String label;

  /// The finished value line, e.g. `$3,000 → $4,000`. Empty hides the line
  /// entirely (a record with a label but no value, such as a category archive).
  final String value;

  /// A raised limit / pushed-out deadline. Trails an amber glyph.
  final bool amber;

  /// The amber glyph — a deadline (`schedule_rounded`) on a goal, a rising
  /// limit (`trending_up_rounded`) on a budget. Named by the caller because the
  /// same colour means different things on the two screens.
  final IconData amberIcon;

  /// When set, the whole row announces as this one sentence to a screen reader
  /// (the amber flag folded in as words, not a separate node). Null leaves the
  /// row's default reading untouched — the goal screen relies on that.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              date,
              style: AppText.caption.copyWith(fontSize: 11.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.rowSubtitle.copyWith(fontSize: 12.5)),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          if (amber)
            Icon(amberIcon, size: 15, color: AppColors.warning),
        ],
      ),
    );
    if (semanticsLabel == null) return row;
    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: row,
    );
  }
}
