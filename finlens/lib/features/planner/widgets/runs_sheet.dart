import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Which grid the Runs sheet draws (task 067.1 §6c).
enum RunsMode {
  /// A day grid with a month stepper — Once, Every week, Every … days.
  days,

  /// A 4×3 month grid with a year stepper — Every month.
  months,
}

/// What the Runs sheet returns: the chosen FROM day (or first-of-month in
/// months mode) and the rounded UNTIL — the last day of the period that
/// contains the picked end, or the last day of the UNTIL month, or null for
/// no end. The caller turns these into a budget's anchor / runsUntil / endedAt
/// (§6d); the sheet owns the period rounding so both ends are already whole.
class RunsResult {
  const RunsResult(this.from, this.until);

  final DateTime from;
  final DateTime? until;
}

/// The Runs sheet (§6c, D.5 / D.6). Days mode is a day grid built here — the
/// [RangeCalendar]'s cells, pills and Apply label differ, so it is not reused,
/// only its date maths. Months mode is a 4×3 grid styled like the Planner month
/// picker. Returns null on Cancel.
Future<RunsResult?> showRunsSheet(
  BuildContext context, {
  required RunsMode mode,
  required bool once,
  required int strideDays,
  required DateTime today,
  required DateTime initialFrom,
  DateTime? initialUntil,
  required bool fromLocked,
  required String subtitle,
}) {
  return showModalBottomSheet<RunsResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RunsSheet(
      mode: mode,
      once: once,
      strideDays: strideDays,
      today: today,
      initialFrom: initialFrom,
      initialUntil: initialUntil,
      fromLocked: fromLocked,
      subtitle: subtitle,
    ),
  );
}

enum _Editing { from, until }

class _RunsSheet extends StatefulWidget {
  const _RunsSheet({
    required this.mode,
    required this.once,
    required this.strideDays,
    required this.today,
    required this.initialFrom,
    required this.initialUntil,
    required this.fromLocked,
    required this.subtitle,
  });

  final RunsMode mode;
  final bool once;
  final int strideDays;
  final DateTime today;
  final DateTime initialFrom;
  final DateTime? initialUntil;
  final bool fromLocked;
  final String subtitle;

  @override
  State<_RunsSheet> createState() => _RunsSheetState();
}

class _RunsSheetState extends State<_RunsSheet> {
  late DateTime _from;

  /// The raw end the user tapped, or null for no end. The rounded value the
  /// pill and Apply show is derived from it via [_roundedUntil].
  DateTime? _until;

  /// No end only applies to a repeating budget (never Once).
  late bool _noEnd;

  late _Editing _editing;

