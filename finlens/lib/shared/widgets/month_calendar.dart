import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// A single-date month calendar: the month header (title + prev/next arrows),
/// the weekday row and the day grid.
///
/// Extracted from the reporting-date sheet ([showReportingDateSheet]) so that
/// sheet and the typed-date sheet ([showTypedDateSheet]) share one calendar
/// rather than growing a third month grid (Task 25 §2). The reporting sheet
/// keeps its Today/Apply buttons and its "no future" rule by passing
/// [isEnabled] and [lastMonth]; nothing about its look or behaviour changes.
///
/// The widget is presentational and fully controlled: the parent owns the shown
/// [month] and the [selected] day, so a typed date can move the calendar and a
/// tapped day can fill a field — two views of one value that stay in step.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.onPick,
    required this.onMonthChanged,
    this.isEnabled,
    this.firstMonth,
    this.lastMonth,
  });

  /// The month currently shown (day is ignored).
  final DateTime month;

  /// The selected day, or null when nothing is chosen yet.
  final DateTime? selected;

  /// Reference "today" — draws the ring on today's cell.
  final DateTime today;

  final ValueChanged<DateTime> onPick;
  final ValueChanged<DateTime> onMonthChanged;

  /// Whether a given day (day-only) may be picked. Days that fail are dimmed and
  /// inert. Null means every day in the shown month is pickable.
  final bool Function(DateTime day)? isEnabled;

  /// Navigation floor/ceiling (month granularity); null means unbounded that
  /// way. The reporting sheet caps [lastMonth] at the current month.
  final DateTime? firstMonth;
  final DateTime? lastMonth;

  DateTime get _monthStart => DateTime(month.year, month.month);

  bool get _canGoPrev =>
      firstMonth == null ||
      _monthStart.isAfter(DateTime(firstMonth!.year, firstMonth!.month));

  bool get _canGoNext =>
      lastMonth == null ||
      _monthStart.isBefore(DateTime(lastMonth!.year, lastMonth!.month));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthYearLong(_monthStart, AppLocalizations.of(context)),
                style: AppText.rowTitle,
              ),
            ),
            _NavArrow(
              icon: Icons.chevron_left_rounded,
              onTap: _canGoPrev
                  ? () => onMonthChanged(DateTime(month.year, month.month - 1))
                  : null,
            ),
            const SizedBox(width: Insets.sm),
            _NavArrow(
              icon: Icons.chevron_right_rounded,
              onTap: _canGoNext
                  ? () => onMonthChanged(DateTime(month.year, month.month + 1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        const _WeekdayRow(),
        const SizedBox(height: Insets.sm),
        _grid(),
      ],
    );
  }

  Widget _grid() {
    final first = _monthStart;
    // Monday-first: DateTime.weekday is 1..7 starting Monday already.
    final leading = first.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        _day(DateTime(month.year, month.month, d)),
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
    final enabled = isEnabled?.call(date) ?? true;
    final isToday = date == DateTime(today.year, today.month, today.day);
    final sel = selected;
    final isPicked =
        sel != null &&
        date.year == sel.year &&
        date.month == sel.month &&
        date.day == sel.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onPick(date) : null,
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
              color: !enabled
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
