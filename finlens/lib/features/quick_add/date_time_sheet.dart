import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The transaction form's date **and time** picker — an app-native bottom sheet
/// that replaces Flutter's stock [showDatePicker].
///
/// The row it backs promises a date *and* a time ("9 Aug, 14:32"); the stock
/// dialog only edits the date, so the time was frozen and invisible. This sheet
/// makes both editable in one place: a summary line whose two halves double as
/// the switch between a calendar and two time wheels, in a single fixed-height
/// area so the sheet never changes height when you flip between them.
///
/// [now] is injected rather than read from the wall clock — the app pins its
/// reference date ([AppStore.today]) so the documented screens stay
/// reproducible, and the tests need a deterministic "now" for the `Now` button
/// and the today-ring. [firstDate]/[lastDate] mirror the bounds the old
/// `showDatePicker` enforced and are preserved exactly.
Future<DateTime?> showDateTimeSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime now,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    isScrollControlled: true,
    builder: (_) => _DateTimeSheet(
      initial: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      now: now,
    ),
  );
}

/// The single fixed-height area that both the calendar and the time wheels fill.
/// Sized to the calendar (the taller of the two): a 32pt month header, a 20pt
/// weekday strip, and six 30pt day rows plus their gaps. Confirmed identical in
/// both views because both children are wrapped in a `SizedBox(height:)` of this
/// value.
const double _kAreaHeight = 268;

enum _View { date, time }

class _DateTimeSheet extends StatefulWidget {
  const _DateTimeSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.now,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime now;

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  /// The value being edited. Committed only on Done.
  late DateTime _value = widget.initial;

  /// The month shown by the calendar, independent of the selection so the user
  /// can browse without changing the day.
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  /// Opens with the date active — most visits correct the date (spec §3).
  _View _view = _View.date;

  /// True while the month-and-year selector (spec §4) is showing.
  bool _pickingMonth = false;

