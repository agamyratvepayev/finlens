import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'pickers.dart';
import 'repeat_sheet.dart';
import 'split_sheet.dart';
import 'widgets/amount_hero.dart';
import 'widgets/form_kit.dart';
import 'widgets/transaction_form_shell.dart';

export 'pickers.dart' show showNewAccountSheet, showNewCategorySheet;

/// Spec 3 — the single central entry point, reachable from every header's +.
///
/// One shell hosts all six record types; a type is a [FormConfig], not a
/// screen, so switching type never rebuilds the chrome.
Future<void> showQuickAdd(
  BuildContext context, {
  QuickAddType type = QuickAddType.expense,
  String? fixedFromAccountId,
  String? fixedToAccountId,
  Txn? editing,
  Txn? copyOf,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuickAddScreen(
        initialType: type,
        fixedFromAccountId: fixedFromAccountId,
        fixedToAccountId: fixedToAccountId,
        editing: editing,
        copyOf: copyOf,
      ),
    ),
  );
}

class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({
    super.key,
    required this.initialType,
    this.fixedFromAccountId,
    this.fixedToAccountId,
    this.editing,
    this.copyOf,
  });

  final QuickAddType initialType;

  /// Set by "Add expense" / "Pay card" on Account Detail (spec 1.4), which
  /// pre-fill one side so the user skips the account-picking step.
  final String? fixedFromAccountId;
  final String? fixedToAccountId;

  /// Spec 2.3 — editing an existing entry; the type is locked.
  final Txn? editing;

  /// Spec 2.2 — Copy opens a new form pre-filled with today's date.
  final Txn? copyOf;

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

/// What a from/to slot is allowed to hold, so a type switch can keep the refs
/// that still make sense and clear only the ones that do not.
enum _Slot { none, account, expenseCategory, incomeCategory }

