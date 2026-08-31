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
  DateTime? firstData,
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
      firstData: firstData,
      disableFuture: disableFuture,
    ),
  );
}

class _RangePickerSheet extends StatefulWidget {
  const _RangePickerSheet({
    required this.current,
    required this.hasData,
    required this.countBetween,
    required this.firstData,
    required this.disableFuture,
  });

  final DateRange current;
  final bool Function(DateTime day) hasData;
  final int Function(DateTime from, DateTime to) countBetween;

  /// Earliest data date, so `All time` resolves to `Since Mar 2023` rather than
  /// the epoch floor (spec §1.1).
  final DateTime? firstData;
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
                firstData: widget.firstData,
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
    required this.firstData,
    required this.onPick,
    required this.onCustom,
  });

  final DateRange current;
  final DateTime? firstData;
  final ValueChanged<DateRange> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Its own title key — a Ledger string on an Insight surface reads wrong
        // (spec §1.5).
        _SheetTitle(l.insPeriod),
        for (final preset in rangePresetOrder) _presetRow(context, preset, l),
        // The divider is meaningful: above it, one tap finishes; below it, a
        // second screen (the calendar) opens.
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        _customRow(context, l),
      ],
    );
  }

  Widget _presetRow(BuildContext context, RangePreset preset, AppLocalizations l) {
    final active = current.preset == preset;
    final resolved = preset.resolve(AppStore.today);
    // `All time` earns its trailing label most: nothing else on the sheet says
    // when the data begins (spec §1.1).
    final resolvedLabel =
        resolved.label(AppStore.today, l, firstEver: firstData);
    return Semantics(
      button: true,
      selected: active,
      // "This month, 1–31 Aug, selected." (spec §9).
      label: active
          ? l.insA11yPresetSelected(preset.label(l), resolvedLabel)
          : '${preset.label(l)}, $resolvedLabel',
      child: ExcludeSemantics(
        child: InkWell(
      onTap: () => onPick(resolved),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              // The check alone marks the active row — the old bold weight was a
              // redundant second signal (spec §1.1). Raised to 18pt to match the
              // scoped ledger's.
              child: active
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.accentLight)
                  : null,
            ),
            // The name ellipsizes at 320pt; the resolved range does not — a
            // truncated date range is read wrong (spec §1.1).
            Expanded(
              child: Text(
                preset.label(l),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              resolvedLabel,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _customRow(BuildContext context, AppLocalizations l) {
    // While a custom range is live, the row says which one — otherwise the only
    // way to learn the active custom window is to open the calendar (spec §1.2).
    final isCustom = current.preset == null;
    final sub = isCustom
        ? '${current.label(AppStore.today, l)} · ${l.insDaysCount(current.days)}'
        : null;
    return Semantics(
      button: true,
      // "Select date range, currently 5–9 Aug, 5 days." (spec §9).
      label: isCustom
          ? l.insA11yCustomRow(
              current.label(AppStore.today, l), l.insDaysCount(current.days))
          : l.insSelectDateRange,
      child: ExcludeSemantics(
        child: InkWell(
      onTap: onCustom,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.accentLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.insSelectDateRange,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.accentLight)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.accentLight),
          ],
        ),
      ),
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
