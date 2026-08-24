import 'package:flutter/material.dart';

import '../../../core/store/app_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/range_calendar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
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
          _presetRow(preset, counts[preset] ?? 0, AppLocalizations.of(context)),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        // Custom range… — an accent row that opens the calendar.
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
                Text('${AppLocalizations.of(context).ldgCustomRange}…',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.accentLight)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _presetRow(SameRangePreset preset, int count, AppLocalizations l) {
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
                  preset.label(l),
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
  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final bucket = store.sameTransactions(widget.sameKey);
    final daysWithTxn = {for (final t in bucket) _dayOnly(t.date)};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTitle('CUSTOM RANGE'),
        // The Same-transactions calendar keeps its original behaviour: empty
        // start, future days tappable, and Apply disabled at n = 0.
        RangeCalendar(
          today: AppStore.today,
          hasData: daysWithTxn.contains,
          countBetween: (from, to) => store.sameCountBetween(
            widget.sameKey,
            from,
            DateTime(to.year, to.month, to.day, 23, 59, 59, 999),
          ),
          onApply: (from, to) =>
              widget.onApply(SameRangeChoice.custom(from, to)),
        ),
      ],
    );
  }
}
