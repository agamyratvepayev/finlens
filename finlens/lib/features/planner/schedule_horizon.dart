import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Schedule's four horizon presets. This enum is **local to the Planner
/// feature** on purpose (§11.3): the Ledger's backward-looking [RangePreset]
/// drives the period strip and `copyShifted`, so a forward preset must never
/// leak into it. Horizons are constructed as preset-less [DateRange]s.
enum SchedulePreset { thisWeek, next30, thisMonth, next3Months }

/// Schedule's own forward window — a fixed start (always today) and one of four
/// preset ends or a custom end date. It reads and writes nothing global: not
/// `_month`, not `store.period` (§1).
class ScheduleHorizon {
  const ScheduleHorizon.preset(SchedulePreset this.preset) : customEnd = null;
  const ScheduleHorizon.until(DateTime this.customEnd) : preset = null;

  final SchedulePreset? preset;
  final DateTime? customEnd;

  static const ScheduleHorizon fallback =
      ScheduleHorizon.preset(SchedulePreset.next30);

  static const List<SchedulePreset> presetOrder = [
    SchedulePreset.thisWeek,
    SchedulePreset.next30,
    SchedulePreset.thisMonth,
    SchedulePreset.next3Months,
  ];

  /// The forward range `[today, end]`, built with `preset: null` so it can never
  /// land in Ledger's picker (§11.3).
  DateRange range(DateTime today) {
    final start = _day(today);
    final end = _endDay(today);
    return DateRange(
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    );
  }

  static DateRange rangeOf(SchedulePreset preset, DateTime today) =>
      ScheduleHorizon.preset(preset).range(today);

  DateTime _endDay(DateTime today) {
    final start = _day(today);
    switch (preset) {
      case SchedulePreset.thisWeek:
        return start.add(const Duration(days: 7));
      case SchedulePreset.next30:
        return start.add(const Duration(days: 30));
      case SchedulePreset.thisMonth:
        return DateTime(today.year, today.month + 1, 0);
      case SchedulePreset.next3Months:
        return start.add(const Duration(days: 90));
      case null:
        return _day(customEnd!);
    }
  }

  /// The span the label reports: 9 Aug → 8 Sep reads "30 days"; a custom
  /// 9 → 19 Aug reads "10 days".
  int spanDays(DateTime today) => _endDay(today).difference(_day(today)).inDays;

  int _mirrorDays(DateTime today) {
    switch (preset) {
      case SchedulePreset.thisWeek:
        return 7;
      case SchedulePreset.next30:
        return 30;
      case SchedulePreset.next3Months:
        return 90;
      case SchedulePreset.thisMonth:
        return 0; // handled by the calendar-month branch
      case null:
        return spanDays(today);
    }
  }

  /// The mirror of the horizon, backwards, for the completed section (§5).
  DateRange completedPeriod(DateTime today) {
    final endOfToday =
        DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    if (preset == SchedulePreset.thisMonth) {
      return DateRange(DateTime(today.year, today.month, 1), endOfToday);
    }
    final start = _day(today).subtract(Duration(days: _mirrorDays(today)));
    return DateRange(start, endOfToday);
  }

  String controlLabel(AppLocalizations l) {
    switch (preset) {
      case SchedulePreset.thisWeek:
        return l.schHorizonThisWeek;
      case SchedulePreset.next30:
        return l.schHorizonNext30;
      case SchedulePreset.thisMonth:
        return l.schHorizonThisMonth;
      case SchedulePreset.next3Months:
        return l.schHorizonNext3Months;
      case null:
        return l.schUntilControl(dayMonth(customEnd!, l));
    }
  }

  String completedLabel(AppLocalizations l, DateTime today) =>
      preset == SchedulePreset.thisMonth
          ? l.schCompletedThisMonth
          : l.schCompletedLastDays(_mirrorDays(today));

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

String presetLabel(SchedulePreset p, AppLocalizations l) => switch (p) {
      SchedulePreset.thisWeek => l.schHorizonThisWeek,
      SchedulePreset.next30 => l.schHorizonNext30,
      SchedulePreset.thisMonth => l.schHorizonThisMonth,
      SchedulePreset.next3Months => l.schHorizonNext3Months,
    };

// ── The horizon control (Row 1's leading slot) ──────────────────────────────

/// The `Next 30 days ⌄` control — same shape/type as Budgets' `_MonthControl`
/// (18 pt · w700 · −0.3, `keyboard_arrow_down_rounded` in `textSecondary`,
/// `FittedBox(scaleDown)` so it never clips at 320 pt) (§1).
class ScheduleControl extends StatelessWidget {
  const ScheduleControl({super.key, required this.horizon, required this.onTap});

