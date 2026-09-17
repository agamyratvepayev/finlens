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

/// The interval clause: `Every 3 weeks` / `Every 4 months` for n > 1, and the
/// number-free `Every week` / `Every month` for n == 1 (task 030 §5 — a leading
/// `1` reads as a stutter next to the day list). Russian needs a gendered
/// "every" at n == 1 (каждый/каждую), so it is spelled out per unit; en/tr/tk
/// read naturally as `rcEvery` + the singular noun the plural's `one` form
/// already carries.
String _everyPhrase(int n, RepeatUnit unit, AppLocalizations l) {
  final noun = switch (unit) {
    RepeatUnit.day => l.rcNDays(n),
    RepeatUnit.week => l.rcNWeeks(n),
    RepeatUnit.month => l.rcNMonths(n),
    RepeatUnit.year => l.rcNYears(n),
  };
  if (n != 1) return '${l.rcEvery} $noun';
  if (l.localeName == 'ru') {
    final every = unit == RepeatUnit.week ? 'Каждую' : 'Каждый';
    final single = switch (unit) {
      RepeatUnit.day => 'день',
      RepeatUnit.week => 'неделю',
      RepeatUnit.month => 'месяц',
      RepeatUnit.year => 'год',
    };
    return '$every $single';
  }
  // Drop the leading "1 " from the plural's singular form: "1 month" → "month".
  final single = noun.replaceFirst(RegExp(r'^1\s+'), '');
  return '${l.rcEvery} $single';
}

/// Joins 1–3 day tokens as "a", "a and b" or "a, b and c" (task 030 §5). The
/// last pair uses `rcAnd`; earlier items a plain comma.
String _joinDays(List<String> items, AppLocalizations l) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head ${l.rcAnd} ${items.last}';
}