  /// The stepper's current page — a month in days mode, a year in months mode.
  late DateTime _page;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _from = widget.mode == RunsMode.months
        ? DateTime(widget.initialFrom.year, widget.initialFrom.month)
        : _dayOnly(widget.initialFrom);
    _noEnd = !widget.once && widget.initialUntil == null;
    _until = widget.initialUntil == null
        ? null
        : (widget.mode == RunsMode.months
            ? DateTime(widget.initialUntil!.year, widget.initialUntil!.month)
            : _dayOnly(widget.initialUntil!));
    // Open aimed at UNTIL when FROM is fixed (edit mode) or a concrete end is
    // already set; otherwise at FROM so the first tap starts a fresh window —
    // including when No end is on and FROM is free (task 070 A7 / 067.1 §6c).
    _editing = (widget.fromLocked || _until != null)
        ? _Editing.until
        : _Editing.from;
    final anchor = _until ?? _from;
    _page = widget.mode == RunsMode.months
        ? DateTime(anchor.year)
        : DateTime(anchor.year, anchor.month);
  }

  // ── UNTIL rounding (§6c) ────────────────────────────────────────────────

  /// The last day of the period that contains [day], measured in whole
  /// [strideDays] strides from FROM. Once is exact — no rounding.
  DateTime _roundPeriodEnd(DateTime day) {
    if (widget.once) return day;
    final diff = day.difference(_from).inDays;
    final idx = diff < 0 ? 0 : diff ~/ widget.strideDays;
    return _from.add(Duration(days: (idx + 1) * widget.strideDays - 1));
  }

  /// The whole end the pill and Apply show: a rounded day (days mode) or the
  /// last day of the UNTIL month (months mode). Null when there is no end.
  DateTime? get _roundedUntil {
    if (_noEnd || _until == null) return null;
    if (widget.mode == RunsMode.months) {
      return DateTime(_until!.year, _until!.month + 1, 0);
    }
    return _roundPeriodEnd(_until!);
  }

  bool get _complete => widget.once ? _until != null : (_noEnd || _until != null);

  // ── Interaction ──────────────────────────────────────────────────────────

  void _tap(DateTime value) {
    final v = widget.mode == RunsMode.months
        ? DateTime(value.year, value.month)
        : _dayOnly(value);
    HapticFeedback.selectionClick();
    setState(() {
      // No end on: a tap only ever moves FROM, never UNTIL, and never turns No
      // end off — only the switch does (task 070 A7). With FROM locked the grid
      // is inert until the switch is off.
      if (_noEnd) {
        if (!widget.fromLocked) _from = v;
        return;
      }
      if (_editing == _Editing.from && !widget.fromLocked) {
        _from = v;
        if (_until != null && !_until!.isAfter(v)) _until = null;
        _editing = _Editing.until;
        return;
      }
      // Editing UNTIL. A pick before FROM restarts FROM there — unless FROM is
      // locked, in which case earlier cells are inert and never reach here.
      if (v.isBefore(_from)) {
        if (widget.fromLocked) return;
        _from = v;
        _until = null;
        _editing = _Editing.until;
        return;
      }
      _until = v;
    });
  }

  void _toggleNoEnd(bool on) {
    setState(() {
      _noEnd = on;
      if (on) {
        _until = null;
        _editing = _Editing.from;
      } else {
        _editing = _Editing.until;
      }
    });
  }

  void _apply() {
    final from = widget.mode == RunsMode.months
        ? DateTime(_from.year, _from.month, 1)
        : _from;
    Navigator.of(context).pop(RunsResult(from, _roundedUntil));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SingleChildScrollView(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title + Cancel.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.bgRuns,
                          style: AppText.rowTitle.copyWith(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(l.actionCancel,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textTertiary)),
                ),
              ),
              _pills(l),
              const SizedBox(height: 14),
              if (widget.mode == RunsMode.months) _monthsBody(l) else _daysBody(l),
              if (!widget.once) _noEndRow(l),
              _applyButton(l),
              const SizedBox(height: Insets.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pills(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _pill(
              caps: l.calFrom,
              value: _fromLabel(l),
              active: _editing == _Editing.from && !widget.fromLocked,
              locked: widget.fromLocked,
              onTap: widget.fromLocked
                  ? null
                  : () => setState(() => _editing = _Editing.from),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _pill(
              caps: l.bgRunsUntil,
              value: _untilLabel(l),
              active: _editing == _Editing.until && !_noEnd,
              muted: _noEnd,
              onTap: _noEnd
                  ? null
                  : () => setState(() => _editing = _Editing.until),
            ),
          ),
        ],
      ),
    );
  }

  String _fromLabel(AppLocalizations l) => widget.mode == RunsMode.months
      ? monthYear(_from, l)
      : dayMonthYear(_from, l); // days-mode pills carry the year (A7 / D.5)

  String _untilLabel(AppLocalizations l) {
    if (_noEnd) return l.bgNoEnd;
    final u = _roundedUntil;
    if (u == null) return '—';
    return widget.mode == RunsMode.months
        ? monthYear(u, l)
        : dayMonthYear(u, l);
  }

  Widget _pill({
    required String caps,
    required String value,
    required bool active,
    bool locked = false,
    bool muted = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.tint(AppColors.accent, 0.18)
              : AppColors.sheetCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 1.5,
            color: active ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(caps,
                style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    // A locked FROM is textTertiary; UNTIL's "No end" value is
                    // textSecondary, not tertiary (task 070 A7).
                    color: locked
                        ? AppColors.textTertiary
                        : (muted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }

  // ── Days grid ──────────────────────────────────────────────────────────

  Widget _daysBody(AppLocalizations l) {
    return Column(
      children: [
        _stepper(
          label: monthYearLong(_page, l),
          onPrev: () =>
              setState(() => _page = DateTime(_page.year, _page.month - 1)),
          onNext: () =>
              setState(() => _page = DateTime(_page.year, _page.month + 1)),
        ),
        const SizedBox(height: Insets.sm),
        const _WeekdayRow(),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _daysGrid(),
        ),
      ],
    );
  }

  Widget _daysGrid() {
    final first = DateTime(_page.year, _page.month, 1);
    final leading = first.weekday % 7; // Sunday-first
    final days = DateTime(_page.year, _page.month + 1, 0).day;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 0,
      children: [
        for (var i = 0; i < leading; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          _dayCell(DateTime(_page.year, _page.month, d)),
      ],
    );
  }

  Widget _dayCell(DateTime date) {
    final until = _roundedUntil;
    final isFrom = date == _from;
    final isUntil = until != null && date == until;
    final inRange =
        until != null && date.isAfter(_from) && date.isBefore(until);
    final isEndpoint = isFrom || isUntil;
    // With FROM locked, days before it are inert.
    final disabled = widget.fromLocked && date.isBefore(_from);

    BorderRadius? radius;
    if (isFrom && isUntil) {
      radius = BorderRadius.circular(18);
    } else if (isFrom) {
      radius = const BorderRadius.horizontal(left: Radius.circular(18));
    } else if (isUntil) {
      radius = const BorderRadius.horizontal(right: Radius.circular(18));
    }
    final Color? fill = isEndpoint
        ? AppColors.accent
        : (inRange ? AppColors.tint(AppColors.accent, 0.22) : null);
    final Color textColor = disabled
        ? AppColors.futureDay
        : isEndpoint
            ? Colors.white
            : AppColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => _tap(date),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, borderRadius: radius),
        child: Text('${date.day}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w500,
                color: textColor)),
      ),
    );
  }

  // ── Months grid ────────────────────────────────────────────────────────

  Widget _monthsBody(AppLocalizations l) {
    return Column(
      children: [
        _stepper(
          label: '${_page.year}',
          onPrev: () => setState(() => _page = DateTime(_page.year - 1)),
          onNext: () => setState(() => _page = DateTime(_page.year + 1)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              for (var m = 1; m <= 12; m++) _monthCell(l, m),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthCell(AppLocalizations l, int month) {
    final cell = DateTime(_page.year, month);
    final until = _roundedUntil == null
        ? null
        : DateTime(_roundedUntil!.year, _roundedUntil!.month);
    final isFrom = cell == _from;
    final isUntil = until != null && cell == until;
    final inRange =
        until != null && cell.isAfter(_from) && cell.isBefore(until);
    final isEndpoint = isFrom || isUntil;
    final disabled = widget.fromLocked && cell.isBefore(_from);

    final Color fill = isEndpoint
        ? AppColors.accent
        : (inRange
            ? AppColors.tint(AppColors.accent, 0.22)
            : AppColors.sheetCard);
    final Color textColor = disabled
        ? AppColors.futureDay
        : isEndpoint
            ? Colors.white
            : AppColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => _tap(cell),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(monthShort(month, l),
            style: TextStyle(
                fontSize: 15,
                fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w500,
                color: textColor)),
      ),
    );
  }

  Widget _stepper({
    required String label,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPrev,
            child: const Icon(Icons.chevron_left_rounded,
                size: 22, color: AppColors.accentLight),
          ),
          const SizedBox(width: Insets.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onNext,
            child: const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.accentLight),
          ),
        ],
      ),
    );
  }

  Widget _noEndRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(l.bgNoEnd,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ),
            // The app's one switch (task 070 A7), not a bare Switch.adaptive.
            FormSwitch(value: _noEnd, onChanged: _toggleNoEnd),
          ],
        ),
      ),
    );
  }

  Widget _applyButton(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _complete ? _apply : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.tint(AppColors.accent, 0.3),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle:
                const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
          child: Text(_applyLabel(l)),
        ),
      ),
    );
  }

  String _applyLabel(AppLocalizations l) {
    final until = _roundedUntil;
    if (until == null) return l.actionApply; // no end
    if (widget.mode == RunsMode.months) {
      final months = (until.year - _from.year) * 12 +
          (until.month - _from.month) +
          1;
      return l.bgApplyMonths(months);
    }
    if (widget.once) {
      final days = until.difference(_from).inDays + 1;
      return l.bgApplyDays(days);
    }
    final totalDays = until.difference(_from).inDays + 1;
    final periods = totalDays ~/ widget.strideDays;
    if (widget.strideDays == 7) return l.bgApplyWeeks(periods);
    return l.bgApplyPeriods(periods);
  }
}

/// Sunday-first weekday header, matching the app's other day grids.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final letter in _labels)
            Expanded(
              child: Center(
                child: Text(letter,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary)),
              ),
            ),
        ],
      ),
    );
  }
}
