import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'date_time_sheet.dart';
import 'widgets/form_kit.dart';

/// The full outcome of the transaction form's Repeat chooser: the cadence, its
/// day-sets, a custom `Every N unit` rule, and an end condition. A value the
/// app already knows how to store — it becomes a Planner Task on save (Repeat
/// spec §1). Distinct from the Planner sheet's [RepeatSelection], which offers a
/// different set of cadences and no end condition.
class TxnRepeatSelection {
  const TxnRepeatSelection({
    required this.freq,
    this.weekdays = const {},
    this.daysOfMonth = const {},
    this.interval = 1,
    this.unit,
    this.endDate,
    this.endCount,
  });

  final RepeatFrequency freq;
  final Set<int> weekdays;
  final Set<int> daysOfMonth;

  /// `Every N unit` step for a [RepeatFrequency.custom] rule; 1 otherwise.
  final int interval;

  /// The custom rule's unit; null unless [freq] is `custom`.
  final RepeatUnit? unit;

  /// End condition — at most one is non-null; both null means it never ends.
  final DateTime? endDate;
  final int? endCount;
}

/// The frequency word shown on the Repeat row and in the sheet — no day detail.
/// The five words the sheet offers plus a defensive fold of the Planner-only
/// cadences to `Custom` (so a transaction edited from a biweekly/quarterly task
/// still reads sensibly).
String txnRepeatWord(RepeatFrequency f, AppLocalizations l) => switch (f) {
      RepeatFrequency.none => l.repeatNever,
      RepeatFrequency.daily => l.rcDaily,
      RepeatFrequency.weekly => l.repeatWeekly,
      RepeatFrequency.monthly => l.repeatMonthly,
      RepeatFrequency.custom ||
      RepeatFrequency.biweekly ||
      RepeatFrequency.quarterly ||
      RepeatFrequency.yearly =>
        l.rcCustom,
    };

/// Composes `Every 3 weeks` / `Every 1 week` with an ICU-plural unit noun.
String _everyPhrase(int n, RepeatUnit unit, AppLocalizations l) {
  final noun = switch (unit) {
    RepeatUnit.day => l.rcNDays(n),
    RepeatUnit.week => l.rcNWeeks(n),
    RepeatUnit.month => l.rcNMonths(n),
    RepeatUnit.year => l.rcNYears(n),
  };
  return '${l.rcEvery} $noun';
}

/// Opens the Repeat chooser. Returns the selection on Done, or null when
/// dismissed (the caller keeps its current value).
Future<TxnRepeatSelection?> showTxnRepeatSheet(
  BuildContext context, {
  required TxnRepeatSelection current,
  required DateTime date,
}) {
  return showModalBottomSheet<TxnRepeatSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RepeatSheet(current: current, date: date),
  );
}

// ── Shared sheet chrome ──────────────────────────────────────────────────────

Widget _grabber() => Container(
      width: 34,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.sheetGrabber,
        borderRadius: BorderRadius.circular(2),
      ),
    );

/// Title on the left, a `Cancel` on the right. Done is a bottom button so it
/// reads as the commit (Repeat spec §4).
Widget _sheetHeader(BuildContext context, String title, VoidCallback onCancel) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: Text(AppLocalizations.of(context).actionCancel,
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

Widget _doneButton(BuildContext context, VoidCallback onDone) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13)),
          ),
          child: Text(AppLocalizations.of(context).actionDone,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w600)),
        ),
      ),
    );

Widget _sheetCard(List<Widget> children) => Container(
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

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07 * 10.5,
              color: AppColors.textTertiary,
            )),
      ),
    );