/// The month day-set as it reads in the summary. English prefixes the article
/// ("the 9th and 14th"); Russian follows the app's established genitive form
/// ("9-го и 14-го числа", mirroring `rsMonthlyOnDay`); tr/tk list the ordinals
/// as `ordinalDay` renders them. [days] is sorted and may include
/// [kLastDayOfMonth].
String _monthDaysClause(List<int> days, AppLocalizations l) {
  final hasLast = days.contains(kLastDayOfMonth);
  final nums = [for (final d in days) if (d != kLastDayOfMonth) ordinalDay(d, l)];
  if (l.localeName == 'ru') {
    return _joinDays([
      if (nums.isNotEmpty) '${_joinDays(nums, l)} числа',
      if (hasLast) l.rcLastDay,
    ], l);
  }
  final tokens = [
    for (final d in days) d == kLastDayOfMonth ? l.rcLastDay : ordinalDay(d, l),
  ];
  final joined = _joinDays(tokens, l);
  return l.localeName == 'en' ? 'the $joined' : joined;
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
        // Different type sizes on one line: align the letters, not the boxes.
        // Centring put the 17pt title's line box and the Cancel tap target on
        // the same midpoint, leaving their baselines apart.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
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

  // The interval is typed in place (task 030 §2.2), on the system numeric
  // keyboard — a count, not money, so not the app's `NumericKeypad`.
  final _nFocus = FocusNode();
  late final _nCtl = TextEditingController(text: '$_n');

  /// True while the engine honours more than one day per period.
  ///
  /// `Recurrence._nextCustom` reads the day-set only when the interval is 1; for
  /// wider cadences it steps whole periods from the anchor and keeps a single
  /// day. Offering a multi-select there collects input that is silently dropped
  /// at save, so the grid narrows to match what will actually happen (task 030
  /// §4). Widening the engine is a separate task — see the spec's Non-goals.
  bool get _multiDay => _n == 1;

  @override
  void initState() {
    super.initState();
    // Clamp the typed interval and collapse day-sets when focus leaves.
    _nFocus.addListener(() {
      if (!_nFocus.hasFocus) _commitN();
    });
  }

  @override
  void dispose() {
    _nFocus.dispose();
    _nCtl.dispose();
    super.dispose();
  }

  void _setUnit(RepeatUnit u) => setState(() {
        _unit = u;
        if (u == RepeatUnit.week && _weekdays.isEmpty) {
          _weekdays = {widget.date.weekday};
        }
        if (u == RepeatUnit.month && _daysOfMonth.isEmpty) {
          _daysOfMonth = {widget.date.day};
        }
      });

  /// Adds [value] to [set]. With interval 1 it toggles but refuses to empty the
  /// set — a recurrence on no day is not a recurrence (§5). With interval > 1
  /// the engine keeps a single day, so selection replaces rather than
  /// accumulates (task 030 §4).
  void _toggle(Set<int> set, int value) {
    setState(() {
      if (_multiDay) {
        if (set.contains(value)) {
          if (set.length > 1) set.remove(value);
        } else {
          set.add(value);
        }
      } else {
        set
          ..clear()
          ..add(value);
      }
    });
  }

  /// Applies a new interval. When [rewrite] the value is committed: it is
  /// clamped and the field text is rewritten (steppers, blur, Done). While the
  /// user types it is applied raw so the headline and grid track each keystroke;
  /// the clamp waits for blur. Raising the interval above 1 collapses any
  /// multi-day set to its lowest day, on screen (task 030 §4).
  void _applyN(int v, {required bool rewrite}) {
    setState(() {
      _n = rewrite ? v.clamp(1, 99) : v;
      if (_n != 1) {
        if (_weekdays.length > 1) {
          _weekdays = {_weekdays.reduce((a, b) => a < b ? a : b)};
        }
        if (_daysOfMonth.length > 1) {
          _daysOfMonth = {_daysOfMonth.reduce((a, b) => a < b ? a : b)};
        }
      }
      if (rewrite) {
        _nCtl.text = '$_n';
        _nCtl.selection = TextSelection.collapsed(offset: _nCtl.text.length);
      }
    });
  }

  /// Commits the typed interval on blur / Done. An empty field restores the last
  /// valid value.
  void _commitN() => _applyN(int.tryParse(_nCtl.text) ?? _n, rewrite: true);

  void _stepN(int delta) => _applyN((_n + delta).clamp(1, 99), rewrite: true);

  /// The card headline: the interval clause plus the day-set, when the unit has
  /// one (task 030 §5). Day and year units carry no day-set.
  String _summaryLine(AppLocalizations l) {
    final every = _everyPhrase(_n, _unit, l);
    final days = switch (_unit) {
      RepeatUnit.day || RepeatUnit.year => null,
      RepeatUnit.week =>
        _joinDays([for (final d in (_weekdays.toList()..sort())) weekdayShort(d, l)], l),
      RepeatUnit.month => _monthDaysClause(_daysOfMonth.toList()..sort(), l),
    };
    return days == null ? every : l.rcEveryOnDays(every, days);
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
                _sectionLabel(_multiDay ? l.rcOnTheseDays : l.rcOnThisDay),
                _weekdayCard(l),
              ],
              if (_unit == RepeatUnit.month) ...[
                _sectionLabel(_multiDay ? l.rcOnTheseDays : l.rcOnThisDay),
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
            // The live, plural-correct reading of the whole rule — interval and
            // days. Ellipsises rather than wrapping or shoving the stepper (§5).
            Row(
              children: [
                Expanded(
                  child: Text(
                    _summaryLine(l),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
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
          _stepButton(Icons.remove_rounded, _n > 1, () => _stepN(-1)),
          // The interval is typed here — no fourth sheet (task 030 §2.2). Sized
          // to its digits, min 44×44 tap target, tabular figures, digits only,
          // clamped 1..99 on blur.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: IntrinsicWidth(
              child: TextField(
                controller: _nCtl,
                focusNode: _nFocus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                cursorColor: AppColors.accent,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()]),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
                  border: InputBorder.none,
                ),
                onChanged: (t) {
                  final v = int.tryParse(t);
                  if (v != null) _applyN(v, rewrite: false);
                },
                onEditingComplete: _commitN,
              ),
            ),
          ),
          _stepButton(Icons.add_rounded, _n < 99, () => _stepN(1)),
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

  // The count is typed in the After row (task 030 §2.1). Tapping the row selects
  // `after` and focuses the field in one move; there is no second sheet and no
  // Done button but the sheet's own.
  final _countFocus = FocusNode();
  late final _countCtl = TextEditingController(text: '$_count');

  @override
  void initState() {
    super.initState();
    _countFocus.addListener(() {
      // Clamp on blur (never per keystroke), and repaint the accent outline.
      if (!_countFocus.hasFocus) _commitCount();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countFocus.dispose();
    _countCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDateTimeSheet(
      context,
      initial: _date,
      // The end date must be strictly after the transaction's own date (§6).
      firstDate: DateTime(widget.date.year, widget.date.month, widget.date.day)
          .add(const Duration(days: 1)),
      lastDate: DateTime(2100),
      now: StoreScope.read(context).today,
    );
    if (d == null || !mounted) return;
    setState(() {
      _mode = _EndsMode.onDate;
      _date = d;
    });
  }

  void _selectAfter() {
    setState(() => _mode = _EndsMode.after);
    _countFocus.requestFocus();
  }

  /// Commits the typed count on blur / Done. Clamp waits for here so typing the
  /// first `1` of `12` is never snapped to `2`; the floor is 2 (one occurrence
  /// is not a repeat) and the ceiling 999. An empty field restores the last
  /// valid value (§2.1).
  void _commitCount() {
    final v = int.tryParse(_countCtl.text) ?? _count;
    setState(() {
      _count = v.clamp(2, 999);
      _countCtl.text = '$_count';
      _countCtl.selection =
          TextSelection.collapsed(offset: _countCtl.text.length);
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
                mode: _EndsMode.never,
                label: l.repeatNever,
                value: null,
                onTap: () => setState(() => _mode = _EndsMode.never),
              ),
              _hair(),
              _endsRow(
                mode: _EndsMode.onDate,
                label: l.rcOnDate,
                value: dayMonthYear(_date, l),
                onTap: _pickDate,
              ),
              _hair(),
              _afterRow(l),
            ]),
            _doneButton(context, () {
              // Commit any in-progress typing before returning the result (§2.1).
              if (_mode == _EndsMode.after) _commitCount();
              Navigator.of(context).pop(_result());
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// A round clear button in the selected row's trailing slot: the way to undo a
  /// value belongs beside the value, not three rows up (task 030 §3).
  Widget _clearButton() => Semantics(
        button: true,
        label: AppLocalizations.of(context).actionClear,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _mode = _EndsMode.never),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.textSecondary),
            ),
          ),
        ),
      );

  /// The Never and On-a-date rows. The selected row's tick is replaced by a
  /// clear button (task 030 §3) — except Never, which has no value to clear and
  /// keeps its tick. Unselected rows show their candidate value dimmed with a
  /// chevron, so both possibilities stay legible (§6).
  Widget _endsRow({
    required _EndsMode mode,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    final selected = _mode == mode;
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
                      color: selected
                          ? AppColors.accentLight
                          : AppColors.textTertiary,
                    )),
              if (selected && value != null)
                _clearButton()
              else if (selected) ...[
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

  /// The After row. When selected the count is typed in place (task 030 §2.1):
  /// a digits-only field sized to its content, the unit word beside it, and a
  /// clear button. Focus draws the accent outline `TxnNoteFieldRow` uses, inset
  /// so the content does not shift when it appears. Unselected, it reads like
  /// the others — dim value, chevron — and a tap selects and focuses it.
  Widget _afterRow(AppLocalizations l) {
    final selected = _mode == _EndsMode.after;
    final focused = selected && _countFocus.hasFocus;
    // The plural unit word from rcTimes with the number removed → "times".
    final word =
        l.rcTimes(_count).replaceFirst(RegExp('^$_count' r'\s*'), '').trim();

    final trailing = selected
        ? [
            IntrinsicWidth(
              child: TextField(
                controller: _countCtl,
                focusNode: _countFocus,
                textAlign: TextAlign.end,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                cursorColor: AppColors.accent,
                style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.accentLight,
                    fontFeatures: [FontFeature.tabularFigures()]),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                onChanged: (t) {
                  final v = int.tryParse(t);
                  // Track the typed value live (for the plural word) but do not
                  // clamp until blur.
                  if (v != null) setState(() => _count = v);
                },
                onEditingComplete: _commitCount,
              ),
            ),
            const SizedBox(width: 4),
            Text(word,
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.accentLight)),
            _clearButton(),
          ]
        : [
            Text(l.rcTimes(_count),
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.textTertiary)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.formChevron),
          ];

    final content = Row(
      children: [
        Expanded(
          child: Text(l.rcAfter,
              style: TextStyle(
                fontSize: 14.5,
                color: selected ? Colors.white : AppColors.sheetAccountName,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
        ...trailing,
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${l.rcAfter} ${l.rcTimes(_count)}',
      child: InkWell(
        onTap: _selectAfter,
        child: focused
            // The accent outline: margin/padding swapped by 3 so content holds
            // still (§2.1, mirroring TxnNoteFieldRow).
            ? Container(
                margin: const EdgeInsets.all(3),
                constraints:
                    const BoxConstraints(minHeight: kSheetRowHeight - 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: content,
              )
            : Container(
                constraints: const BoxConstraints(minHeight: kSheetRowHeight),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: content,
              ),
      ),
    );
  }
}
