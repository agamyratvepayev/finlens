import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/arithmetic.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/repeat_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/typed_date_sheet.dart';
import '../../theme/app_colors.dart';
import '../quick_add/icon_picker_sheet.dart';
import '../quick_add/pickers.dart';
import '../quick_add/repeat_sheet.dart';
import '../quick_add/widgets/amount_hero.dart';
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

  /// The expected amount, typed on the app keypad (task moved off the system
  /// keyboard so `+ − × ÷` are available like every other amount field). The
  /// stored sign comes from the pay-out/pay-in direction, not the keypad.
  late Expression _amountExpr =
      Expression.ofRaw(AmountEntry.fromDouble(_task.expectedAmount.abs()));
  bool _keypadOpen = false;

  late final TextEditingController _note =
      TextEditingController(text: _task.note ?? '');

  /// The task's own glyph, editable from the title row (task 004 §5a). The
  /// Schedule row tints it by direction, so this previews the glyph, not colour.
  late IconData _icon = _task.icon;

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

  /// Money owed to the user only ever flows in (task 063 §8): a task linked to
  /// a Receivables account is an earning, whatever the stored sign says.
  bool get _isReceivable =>
      _store.accountById(_accountId)?.group == AccountGroup.receivables;

  /// Forces the invariants of receivable mode (§8b): pay-in, and never a
  /// liability transfer. Called on entry and whenever the account changes;
  /// leaving receivable mode keeps pay-in selected, with Direction back on
  /// screen.
  void _normalizeReceivable() {
    if (_isReceivable) {
      _payOut = false;
      _payToAccountId = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _normalizeReceivable();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _currency =>
      _store.accountById(_accountId)?.currency ?? _store.baseCurrency;
  int get _precision => currencyDef(_currency).decimals;

  /// The committed amount, resolving a pending expression silently (spec §5).
  double get _amountValue => _amountExpr.value(_precision) ?? 0;

  /// Focuses the amount row and opens the keypad, closing the system keyboard so
  /// the two are never up together.
  void _focusAmount() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _keypadOpen = true);
  }

  /// Closes the keypad, resolving any pending expression first (spec §5). Called
  /// before opening a picker or saving.
  void _closeKeypad() {
    if (_keypadOpen) {
      setState(() {
        _amountExpr = _amountExpr.evaluated(_precision);
        _keypadOpen = false;
      });
    }
  }

  List<DateTime> get _preview {
    if (_repeats == RepeatFrequency.none) return const [];
    // A transient Task runs the one true [Task.nextOccurrence] rule against the
    // locally-edited frequency, due date and day sets. The stored custom step
    // and end condition ride along (task 063 §7b) so a Custom rule previews
    // truly — though [Task.upcomingPreview] itself does not stop at the end
    // condition (it only steps dates); the end is *shown* beside the preview.
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
      repeatInterval: _task.repeatInterval,
      repeatUnit: _task.repeatUnit,
      repeatEndDate: _task.repeatEndDate,
      repeatEndCount: _task.repeatEndCount,
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
      footer: _keypadOpen
          ? NumericKeypad(
              onKey: (k) => setState(
                  () => _amountExpr = _amountExpr.pressDigit(k, maxDecimals: 2)),
              onBackspace: () =>
                  setState(() => _amountExpr = _amountExpr.backspace()),
              onOperator: (op) =>
                  setState(() => _amountExpr = _amountExpr.pressOperator(op)),
              onEquals: () => setState(
                  () => _amountExpr = _amountExpr.evaluated(_precision)),
              canResolve: _amountExpr.canResolve(_precision),
            )
          : null,
      children: [
        FormSection(
          children: [
            NameField(
              controller: _title,
              hint: l.qaTaskPlaceholder,
              semanticsLabel: l.etTaskTitle,
              leadingIcon: _icon,
              onLeadingTap: _pickIcon,
              leadingSemanticsLabel: l.qaIcon,
            ),
          ],
        ),
        FormSection(
          children: [
            FormRow(
              // The receivable row is the one two-line account row (§8c): its
              // caption says what recording does, and the icon takes the
              // group's own glyph and blue.
              icon: _isReceivable
                  ? AccountGroup.receivables.icon
                  : Icons.account_balance_wallet_rounded,
              iconColor: _isReceivable ? AppColors.receivables : null,
              label: _isReceivable
                  ? l.etOwedBy
                  : (_payOut ? l.etPaidFrom : l.etPaidInto),
              subtitle: _isReceivable ? l.etOwedByHint : null,
              // One line (task 063 §2): the account is the row's value, not a
              // second line; long names ellipsise at the cap.
              value: account?.name ?? l.fieldSelectAccount,
              valueMaxWidth: 170,
              showChevron: true,
              // pickAccount raises a bottom sheet.
              opensSheet: true,
              onTap: () async {
                _closeKeypad();
                final a = await pickAccount(context, title: l.etLinkedAccount);
                // Re-validate even on cancel — the picker can delete a ref (§5).
                if (!mounted) return;
                setState(() {
                  _dropDeletedRefs();
                  if (a != null) _accountId = a.id;
                  _normalizeReceivable();
                });
              },
            ),
            // No Direction on a receivable (§8b): money owed to you only ever
            // flows in — offering "Pay out" here is how a pay-out earning
            // happened in the first place.
            if (!_isReceivable)
              FormRow(
                icon: Icons.swap_vert_rounded,
                label: l.fieldDirection,
                trailing: Flexible(
                  child: SegmentedPicker<bool>(
                    dense: true,
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
              ),
            TxnAmountFieldRow(
              // The Schedule form's own choice for this row (task 061): the
              // currency-neutral # beside the label Amount, not $ / Expected
              // amount — the same amount must read the same on both forms.
              icon: Icons.numbers_rounded,
              label: l.qaAmount,
              raw: _amountExpr.pending,
              expression: _amountExpr,
              currency: account?.currency ?? store.baseCurrency,
              focused: _keypadOpen,
              onTap: _focusAmount,
              // The task's currency follows its account; the chip is a label
              // here, so its tap re-focuses the amount rather than picking.
              onCurrencyTap: _focusAmount,
            ),
            FormRow(
              icon: Icons.category_rounded,
              // Paid to never appears in receivable mode (§8d): an earning
              // books into an income category, full stop.
              label: (!_isReceivable && _payOut) ? l.etPaidTo : l.fieldCategory,
              // Empty is the same imperative the transaction form's rows use
              // (task 063 §5a) — never the old "Where …" sentence.
              value: _destinationInfo(store) == null ? l.qaChooseCategory : null,
              valueColor: AppColors.textTertiary,
              trailing: _destinationTrailing(store),
              showChevron: true,
              // _pickDestination raises a bottom sheet (category / pay-out picker).
              opensSheet: true,
              onTap: _pickDestination,
            ),
            _dueRow(store, l),
            FormRow(
              icon: Icons.repeat_rounded,
              label: _repeats == RepeatFrequency.none
                  ? l.etRepeats
                  : l.etRepeatsCadence(
                      repeatCadenceLabel(_repeats, _weekdays, _daysOfMonth, _due, l)
                          .toLowerCase()),
              // Spec 5.7 — the preview is what makes a series comprehensible;
              // task 063 §7b adds how the series ends, read from the stored
              // task (this screen shows the end, it cannot edit it).
              subtitle: _preview.isEmpty ? l.etOneOff : null,
              subtitleSpans: _preview.isEmpty ? null : _previewSpans(l),
              value:
                  _preview.isEmpty ? _repeats.label(AppLocalizations.of(context)) : null,
              showChevron: true,
              // _pickRepeat raises a bottom sheet (showRepeatSheet).
              opensSheet: true,
              onTap: _pickRepeat,
            ),
            // Remind is removed (§4): no notification package ships, so nothing
            // schedules a reminder and the switch only wrote fixed values the
            // user never chose. Task.reminderDaysBefore/reminderTime stay on the
            // model and are preserved through _save (updateTask keeps them when
            // no reminder args are passed), so existing data survives untouched.
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
              // A saved note reads as content, not a blank row (task 063 §1e):
              // the label becomes a caption and the text wraps below it.
              stacked: true,
            ),
          ],
        ),
      ],
    );
  }

  /// The chosen destination — a category, or (pay-out only) a liability
  /// account. Null when nothing is chosen yet.
  ({IconData icon, Color color, String name})? _destinationInfo(
      AppStore store) {
    if (!_isReceivable && _payToAccountId != null) {
      final a = store.accountById(_payToAccountId);
      if (a != null) return (icon: a.displayIcon, color: a.color, name: a.name);
    }
    final c = store.categoryById(_categoryId);
    if (c != null) return (icon: c.icon, color: c.color, name: c.name);
    return null;
  }

  /// The chosen destination as the row's value (task 063 §5b): its 20 pt tile,
  /// then its name. The `Transfer — no budget category` caption lives in the
  /// destination sheet's row, not here.
  Widget? _destinationTrailing(AppStore store) {
    final d = _destinationInfo(store);
    if (d == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTile(d.icon, color: d.color, size: 20, iconSize: 12),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            d.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: RowMetrics.valueSize,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Next due — and, when the date has passed, how late, in red (task 063 §6).
  Widget _dueRow(AppStore store, AppLocalizations l) {
    final today = store.today;
    final dueDay = DateTime(_due.year, _due.month, _due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final lateDays = todayDay.difference(dueDay).inDays;
    final late = lateDays > 0;
    return FormRow(
      icon: Icons.event_rounded,
      label: l.etNextDue,
      value: late
          ? '${dayMonth(_due, l)} · ${l.schDaysLate(lateDays)}'
          : dayMonth(_due, l),
      valueColor: late ? AppColors.negative : null,
      showChevron: true,
      onTap: _pickDue,
    );
  }

  /// The repeat preview with the series' end after the ellipsis (§7b), in
  /// accentLight: `· {n} times` for a count, `· last {date}` for a date,
  /// nothing when the series never ends.
  List<InlineSpan> _previewSpans(AppLocalizations l) {
    final dates =
        _preview.map((d) => repeatPreviewDate(d, _repeats, l)).join(' · ');
    final endCount = _task.repeatEndCount;
    final endDate = _task.repeatEndDate;
    final String? end = endCount != null
        ? l.rcTimes(endCount)
        : endDate != null
            ? l.etRepeatLast(dayMonthYear(endDate, l))
            : null;
    return [
      TextSpan(text: '$dates …'),
      if (end != null) ...[
        const TextSpan(text: ' · '),
        TextSpan(
            text: end, style: const TextStyle(color: AppColors.accentLight)),
      ],
    ];
  }

  /// Clears any nullable ref the form holds that no longer resolves after a
  /// picker closes (task 033 §5). Archived items still resolve and are kept.
  /// `_accountId` is non-nullable and cannot be cleared to a placeholder here —
  /// its row already renders "select account" when the id fails to resolve.
  void _dropDeletedRefs() {
    if (_categoryId != null && _store.categoryById(_categoryId) == null) {
      _categoryId = null;
    }
    if (_payToAccountId != null &&
        _store.accountById(_payToAccountId) == null) {
      _payToAccountId = null;
    }
  }

  Future<void> _pickDestination() async {
    _closeKeypad();
    if (!_payOut) {
      final c = await pickCategory(context, type: CategoryType.income);
      // Re-validate even on cancel — the picker can delete a ref (§5).
      if (!mounted) return;
      setState(() {
        _dropDeletedRefs();
        if (c != null) {
          _categoryId = c.id;
          _payToAccountId = null;
        }
      });
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

  Future<void> _pickIcon() async {
    _closeKeypad();
    final picked = await showCategoryIconPicker(
      context,
      color: AppColors.task,
      selected: _icon,
    );
    if (picked != null && mounted) setState(() => _icon = picked);
  }

  Future<void> _pickDue() async {
    _closeKeypad();
    final picked = await showTypedDateSheet(
      context,
      initialDate: _due,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    // A task's time is a separate question — the stock time picker still follows
    // the date (Task 25 §3).
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
    _closeKeypad();
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
    // Belt and braces: receivable mode's invariants hold at save even if the
    // account changed without passing through the picker's setState.
    _normalizeReceivable();
    final noteText = _note.text.trim();
    _store.updateTask(
      _task,
      title: _title.text.trim(),
      icon: _icon,
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
      // No reminder args (§4): updateTask leaves reminderDaysBefore/reminderTime
      // as they are when none are passed and clearReminder is false, so a task
      // that carried reminder fields keeps them across an edit.
    );
    Navigator.of(context).pop();
  }
}