// ── Repeat sheet (§4) ────────────────────────────────────────────────────────

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.current, required this.date});

  final TxnRepeatSelection current;
  final DateTime date;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  // The five cadences this sheet offers, in display order.
  static const _rows = [
    RepeatFrequency.none,
    RepeatFrequency.daily,
    RepeatFrequency.weekly,
    RepeatFrequency.monthly,
    RepeatFrequency.custom,
  ];

  late RepeatFrequency _freq = _normalise(widget.current.freq);
  late Set<int> _weekdays = {...widget.current.weekdays};
  late Set<int> _daysOfMonth = {...widget.current.daysOfMonth};
  late int _interval = widget.current.interval;
  late RepeatUnit _unit = widget.current.unit ?? RepeatUnit.month;
  late DateTime? _endDate = widget.current.endDate;
  late int? _endCount = widget.current.endCount;

  /// Folds a Planner-only cadence onto `custom` so an edited transaction lands
  /// on the Custom row rather than an option this sheet does not show.
  RepeatFrequency _normalise(RepeatFrequency f) => switch (f) {
        RepeatFrequency.biweekly ||
        RepeatFrequency.quarterly ||
        RepeatFrequency.yearly =>
          RepeatFrequency.custom,
        _ => f,
      };

  Future<void> _selectFreq(RepeatFrequency f) async {
    if (f == RepeatFrequency.custom) {
      await _openCustom();
      return;
    }
    setState(() {
      _freq = f;
      // Leaving `custom` discards its rule; switching to `Never` also clears
      // the end condition (Repeat spec §4). Plain Weekly/Monthly seed the
      // transaction's own weekday / day-of-month so the row means "on this day".
      _interval = 1;
      _unit = RepeatUnit.month;
      if (f == RepeatFrequency.none) {
        _weekdays = {};
        _daysOfMonth = {};
        _endDate = null;
        _endCount = null;
      } else if (f == RepeatFrequency.weekly) {
        _weekdays = {widget.date.weekday};
        _daysOfMonth = {};
      } else if (f == RepeatFrequency.monthly) {
        _daysOfMonth = {widget.date.day};
        _weekdays = {};
      } else {
        _weekdays = {};
        _daysOfMonth = {};
      }
    });
  }

  Future<void> _openCustom() async {
    final res = await _showCustomSheet(
      context,
      date: widget.date,
      interval: _interval,
      unit: _unit,
      weekdays: _weekdays,
      daysOfMonth: _daysOfMonth,
    );
    if (res == null || !mounted) return;
    setState(() {
      _freq = RepeatFrequency.custom;
      _interval = res.interval;
      _unit = res.unit;
      _weekdays = res.weekdays;
      _daysOfMonth = res.daysOfMonth;
    });
  }

  Future<void> _openEnds() async {
    final res = await _showEndsSheet(
      context,
      date: widget.date,
      endDate: _endDate,
      endCount: _endCount,
    );
    if (res == null || !mounted) return;
    setState(() {
      _endDate = res.date;
      _endCount = res.count;
    });
  }

  String _endsSummary(AppLocalizations l) => _endDate != null
      ? dayMonthYear(_endDate!, l)
      : _endCount != null
          ? l.rcTimes(_endCount!)
          : l.repeatNever;

  TxnRepeatSelection _result() {
    if (_freq == RepeatFrequency.none) {
      return const TxnRepeatSelection(freq: RepeatFrequency.none);
    }
    return TxnRepeatSelection(
      freq: _freq,
      weekdays: {..._weekdays},
      daysOfMonth: {..._daysOfMonth},
      interval: _interval,
      unit: _freq == RepeatFrequency.custom ? _unit : null,
      endDate: _endDate,
      endCount: _endCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _grabber(),
            _sheetHeader(context, l.rsRepeat, () => Navigator.of(context).pop()),
            _sheetCard([
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) _hair(),
                _freqRow(_rows[i], l),
              ],
            ]),
            // The Ends row is meaningless on something that never repeats, so it
            // appears only when a cadence is chosen (§4).
            if (_freq != RepeatFrequency.none)
              _sheetCard([_endsRow(l)]),
            _doneButton(context, () => Navigator.of(context).pop(_result())),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _freqRow(RepeatFrequency f, AppLocalizations l) {
    final selected = _freq == f;
    final isCustom = f == RepeatFrequency.custom;
    return Semantics(
      button: true,
      selected: selected,
      label: txnRepeatWord(f, l),
      child: InkWell(
        onTap: () => _selectFreq(f),
        child: Container(
          constraints: const BoxConstraints(minHeight: kSheetRowHeight),
          color: selected ? AppColors.accent.withValues(alpha: 0.16) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  txnRepeatWord(f, l),
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
              // Custom always advertises that it opens a sheet.
              if (isCustom) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.formChevron),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _endsRow(AppLocalizations l) {
    return Semantics(
      button: true,
      label: '${l.rcEnds} ${_endsSummary(l)}',
      child: InkWell(
        onTap: _openEnds,
        child: Container(
          constraints: const BoxConstraints(minHeight: kSheetRowHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l.rcEnds,
                    style: const TextStyle(
                        fontSize: 14.5, color: Colors.white)),
              ),
              Text(_endsSummary(l),
                  style: const TextStyle(
                      fontSize: 14.5, color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.formChevron),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom sheet (§5) ────────────────────────────────────────────────────────

class _CustomResult {
  const _CustomResult(this.interval, this.unit, this.weekdays, this.daysOfMonth);
  final int interval;
  final RepeatUnit unit;
  final Set<int> weekdays;
  final Set<int> daysOfMonth;
}

/// The value 32 stands for "the last day of the month, whatever it is" — the
/// month grid's `Last` cell. The occurrence engine clamps any day past a
/// month's length to that month's last day, so 32 always resolves to the last
/// day, and 31 + Last collapse to one occurrence in a 31-day month (§5, §11).
const int kLastDayOfMonth = 32;

Future<_CustomResult?> _showCustomSheet(
  BuildContext context, {
  required DateTime date,
  required int interval,
  required RepeatUnit unit,
  required Set<int> weekdays,
  required Set<int> daysOfMonth,
}) {
  return showModalBottomSheet<_CustomResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CustomSheet(
      date: date,
      interval: interval,
      unit: unit,
      weekdays: weekdays,
      daysOfMonth: daysOfMonth,
    ),
  );
}

class _CustomSheet extends StatefulWidget {
  const _CustomSheet({
    required this.date,
    required this.interval,
    required this.unit,
    required this.weekdays,
    required this.daysOfMonth,
  });

  final DateTime date;
  final int interval;
  final RepeatUnit unit;
  final Set<int> weekdays;
  final Set<int> daysOfMonth;

  @override
  State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  late int _n = widget.interval.clamp(1, 99);
  late RepeatUnit _unit = widget.unit;
  // Both grids seed from the transaction's own date, so the user who only
  // changes N gets a sensible day set for free.
  late Set<int> _weekdays =
      widget.weekdays.isEmpty ? {widget.date.weekday} : {...widget.weekdays};
  late Set<int> _daysOfMonth =
      widget.daysOfMonth.isEmpty ? {widget.date.day} : {...widget.daysOfMonth};

  void _setUnit(RepeatUnit u) => setState(() {
        _unit = u;
        if (u == RepeatUnit.week && _weekdays.isEmpty) {
          _weekdays = {widget.date.weekday};
        }
        if (u == RepeatUnit.month && _daysOfMonth.isEmpty) {
          _daysOfMonth = {widget.date.day};
        }
      });

  /// Toggles [value] in [set] but refuses to empty it — a recurrence that
  /// recurs on no day is not a recurrence (§5).
  void _toggle(Set<int> set, int value) {
    setState(() {
      if (set.contains(value)) {
        if (set.length > 1) set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  Future<void> _editN() async {
    final v = await _showNumberSheet(
      context,
      title: AppLocalizations.of(context).rcEvery,
      initial: _n,
      min: 1,
      max: 99,
    );
    if (v != null && mounted) setState(() => _n = v);
  }

  _CustomResult _result() => _CustomResult(
        _n,
        _unit,
        _unit == RepeatUnit.week ? {..._weekdays} : {},
        _unit == RepeatUnit.month ? {..._daysOfMonth} : {},
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _grabber(),
              _sheetHeader(
                  context, l.rcCustom, () => Navigator.of(context).pop()),
              _everyControl(l),
              if (_unit == RepeatUnit.week) ...[
                _sectionLabel(l.rcOnTheseDays),
                _weekdayCard(l),
              ],
              if (_unit == RepeatUnit.month) ...[
                _sectionLabel(l.rcOnTheseDays),
                _monthGridCard(l),
              ],
              _doneButton(
                  context, () => Navigator.of(context).pop(_result())),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _everyControl(AppLocalizations l) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The live, plural-correct reading of the rule.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _everyPhrase(_n, _unit, l),
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
                _stepper(),
              ],
            ),
            const SizedBox(height: 12),
            _unitPicker(l),
          ],
        ),
      );

  Widget _stepper() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove_rounded, _n > 1, () {
            if (_n > 1) setState(() => _n--);
          }),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _editN,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              alignment: Alignment.center,
              child: Text('$_n',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ),
          _stepButton(Icons.add_rounded, _n < 99, () {
            if (_n < 99) setState(() => _n++);
          }),
        ],
      );

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) =>
      Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon,
                size: 20,
                color: enabled
                    ? AppColors.accentLight
                    : AppColors.textTertiary),
          ),
        ),
      );

  Widget _unitPicker(AppLocalizations l) {
    final units = <(RepeatUnit, String)>[
      (RepeatUnit.day, l.rcUnitDay),
      (RepeatUnit.week, l.rcUnitWeek),
      (RepeatUnit.month, l.rcUnitMonth),
      (RepeatUnit.year, l.rcUnitYear),
    ];
    return Row(
      children: [
        for (var i = 0; i < units.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: _unit == units[i].$1,
              label: units[i].$2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setUnit(units[i].$1),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _unit == units[i].$1
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    units[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _unit == units[i].$1
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _unit == units[i].$1
                          ? Colors.white
                          : AppColors.sheetAccountName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _weekdayCard(AppLocalizations l) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
        ),
        // Seven flexible cells: each fills a share of the width and is 44pt
        // tall, so the vertical hit target holds even at 320pt where seven
        // fixed 44pt circles would not fit.
        child: Row(
          children: [
            for (final wd in kWeekOrderMonFirst)
              Expanded(
                child: _dayCircle(
                  label: weekdayNarrow(wd, l),
                  selected: _weekdays.contains(wd),
                  onTap: () => _toggle(_weekdays, wd),
                ),
              ),
          ],
        ),
      );

  Widget _dayCircle({
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
          child: SizedBox(
            height: kSheetRowHeight,
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final d = c.maxWidth < 40 ? c.maxWidth : 40.0;
                  return Container(
                    width: d,
                    height: d,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : AppColors.sheetAccountName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

  Widget _monthGridCard(AppLocalizations l) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
        ),
        // 32 cells: days 1..31 plus a final `Last`. Fixed 44pt row height keeps
        // the vertical hit area on target at every width; cell width narrows to
        // fit seven columns (see the report for measured sizes).
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 32,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: kSheetRowHeight,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, i) {
            final isLast = i == 31;
            final day = isLast ? kLastDayOfMonth : i + 1;
            return _gridCell(
              label: isLast ? l.rcLast : '${i + 1}',
              selected: _daysOfMonth.contains(day),
              onTap: () => _toggle(_daysOfMonth, day),
            );
          },
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
              color:
                  selected ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: label.length > 2 ? 11 : 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.sheetAccountName,
              ),
            ),
          ),
        ),
      );
}

