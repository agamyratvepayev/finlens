import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Reporting-date picker.
///
/// Returns the chosen day, or `AppStore.today` via the Today button meaning
/// "back to live". Future dates are disabled — a balance sheet looks backward.
Future<DateTime?> showReportingDateSheet(
  BuildContext context, {
  required DateTime? selected,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    isScrollControlled: true,
    builder: (_) => _DateSheet(selected: selected),
  );
}

/// Sentinel meaning "return to the live view".
final liveDate = DateTime.utc(1970);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.selected});

  final DateTime? selected;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month = DateTime(
    (widget.selected ?? AppStore.today).year,
    (widget.selected ?? AppStore.today).month,
  );
  late DateTime _picked = widget.selected ?? AppStore.today;

  DateTime get _today =>
      DateTime(AppStore.today.year, AppStore.today.month, AppStore.today.day);

  bool get _canGoNext =>
      _month.isBefore(DateTime(AppStore.today.year, AppStore.today.month));

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
            Row(
              children: [
                Expanded(
                  child: Text(monthYearLong(_month, AppLocalizations.of(context)),
                      style: AppText.rowTitle),
                ),
                _NavArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  // Never navigate past the current month.
                  onTap: _canGoNext
                      ? () => setState(
                            () => _month = DateTime(_month.year, _month.month + 1),
                          )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            const _WeekdayRow(),
            const SizedBox(height: Insets.sm),
            _grid(),
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

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    // Monday-first: DateTime.weekday is 1..7 starting Monday already.
    final leading = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _day(DateTime(_month.year, _month.month, d)),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _day(DateTime date) {
    final isFuture = date.isAfter(_today);
    final isToday = date == _today;
    final isPicked = date.year == _picked.year &&
        date.month == _picked.month &&
        date.day == _picked.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isFuture ? null : () => setState(() => _picked = date),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPicked ? AppColors.accent : null,
            shape: BoxShape.circle,
            border: isToday && !isPicked
                ? Border.all(color: AppColors.accent, width: 1.5)
                : null,
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: isPicked ? FontWeight.w700 : FontWeight.w500,
              color: isFuture
                  ? AppColors.textTertiary.withValues(alpha: 0.45)
                  : (isPicked ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in _labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: AppText.listSectionLabel.copyWith(letterSpacing: 0),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.textPrimary
              : AppColors.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
