import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/date_range.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'range_calendar.dart';

/// The preset list + custom-range calendar, built for Insight and shaped so a
/// second caller can adopt it without a third private copy of a seven-row sheet
/// (that is how two screens start disagreeing about what "Last 3 months" means).
///
/// Returns the chosen [DateRange] — a preset range carries its [RangePreset] so
/// the caller can persist the unit (spec §2.5); a custom range carries `preset:
/// null` and shifts as a whole window. Returns null if dismissed.
///
/// This is deliberately NOT a "move" of the scoped ledger's sheet: that sheet is
/// preset-rows-only and returns a `RangePreset` with caller-side, scope-specific
/// unit persistence and chip-tint state — folding it into this calendar-shaped
/// signature would change its behaviour. It is modelled instead on
/// `same_range_sheet.dart`, which already pairs presets with [RangeCalendar].
Future<DateRange?> showRangePickerSheet(
  BuildContext context, {
  required DateRange current,
  required bool Function(DateTime day) hasData,
  required int Function(DateTime from, DateTime to) countBetween,
  bool disableFuture = true,
}) {
  return showModalBottomSheet<DateRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RangePickerSheet(
      current: current,
      hasData: hasData,
      countBetween: countBetween,
      disableFuture: disableFuture,
    ),
  );
}

/// The seven presets, in the scoped ledger's display order (spec §2.2) so the
/// two sheets never disagree.
const _presetOrder = <RangePreset>[
  RangePreset.thisMonth,
  RangePreset.lastMonth,
  RangePreset.thisWeek,
  RangePreset.lastWeek,
  RangePreset.last3Months,
  RangePreset.thisYear,
  RangePreset.allTime,
];

class _RangePickerSheet extends StatefulWidget {
  const _RangePickerSheet({
    required this.current,
    required this.hasData,
    required this.countBetween,
    required this.disableFuture,
  });

  final DateRange current;
  final bool Function(DateTime day) hasData;
  final int Function(DateTime from, DateTime to) countBetween;
  final bool disableFuture;

  @override
  State<_RangePickerSheet> createState() => _RangePickerSheetState();
}

class _RangePickerSheetState extends State<_RangePickerSheet> {
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                current: widget.current,
                hasData: widget.hasData,
                countBetween: widget.countBetween,
                disableFuture: widget.disableFuture,
                onApply: (range) => Navigator.of(context).pop(range),
              )
            else
              _PresetList(
                current: widget.current,
                onPick: (range) => Navigator.of(context).pop(range),
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
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.lg, Insets.gutter, Insets.sm),
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
    required this.current,
    required this.onPick,
    required this.onCustom,
  });

  final DateRange current;
  final ValueChanged<DateRange> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(l.ldgPeriod),
        for (final preset in _presetOrder) _presetRow(context, preset, l),
        // The divider is meaningful: above it, one tap finishes; below it, a
        // second screen (the calendar) opens.
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        InkWell(
          onTap: onCustom,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.gutter, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.accentLight),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.insSelectDateRange,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.accentLight)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.accentLight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _presetRow(BuildContext context, RangePreset preset, AppLocalizations l) {
    final active = current.preset == preset;
    return InkWell(
      onTap: () => onPick(preset.resolve(AppStore.today)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 11),
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
                preset.label(l),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRange extends StatelessWidget {
  const _CustomRange({
    required this.current,
    required this.hasData,
    required this.countBetween,
    required this.disableFuture,
    required this.onApply,
  });

  final DateRange current;
  final bool Function(DateTime day) hasData;
  final int Function(DateTime from, DateTime to) countBetween;
  final bool disableFuture;
  final ValueChanged<DateRange> onApply;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(l.insSelectDateRange),
        RangeCalendar(
          today: AppStore.today,
          hasData: hasData,
          countBetween: countBetween,
          disableFuture: disableFuture,
          // Insight is a report of the past: verifying an empty stretch is a
          // legitimate question (it lands on the empty state), so Apply stays
          // enabled at n = 0.
          applyEnabledAtZero: true,
          // Seed with the live window so reopening shows the current selection.
          initialFrom: current.start,
          initialTo: current.end,
          onApply: (from, to) => onApply(
            DateRange(
              DateTime(from.year, from.month, from.day),
              DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
            ),
          ),
        ),
      ],
    );
  }
}