// ── Ends sheet (§6) ──────────────────────────────────────────────────────────

class _EndsResult {
  const _EndsResult(this.date, this.count);
  final DateTime? date;
  final int? count;
}

enum _EndsMode { never, onDate, after }

Future<_EndsResult?> _showEndsSheet(
  BuildContext context, {
  required DateTime date,
  required DateTime? endDate,
  required int? endCount,
}) {
  return showModalBottomSheet<_EndsResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EndsSheet(date: date, endDate: endDate, endCount: endCount),
  );
}

class _EndsSheet extends StatefulWidget {
  const _EndsSheet({required this.date, this.endDate, this.endCount});

  final DateTime date;
  final DateTime? endDate;
  final int? endCount;

  @override
  State<_EndsSheet> createState() => _EndsSheetState();
}

class _EndsSheetState extends State<_EndsSheet> {
  late _EndsMode _mode = widget.endDate != null
      ? _EndsMode.onDate
      : widget.endCount != null
          ? _EndsMode.after
          : _EndsMode.never;
  // Candidate values shown (dimmed) even on unselected rows, so both
  // possibilities are visible without choosing them (§6).
  late DateTime _date = widget.endDate ??
      DateTime(widget.date.year + 1, widget.date.month, widget.date.day);
  late int _count = widget.endCount ?? 12;