  // Wheel controllers are held (not rebuilt each frame) so a scroll flick keeps
  // its momentum and so `Now` can jump the wheels programmatically. Created in
  // [didChangeDependencies] because the hour wheel's shape depends on
  // MediaQuery's 12-/24-hour setting.
  FixedExtentScrollController? _hourCtl;
  FixedExtentScrollController? _minuteCtl;
  FixedExtentScrollController? _periodCtl;
  bool _use24 = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
    if (_hourCtl == null || use24 != _use24) {
      _use24 = use24;
      _hourCtl?.dispose();
      _minuteCtl?.dispose();
      _periodCtl?.dispose();
      _hourCtl = FixedExtentScrollController(initialItem: _hourIndex());
      _minuteCtl = FixedExtentScrollController(initialItem: _value.minute);
      _periodCtl =
          FixedExtentScrollController(initialItem: _value.hour >= 12 ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _hourCtl?.dispose();
    _minuteCtl?.dispose();
    _periodCtl?.dispose();
    super.dispose();
  }

  /// The hour wheel's item index for the current value, in the active format.
  int _hourIndex() => _use24
      ? _value.hour
      : (_value.hour % 12 == 0 ? 11 : (_value.hour % 12) - 1);

  DateTime get _firstDay =>
      DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
  DateTime get _lastDay =>
      DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
  DateTime get _todayDay =>
      DateTime(widget.now.year, widget.now.month, widget.now.day);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            // Title row: "Date" left, Cancel right.
            Row(
              children: [
                Expanded(child: Text(l.qaDate, style: AppText.rowTitle)),
                _TextButton(
                  label: l.actionCancel,
                  onTap: () => Navigator.of(context).pop(),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            _summaryLine(l),
            const SizedBox(height: Insets.lg),
            SizedBox(
              key: const ValueKey('dt-area'),
              height: _kAreaHeight,
              child: _view == _View.date
                  ? (_pickingMonth ? _monthYearSelector(l) : _calendar(l))
                  : _timeView(l),
            ),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: Text(l.actionDone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary line ───────────────────────────────────────────────────────────

  Widget _summaryLine(AppLocalizations l) {
    final dateActive = _view == _View.date;
    final dateText = dateAbsolute(_value, l, now: widget.now);
    final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_value),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The date may ellipsize at large text scale; the time never does — it
        // is the shorter, more precise half (spec §6).
        Expanded(
          child: _SummaryHalf(
            key: const ValueKey('dt-date-half'),
            text: dateText,
            active: dateActive,
            alignEnd: false,
            onTap: () {
              if (!dateActive || _pickingMonth) {
                setState(() {
                  _view = _View.date;
                  _pickingMonth = false;
                });
              }
            },
          ),
        ),
        const SizedBox(width: Insets.md),
        _SummaryHalf(
          key: const ValueKey('dt-time-half'),
          text: timeText,
          active: !dateActive,
          alignEnd: true,
          onTap: () {
            if (dateActive) setState(() => _view = _View.time);
          },
        ),
      ],
    );
  }

  // ── Calendar ─────────────────────────────────────────────────────────────

  bool _canGoPrev() =>
      DateTime(_month.year, _month.month, 1).isAfter(DateTime(_firstDay.year, _firstDay.month, 1));
  bool _canGoNext() =>
      DateTime(_month.year, _month.month, 1).isBefore(DateTime(_lastDay.year, _lastDay.month, 1));

  Widget _calendar(AppLocalizations l) {
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _pickingMonth = true),
                  child: Semantics(
                    button: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(monthYearLong(_month, l), style: AppText.rowTitle),
                        const Icon(Icons.arrow_drop_down_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: _canGoPrev()
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1))
                    : null,
              ),
              const SizedBox(width: Insets.sm),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: _canGoNext()
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        _weekdayRow(l),
        const SizedBox(height: Insets.sm),
        Expanded(child: SingleChildScrollView(child: _grid(l))),
      ],
    );
  }

  /// First day of week comes from the locale (0 = Sunday). Turkish/Russian/
  /// Turkmen resolve to Monday; en to Sunday.
  int get _firstWeekday => MaterialLocalizations.of(context).firstDayOfWeekIndex;

  Widget _weekdayRow(AppLocalizations l) {
    return Row(
      key: const ValueKey('dt-weekdays'),
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                // Column i's weekday in ISO terms (1 = Mon … 7 = Sun).
                weekdayNarrow(_isoForColumn(i), l),
                style: AppText.listSectionLabel.copyWith(letterSpacing: 0),
              ),
            ),
          ),
      ],
    );
  }

  int _isoForColumn(int column) {
    final sun0 = (_firstWeekday + column) % 7; // 0 = Sun … 6 = Sat
    return sun0 == 0 ? 7 : sun0;
  }

  int _columnFor(DateTime day) {
    final sun0 = day.weekday % 7; // Mon(1)->1 … Sun(7)->0
    return (sun0 - _firstWeekday + 7) % 7;
  }

  Widget _grid(AppLocalizations l) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = _columnFor(first);
    final days = daysInMonth(_month);
    // Always render six rows so the grid height is identical across months.
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const _EmptyCell(),
      for (var d = 1; d <= days; d++)
        _dayCell(DateTime(_month.year, _month.month, d), l),
    ];
    while (cells.length < 42) {
      cells.add(const _EmptyCell());
    }
    return Column(
      children: [
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: cells[row * 7 + col]),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(DateTime date, AppLocalizations l) {
    final disabled = date.isBefore(_firstDay) || date.isAfter(_lastDay);
    final isToday = date == _todayDay;
    final selected = date.year == _value.year &&
        date.month == _value.month &&
        date.day == _value.day;

    return Semantics(
      button: !disabled,
      // Every day cell announces its full date; `selected`/`enabled` carry the
      // today/selected/disabled state to the reader (spec §6).
      selected: selected,
      enabled: !disabled,
      label: dayMonthYear(date, l),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled
            ? null
            // Selecting a day changes only the date; the time is untouched.
            : () => setState(() => _value = DateTime(date.year, date.month,
                date.day, _value.hour, _value.minute)),
        child: SizedBox(
          height: 30,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : null,
                shape: BoxShape.circle,
                // Today is ringed; when today is also the selection only the
                // fill renders (spec §4).
                border: isToday && !selected
                    ? Border.all(color: AppColors.accent, width: 1.5)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: disabled
                      ? AppColors.textTertiary.withValues(alpha: 0.4)
                      : (selected ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Month-and-year selector ─────────────────────────────────────────────────

  Widget _monthYearSelector(AppLocalizations l) {
    final canPrevYear = _month.year > widget.firstDate.year;
    final canNextYear = _month.year < widget.lastDate.year;
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: canPrevYear
                    ? () => setState(() =>
                        _month = DateTime(_month.year - 1, _month.month))
                    : null,
              ),
              Expanded(
                child: Center(
                  child: Text('${_month.year}', style: AppText.rowTitle),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: canNextYear
                    ? () => setState(() =>
                        _month = DateTime(_month.year + 1, _month.month))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            mainAxisSpacing: Insets.sm,
            crossAxisSpacing: Insets.sm,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var m = 1; m <= 12; m++) _monthChip(m, l),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthChip(int month, AppLocalizations l) {
    final target = DateTime(_month.year, month);
    // A month is reachable only if it holds at least one in-bounds day.
    final monthEnd = DateTime(_month.year, month, daysInMonth(target));
    final disabled = monthEnd.isBefore(_firstDay) ||
        DateTime(_month.year, month, 1).isAfter(_lastDay);
    final selected = month == _month.month;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled
          ? null
          : () => setState(() {
                _month = DateTime(_month.year, month);
                _pickingMonth = false;
              }),
      child: Semantics(
        button: !disabled,
        selected: selected,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Text(
            monthShort(month, l),
            style: AppText.rowTitle.copyWith(
              color: disabled
                  ? AppColors.textTertiary.withValues(alpha: 0.4)
                  : (selected ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  // ── Time wheels ─────────────────────────────────────────────────────────────

  Widget _timeView(AppLocalizations l) {
    final material = MaterialLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Hours.
              Expanded(
                child: _wheel(
                  controller: _hourCtl!,
                  count: _use24 ? 24 : 12,
                  label: (i) =>
                      _use24 ? i.toString().padLeft(2, '0') : '${i + 1}',
                  onChanged: (i) => _setHour24(
                      _use24 ? i : _to24(i + 1, _value.hour >= 12)),
                ),
              ),
              // Minutes step by 1 (spec §5).
              Expanded(
                child: _wheel(
                  controller: _minuteCtl!,
                  count: 60,
                  label: (i) => i.toString().padLeft(2, '0'),
                  onChanged: (i) => setState(() => _value = DateTime(_value.year,
                      _value.month, _value.day, _value.hour, i)),
                ),
              ),
              // AM/PM wheel only in 12-hour locales.
              if (!_use24)
                Expanded(
                  child: _wheel(
                    controller: _periodCtl!,
                    count: 2,
                    label: (i) => i == 0
                        ? material.anteMeridiemAbbreviation
                        : material.postMeridiemAbbreviation,
                    onChanged: (i) {
                      final h12 = _value.hour % 12 == 0 ? 12 : _value.hour % 12;
                      _setHour24(_to24(h12, i == 1));
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        // Now sets only the time; the date is untouched (spec §5).
        _TextButton(
          label: l.sheetNow,
          color: AppColors.accent,
          onTap: _setNow,
        ),
      ],
    );
  }

  int _to24(int hour12, bool pm) => (hour12 % 12) + (pm ? 12 : 0);

  void _setHour24(int hour) => setState(() => _value = DateTime(
      _value.year, _value.month, _value.day, hour, _value.minute));

  void _setNow() {
    setState(() => _value = DateTime(_value.year, _value.month, _value.day,
        widget.now.hour, widget.now.minute));
    // Move the wheels to match; the attached pickers ignore a no-op jump.
    _hourCtl?.jumpToItem(_hourIndex());
    _minuteCtl?.jumpToItem(_value.minute);
    _periodCtl?.jumpToItem(_value.hour >= 12 ? 1 : 0);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 34,
      diameterRatio: 1.2,
      selectionOverlay: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      onSelectedItemChanged: onChanged,
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(
              label(i),
              style: AppText.rowTitle.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Small pieces ───────────────────────────────────────────────────────────

class _SummaryHalf extends StatelessWidget {
  const _SummaryHalf({
    super.key,
    required this.text,
    required this.active,
    required this.alignEnd,
    required this.onTap,
  });

  final String text;
  final bool active;
  final bool alignEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Text(
      text,
      maxLines: 1,
      // The time never truncates; the date may (spec §6). The time half is not
      // wrapped in Expanded so it keeps its intrinsic width.
      overflow: alignEnd ? TextOverflow.visible : TextOverflow.ellipsis,
      // Same base size in both states — only colour and the underline change,
      // so the value never shifts as it goes active/inactive.
      style: AppText.amountLarge.copyWith(
        color: active ? AppColors.accent : AppColors.textSecondary,
        decoration: active ? TextDecoration.underline : TextDecoration.none,
        decorationColor: AppColors.accent,
        decorationThickness: 2,
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // ≥44pt tap height (spec §3).
          constraints: const BoxConstraints(minHeight: 44),
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: content,
        ),
      ),
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

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap, required this.color});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.rowTitle.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 30);
}
