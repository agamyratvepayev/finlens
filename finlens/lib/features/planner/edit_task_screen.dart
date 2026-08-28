import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import '../quick_add/repeat_sheet.dart';
import 'edit_scaffold.dart';
import 'mark_paid_sheet.dart';

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
  late final TextEditingController _note =
      TextEditingController(text: _task.note ?? '');

  late String _accountId = _task.linkedAccountId;
  late String? _categoryId = _task.categoryId;

  /// Set ⇒ the destination is a liability account and the task is a transfer
  /// (§10.4); mutually exclusive with [_categoryId].
  late String? _payToAccountId = _task.payToAccountId;
  late DateTime _due = _task.dueDate;
  late RepeatFrequency _repeats = _task.repeats;
  late Set<int> _weekdays = {..._task.weekdays};
  late Set<int> _daysOfMonth = {..._task.daysOfMonth};
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
    _note.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  List<DateTime> get _preview {
    if (_repeats == RepeatFrequency.none) return const [];
    // A transient Task runs the one true [Task.nextOccurrence] rule against the
    // locally-edited frequency, due date and day sets.
    return Task(
      id: '',
      title: '',
      linkedAccountId: '',
      expectedAmount: 0,
      dueDate: _due,
      icon: _task.icon,
      repeats: _repeats,
      weekdays: _weekdays,
      daysOfMonth: _daysOfMonth,
    ).upcomingPreview(3);
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
                onChanged: (v) => setState(() {
                  _payOut = v;
                  // Pay-in can only book into an income category, never a
                  // liability account (§10.4).
                  if (!v) _payToAccountId = null;
                }),
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
              label: _payOut ? l.etPaidTo : l.fieldCategory,
              subtitle: _destinationSubtitle(store, l),
              showChevron: true,
              onTap: _pickDestination,
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
                  : l.etRepeatsCadence(
                      repeatCadenceLabel(_repeats, _weekdays, _daysOfMonth, _due, l)
                          .toLowerCase()),
              // Spec 5.7 — the preview is what makes a series comprehensible.
              subtitle: _preview.isEmpty
                  ? l.etOneOff
                  : '${_preview.map((d) => repeatPreviewDate(d, _repeats, AppLocalizations.of(context))).join(' · ')} …',
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
        // The note lives on the task (§7.4) and is written here — Mark as paid,
        // Skip, Pause and Delete moved to the Task detail and the ••• menu (§8).
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.notes_rounded,
              label: l.etNote,
              controller: _note,
              hint: l.etNoteHint,
            ),
          ],
        ),
      ],
    );
  }

  String _destinationSubtitle(AppStore store, AppLocalizations l) {
    if (_payToAccountId != null) {
      return '${store.accountById(_payToAccountId)?.name ?? '—'} · '
          '${l.mpTransferNoCategory}';
    }
    return store.categoryById(_categoryId)?.name ?? l.etCategoryHint;
  }

  Future<void> _pickDestination() async {
    if (!_payOut) {
      final c = await pickCategory(context, type: CategoryType.income);
      if (c != null) {
        setState(() {
          _categoryId = c.id;
          _payToAccountId = null;
        });
      }
      return;
    }
    // Pay-out: expense categories or a liability account (a transfer) (§10.4).
    final store = StoreScope.read(context);
    final picked = await pickPayOutDestination(context, store);
    if (picked == null) return;
    setState(() {
      if (picked.isAccount) {
        _payToAccountId = picked.id;
        _categoryId = null;
      } else {
        _categoryId = picked.id;
        _payToAccountId = null;
      }
    });
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
    final sel = await showRepeatSheet(
      context,
      current: _repeats,
      date: _due,
      weekdays: _weekdays,
      daysOfMonth: _daysOfMonth,
    );
    if (sel == null) return;
    setState(() {
      _repeats = sel.freq;
      _weekdays = sel.weekdays;
      _daysOfMonth = sel.daysOfMonth;
    });
  }

  void _save() {
    final noteText = _note.text.trim();
    _store.updateTask(
      _task,
      title: _title.text.trim(),
      linkedAccountId: _accountId,
      expectedAmount: _payOut ? -_amountValue : _amountValue,
      dueDate: _due,
      categoryId: _payToAccountId == null ? _categoryId : null,
      payToAccountId: _payToAccountId,
      clearCategory: _payToAccountId != null,
      clearPayTo: _payToAccountId == null,
      note: noteText.isEmpty ? '' : noteText,
      repeats: _repeats,
      weekdays: _weekdays,
      daysOfMonth: _daysOfMonth,
      priority: _priority,
      reminderDaysBefore: _remind ? _remindDays : null,
      reminderTime: _remind ? _remindTime : null,
      clearReminder: !_remind,
    );
    Navigator.of(context).pop();
  }
}
