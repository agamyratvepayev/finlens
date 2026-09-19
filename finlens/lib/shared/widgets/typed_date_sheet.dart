import 'package:flutter/material.dart';

import '../../core/store/app_store.dart';
import '../../core/utils/date_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'month_calendar.dart';
import 'typed_date_field.dart';

/// An app-native, date-only picker with a **typed field and a calendar** (Task
/// 25 §2). Typing reaches a far date fast (a goal's target is a year out);
/// tapping reaches a near one. The two are views of one value and stay in step:
/// a valid typed date moves the calendar, a tapped day fills the field.
///
/// Replaces Flutter's stock `showDatePicker` at every date-only call site, whose
/// `InputDatePickerFormField` could not format as you type and offered no
/// `inputFormatters` to make it. Every caller's [firstDate]/[lastDate] and seed
/// are preserved exactly — this changes how a date is entered, never which dates
/// are allowed. Returns the chosen date, or null if dismissed.
Future<DateTime?> showTypedDateSheet(
  BuildContext context, {
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialMonth,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    isScrollControlled: true,
    builder: (_) => _TypedDateSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialMonth: initialMonth,
      today: StoreScope.read(context).today,
    ),
  );
}

class _TypedDateSheet extends StatefulWidget {
  const _TypedDateSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.initialMonth,
    required this.today,
  });

  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialMonth;
  final DateTime today;

  @override
  State<_TypedDateSheet> createState() => _TypedDateSheetState();
}

class _TypedDateSheetState extends State<_TypedDateSheet> {
  late final TextEditingController _controller;
  late DateEntry _entry;
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialDate;
    _entry = seed == null ? DateEntry.empty : DateEntry.fromDate(seed);
    _selected = seed;
    _controller = TextEditingController(text: _entry.text);
    // Field empty → open the calendar on the anchor month (a goal target opens
    // on next year, per its seed); otherwise on the seeded date's month.
    _month = DateTime(
      (seed ?? widget.initialMonth ?? widget.today).year,
      (seed ?? widget.initialMonth ?? widget.today).month,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime? get _validDate =>
      _entry.dateWithin(widget.firstDate, widget.lastDate);

  String? _errorFor(AppLocalizations l) {
    switch (_entry.validate(
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    )) {
      case DateEntryError.notReal:
        return l.dateErrorNotReal;
      case DateEntryError.outOfRange:
        return l.dateErrorOutOfRange;
      case DateEntryError.incomplete:
      case DateEntryError.ok:
        return null;
    }
  }

  void _onFieldChanged(DateEntry entry) {
    setState(() {
      _entry = entry;
      final valid = entry.dateWithin(widget.firstDate, widget.lastDate);
      if (valid != null) {
        // A valid typed date moves the calendar and selects the day (§2).
        _selected = valid;
        _month = DateTime(valid.year, valid.month);
      } else {
        _selected = null;
      }
    });
  }

  void _onCalendarPick(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    setState(() {
      _entry = DateEntry.fromDate(d);
      _selected = d;
      _month = DateTime(d.year, d.month);
    });
    // Fill the field, formatted, with the caret at the end (§2).
    TypedDateField.setText(_controller, _entry);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canConfirm = _validDate != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.gutter,
          right: Insets.gutter,
          top: Insets.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: Insets.lg),
              TypedDateField(
                controller: _controller,
                onChanged: _onFieldChanged,
                errorText: _errorFor(l),
                autofocus: true,
              ),
              const SizedBox(height: Insets.lg),
              MonthCalendar(
                month: _month,
                selected: _selected,
                today: widget.today,
                firstMonth: DateTime(
                  widget.firstDate.year,
                  widget.firstDate.month,
                ),
                lastMonth: DateTime(
                  widget.lastDate.year,
                  widget.lastDate.month,
                ),
                isEnabled: (d) =>
                    !d.isBefore(
                      DateTime(
                        widget.firstDate.year,
                        widget.firstDate.month,
                        widget.firstDate.day,
                      ),
                    ) &&
                    !d.isAfter(
                      DateTime(
                        widget.lastDate.year,
                        widget.lastDate.month,
                        widget.lastDate.day,
                      ),
                    ),
                onMonthChanged: (m) => setState(() => _month = m),
                onPick: _onCalendarPick,
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                      ),
                      child: Text(l.actionCancel),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: canConfirm
                          ? () => Navigator.of(context).pop(_validDate)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.tint(
                          AppColors.accent,
                          0.3,
                        ),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                      ),
                      child: Text(l.actionDone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
