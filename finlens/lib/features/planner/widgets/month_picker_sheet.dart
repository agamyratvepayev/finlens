import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Planner's own month picker (spec 5.1). Deliberately NOT the Ledger's period
/// sheet: that one writes `store.period` and clamps its years to today, whereas
/// Planner keeps its own month, decoupled from the global period, and must
/// reach future months (they simply read $0). A year stepper and a grid of 12
/// month chips is all a month-only scope needs.
Future<void> showPlannerMonthPicker(
  BuildContext context, {
  required DateTime initial,
  required ValueChanged<DateTime> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MonthPicker(initial: initial, onPick: onPick),
  );
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial, required this.onPick});

  final DateTime initial;
  final ValueChanged<DateTime> onPick;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year;

  // A generous, fixed window — a budget review needs a few years back and the
  // odd month forward, not the whole calendar.
  static const _minYear = 2020;
  static const _maxYear = 2035;

  void _stepYear(int delta) {
    final next = _year + delta;
    if (next < _minYear || next > _maxYear) return;
    HapticFeedback.selectionClick();
    setState(() => _year = next);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(AppLocalizations.of(context).mpMonth, style: AppText.label),
            const SizedBox(height: Insets.md),
            _yearStepper(),
            const SizedBox(height: Insets.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                0,
                Insets.gutter,
                Insets.md,
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: Insets.sm,
                crossAxisSpacing: Insets.sm,
                childAspectRatio: 2.4,
                children: [
                  for (var m = 1; m <= 12; m++) _monthChip(m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.textSecondary,
          onPressed: _year > _minYear ? () => _stepYear(-1) : null,
        ),
        SizedBox(
          width: 92,
          child: Center(
            child: Text(
              '$_year',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.textSecondary,
          onPressed: _year < _maxYear ? () => _stepYear(1) : null,
        ),
      ],
    );
  }

  Widget _monthChip(int month) {
    final selected =
        _year == widget.initial.year && month == widget.initial.month;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onPick(DateTime(_year, month));
        Navigator.of(context).pop();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Text(
          monthShort(month, AppLocalizations.of(context)),
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