class _QuickAddScreenState extends State<QuickAddScreen>
    with SingleTickerProviderStateMixin {
  late QuickAddType _type;

  /// The literal characters typed into the hero, not a double — the display
  /// has to tell entered digits from decimals not yet reached.
  String _raw = '';

  final _note = TextEditingController();
  final _title = TextEditingController();
  final _titleFocus = FocusNode();

  String _currency = 'USD';
  String? _fromRef;
  String? _toRef;
  DateTime _date = AppStore.today;
  List<String> _tags = [];

  bool _keypadOpen = false;

  // Transfer
  double? _rateOverride;

  // Goal
  DateTime? _targetDate;
  double _startingAmount = 0;
  IconData _goalIcon = Icons.savings_rounded;

  // Toggles, shared across types that use them.
  RepeatFrequency _repeatFreq = RepeatFrequency.none;
  String? _recurrenceTaskId; // the Planner Task backing an existing repeat
  List<SplitLine>? _splitLines; // non-null once a split is applied
  bool _hasFee = false;
  bool _autoFund = false;
  bool _remind = false;

  /// The field flagged as missing after an incomplete Save (§3), and the pulse
  /// that flashes it. Cleared as soon as the field is filled.
  String? _flag;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));

  bool _editLoaded = false;

  bool get _isEditing => widget.editing != null;
  bool get _hasSplit => _splitLines != null;
  bool get _hasRepeat => _repeatFreq != RepeatFrequency.none;

  @override
  void initState() {
    super.initState();
    final source = widget.editing ?? widget.copyOf;
    if (source != null) {
      _type = switch (source.type) {
        TxnType.expense => QuickAddType.expense,
        TxnType.income => QuickAddType.income,
        TxnType.transfer => QuickAddType.transfer,
        TxnType.rebalance => QuickAddType.rebalance,
      };
      _raw = AmountEntry.fromDouble(source.amount);
      _currency = source.currency;
      _fromRef = source.fromRef;
      _toRef = source.toRef;
      // Spec 2.2 — a copy lands on today; an edit keeps its original date.
      _date = widget.editing != null ? source.date : AppStore.today;
      _tags = List.of(source.tags);
      _note.text = source.note;
      _hasFee = (source.fee ?? 0) > 0;
      _rateOverride = source.exchangeRate;
    } else {
      _type = widget.initialType;
      _fromRef = widget.fixedFromAccountId;
      _toRef = widget.fixedToAccountId;
    }
    // A text hero takes the system keyboard; a numeric one takes the keypad.
    _keypadOpen = !_isEditing && _type != QuickAddType.newTask;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Editing a saved transaction loads its repeat rule and, for a split, the
    // whole group (spec §1/§2). Done once, and here rather than initState so
    // the store is reachable.
    if (_editLoaded || widget.editing == null) return;
    _editLoaded = true;
    final store = StoreScope.read(context);
    final src = widget.editing!;
    _recurrenceTaskId = src.recurrenceTaskId;
    if (_recurrenceTaskId != null) {
      _repeatFreq = store.taskById(_recurrenceTaskId)?.repeats ??
          RepeatFrequency.none;
    }
    if (src.splitGroupId != null) {
      final group = store.txns
          .where((t) => t.splitGroupId == src.splitGroupId)
          .toList();
      if (group.length >= 2) {
        _splitLines = [
          for (final t in group)
            SplitLine(
              categoryId:
                  t.type == TxnType.income ? t.fromRef : t.toRef,
              amount: t.amount,
            ),
        ];
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _note.dispose();
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  double get _amount => AmountEntry.value(_raw);

  // ── Type switching ────────────────────────────────────────────────────────

  _Slot _fromSlot(QuickAddType t) => switch (t) {
        QuickAddType.expense => _Slot.account,
        QuickAddType.income => _Slot.incomeCategory,
        QuickAddType.transfer => _Slot.account,
        QuickAddType.rebalance => _Slot.account,
        QuickAddType.newGoal => _Slot.none,
        QuickAddType.newTask => _Slot.expenseCategory,
      };

  _Slot _toSlot(QuickAddType t) => switch (t) {
        QuickAddType.expense => _Slot.expenseCategory,
        QuickAddType.income => _Slot.account,
        QuickAddType.transfer => _Slot.account,
        QuickAddType.rebalance => _Slot.account,
        QuickAddType.newGoal => _Slot.account,
        QuickAddType.newTask => _Slot.account,
      };

  /// Keeps a ref only if the incoming type can still hold it. Amount, date
  /// and note are untouched by a type change — clearing the whole form
  /// because the user picked the wrong type first is punishing.
  String? _keepRef(AppStore store, String? ref, _Slot slot) {
    if (ref == null || slot == _Slot.none) return null;
    return switch (slot) {
      _Slot.account => store.accountById(ref) != null ? ref : null,
      _Slot.expenseCategory =>
        store.categoryById(ref)?.type == CategoryType.expense ? ref : null,
      _Slot.incomeCategory =>
        store.categoryById(ref)?.type == CategoryType.income ? ref : null,
      _Slot.none => null,
    };
  }

  void _switchType(QuickAddType next) {
    final store = StoreScope.read(context);
    setState(() {
      _fromRef = _keepRef(store, _fromRef, _fromSlot(next));
      _toRef = _keepRef(store, _toRef, _toSlot(next));
      _type = next;
      _keypadOpen = next != QuickAddType.newTask;
      if (next == QuickAddType.newTask) _titleFocus.requestFocus();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Whether the currently flagged field has since been filled (§3).
  bool _flagSatisfied(String flag) => switch (flag) {
        'amount' => _amount > 0,
        'from' => _fromRef != null,
        'to' => _toRef != null,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Filling a flagged field clears its flag immediately (§3).
    if (_flag != null && _flagSatisfied(_flag!)) _flag = null;
    return TransactionFormShell(
      config: _config(store),
      typeLocked: _isEditing,
      flashTarget: _flag,
      flashPulse: _pulse,
      onCancel: () => Navigator.of(context).pop(),
      onTypeTap: _showTypeMenu,
      onSave: () => _save(store),
      keypadOpen: _keypadOpen,
      onHeroTap: () {
        _titleFocus.unfocus();
        setState(() => _keypadOpen = true);
      },
      onKey: (k) => setState(() => _raw = AmountEntry.press(_raw, k)),
      onBackspace: () => setState(() => _raw = AmountEntry.backspace(_raw)),
      onDismissKeypad: () => setState(() => _keypadOpen = false),
    );
  }

  FormConfig _config(AppStore store) => switch (_type) {
        QuickAddType.expense => _expense(store),
        QuickAddType.income => _income(store),
        QuickAddType.transfer => _transfer(store),
        QuickAddType.rebalance => _rebalance(store),
        QuickAddType.newGoal => _goal(store),
        QuickAddType.newTask => _task(store),
      };

  // ── Shared field builders ─────────────────────────────────────────────────

  NumericHero _amountHero([String label = 'Amount']) => NumericHero(
        label: label,
        raw: _raw,
        currency: _currency,
        onCurrencyTap: () async {
          final c = await pickCurrency(context, _currency);
          if (c != null && mounted) setState(() => _currency = c);
        },
      );

  FieldSpec _dateField({String label = 'Date'}) => FieldSpec(
        icon: Icons.event_rounded,
        label: label,
        value: dateTimeLabel(_date, AppLocalizations.of(context), now: AppStore.today),
        onTap: _pickDate,
      );

  FieldSpec _tagField() => FieldSpec(
        icon: Icons.sell_rounded,
        label: 'Tag',
        value: _tags.isEmpty ? null : _tags.join(', '),
        emptyText: 'None',
        onTap: () async {
          final v = await _promptText(
            title: 'Tag',
            initial: _tags.join(', '),
            hint: 'e.g. Groceries',
          );
          if (v == null || !mounted) return;
          setState(() => _tags = v
              .split(',')
              .map((t) => t.trim().replaceAll('#', ''))
              .where((t) => t.isNotEmpty)
              .toList());
        },
      );

  FieldSpec _noteField() {
    final text = _note.text.trim();
    return FieldSpec(
      icon: Icons.notes_rounded,
      label: 'Note',
      value: text.isEmpty
          ? null
          : (text.length > 20 ? '${text.substring(0, 20)}…' : text),
      emptyText: 'Add a note',
      onTap: () async {
        final v = await _promptText(
          title: 'Note',
          initial: _note.text,
          hint: 'Optional',
        );
        if (v == null || !mounted) return;
        setState(() => _note.text = v);
      },
    );
  }

  FormToggle _repeatToggle() => FormToggle(
        icon: Icons.repeat_rounded,
        label: repeatButtonLabel(_repeatFreq),
        value: _hasRepeat,
        semanticValue: _hasRepeat
            ? repeatButtonLabel(_repeatFreq).toLowerCase()
            : 'off',
        onTap: _openRepeat,
      );

  FormToggle _splitToggle(AppStore store) => FormToggle(
        icon: Icons.call_split_rounded,
        label: _hasSplit ? '${_splitLines!.length} categories' : 'Split',
        value: _hasSplit,
        enabled: _amount > 0,
        semanticValue: _amount <= 0
            ? 'unavailable until an amount is entered'
            : (_hasSplit ? '${_splitLines!.length} categories' : 'off'),
        onTap: () => _openSplit(store),
      );

  Future<void> _openRepeat() async {
    // Planner's Task can't represent a multi-transaction (split) occurrence, so
    // the combination is blocked with a clear message (spec §5).
    if (_hasSplit) {
      _toast("Can't repeat a split transaction");
      return;
    }
    setState(() => _keypadOpen = false);
    final freq =
        await showRepeatSheet(context, current: _repeatFreq, date: _date);
    if (freq == null || !mounted) return;
    setState(() => _repeatFreq = freq);
  }

  Future<void> _openSplit(AppStore store) async {
    if (_hasRepeat) {
      _toast("Can't split a repeating transaction");
      return;
    }
    if (_amount <= 0) return;
    final catType =
        _type == QuickAddType.income ? CategoryType.income : CategoryType.expense;
    final account =
        store.accountById(_type == QuickAddType.income ? _toRef : _fromRef);
    setState(() => _keypadOpen = false);
    final result = await showSplitSheet(
      context,
      total: _amount,
      currency: _currency,
      accountName: account?.name ?? '—',
      categoryType: catType,
      initial: _splitLines ?? const [],
    );
    if (result == null || !mounted) return;
    setState(() => _splitLines = result.length >= 2 ? result : null);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _splitBalanced() =>
      _splitLines != null && splitBalanced(_amount, _splitLines!);

  // ── Configs ───────────────────────────────────────────────────────────────

  FormConfig _expense(AppStore store) {
    final from = store.accountById(_fromRef);
    final to = store.categoryById(_toRef);
    return FormConfig(
      typeName: 'Expense',
      accent: AppColors.expense,
      accentDim: AppColors.expenseDim,
      hero: _amountHero(),
      groups: [
        FieldGroup('REQUIRED', [
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: 'From',
            value: from?.name,
            emptyText: 'Choose account',
            flashId: 'from',
            onTap: widget.fixedFromAccountId != null
                ? null
                : () => _pickAccountInto(store, isFrom: true, title: 'Pay from'),
          ),
          FieldSpec(
            icon: Icons.category_rounded,
            label: 'To',
            // A split replaces the single category with the line count (§2).
            value: _hasSplit ? '${_splitLines!.length} categories' : to?.name,
            emptyText: 'Choose category',
            flashId: 'to',
            onTap: _hasSplit
                ? () => _openSplit(store)
                : () => _pickCategoryInto(CategoryType.expense, isFrom: false),
          ),
        ]),
        FieldGroup('OPTIONAL', [_dateField(), _tagField(), _noteField()]),
      ],
      toggles: [_repeatToggle(), _splitToggle(store)],
      saveLabel: 'Save expense',
      blockers: [
        Blocker(unmet: _amount <= 0, label: 'Enter an amount', flashId: 'amount'),
        Blocker(unmet: _fromRef == null, label: 'Choose an account', flashId: 'from'),
        Blocker(
            unmet: _toRef == null && !_hasSplit,
            label: 'Choose a category',
            flashId: 'to'),
        Blocker(
            unmet: _hasSplit && !_splitBalanced(),
            label: 'Balance the split',
            flashId: 'to'),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _income(AppStore store) {
    final from = store.categoryById(_fromRef);
    final to = store.accountById(_toRef);
    return FormConfig(
      typeName: 'Income',
      accent: AppColors.income,
      accentDim: AppColors.incomeDim,
      hero: _amountHero(),
      groups: [
        FieldGroup('REQUIRED', [
          FieldSpec(
            icon: Icons.category_rounded,
            label: 'From',
            // Income splits the source category, so From carries the count.
            value: _hasSplit ? '${_splitLines!.length} categories' : from?.name,
            emptyText: 'Choose source',
            flashId: 'from',
            onTap: _hasSplit
                ? () => _openSplit(store)
                : () => _pickCategoryInto(CategoryType.income, isFrom: true),
          ),
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: 'To',
            value: to?.name,
            emptyText: 'Choose account',
            flashId: 'to',
            onTap: () =>
                _pickAccountInto(store, isFrom: false, title: 'Deposit into'),
          ),
        ]),
        FieldGroup('OPTIONAL', [_dateField(), _tagField(), _noteField()]),
      ],
      toggles: [_repeatToggle(), _splitToggle(store)],
      saveLabel: 'Save income',
      blockers: [
        Blocker(unmet: _amount <= 0, label: 'Enter an amount', flashId: 'amount'),
        Blocker(
            unmet: _fromRef == null && !_hasSplit,
            label: 'Choose a source',
            flashId: 'from'),
        Blocker(unmet: _toRef == null, label: 'Choose an account', flashId: 'to'),
        Blocker(
            unmet: _hasSplit && !_splitBalanced(),
            label: 'Balance the split',
            flashId: 'from'),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _transfer(AppStore store) {
    final from = store.accountById(_fromRef);
    final to = store.accountById(_toRef);
    final cross =
        from != null && to != null && from.currency != to.currency;
    final rate = _rateOverride ?? _defaultRate(from, to);

    return FormConfig(
      typeName: 'Transfer',
      accent: AppColors.transfer,
      accentDim: AppColors.transferDim,
      hero: _amountHero(),
      groups: [
        FieldGroup('REQUIRED', [
          FieldSpec(
            icon: Icons.north_east_rounded,
            label: 'From',
            value: from?.name,
            emptyText: 'Choose account',
            flashId: 'from',
            onTap: widget.fixedFromAccountId != null
                ? null
                : () => _pickAccountInto(
                      store,
                      isFrom: true,
                      title: 'Transfer from',
                      excludeId: _toRef,
                    ),
          ),
          FieldSpec(
            icon: Icons.south_west_rounded,
            label: 'To',
            value: to?.name,
            emptyText: 'Choose account',
            flashId: 'to',
            onTap: widget.fixedToAccountId != null
                ? null
                : () => _pickAccountInto(
                      store,
                      isFrom: false,
                      title: 'Transfer to',
                      excludeId: _fromRef,
                    ),
          ),
        ]),
        // Absent entirely when both sides share a currency — not disabled,
        // not empty.
        if (cross)
          FieldGroup('EXCHANGE', [
            FieldSpec(
              icon: Icons.currency_exchange_rounded,
              label: 'Rate',
              value: '1 ${from.currency} = ${rate.toStringAsFixed(4)} '
                  '${to.currency}',
              onTap: () => _editRate(from, to, rate),
            ),
            FieldSpec(
              icon: Icons.check_circle_rounded,
              label: 'Receives',
              value: money(_amount * rate, currency: to.currency),
            ),
          ]),
        // No Tag: money moved between your own accounts is not spending and
        // should not enter tag reporting.
        FieldGroup('OPTIONAL', [_dateField(), _noteField()]),
      ],
      toggles: [
        _repeatToggle(),
        FormToggle(
          icon: Icons.percent_rounded,
          label: 'Fee',
          value: _hasFee,
          onTap: () => setState(() => _hasFee = !_hasFee),
        ),
      ],
      saveLabel: 'Save transfer',
      blockers: [
        Blocker(unmet: _amount <= 0, label: 'Enter an amount', flashId: 'amount'),
        Blocker(
            unmet: _fromRef == null,
            label: 'Choose a source account',
            flashId: 'from'),
        Blocker(
            unmet: _toRef == null,
            label: 'Choose a destination',
            flashId: 'to'),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _rebalance(AppStore store) {
    final account = store.accountById(_toRef);
    final current = account == null ? 0.0 : store.balanceOf(account.id);
    final entered = _raw.isEmpty ? null : _amount;
    final diff = entered == null ? null : entered - current;

    return FormConfig(
      typeName: 'Rebalance',
      accent: AppColors.rebalance,
      accentDim: AppColors.rebalanceDim,
      // The user types what the balance *is*, not what changed.
      hero: _amountHero('New balance'),
      groups: [
        FieldGroup('REQUIRED', [
          FieldSpec(
            icon: Icons.donut_large_rounded,
            label: 'Account',
            value: account?.name,
            emptyText: 'Choose account',
            onTap: () => _pickAccountInto(
              store,
              isFrom: false,
              title: 'Revalue account',
              alsoSetFrom: true,
            ),
          ),
          FieldSpec(
            icon: Icons.menu_book_rounded,
            label: 'Current',
            value: account == null
                ? null
                : money(current, currency: account.currency),
            emptyText: '—',
            valueColor: AppColors.textSecondary,
          ),
          FieldSpec(
            icon: Icons.swap_vert_rounded,
            label: 'Difference',
            value: diff == null
                ? null
                : money(diff, currency: _currency, showSign: true),
            emptyText: '—',
            valueColor: diff == null
                ? null
                : (diff >= 0 ? AppColors.positive : AppColors.negative),
          ),
        ]),
        FieldGroup('OPTIONAL', [
          _dateField(),
          FieldSpec(
            icon: Icons.label_outline_rounded,
            label: 'Reason',
            value: store.categoryById(_fromRef)?.name,
            emptyText: 'Adjustment',
            onTap: () => _pickCategoryInto(CategoryType.expense, isFrom: true),
          ),
          _noteField(),
        ]),
      ],
      hint: diff == null || diff == 0
          ? null
          : HintSpec.parts([
              'Books a ',
              money(diff, currency: _currency, showSign: true),
              ' adjustment dated today. Past reports are not rewritten.',
            ]),
      // A correction is not recurring and cannot be split, so the row is
      // omitted rather than shown disabled.
      toggles: const [],
      saveLabel: 'Save adjustment',
      blockers: [
        Blocker(unmet: _toRef == null, label: 'Choose an account'),
        Blocker(unmet: _raw.isEmpty, label: 'Enter the new balance'),
        Blocker(
          unmet: _raw.isNotEmpty && diff == 0,
          label: 'Balance unchanged',
        ),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _goal(AppStore store) {
    final target = _amount;
    final linked = store.accountById(_toRef);
    final months = _targetDate == null
        ? 0
        : (_targetDate!.year - AppStore.today.year) * 12 +
            (_targetDate!.month - AppStore.today.month);
    final perMonth =
        months > 0 ? (target - _startingAmount) / months : null;

    return FormConfig(
      typeName: 'New Goal',
      // Violet, not brand purple: a goal amount in the Save colour would read
      // as an interactive control rather than data.
      accent: AppColors.goal,
      accentDim: AppColors.goalDim,
      hero: _amountHero('Target'),
      groups: [
        FieldGroup('REQUIRED', [
          FieldSpec(
            icon: Icons.flag_rounded,
            label: 'Name',
            value: _title.text.trim().isEmpty ? null : _title.text.trim(),
            emptyText: 'Name your goal',
            onTap: () async {
              final v = await _promptText(
                title: 'Goal name',
                initial: _title.text,
                hint: 'e.g. MacBook Pro M4',
              );
              if (v == null || !mounted) return;
              setState(() => _title.text = v);
            },
          ),
          FieldSpec(
            icon: Icons.event_rounded,
            label: 'Target date',
            value: _targetDate == null ? null : monthYear(_targetDate!, AppLocalizations.of(context)),
            emptyText: 'Set a date',
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _targetDate ??
                    DateTime(AppStore.today.year + 1, AppStore.today.month),
                firstDate: AppStore.today,
                lastDate: DateTime(2035),
              );
              if (d != null && mounted) setState(() => _targetDate = d);
            },
          ),
          FieldSpec(
            icon: Icons.savings_rounded,
            label: 'Funding account',
            value: linked?.name,
            emptyText: 'Choose account',
            onTap: () => _pickAccountInto(
              store,
              isFrom: false,
              title: 'Money kept in',
              filter: (a) => a.isAsset,
            ),
          ),
        ]),
        FieldGroup('OPTIONAL', [
          FieldSpec(
            icon: Icons.input_rounded,
            label: 'Starting amount',
            value: _startingAmount == 0 ? null : money(_startingAmount),
            emptyText: 'None',
            onTap: () async {
              final v = await _promptText(
                title: 'Starting amount',
                initial: _startingAmount == 0 ? '' : '$_startingAmount',
                hint: '0',
                numeric: true,
              );
              if (v == null || !mounted) return;
              setState(() => _startingAmount = double.tryParse(v) ?? 0);
            },
          ),
          FieldSpec(
            icon: _goalIcon,
            label: 'Icon & colour',
            value: 'Tap to change',
            onTap: _pickGoalIcon,
          ),
          _noteField(),
        ]),
      ],
      hint: perMonth == null || perMonth <= 0
          ? null
          : HintSpec.parts([
              'Put aside ',
              '${money(perMonth)} / month',
              ' for $months months to reach it on time.',
            ]),
      toggles: [
        FormToggle(
          icon: Icons.autorenew_rounded,
          label: 'Auto-fund',
          value: _autoFund,
          onTap: () => setState(() => _autoFund = !_autoFund),
        ),
        FormToggle(
          icon: Icons.alarm_rounded,
          label: 'Remind',
          value: _remind,
          onTap: () => setState(() => _remind = !_remind),
        ),
      ],
      saveLabel: 'Create goal',
      blockers: [
        Blocker(unmet: _title.text.trim().isEmpty, label: 'Name your goal'),
        Blocker(unmet: target <= 0, label: 'Set a target'),
        Blocker(unmet: _targetDate == null, label: 'Set a target date'),
        // Not in the spec's list, but the store cannot create a goal without
        // somewhere to keep the money.
        Blocker(unmet: _toRef == null, label: 'Choose a funding account'),
      ],
    );
  }

  FormConfig _task(AppStore store) {
    final account = store.accountById(_toRef);
    return FormConfig(
      typeName: 'New Task',
      accent: AppColors.task,
      accentDim: AppColors.taskDim,
      // The only type with no amount, so the hero is text.
      hero: TextHero(
        caption: 'Task title',
        placeholder: 'What needs doing?',
        controller: _title,
        focusNode: _titleFocus,
      ),
      groups: [
        FieldGroup('REQUIRED', [_dateField(label: 'Due')]),
        FieldGroup('OPTIONAL', [
          // Demoted from Required: most tasks have no amount. When set, the
          // task can later be turned into a transaction in one tap.
          FieldSpec(
            icon: Icons.attach_money_rounded,
            label: 'Amount',
            value: _raw.isEmpty ? null : money(_amount, currency: _currency),
            emptyText: 'None',
            onTap: () async {
              final v = await _promptText(
                title: 'Amount',
                initial: _raw,
                hint: '0',
                numeric: true,
              );
              if (v == null || !mounted) return;
              setState(() => _raw = v.trim());
            },
          ),
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Account',
            value: account?.name,
            emptyText: 'None',
            onTap: () =>
                _pickAccountInto(store, isFrom: false, title: 'Linked account'),
          ),
          FieldSpec(
            icon: Icons.category_rounded,
            label: 'Category',
            value: store.categoryById(_fromRef)?.name,
            emptyText: 'None',
            onTap: () => _pickCategoryInto(CategoryType.expense, isFrom: true),
          ),
          _noteField(),
        ]),
      ],
      toggles: [
        _repeatToggle(),
        FormToggle(
          icon: Icons.alarm_rounded,
          label: 'Remind',
          value: _remind,
          onTap: () => setState(() => _remind = !_remind),
        ),
      ],
      saveLabel: 'Create task',
      blockers: [
        Blocker(unmet: _title.text.trim().isEmpty, label: 'Name the task'),
        Blocker(unmet: false, label: 'Set a due date'),
      ],
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickAccountInto(
    AppStore store, {
    required bool isFrom,
    required String title,
    String? excludeId,
    bool Function(Account)? filter,
    bool alsoSetFrom = false,
  }) async {
    setState(() => _keypadOpen = false);
    final a = await pickAccount(
      context,
      title: title,
      excludeId: excludeId,
      filter: filter,
    );
    if (a == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromRef = a.id;
      } else {
        _toRef = a.id;
        if (alsoSetFrom) _fromRef = a.id;
      }
      _currency = a.currency;
    });
  }

  Future<void> _pickCategoryInto(CategoryType type,
      {required bool isFrom}) async {
    setState(() => _keypadOpen = false);
    final c = await pickCategory(context, type: type);
    if (c == null || !mounted) return;
    setState(() => isFrom ? _fromRef = c.id : _toRef = c.id);
  }

  Future<void> _pickDate() async {
    setState(() => _keypadOpen = false);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null || !mounted) return;
    setState(
      () => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute),
    );
  }

  double _defaultRate(Account? from, Account? to) {
    if (from == null || to == null) return 1;
    return Fx.rate(from.currency, to.currency);
  }

  Future<void> _editRate(Account from, Account to, double current) async {
    final v = await _promptText(
      title: 'Exchange rate',
      initial: current.toStringAsFixed(4),
      hint: '1 ${from.currency} = ? ${to.currency}',
      numeric: true,
    );
    if (v == null || !mounted) return;
    setState(() => _rateOverride = double.tryParse(v));
  }

  Future<void> _pickGoalIcon() async {
    setState(() => _keypadOpen = false);
    const icons = [
      Icons.savings_rounded,
      Icons.flag_rounded,
      Icons.shopping_bag_rounded,
      Icons.flight_rounded,
      Icons.home_rounded,
      Icons.directions_car_rounded,
      Icons.school_rounded,
      Icons.favorite_rounded,
    ];
    final picked = await showModalBottomSheet<IconData>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Icon', style: AppText.rowTitle),
              const SizedBox(height: Insets.lg),
              Wrap(
                spacing: Insets.md,
                runSpacing: Insets.md,
                children: [
                  for (final i in icons)
                    GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(i),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: i == _goalIcon
                              ? AppColors.tint(AppColors.goal, 0.2)
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(
                          i,
                          color: i == _goalIcon
                              ? AppColors.goal
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _goalIcon = picked);
  }

  /// Free-text entry on a sheet, so Note and Tag keep the system keyboard
  /// while the amount keeps the keypad.
  Future<String?> _promptText({
    required String title,
    required String initial,
    String? hint,
    bool numeric = false,
  }) async {
    setState(() => _keypadOpen = false);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      builder: (_) => _TextPromptSheet(
        title: title,
        initial: initial,
        hint: hint,
        numeric: numeric,
      ),
    );
  }

  void _showTypeMenu() {
    setState(() => _keypadOpen = false);
    showAppSheet<void>(
      context,
      title: 'What are you adding?',
      initialSize: 0.55,
      builder: (sheetContext, controller) => ListView(
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
                for (var i = 0; i < QuickAddType.values.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  _typeOption(sheetContext, QuickAddType.values[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeOption(BuildContext sheetContext, QuickAddType type) {
    return InkWell(
      onTap: () {
        Navigator.of(sheetContext).pop();
        _switchType(type);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: type.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
                child: Text(type.label(AppLocalizations.of(sheetContext)),
                    style: AppText.rowTitle)),
            if (type == _type)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }

  // ── Editing extras ────────────────────────────────────────────────────────

  /// Both are edit-only: a record being created has no history to stamp and
  /// nothing to delete.
  List<Widget> _editingExtras() {
    if (!_isEditing) return const [];
    final txn = widget.editing!;
    final edits = txn.editedCount;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(kFormMargin, 20, kFormMargin, 0),
        child: Text(
          // Never edited shows the created stamp alone rather than "never
          // edited" — the absence already says it.
          'Created ${dateTimeLabel(txn.createdAt, AppLocalizations.of(context), now: AppStore.today)}'
          '${edits == 0 ? '' : ' · edited ${edits == 1 ? 'once' : '$edits times'}'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            height: 1.3,
            color: AppColors.formDim2,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(kFormMargin, 12, kFormMargin, 0),
        child: Material(
          color: AppColors.fieldCard,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // This one does confirm: once the form closes there is no undo
            // path, unlike the ledger's swipe-to-delete.
            onTap: () async {
              final store = StoreScope.read(context);
              final gid = txn.splitGroupId;
              if (gid != null) {
                // Deleting one line offers to delete the whole group (§2).
                final count =
                    store.txns.where((t) => t.splitGroupId == gid).length;
                final whole = await _confirmSplitDelete(count);
                if (whole == null || !mounted) return;
                if (whole) {
                  _deleteGroup(store, txn);
                } else {
                  _deleteTaskOf(store, txn);
                  store.deleteTxn(txn);
                }
              } else {
                final ok = await confirmDeleteTxn(context, txn);
                if (!ok || !mounted) return;
                // A repeat rule is deleted with its originating transaction (§5).
                _deleteTaskOf(store, txn);
                store.deleteTxn(txn);
              }
              if (mounted) Navigator.of(context).pop();
            },
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Delete this entry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: AppColors.negative,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: AppColors.negative.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  DateTime _nextDate(DateTime d, RepeatFrequency f) => switch (f) {
        RepeatFrequency.weekly => d.add(const Duration(days: 7)),
        RepeatFrequency.monthly =>
          DateTime(d.year, d.month + 1, d.day, d.hour, d.minute),
        RepeatFrequency.quarterly =>
          DateTime(d.year, d.month + 3, d.day, d.hour, d.minute),
        RepeatFrequency.yearly =>
          DateTime(d.year + 1, d.month, d.day, d.hour, d.minute),
        RepeatFrequency.none => d,
      };

  /// Creates, replaces, or clears the Planner Task backing this transaction's
  /// repeat (spec §1). The rule starts at the *next* occurrence — the entered
  /// transaction is the first one.
  void _applyRepeatFor(AppStore store, Txn txn,
      {required bool income, bool transfer = false}) {
    final oldId = txn.recurrenceTaskId;
    if (oldId != null) {
      final old = store.taskById(oldId);
      if (old != null) store.deleteTaskSeries(old);
      txn.recurrenceTaskId = null;
    }
    if (!_hasRepeat) return;
    final String accountId;
    final String? categoryId;
    final double expected;
    if (transfer) {
      accountId = _fromRef!;
      categoryId = null;
      expected = -_amount;
    } else if (income) {
      accountId = _toRef!;
      categoryId = _fromRef;
      expected = _amount;
    } else {
      accountId = _fromRef!;
      categoryId = _toRef;
      expected = -_amount;
    }
    final note = _note.text.trim();
    final task = store.addTask(
      title: note.isNotEmpty
          ? note
          : (store.categoryById(categoryId)?.name ?? 'Recurring'),
      linkedAccountId: accountId,
      expectedAmount: expected,
      dueDate: _nextDate(_date, _repeatFreq),
      icon: Icons.repeat_rounded,
      categoryId: categoryId,
      repeats: _repeatFreq,
    );
    txn.recurrenceTaskId = task.id;
  }

  /// Writes an expense/income — one transaction, or one per split line sharing
  /// a splitGroupId (spec §2). Repeat is blocked while a split is applied.
  void _writeExpenseIncome(AppStore store, {required bool income}) {
    final txnType = income ? TxnType.income : TxnType.expense;
    final note = _note.text.trim();
    if (_hasSplit) {
      final accountId = income ? _toRef! : _fromRef!;
      String? gid;
      for (var i = 0; i < _splitLines!.length; i++) {
        final line = _splitLines![i];
        final t = store.addTxn(
          type: txnType,
          amount: line.amount,
          currency: _currency,
          fromRef: income ? line.categoryId! : accountId,
          toRef: income ? accountId : line.categoryId!,
          date: _date,
          tags: _tags,
          note: note,
          splitGroupId: gid,
        );
        if (i == 0) {
          gid = t.id;
          t.splitGroupId = gid;
        }
      }
    } else {
      final t = store.addTxn(
        type: txnType,
        amount: _amount,
        currency: _currency,
        fromRef: _fromRef!,
        toRef: _toRef!,
        date: _date,
        tags: _tags,
        note: note,
      );
      _applyRepeatFor(store, t, income: income);
    }
  }

  void _deleteGroup(AppStore store, Txn editing) {
    final gid = editing.splitGroupId;
    final rows = gid == null
        ? [editing]
        : store.txns.where((t) => t.splitGroupId == gid).toList();
    for (final t in rows) {
      _deleteTaskOf(store, t);
      store.deleteTxn(t);
    }
  }

  void _deleteTaskOf(AppStore store, Txn txn) {
    final rid = txn.recurrenceTaskId;
    if (rid != null) {
      final task = store.taskById(rid);
      if (task != null) store.deleteTaskSeries(task);
    }
  }

  /// Delete confirmation for a split line: true = whole group, false = just this
  /// line, null = cancelled (spec §2).
  Future<bool?> _confirmSplitDelete(int count) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Delete split', style: AppText.rowTitle),
              const SizedBox(height: Insets.sm),
              Text(
                'This is one of $count linked split transactions.',
                style: AppText.caption,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.negative,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text('Delete all $count'),
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Delete just this line',
                    style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save(AppStore store) {
    // §3 — validate on tap: name the first missing field, flash it, do not save.
    final blocker = _config(store).firstUnmet;
    if (blocker != null) {
      _toast(blocker.label);
      if (blocker.flashId != null) {
        setState(() => _flag = blocker.flashId);
        _pulse.forward(from: 0);
      }
      return;
    }

    final income = _type == QuickAddType.income;

    if (_isEditing) {
      final editing = widget.editing!;
      final splitInvolved =
          (_type == QuickAddType.expense || income) &&
              (_hasSplit || editing.splitGroupId != null);
      if (splitInvolved) {
        // Replace the whole group (or single txn) with the current state.
        _deleteGroup(store, editing);
        _writeExpenseIncome(store, income: income);
      } else {
        store.updateTxn(
          editing,
          amount: _type == QuickAddType.rebalance
              ? _amount - store.balanceOf(_toRef!)
              : _amount,
          fromRef: _fromRef,
          toRef: _toRef,
          date: _date,
          tags: _tags,
          note: _note.text.trim(),
        );
        if (_type == QuickAddType.expense ||
            income ||
            _type == QuickAddType.transfer) {
          _applyRepeatFor(store, editing,
              income: income, transfer: _type == QuickAddType.transfer);
        }
      }
      Navigator.of(context).pop();
      return;
    }

    switch (_type) {
      case QuickAddType.expense:
      case QuickAddType.income:
        _writeExpenseIncome(store, income: income);
      case QuickAddType.transfer:
        final from = store.accountById(_fromRef)!;
        final to = store.accountById(_toRef)!;
        final cross = from.currency != to.currency;
        final rate = _rateOverride ?? _defaultRate(from, to);
        final t = store.addTxn(
          type: TxnType.transfer,
          amount: _amount,
          currency: from.currency,
          fromRef: from.id,
          toRef: to.id,
          date: _date,
          exchangeRate: cross ? rate : null,
          toAmount: cross ? _amount * rate : null,
          note: _note.text.trim(),
        );
        _applyRepeatFor(store, t, income: false, transfer: true);
      case QuickAddType.rebalance:
        final asset = store.accountById(_toRef)!;
        store.addTxn(
          type: TxnType.rebalance,
          amount: _amount - store.balanceOf(asset.id),
          currency: asset.currency,
          fromRef: asset.id,
          toRef: asset.id,
          date: _date,
          note: _note.text.trim().isEmpty
              ? 'Balance adjustment'
              : _note.text.trim(),
        );
      case QuickAddType.newGoal:
        store.addGoal(
          name: _title.text.trim(),
          type: GoalType.saving,
          targetAmount: _amount,
          linkedAccountId: _toRef!,
          icon: _goalIcon,
          targetDate: _targetDate,
          initialDeposit: _startingAmount,
          depositFromAccountId: _startingAmount > 0 ? _toRef : null,
          note: _note.text.trim(),
        );
      case QuickAddType.newTask:
        // Account is optional on a task, but the store needs somewhere to
        // hang it — fall back to the first account when none was chosen.
        final linked = _toRef ??
            (store.accounts.isEmpty ? null : store.accounts.first.id);
        if (linked == null) return;
        store.addTask(
          title: _title.text.trim(),
          linkedAccountId: linked,
          expectedAmount: -_amount,
          dueDate: _date,
          icon: Icons.arrow_circle_up_rounded,
          categoryId: _fromRef,
          repeats: _repeatFreq,
          reminderDaysBefore: _remind ? 2 : null,
          reminderTime: _remind ? const TimeOfDay(hour: 9, minute: 0) : null,
        );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_type.label(AppLocalizations.of(context))} saved')),
    );
  }
}

/// Free-text entry sheet for Note and Tag, which keep the system keyboard
/// while the amount keeps the in-app keypad.
///
/// The controller lives here rather than in the caller on purpose: awaiting
/// `showModalBottomSheet` returns the moment `pop()` is called, but the sheet
/// keeps rebuilding through its exit animation for several frames after that.
/// Disposing at the await site therefore tore the controller out from under a
/// still-building TextField. A State's `dispose()` runs only once the route is
/// actually gone, which is the guarantee this needs.
class _TextPromptSheet extends StatefulWidget {
  const _TextPromptSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.numeric,
  });

  final String title;
  final String initial;
  final String? hint;
  final bool numeric;

  @override
  State<_TextPromptSheet> createState() => _TextPromptSheetState();
}

class _TextPromptSheetState extends State<_TextPromptSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppText.rowTitle),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: widget.numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                style: AppText.body.copyWith(fontSize: 16),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AppColors.formDim2),
                  filled: true,
                  fillColor: AppColors.fieldCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) => Navigator.of(context).pop(v),
              ),
              const SizedBox(height: Insets.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
