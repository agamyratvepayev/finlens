import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// The outcome of the Repeat chooser: a frequency plus the days within it.
/// [weekdays] is meaningful only for weekly; [daysOfMonth] for monthly, and it
/// also carries the single seed day for quarterly/yearly so those never drift.
class RepeatSelection {
  const RepeatSelection(
    this.freq, {
    this.weekdays = const {},
    this.daysOfMonth = const {},
  });

  final RepeatFrequency freq;
  final Set<int> weekdays;
  final Set<int> daysOfMonth;
}

/// The frequencies the Repeat sheet offers, in display order. "Every 2 weeks"
/// sits between weekly and monthly. Custom rules and the ENDS section remain
/// out of scope; the model now *can* hold biweekly and multi-day cadences.
List<(RepeatFrequency, String)> _optionsFor(AppLocalizations l) => [
      (RepeatFrequency.none, l.repeatNever),
      (RepeatFrequency.weekly, l.rsEveryWeek),
      (RepeatFrequency.biweekly, l.rsEvery2Weeks),
      (RepeatFrequency.monthly, l.rsEveryMonth),
      (RepeatFrequency.quarterly, l.rsEveryQuarter),
      (RepeatFrequency.yearly, l.rsEveryYear),
    ];

/// Opens the Repeat chooser and returns the selection (Done), or null if
/// dismissed without confirming (caller keeps its current value and day sets).
Future<RepeatSelection?> showRepeatSheet(
  BuildContext context, {
  required RepeatFrequency current,
  required DateTime date,
  Set<int> weekdays = const {},
  Set<int> daysOfMonth = const {},
}) {
  return showModalBottomSheet<RepeatSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RepeatSheet(
      current: current,
      date: date,
      weekdays: weekdays,
      daysOfMonth: daysOfMonth,
    ),
  );
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({
    required this.current,
    required this.date,
    required this.weekdays,
    required this.daysOfMonth,
  });

  final RepeatFrequency current;
  final DateTime date;
  final Set<int> weekdays;
  final Set<int> daysOfMonth;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RepeatFrequency _freq = widget.current;
  // Both pickers seed from the transaction's own date, so a user who never
  // touches them gets exactly today's behaviour.
  late final Set<int> _weekdays =
      widget.weekdays.isEmpty ? {widget.date.weekday} : {...widget.weekdays};
  late final Set<int> _daysOfMonth =
      widget.daysOfMonth.isEmpty ? {widget.date.day} : {...widget.daysOfMonth};

  /// The selection to hand back to the caller, populated for the chosen
  /// frequency. Quarterly/yearly carry the seed day so their series stay on it.
  RepeatSelection get _selection => switch (_freq) {
        RepeatFrequency.weekly =>
          RepeatSelection(_freq, weekdays: {..._weekdays}),
        RepeatFrequency.monthly =>
          RepeatSelection(_freq, daysOfMonth: {..._daysOfMonth}),
        RepeatFrequency.quarterly ||
        RepeatFrequency.yearly =>
          RepeatSelection(_freq, daysOfMonth: {widget.date.day}),
        RepeatFrequency.none || RepeatFrequency.biweekly =>
          RepeatSelection(_freq),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final options = _optionsFor(l);
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
                  Expanded(
                    child: Text(l.rsRepeat,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(_selection),
                    child: Text(l.actionDone,
                        style: const TextStyle(
                            fontSize: 14.5, color: AppColors.accent)),
                  ),
                ],
              ),
            ),
            _sectionLabel(l.rsHowOften.toUpperCase()),
            _card([
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) _hair(),
                _row(options[i].$1, options[i].$2),
                // The selected option's picker expands directly beneath its row.
                if (_freq == options[i].$1 && _freq == RepeatFrequency.weekly)
                  _weekdayPicker(l),
                if (_freq == options[i].$1 && _freq == RepeatFrequency.monthly)
                  _dayOfMonthPicker(l),
              ],
            ]),
            if (_freq != RepeatFrequency.none) _preview(l),
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

  /// The seven weekday chips, laid out Monday-first. Multi-select, minimum one:
  /// the last selected chip cannot be turned off.
  Widget _weekdayPicker(AppLocalizations l) => Container(
        width: double.infinity,
        color: AppColors.accent.withValues(alpha: 0.10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final wd in kWeekOrderMonFirst)
              _chip(
                label: weekdayNarrow(wd, l),
                selected: _weekdays.contains(wd),
                onTap: () => _toggle(_weekdays, wd),
              ),
          ],
        ),
      );

  /// The 1–31 grid, seven columns. Multi-select, minimum one. A note appears
  /// when any short-month day (29/30/31) is chosen.
  Widget _dayOfMonthPicker(AppLocalizations l) {
    final hasShortDay = _daysOfMonth.any((d) => d >= 29);
    return Container(
      width: double.infinity,
      color: AppColors.accent.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
            children: [
              for (var d = 1; d <= 31; d++)
                _gridCell(
                  label: '$d',
                  selected: _daysOfMonth.contains(d),
                  onTap: () => _toggle(_daysOfMonth, d),
                ),
            ],
          ),
          if (hasShortDay) ...[
            const SizedBox(height: 8),
            Text(
              l.rsShorterMonths,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.accentLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Toggles [value] in [set] but refuses to empty the set (minimum one).
  void _toggle(Set<int> set, int value) {
    setState(() {
      if (set.contains(value)) {
        if (set.length > 1) set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.sheetAccountName,
              ),
            ),
          ),
        ),
      );

  Widget _gridCell({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.sheetAccountName,
              ),
            ),
          ),
        ),
      );

  /// The live "Next …" preview, computed from a transient Task so it uses the
  /// exact same [Task.nextOccurrence] logic the store will run.
  Widget _preview(AppLocalizations l) {
    final sel = _selection;
    final probe = Task(
      id: '',
      title: '',
      linkedAccountId: '',
      expectedAmount: 0,
      dueDate: widget.date,
      icon: Icons.repeat_rounded,
      repeats: sel.freq,
      weekdays: sel.weekdays,
      daysOfMonth: sel.daysOfMonth,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        repeatPreviewLine(probe.upcomingPreview(3), sel.freq, l),
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.45,
          color: AppColors.accentLight,
        ),
      ),
    );
  }
}
