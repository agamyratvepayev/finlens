import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../theme/app_colors.dart';

/// The frequencies Planner's [RepeatFrequency] can actually persist (spec §1).
/// "Every 2 weeks", "Custom…" and the whole ENDS section are intentionally
/// omitted — Planner's Task model cannot represent a biweekly cadence, a custom
/// rule, or an end condition, and the hard boundary forbids extending it.
const _options = <(RepeatFrequency, String)>[
  (RepeatFrequency.none, 'Never'),
  (RepeatFrequency.weekly, 'Every week'),
  (RepeatFrequency.monthly, 'Every month'),
  (RepeatFrequency.quarterly, 'Every quarter'),
  (RepeatFrequency.yearly, 'Every year'),
];

/// Opens the Repeat chooser and returns the selected frequency (Done), or null
/// if dismissed without confirming (caller keeps the current value).
Future<RepeatFrequency?> showRepeatSheet(
  BuildContext context, {
  required RepeatFrequency current,
  required DateTime date,
}) {
  return showModalBottomSheet<RepeatFrequency>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RepeatSheet(current: current, date: date),
  );
}

/// Human summary of a repeat, derived from the transaction's own date.
String repeatSummary(RepeatFrequency freq, DateTime date) {
  if (freq == RepeatFrequency.none) return '';
  final cadence = switch (freq) {
    RepeatFrequency.none => '',
    RepeatFrequency.weekly => 'every week on ${_weekday(date)}',
    RepeatFrequency.monthly => 'on the ${_ordinal(date.day)} of every month',
    RepeatFrequency.quarterly =>
      'on the ${_ordinal(date.day)}, every 3 months',
    RepeatFrequency.yearly => 'every year on ${date.day} ${_month(date)}',
  };
  return 'Repeats $cadence, starting ${date.day} ${_month(date)}. '
      'Managed in Planner.';
}

/// Short label for the button (e.g. "Every month"), or "Repeat" when off.
String repeatButtonLabel(RepeatFrequency freq) {
  for (final (f, label) in _options) {
    if (f == freq) return f == RepeatFrequency.none ? 'Repeat' : label;
  }
  return 'Repeat';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String _month(DateTime d) => _months[d.month - 1];
String _weekday(DateTime d) => _weekdays[d.weekday - 1];

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.current, required this.date});

  final RepeatFrequency current;
  final DateTime date;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RepeatFrequency _freq = widget.current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 14, 12),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Repeat',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(_freq),
                    child: const Text('Done',
                        style: TextStyle(fontSize: 14.5, color: AppColors.accent)),
                  ),
                ],
              ),
            ),
            _sectionLabel('HOW OFTEN'),
            _card([
              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) _hair(),
                _row(_options[i].$1, _options[i].$2),
              ],
            ]),
            if (_freq != RepeatFrequency.none) _summary(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.07 * 10.5,
                color: AppColors.textTertiary,
              )),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.06));

  Widget _row(RepeatFrequency freq, String label) {
    final selected = _freq == freq;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => setState(() => _freq = freq),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          color: selected ? AppColors.accent.withValues(alpha: 0.16) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: selected ? Colors.white : AppColors.sheetAccountName,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.accentLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          repeatSummary(_freq, widget.date),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.accentLight,
          ),
        ),
      );
}
