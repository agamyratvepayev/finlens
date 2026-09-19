import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Reporting-date picker.
///
/// Returns the chosen day, or `AppStore.today` via the Today button meaning
/// "back to live". Future dates are disabled — a balance sheet looks backward.
Future<DateTime?> showReportingDateSheet(
  BuildContext context, {
  required DateTime? selected,
  required DateTime today,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    isScrollControlled: true,
    builder: (_) => _DateSheet(selected: selected, today: today),
  );
}

/// Sentinel meaning "return to the live view".
final liveDate = DateTime.utc(1970);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.selected, required this.today});

  final DateTime? selected;
  final DateTime today;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month = DateTime(
    (widget.selected ?? widget.today).year,
    (widget.selected ?? widget.today).month,
  );
  late DateTime _picked = widget.selected ?? widget.today;

  DateTime get _today => widget.today;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.md,
          Insets.gutter,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Insets.lg),
            MonthCalendar(
              month: _month,
              selected: _picked,
              today: _today,
              // Never navigate past the current month.
              lastMonth: DateTime(_today.year, _today.month),
              // A balance sheet looks backward — future days are inert.
              isEnabled: (d) => !d.isAfter(_today),
              onMonthChanged: (m) => setState(() => _month = m),
              onPick: (d) => setState(() => _picked = d),
            ),
            const SizedBox(height: Insets.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(liveDate),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).sheetToday),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_picked),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).sheetApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
