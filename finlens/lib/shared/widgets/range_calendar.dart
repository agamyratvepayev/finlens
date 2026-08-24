import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The FROM/TO + month-calendar + live-count Apply block, shared by the
/// Same-transactions range sheet and the Ledger's Period sheet.
///
/// Extracted from the (previously private, Same-transactions-only) calendar so
/// the two callers share one visual language rather than maintaining a third
/// calendar. Behaviour that legitimately differs between the two is exposed as
/// parameters:
///  * [disableFuture]   — the Ledger has no future, so future days are inert
///                        (#3A3A3C). Same-transactions leaves them tappable.
///  * [applyEnabledAtZero] — on the Ledger, verifying an empty stretch is a
///                        real goal, so Apply stays enabled at n = 0. The
///                        Same-transactions sheet keeps it disabled there.
///  * [initialFrom]/[initialTo] — a friendly starter window (the Ledger seeds
///                        today−3 … today); pass null/null to open empty.
///
/// The block owns only the fields, the calendar and the Apply button — each
/// caller supplies its own section title / back control above it.
class RangeCalendar extends StatefulWidget {
  const RangeCalendar({
    super.key,
    required this.hasData,
    required this.countBetween,
    required this.onApply,
    required this.today,
    this.initialFrom,
    this.initialTo,
    this.applyEnabledAtZero = false,
    this.disableFuture = false,
  });

  /// Whether a given day (day-only) holds at least one matching transaction —
  /// drives the dimmed/undimmed cell. Answered from one grouped query per open.
  final bool Function(DateTime day) hasData;

  /// Live count for a complete, inclusive `from … to` range (both day-only).
  /// The endpoints are inclusive; the callback is responsible for counting the
  /// whole of the TO day.
  final int Function(DateTime from, DateTime to) countBetween;

  /// Fires with the chosen inclusive range (both day-only) when Apply is hit.
  final void Function(DateTime from, DateTime to) onApply;

  final DateTime today;
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final bool applyEnabledAtZero;
  final bool disableFuture;

  @override
  State<RangeCalendar> createState() => _RangeCalendarState();
}

enum _Editing { from, to }

class _RangeCalendarState extends State<RangeCalendar> {
  late DateTime _month;
  DateTime? _from;
  DateTime? _to;

  /// Which field the next calendar tap fills. A seeded (complete) range opens
  /// aimed at FROM, so the first tap starts a fresh window.
  _Editing _editing = _Editing.from;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom == null ? null : _dayOnly(widget.initialFrom!);
    _to = widget.initialTo == null ? null : _dayOnly(widget.initialTo!);
    final anchor = _to ?? _from ?? widget.today;
    _month = DateTime(anchor.year, anchor.month);
  }

  DateTime get _todayDay => _dayOnly(widget.today);

  bool _isFuture(DateTime day) =>
      widget.disableFuture && day.isAfter(_todayDay);

  void _tapDay(DateTime day) {
    if (_isFuture(day)) return;
    setState(() {
      if (_editing == _Editing.from || _from == null) {
        _from = day;
        // A stale TO that no longer sits after the new FROM is dropped.
        if (_to != null && !_to!.isAfter(day)) _to = null;
        _editing = _Editing.to;
      } else if (day.isBefore(_from!)) {
        // Tapping earlier than FROM restarts the window there (spec restart
        // rule); the next tap still completes it as TO.
        _from = day;
        _to = null;
        _editing = _Editing.to;
      } else {
        _to = day; // FROM == TO (a single day) is valid.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final from = _from, to = _to;
    final complete = from != null && to != null;
    final count = complete ? widget.countBetween(from, to) : 0;
    final canApply = complete && (widget.applyEnabledAtZero || count > 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: Row(
            children: [
              Expanded(
                child: _field(
                  AppLocalizations.of(context).calFrom,
                  from,
                  active: _editing == _Editing.from,
                  onTap: () => setState(() => _editing = _Editing.from),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _field(
                  AppLocalizations.of(context).calTo,
                  to,
                  active: _editing == _Editing.to,
                  onTap: from == null
                      ? null
                      : () => setState(() => _editing = _Editing.to),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        _monthHeader(),
        const SizedBox(height: Insets.md),
        const _WeekdayRow(),
        const SizedBox(height: Insets.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: _grid(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, 0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canApply ? () => widget.onApply(from, to) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.tint(AppColors.accent, 0.3),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Text(
                complete
                    ? '${AppLocalizations.of(context).actionApply} · ${AppLocalizations.of(context).countTransactions(count)}'
                    : AppLocalizations.of(context).actionApply,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String caps,
    DateTime? value, {
    required bool active,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(color: AppColors.accent, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caps,
              style: const TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value == null ? '—' : dayMonth(value, AppLocalizations.of(context)),
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Row(
        children: [
          Expanded(
            child: Text(
              monthYearLong(_month, AppLocalizations.of(context)),
              style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _MonthArrow(
            icon: Icons.chevron_left_rounded,
            onTap: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
          ),
          const SizedBox(width: Insets.sm),
          _MonthArrow(
            icon: Icons.chevron_right_rounded,
            onTap: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    // Sunday-first (matching the S M T W T F S header): Sunday(7)→0 … Sat(6)→6.
    final leading = first.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 0,
      children: [
        for (var i = 0; i < leading; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          _day(DateTime(_month.year, _month.month, d)),
      ],
    );
  }

  Widget _day(DateTime date) {
    final from = _from, to = _to;
    final isFrom = from != null && date == from;
    final isTo = to != null && date == to;
    final inRange = from != null &&
        to != null &&
        date.isAfter(from) &&
        date.isBefore(to);
    final isEndpoint = isFrom || isTo;
    final future = _isFuture(date);
    final hasTxn = widget.hasData(date);

    // Band fill: endpoints solid, in-between tinted, with the outer corner of
    // each endpoint rounded so the run reads as one continuous band.
    BorderRadius? radius;
    if (isFrom && isTo) {
      radius = BorderRadius.circular(8);
    } else if (isFrom) {
      radius = const BorderRadius.horizontal(left: Radius.circular(8));
    } else if (isTo) {
      radius = const BorderRadius.horizontal(right: Radius.circular(8));
    }

    final Color? fill = isEndpoint
        ? AppColors.accent
        : (inRange ? AppColors.tint(AppColors.accent, 0.18) : null);

    final Color textColor = future
        ? AppColors.futureDay
        : isEndpoint
            ? Colors.white
            : (hasTxn ? AppColors.textPrimary : AppColors.emptyDay);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: future ? null : () => _tapDay(date),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, borderRadius: radius),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Row(
        children: [
          for (final l in _labels)
            Expanded(
              child: Center(
                child: Text(
                  l,
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
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Icon(icon, size: 22, color: AppColors.accentLight),
    );
  }
}