  Future<void> _pickDate() async {
    final d = await showDateTimeSheet(
      context,
      initial: _date,
      // The end date must be strictly after the transaction's own date (§6).
      firstDate: DateTime(widget.date.year, widget.date.month, widget.date.day)
          .add(const Duration(days: 1)),
      lastDate: DateTime(2100),
      now: AppStore.today,
    );
    if (d == null || !mounted) return;
    setState(() {
      _mode = _EndsMode.onDate;
      _date = d;
    });
  }

  Future<void> _pickCount() async {
    final v = await _showNumberSheet(
      context,
      title: AppLocalizations.of(context).rcAfter,
      initial: _count,
      // At least two — something that happens once is not a repeat (§6). The
      // first occurrence counts toward the total.
      min: 2,
      max: 999,
    );
    if (v == null || !mounted) return;
    setState(() {
      _mode = _EndsMode.after;
      _count = v;
    });
  }

  _EndsResult _result() => switch (_mode) {
        _EndsMode.never => const _EndsResult(null, null),
        _EndsMode.onDate => _EndsResult(_date, null),
        _EndsMode.after => _EndsResult(null, _count),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _grabber(),
            _sheetHeader(context, l.rcEnds, () => Navigator.of(context).pop()),
            _sheetCard([
              _endsRow(
                label: l.repeatNever,
                value: null,
                selected: _mode == _EndsMode.never,
                onTap: () => setState(() => _mode = _EndsMode.never),
              ),
              _hair(),
              _endsRow(
                label: l.rcOnDate,
                value: dayMonthYear(_date, l),
                selected: _mode == _EndsMode.onDate,
                onTap: _pickDate,
              ),
              _hair(),
              _endsRow(
                label: l.rcAfter,
                value: l.rcTimes(_count),
                selected: _mode == _EndsMode.after,
                onTap: _pickCount,
              ),
            ]),
            _doneButton(context, () => Navigator.of(context).pop(_result())),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _endsRow({
    required String label,
    required String? value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: value == null ? label : '$label $value',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: kSheetRowHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: selected ? Colors.white : AppColors.sheetAccountName,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
              if (value != null)
                Text(value,
                    style: TextStyle(
                      fontSize: 14.5,
                      // Selected row's value is primary; the others dim, so both
                      // possibilities are legible without choosing them (§6).
                      color: selected
                          ? AppColors.accentLight
                          : AppColors.textTertiary,
                    )),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.accentLight),
              ] else if (value != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.formChevron),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared number entry ──────────────────────────────────────────────────────

/// A small sheet for typing a bounded integer (the custom `N` and the `After`
/// count). Clamps to [min]..[max] on submit, so the floors the spec sets
/// (N ≥ 1, count ≥ 2) can never be crossed.
Future<int?> _showNumberSheet(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    builder: (_) => _NumberSheet(title: title, initial: initial, min: min, max: max),
  );
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
  });

  final String title;
  final int initial;
  final int min;
  final int max;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(parsed.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                cursorColor: AppColors.accent,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.fieldCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(AppLocalizations.of(context).actionDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
