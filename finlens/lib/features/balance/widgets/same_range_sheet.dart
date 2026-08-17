import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../same_transactions.dart';

/// The date-range sheet for the Same-transactions screen: seven presets — each
/// with its live count under the current key — plus a custom-range calendar.
/// Returns the chosen [SameRangeChoice], or null if dismissed.
Future<SameRangeChoice?> showSameRangeSheet(
  BuildContext context, {
  required SameKey key,
  required SameRangeChoice current,
}) {
  return showModalBottomSheet<SameRangeChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface, // #161618, per spec §4
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RangeSheet(sameKey: key, current: current),
  );
}

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.sameKey, required this.current});

  final SameKey sameKey;
  final SameRangeChoice current;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
            if (_custom)
              _CustomRange(
                sameKey: widget.sameKey,
                onApply: (choice) => Navigator.of(context).pop(choice),
              )
            else
              _PresetList(
                sameKey: widget.sameKey,
                current: widget.current,
                onPick: (choice) => Navigator.of(context).pop(choice),
                onCustom: () => setState(() => _custom = true),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.lg, Insets.gutter, Insets.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.66,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
}

class _PresetList extends StatelessWidget {
  const _PresetList({
    required this.sameKey,
    required this.current,
    required this.onPick,
    required this.onCustom,
  });

  final SameKey sameKey;
  final SameRangeChoice current;
  final ValueChanged<SameRangeChoice> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final counts = store.sameRangeCounts(sameKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('DATE RANGE'),
        for (final preset in SameRangePreset.values)
          _presetRow(preset, counts[preset] ?? 0),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        // Custom range… — an accent row that opens the calendar.
        InkWell(
          onTap: onCustom,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.accentLight),
                SizedBox(width: 10),
                Text('Custom range…',
                    style: TextStyle(fontSize: 15, color: AppColors.accentLight)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _presetRow(SameRangePreset preset, int count) {
    final active = !current.isCustom && current.preset == preset;
    final selectable = count > 0;
    // A zero-count preset must be visibly un-enterable.
    final opacity = selectable ? 1.0 : 0.4;

    return InkWell(
      onTap: selectable ? () => onPick(SameRangeChoice.preset(preset)) : null,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.gutter, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: active
                    ? const Icon(Icons.check_rounded,
                        size: 17, color: AppColors.accentLight)
                    : null,
              ),
              Expanded(
                child: Text(
                  preset.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomRange extends StatefulWidget {
  const _CustomRange({required this.sameKey, required this.onApply});

  final SameKey sameKey;
  final ValueChanged<SameRangeChoice> onApply;

  @override
  State<_CustomRange> createState() => _CustomRangeState();
}

class _CustomRangeState extends State<_CustomRange> {
  late DateTime _month =
      DateTime(AppStore.today.year, AppStore.today.month);
  DateTime? _from;
  DateTime? _to;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _tap(DateTime day) {
    setState(() {
      if (_from == null || (_from != null && _to != null)) {
        _from = day;
        _to = null;
      } else if (day.isBefore(_from!)) {
        // Tapping earlier than FROM restarts the selection there.
        _from = day;
        _to = null;
      } else {
        _to = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final bucket = store.sameTransactions(widget.sameKey);
    final daysWithTxn = {for (final t in bucket) _dayOnly(t.date)};

    final complete = _from != null && _to != null;
    final count = complete
        ? store.sameCountBetween(
            widget.sameKey,
            _from!,
            DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59, 999),
          )
        : 0;
    final editingTo = _from != null && _to == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('CUSTOM RANGE'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: Row(
            children: [
              Expanded(
                  child: _field('FROM', _from, active: !editingTo)),
              const SizedBox(width: Insets.md),
              Expanded(child: _field('TO', _to, active: editingTo)),
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
          child: _grid(daysWithTxn),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 14, Insets.lg, 0),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (complete && count > 0)
                  ? () => widget.onApply(SameRangeChoice.custom(
                      _dayOnly(_from!), _dayOnly(_to!)))
                  : null,
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
                    ? 'Apply · $count ${count == 1 ? 'transaction' : 'transactions'}'
                    : 'Apply',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String caps, DateTime? value, {required bool active}) {
    return Container(
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
            value == null ? '—' : dayMonth(value),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
              monthYearLong(_month),
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

  Widget _grid(Set<DateTime> daysWithTxn) {
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
          _day(DateTime(_month.year, _month.month, d), daysWithTxn),
      ],
    );
  }

  Widget _day(DateTime date, Set<DateTime> daysWithTxn) {
    final from = _from, to = _to;
    final isFrom = from != null && date == from;
    final isTo = to != null && date == to;
    final inRange = from != null &&
        to != null &&
        date.isAfter(from) &&
        date.isBefore(to);
    final isEndpoint = isFrom || isTo;
    final hasTxn = daysWithTxn.contains(date);

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

    final Color textColor = isEndpoint
        ? Colors.white
        : (hasTxn ? AppColors.textPrimary : AppColors.emptyDay);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(date),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: isEndpoint ? radius : (inRange ? null : null),
        ),
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
    // Spec §4 shows a Sunday-first header row.
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
