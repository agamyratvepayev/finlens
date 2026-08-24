import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import 'edit_scaffold.dart';

/// Spec 5.7 — task parameters, plus the strict separation between acting on
/// *this occurrence* and acting on *the whole series*.
///
/// The classic calendar-app trap is a user who wants to skip one month and
/// instead cancels the whole subscription; the two actions are therefore
/// separate rows, and the single-occurrence one names its date.
class EditTaskScreen extends StatefulWidget {
  const EditTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Task _task = _store.taskById(widget.taskId)!;

  late final TextEditingController _title =
      TextEditingController(text: _task.title);
  late final TextEditingController _amount = TextEditingController(
    text: _task.expectedAmount.abs() % 1 == 0
        ? _task.expectedAmount.abs().toStringAsFixed(0)
        : _task.expectedAmount.abs().toStringAsFixed(2),
  );

  late String _accountId = _task.linkedAccountId;
  late String? _categoryId = _task.categoryId;
  late DateTime _due = _task.dueDate;
  late RepeatFrequency _repeats = _task.repeats;
  late final Priority _priority = _task.priority;
  late bool _payOut = _task.isPayOut;
  late bool _remind = _task.reminderDaysBefore != null;
  late final int _remindDays = _task.reminderDaysBefore ?? 2;
  late final TimeOfDay _remindTime =
      _task.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  List<DateTime> get _preview {
    if (_repeats == RepeatFrequency.none) return const [];
    final out = <DateTime>[];
    var d = _due;
    for (var i = 0; i < 3; i++) {
      out.add(d);
      d = switch (_repeats) {
        RepeatFrequency.none => d,
        RepeatFrequency.weekly => d.add(const Duration(days: 7)),
        RepeatFrequency.monthly => DateTime(d.year, d.month + 1, d.day),
        RepeatFrequency.quarterly => DateTime(d.year, d.month + 3, d.day),
        RepeatFrequency.yearly => DateTime(d.year + 1, d.month, d.day),
      };
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final account = store.accountById(_accountId);

    return EditScaffold(
      title: l.etTitle,
      onSave:
          _title.text.trim().isNotEmpty && _amountValue > 0 ? _save : null,
      children: [
        FormSection(
          children: [
            TextFieldRow(
              icon: _task.icon,
              label: l.etTaskTitle,
              controller: _title,
              trailing: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        FormSection(
          children: [
            FormRow(
              icon: Icons.account_balance_wallet_rounded,
              label: _payOut ? l.etPaidFrom : l.etPaidInto,
              subtitle: account?.name ?? l.fieldSelectAccount,
              showChevron: true,
              onTap: () async {
                final a = await pickAccount(context, title: l.etLinkedAccount);
                if (a != null) setState(() => _accountId = a.id);
              },
            ),
            FormRow(
              icon: Icons.swap_vert_rounded,
              label: l.fieldDirection,
              trailing: SegmentedPicker<bool>(
                values: const [true, false],
                labelOf: (v) => v ? l.etPayOut : l.etPayIn,
                selected: _payOut,
                onChanged: (v) => setState(() => _payOut = v),
              ),
            ),
            TextFieldRow(
              icon: Icons.attach_money_rounded,
              label: l.etExpectedAmount,
              controller: _amount,
              hint: '0',
              trailing: Text(
                currencySymbol(account?.currency ?? 'USD'),
                style: AppText.amount.copyWith(color: AppColors.textSecondary),
              ),
            ),
            FormRow(
              icon: Icons.category_rounded,
              label: l.fieldCategory,
              subtitle: store.categoryById(_categoryId)?.name ??
                  l.etCategoryHint,
              showChevron: true,
              onTap: () async {
                final c = await pickCategory(
                  context,
                  type: _payOut ? CategoryType.expense : CategoryType.income,
                );
                if (c != null) setState(() => _categoryId = c.id);
              },
            ),
            FormRow(
              icon: Icons.event_rounded,
              label: l.etNextDue,
              value: dayMonth(_due, AppLocalizations.of(context)),
              showChevron: true,
              onTap: _pickDue,
            ),
            FormRow(
              icon: Icons.repeat_rounded,
              label: _repeats == RepeatFrequency.none
                  ? l.etRepeats
                  : l.etRepeatsCadence(_repeats.label(l).toLowerCase()),
              // Spec 5.7 — the preview is what makes a series comprehensible.
              subtitle: _preview.isEmpty
                  ? l.etOneOff
                  : '${_preview.map((d) => dayMonth(d, AppLocalizations.of(context))).join(' · ')} …',
              value:
                  _preview.isEmpty ? _repeats.label(AppLocalizations.of(context)) : null,
              showChevron: true,
              onTap: _pickRepeat,
            ),
            ToggleRow(
              icon: Icons.alarm_rounded,
              label: l.etRemindMe,
              subtitle: _remind
                  ? l.etRemindBefore('$_remindDays', _remindTime.format(context))
                  : null,
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
            ),
          ],
        ),
        FormSection(
          children: [
            FormRow(
              icon: Icons.check_circle_rounded,
              label: l.etMarkPaid,
              subtitle: _payOut ? l.etMarkPaidExpense : l.etMarkPaidIncome,
              showChevron: true,
              onTap: _markPaid,
            ),
            if (_task.isRecurring)
              FormRow(
                icon: Icons.skip_next_rounded,
                label: l.etSkipThisMonth,
                subtitle: l.etSeriesContinues(
                    monthShort(_task.nextOccurrence(_due).month, l)),
                showChevron: true,
                onTap: _skip,
              ),
          ],
        ),
        // Spec 5.7 — two distinct deletions, the first named by its date.
        DestructiveRow(
          label: l.etDeleteOnly(dayMonth(_due, l)),
          onTap: _deleteOccurrence,
        ),
        if (_task.isRecurring)
          DestructiveRow(
            label: l.etDeleteWholeSeries,
            subtitle: l.etAllFutureReminders(_task.title),
            onTap: _deleteSeries,
          ),
      ],
    );
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    setState(() {
      _due = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _due.hour,
        time?.minute ?? _due.minute,
      );
    });
  }

  Future<void> _pickRepeat() async {
    final picked = await showAppSheet<RepeatFrequency>(
      context,
      title: AppLocalizations.of(context).etRepeats,
      initialSize: 0.5,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          0,
          Insets.gutter,
          Insets.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < RepeatFrequency.values.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  FormRow(
                    label:
                        RepeatFrequency.values[i].label(AppLocalizations.of(context)),
                    onTap: () =>
                        Navigator.of(context).pop(RepeatFrequency.values[i]),
                    trailing: RepeatFrequency.values[i] == _repeats
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.accentSoft,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _repeats = picked);
  }

  void _save() {
    _store.updateTask(
      _task,
      title: _title.text.trim(),
      linkedAccountId: _accountId,
      expectedAmount: _payOut ? -_amountValue : _amountValue,
      dueDate: _due,
      categoryId: _categoryId,
      repeats: _repeats,
      priority: _priority,
      reminderDaysBefore: _remind ? _remindDays : null,
      reminderTime: _remind ? _remindTime : null,
      clearReminder: !_remind,
    );
    Navigator.of(context).pop();
  }

  /// Spec 5.7 — writes a real Ledger entry, then advances the series.
  void _markPaid() {
    _store.markTaskPaid(_task);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              AppLocalizations.of(context).etRecordedInLedger(_task.title))),
    );
  }

  /// Spec 5.7 — unlike Mark as paid, this writes nothing to the Ledger.
  void _skip() {
    _store.skipTask(_task);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)
            .etSkippedNext(dayMonth(_task.dueDate, AppLocalizations.of(context)))),
      ),
    );
  }

  Future<void> _deleteOccurrence() async {
    final l = AppLocalizations.of(context);
    final next = _task.nextOccurrence(_due);
    final ok = await showDestructiveConfirm(
      context,
      title: l.etDeleteOnlyTitle(dayMonth(_due, l)),
      message: _task.isRecurring ? l.etJustThisOne : l.etOneOffRemoved,
      impact: [
        if (_task.isRecurring) ...[
          ImpactLine.kept(l.etSeriesContinuesOn(dayMonth(next, l))),
          ImpactLine.kept(l.etNoLedgerEntry),
        ] else
          ImpactLine.kept(l.etLedgerUntouched),
        ImpactLine.lost(l.etDisappears(dayMonth(_due, l))),
      ],
      confirmLabel: l.etDeleteDate(dayMonth(_due, l)),
    );
    if (!ok || !mounted) return;
    _store.deleteTaskOccurrence(_task);
    Navigator.of(context).pop();
  }

  Future<void> _deleteSeries() async {
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.etDeleteSeriesTitle(_task.title),
      message: l.etDeleteSeriesMsg,
      impact: [
        ImpactLine.kept(l.etPaymentsStay),
        ImpactLine.lost(l.etAllRemindersCancelled),
        ImpactLine.lost(l.etOutgoingsDrop(money(_task.expectedAmount.abs()))),
      ],
      confirmLabel: l.etDeleteSeries,
    );
    if (!ok || !mounted) return;
    _store.deleteTaskSeries(_task);
    Navigator.of(context).pop();
  }
}