  final ScheduleHorizon horizon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    horizon.controlLabel(AppLocalizations.of(context)),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── The HORIZON preset sheet (§1) ───────────────────────────────────────────

/// Opens the horizon sheet. [counts] are the four preset counts in
/// [ScheduleHorizon.presetOrder] order (overdue excluded). A preset with count
/// 0 is dimmed and not selectable unless [hasOverdue] (the screen still has
/// something to show). Returns the chosen horizon, or null on dismiss; picking
/// `Until a date…` resolves to a custom horizon via the cash-flow picker.
Future<ScheduleHorizon?> showScheduleHorizonSheet(
  BuildContext context, {
  required ScheduleHorizon current,
  required List<int> counts,
  required bool hasOverdue,
  required DateTime today,
}) {
  return showModalBottomSheet<ScheduleHorizon>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _HorizonSheet(
      current: current,
      counts: counts,
      hasOverdue: hasOverdue,
      today: today,
    ),
  );
}

class _HorizonSheet extends StatelessWidget {
  const _HorizonSheet({
    required this.current,
    required this.counts,
    required this.hasOverdue,
    required this.today,
  });

  final ScheduleHorizon current;
  final List<int> counts;
  final bool hasOverdue;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.md),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.sm),
              child: Text(l.schHorizonTitle, style: AppText.label),
            ),
            for (var i = 0; i < ScheduleHorizon.presetOrder.length; i++)
              _presetRow(context, ScheduleHorizon.presetOrder[i], counts[i]),
            // Accent row → the cash-flow picker (§1.2).
            InkWell(
              onTap: () async {
                final picked = await showUntilDatePicker(context, today: today);
                if (picked != null && context.mounted) {
                  Navigator.of(context).pop(ScheduleHorizon.until(picked));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.gutter, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        size: 20, color: AppColors.accentLight),
                    const SizedBox(width: Insets.md),
                    Text(
                      l.schHorizonUntilDate,
                      style: AppText.rowTitle.copyWith(color: AppColors.accentLight),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
              child: Text(
                l.schHorizonFootnote,
                style: AppText.caption.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetRow(BuildContext context, SchedulePreset preset, int count) {
    final l = AppLocalizations.of(context);
    final active = current.preset == preset;
    // A 0-count preset is unselectable unless overdue tasks exist (§1).
    final enabled = count > 0 || hasOverdue;
    final labelColor = enabled ? AppColors.textPrimary : AppColors.textTertiary;

    return InkWell(
      onTap: enabled
          ? () => Navigator.of(context).pop(ScheduleHorizon.preset(preset))
          : null,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: active
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.accentLight)
                  : null,
            ),
            Expanded(
              child: Text(
                presetLabel(preset, l),
                style: AppText.rowTitle.copyWith(
                  color: labelColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: AppText.amount.copyWith(
                color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The cash-flow picker (§1.2) ─────────────────────────────────────────────

/// One-date picker (the start is always today) whose calendar doubles as the
/// cash-flow view: a dot under a day means a task falls on it, red when the
/// running balance is negative on that day. Returns the chosen end date.
Future<DateTime?> showUntilDatePicker(
  BuildContext context, {
  required DateTime today,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UntilDateSheet(today: today),
  );
}

class _UntilDateSheet extends StatefulWidget {
  const _UntilDateSheet({required this.today});

  final DateTime today;

  @override
  State<_UntilDateSheet> createState() => _UntilDateSheetState();
}

class _UntilDateSheetState extends State<_UntilDateSheet> {
  late final DateTime _today =
      DateTime(widget.today.year, widget.today.month, widget.today.day);
  late DateTime _visibleMonth = DateTime(_today.year, _today.month);
  DateTime? _end;

  static const _chips = [10, 14, 45, 60];

  void _setEndDays(int days) {
    final end = _today.add(Duration(days: days));
    setState(() {
      _end = end;
      _visibleMonth = DateTime(end.year, end.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = StoreScope.of(context);

    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Insets.md),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.sheetGrabber,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Text(l.schUntilTitle, style: AppText.label),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Text(l.schUntilNote,
                    style: AppText.caption.copyWith(fontSize: 12)),
              ),
              const SizedBox(height: Insets.md),
              _chipRow(l),
              const SizedBox(height: Insets.md),
              _calendar(context, store, l),
              const SizedBox(height: Insets.md),
              _legend(l),
              const SizedBox(height: Insets.md),
              _resultBlock(store, l),
              const SizedBox(height: Insets.md),
              _applyButton(context, l),
              const SizedBox(height: Insets.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Row(
        children: [
          for (final days in _chips) ...[
            _chip(l, days),
            if (days != _chips.last) const SizedBox(width: Insets.sm),
          ],
        ],
      ),
    );
  }

  Widget _chip(AppLocalizations l, int days) {
    final active = _end != null && _daysBetween(_today, _end!) == days;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setEndDays(days),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.chipActive : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(
            l.schDaysChip(days),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.chipText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context, AppStore store, AppLocalizations l) {
    // Dots for the visible month: tasks on a day, red when that day's running
    // balance is negative (§1.2), evaluated across the whole visible month.
    final monthEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final coverEnd = monthEnd.isBefore(_today) ? _today : monthEnd;
    final range = DateRange(
      _today,
      DateTime(coverEnd.year, coverEnd.month, coverEnd.day, 23, 59, 59, 999),
    );
    final taskDays = store.daysWithTasks(range);
    final negDays = store.negativeDays(range);

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = monthEnd.day;
    // Monday-first offset.
    final leading = (firstOfMonth.weekday - DateTime.monday + 7) % 7;

    final canGoBack = _visibleMonth.isAfter(DateTime(_today.year, _today.month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: canGoBack
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _visibleMonth = DateTime(
                            _visibleMonth.year, _visibleMonth.month - 1));
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.accentLight,
                disabledColor: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '${monthLong(_visibleMonth.month, l)} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _visibleMonth = DateTime(
                      _visibleMonth.year, _visibleMonth.month + 1));
                },
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.accentLight,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayNarrow(wd, l),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _dayCell(
                  DateTime(_visibleMonth.year, _visibleMonth.month, d),
                  taskDays,
                  negDays,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, Set<DateTime> taskDays, Set<DateTime> negDays) {
    final isPast = day.isBefore(_today);
    final isToday = _sameDay(day, _today);
    final isEnd = _end != null && _sameDay(day, _end!);
    final inRange = _end != null &&
        !day.isBefore(_today) &&
        !day.isAfter(_end!);
    final isEndpoint = isToday || isEnd;
    final hasTask = taskDays.contains(day);
    final isNeg = negDays.contains(day);

    Color? bg;
    BorderRadius radius = BorderRadius.zero;
    if (isEndpoint) {
      bg = AppColors.accent;
      radius = BorderRadius.circular(Radii.sm + 1);
    } else if (inRange) {
      bg = AppColors.tint(AppColors.accent, 0.18);
    }

    final textColor = isPast
        ? AppColors.emptyDay
        : (isEndpoint ? Colors.white : AppColors.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isPast
          ? null
          : () => setState(() {
                _end = day;
              }),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w400,
                  color: textColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTask
                      ? (isNeg ? AppColors.negative : AppColors.textSecondary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(AppLocalizations l) {
    Widget dot(Color c) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        );
    final style = AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Row(
        children: [
          dot(AppColors.textSecondary),
          Text(l.schLegendPayment, style: style),
          const SizedBox(width: Insets.md),
          dot(AppColors.negative),
          Text(l.schLegendNegative, style: style),
        ],
      ),
    );
  }

  Widget _resultBlock(AppStore store, AppLocalizations l) {
    final end = _end;
    final days = end == null ? 0 : _daysBetween(_today, end);
    final range = end == null
        ? null
        : DateRange(
            _today, DateTime(end.year, end.month, end.day, 23, 59, 59, 999));
    final payments = range == null ? 0 : store.tasksInHorizon(range).length;
    final projection = range == null ? store.spendable : store.projection(range);
    final short = projection < 0;
    final breach = range == null ? null : store.firstShortfall(range);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: AppColors.fieldCard,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            end == null
                ? l.schUntilPickPrompt
                : '${l.schUntilFromTo(dayMonth(end, l))} · '
                    '${l.schDaysCount(days)} · ${l.schPaymentsCount(payments)}',
            style: AppText.caption.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountText(
                short ? -projection : projection,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, height: 1.0),
                color: short ? AppColors.negative : AppColors.textPrimary,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                short ? l.schShortLabel : l.schLeftLabel,
                style: AppText.caption.copyWith(
                    fontSize: 11.5,
                    color: short ? AppColors.negative : AppColors.textSecondary),
              ),
            ],
          ),
          if (breach != null) ...[
            const SizedBox(height: 4),
            Text(
              l.schShortOnDay(
                money(breach.amount, masked: store.masked),
                dayMonth(breach.day, l),
              ),
              style: AppText.caption
                  .copyWith(fontSize: 11.5, color: AppColors.negative),
            ),
          ],
        ],
      ),
    );
  }

  Widget _applyButton(BuildContext context, AppLocalizations l) {
    final end = _end;
    final enabled = end != null && !_sameDay(end, _today);
    final days = end == null ? 0 : _daysBetween(_today, end);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: SizedBox(
        height: 47,
        child: FilledButton(
          onPressed: enabled ? () => Navigator.of(context).pop(end) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.saveDisabledBg,
            disabledForegroundColor: AppColors.saveDisabledFg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md)),
          ),
          child: Text(
            l.schApplyDays(days),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime(b.year, b.month, b.day)
          .difference(DateTime(a.year, a.month, a.day))
          .inDays;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
