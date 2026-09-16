import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../planner/edit_budget_screen.dart';
import '../planner/edit_goal_screen.dart';
import 'date_time_sheet.dart';
import 'icon_picker_sheet.dart';
import 'pickers.dart';
import 'transfer_math.dart';
import 'type_menu.dart';
import 'tag_picker_sheet.dart';
import 'split_sheet.dart';
import 'widgets/split_summary_rows.dart';
import 'transaction_repeat_sheet.dart';
import 'widgets/amount_hero.dart';
import 'widgets/form_kit.dart';
import 'widgets/transaction_form_shell.dart';
import 'widgets/transfer_sections.dart';

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
  // A goal is created and edited on its own full-screen form (§3), not in the
  // numeric-hero sheet — the WATCHING picker and target↔date pair don't fit here.
  if (type == QuickAddType.newGoal && editing == null && copyOf == null) {
    return openGoalEditor(context);
  }
  // A budget is created on EditBudgetScreen, which requires a category — so like
  // a goal it leaves the sheet, but it asks a category first (§3). Editing an
  // existing transaction can never become a budget, hence the same guard.
  if (type == QuickAddType.newBudget && editing == null && copyOf == null) {
    return startNewBudgetFlow(context);
  }
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

/// New Budget leaves the Quick Add sheet the way New Goal does (§4), landing on
/// [EditBudgetScreen] in create mode with no category chosen. The category is
/// picked *on that screen* now — the old category-first sheet is gone, and the
/// picker it used is reached from the screen's Category row instead (spec §3/§4).
///
/// [context] must stay valid after any open Quick Add screen has been popped and
/// must resolve to the root navigator; the type-menu caller pops Quick Add first
/// and passes the navigator's overlay context (a descendant of the root
/// navigator that outlives the pop) for exactly this reason.
Future<void> startNewBudgetFlow(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const EditBudgetScreen()),
  );
}

/// The single throwaway [Txn] that represents what a save of the given form
/// state would do to its source account — the input to the overdraft warning
/// (task 011 §3.2). Never stored; a pure function so the warning and its parity
/// test share one definition and cannot drift.
///
/// A split expense keeps one source account and one total, so the source's
/// effect is the same whether or not the entry is split — one expense Txn for
/// the whole [amount] models it. A transfer folds its fee back in with
/// `feeFromSource`, because the real write drains the source by the net *and* a
/// separate fee expense; the draft's single effect must equal their sum. A
/// rebalance mirrors the branch `_save` will take (revaluation / income /
/// expense), landing the source on the same figure the write will. Returns null
/// for the creation types that write no transaction.
@visibleForTesting
Txn? buildDraftTxn(
  AppStore store, {
  required QuickAddType type,
  required double amount,
  String? fromRef,
  String? toRef,
  required String currency,
  required DateTime date,
  double? feeAmount,
  Txn? editing,
}) {
  switch (type) {
    case QuickAddType.expense:
      return Txn(
        id: '',
        type: TxnType.expense,
        amount: amount,
        currency: currency,
        fromRef: fromRef ?? '',
        toRef: toRef ?? '',
        date: date,
      );
    case QuickAddType.income:
      return Txn(
        id: '',
        type: TxnType.income,
        amount: amount,
        currency: currency,
        fromRef: fromRef ?? '',
        toRef: toRef ?? '',
        date: date,
      );
    case QuickAddType.transfer:
      final feeAmt = feeAmount ?? 0;
      final net = amount - feeAmt;
      return Txn(
        id: '',
        type: TxnType.transfer,
        amount: net,
        fee: feeAmt > 0 ? feeAmt : null,
        feeFromSource: true,
        currency: currency,
        fromRef: fromRef ?? '',
        toRef: toRef ?? '',
        date: date,
      );
    case QuickAddType.rebalance:
      final asset = store.accountById(toRef);
      if (asset == null) return null;
      // Baseline: balanceOf on create, balanceOf minus the edited record on edit
      // (Rebalance §1a) — the same rule `_baselineBalance` uses.
      final baseline = editing == null
          ? store.balanceOf(asset.id)
          : store.balanceOf(asset.id) - store.effectOfTxnOn(editing, asset.id);
      final signed = asset.group.isAsset ? amount : -amount;
      final delta = signed - baseline;
      final isReval = asset.group == AccountGroup.investments ||
          asset.group == AccountGroup.valuables;
      if (isReval) {
        return Txn(
          id: '',
          type: TxnType.rebalance,
          amount: delta,
          currency: asset.currency,
          fromRef: asset.id,
          toRef: asset.id,
          date: date,
        );
      }
      if (delta >= 0) {
        return Txn(
          id: '',
          type: TxnType.income,
          amount: delta,
          currency: asset.currency,
          fromRef: fromRef ?? '',
          toRef: asset.id,
          date: date,
        );
      }
      return Txn(
        id: '',
        type: TxnType.expense,
        amount: -delta,
        currency: asset.currency,
        fromRef: asset.id,
        toRef: fromRef ?? '',
        date: date,
      );
    case QuickAddType.newBudget:
    case QuickAddType.newGoal:
    case QuickAddType.newTask:
      return null;
  }
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
  final _noteFocus = FocusNode();
  final _title = TextEditingController();
  final _titleFocus = FocusNode();

  /// The glyph the Schedule row will carry. Seeded with the default `addTask`
  /// used to hard-code, so an untouched form saves exactly what it saved before.
  IconData _taskIcon = Icons.arrow_circle_up_rounded;

  /// The currency the transaction is *recorded in*. Set from the source when
  /// editing/copying (initState), otherwise primed to the base currency once
  /// the store is reachable (didChangeDependencies); picking an account
  /// overrides it with that account's currency. It is never left as a
  /// hard-coded dollar — a transaction saved before any account is chosen is
  /// stored in the base, not in USD.
  late String _currency;

  /// A rate the user typed for THIS entry (spec 021b §3) against the reporting
  /// currency, or null to use the proposal (the currency's stored rate today, or
  /// the nearest earlier entry's rate when back-dated). Reset whenever the
  /// currency changes, since a rate is meaningless across currencies.
  double? _entryRateOverride;
  bool _entryRateManual = false;

  String? _fromRef;
  String? _toRef;
  late DateTime _date; // primed from the store's clock in initState
  /// Selected tag IDS (not names). Resolved to display names for the field.
  List<String> _tagIds = [];

  bool _keypadOpen = false;

  /// The task form's amount row, so [_focusAmount] can scroll it above the
  /// docked keypad (task 007 §5.4). Unused by the numeric types — their hero
  /// sits at the top and never needs it.
  final _amountRowKey = GlobalKey();

  // Transfer — the rate and the fee amount are typed in their rows (Transfer-fee
  // spec §2/§3), not on a modal. The controllers own the live text; the summary
  // recomputes on every keystroke that parses.
  final _rateController = TextEditingController();
  final _rateFocus = FocusNode();
  final _feeController = TextEditingController();
  final _feeFocus = FocusNode();

  /// The category the fee expense is booked against (Transfer-fee spec §3.2).
  String? _feeCategoryId;

  /// The currency pair the rate field currently holds a value for. When From/To
  /// change to a new pair the field is re-defaulted; a rate from a pair that is
  /// no longer selected is not remembered (spec §2).
  String? _ratePairKey;

  // Toggles, shared across types that use them.
  RepeatFrequency _repeatFreq = RepeatFrequency.none;
  Set<int> _repeatWeekdays = {}; // weekly fire-days (ISO weekday)
  Set<int> _repeatDaysOfMonth = {}; // monthly fire-days / seed day
  int _repeatInterval = 1; // custom `Every N unit` step
  RepeatUnit _repeatUnit = RepeatUnit.month; // custom unit
  DateTime? _repeatEndDate; // Ends: on a date
  int? _repeatEndCount; // Ends: after N times (incl. the first)
  String? _recurrenceTaskId; // the Planner Task backing an existing repeat
  List<SplitLine>? _splitLines; // non-null once a split is applied
  bool _hasFee = false;

  /// The field flagged as missing after an incomplete Save (§3), and the pulse
  /// that flashes it. Cleared as soon as the field is filled.
  String? _flag;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));

  bool _editLoaded = false;

  /// Guards the one-time base-currency prime for a brand-new transaction (see
  /// [_currency]). Without it, a store notification re-firing
  /// didChangeDependencies would reset a currency the user had already fixed by
  /// picking an account.
  bool _currencyPrimed = false;

  bool get _isEditing => widget.editing != null;
  bool get _hasSplit => _splitLines != null;
  bool get _hasRepeat => _repeatFreq != RepeatFrequency.none;

  @override
  void initState() {
    super.initState();
    // The one clock: a new/copied transaction defaults to the real today (spec
    // §3 — this is the default that stops entries being written to 9 August).
    final store = StoreScope.read(context);
    final today = store.today;
    final source = widget.editing ?? widget.copyOf;
    if (source != null) {
      _type = switch (source.type) {
        TxnType.expense => QuickAddType.expense,
        TxnType.income => QuickAddType.income,
        TxnType.transfer => QuickAddType.transfer,
        TxnType.rebalance => QuickAddType.rebalance,
      };
      // A rebalance stores the *delta*, but the hero shows the *balance*
      // (Rebalance §1b): seed it with the account's resulting balance —
      // baseline + delta, i.e. its current balance magnitude — so reopening a
      // saved rebalance shows the balance it was set to, never the raw delta.
      _raw = source.type == TxnType.rebalance
          ? AmountEntry.fromDouble(store.balanceOf(source.toRef).abs())
          : AmountEntry.fromDouble(source.amount);
      _currency = source.currency;
      // Seed the rate row from the entry's own frozen rate (021b §4) so an edit
      // shows what it froze and a plain amount edit keeps it. A copy re-proposes.
      if (widget.editing != null && source.currency != store.baseCurrency) {
        _entryRateOverride = source.rateToBase;
      }
      _fromRef = source.fromRef;
      _toRef = source.toRef;
      // Spec 2.2 — a copy lands on today; an edit keeps its original date.
      _date = widget.editing != null ? source.date : today;
      _tagIds = List.of(source.tagIds);
      _note.text = source.note;
      _hasFee = (source.fee ?? 0) > 0;
      if (source.type == TxnType.transfer) {
        if (source.exchangeRate != null) {
          _rateController.text = source.exchangeRate!.toStringAsFixed(4);
        }
        // A legacy transfer that stored its fee on the record itself: surface it
        // so an edit forward-migrates it into a linked expense on Save. The
        // linked-expense case (the new model) is loaded once the store is
        // reachable, in didChangeDependencies.
        if ((source.fee ?? 0) > 0) {
          _feeController.text = _plainNumber(source.fee!);
        }
      }
    } else {
      _date = today;
      _type = widget.initialType;
      _fromRef = widget.fixedFromAccountId;
      _toRef = widget.fixedToAccountId;
    }
    // A text hero takes the system keyboard; a numeric one takes the keypad.
    _keypadOpen = !_isEditing && _type != QuickAddType.newTask;
    // Focus the title on open under the same conditions _switchType does (§5b),
    // so the keyboard rises whether the screen was reached from `+` or by
    // switching type. The keypad stays closed — _keypadOpen already excludes it.
    if (!_isEditing && widget.initialType == QuickAddType.newTask) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
    // One at a time (inline-note spec §2): however the note gains focus, the
    // keypad closes. The row's own tap path closes it too; this is the
    // backstop for focus arriving any other way.
    _noteFocus.addListener(_onNoteFocus);
    // The rate and fee amount are inline text fields on the transfer form; like
    // the note, gaining focus closes the numeric keypad so the keypad and the
    // system keyboard are never up together.
    _rateFocus.addListener(_onInlineFieldFocus);
    _feeFocus.addListener(_onInlineFieldFocus);
    // The title now shares a form with the keypad (the task's inline amount,
    // task 007): however the title gains focus, the keypad closes too. Before
    // this change only the note needed the backstop, because the title only ever
    // appeared on a form with no keypad.
    _titleFocus.addListener(_onTitleFocus);
  }

  void _onNoteFocus() {
    if (_noteFocus.hasFocus && _keypadOpen) {
      setState(() => _keypadOpen = false);
    }
  }

  void _onTitleFocus() {
    if (_titleFocus.hasFocus && _keypadOpen) {
      setState(() => _keypadOpen = false);
    }
  }

  void _onInlineFieldFocus() {
    if ((_rateFocus.hasFocus || _feeFocus.hasFocus) && _keypadOpen) {
      setState(() => _keypadOpen = false);
    }
  }

  /// An editable, plain string for a stored amount: no thousands grouping, no
  /// trailing `.0` on a whole number (`5`, not `5.0`; `5.5` stays `5.5`).
  static String _plainNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A brand-new transaction records in the base currency until an account is
    // picked (an edit/copy already carries its source's currency, set in
    // initState). Resolved here rather than initState because the store is only
    // reachable now; a fixed account (scoped Quick Add) wins over the base.
    if (!_currencyPrimed && widget.editing == null && widget.copyOf == null) {
      _currencyPrimed = true;
      final store = StoreScope.read(context);
      final fixedId = widget.fixedFromAccountId ?? widget.fixedToAccountId;
      final fixed = fixedId != null ? store.accountById(fixedId) : null;
      _currency = fixed?.currency ?? store.baseCurrency;
      // Prime the rate for any pre-filled accounts (a scoped Quick Add, or both
      // sides fixed) so the summary computes without a manual re-pick. A new
      // transfer with no accounts clears to empty (spec §2).
      if (_type == QuickAddType.transfer) _syncTransferRateField();
    }
    // Editing a saved transaction loads its repeat rule and, for a split, the
    // whole group (spec §1/§2). Done once, and here rather than initState so
    // the store is reachable.
    if (_editLoaded || widget.editing == null) return;
    _editLoaded = true;
    final store = StoreScope.read(context);
    final src = widget.editing!;
    _recurrenceTaskId = src.recurrenceTaskId;
    if (_recurrenceTaskId != null) {
      final task = store.taskById(_recurrenceTaskId);
      _repeatFreq = task?.repeats ?? RepeatFrequency.none;
      _repeatWeekdays = {...?task?.weekdays};
      _repeatDaysOfMonth = {...?task?.daysOfMonth};
      _repeatInterval = task?.repeatInterval ?? 1;
      _repeatUnit = task?.repeatUnit ?? RepeatUnit.month;
      _repeatEndDate = task?.repeatEndDate;
      _repeatEndCount = task?.repeatEndCount;
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
    if (src.type == TxnType.transfer) {
      // The new model keeps the fee in a linked expense (§4): load its amount
      // and category so the FEE section shows what will be re-saved.
      final feeId = src.feeTxnId;
      if (feeId != null) {
        final fee = store.txnById(feeId);
        if (fee != null) {
          _hasFee = true;
          _feeController.text = _plainNumber(fee.amount);
          _feeCategoryId = fee.toRef;
          // The transfer stores the NET; the Amount field is the GROSS. Rebuild
          // it as net + fee so the hero shows what left the source, and Save's
          // `gross − fee` recovers the same net rather than deducting twice.
          _raw = AmountEntry.fromDouble(src.amount + fee.amount);
        }
      }
      // Mark the loaded pair as already primed so the rate the transfer was
      // saved with is not overwritten by the FX default (§2).
      final from = store.accountById(src.fromRef);
      final to = store.accountById(src.toRef);
      if (from != null && to != null && from.currency != to.currency) {
        _ratePairKey = '${from.currency}>${to.currency}';
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _note.dispose();
    _noteFocus.dispose();
    _title.dispose();
    _titleFocus.dispose();
    _rateController.dispose();
    _rateFocus.dispose();
    _feeController.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  double get _amount => AmountEntry.value(_raw);

  /// A scheduled task's direction comes from its category (task 030 §3): an
  /// income category means the money arrives. Without a category there is
  /// nothing to read, and a task defaults to a pay-out — the sign every task
  /// carried before the create form could ask. The category is held in
  /// `_fromRef` on the task form.
  bool get _taskIsPayIn =>
      StoreScope.read(context).categoryById(_fromRef)?.type ==
      CategoryType.income;

  /// Whether the task form has a resolved category. Only then does the amount
  /// row show a sign (task 030 §3).
  bool _hasTaskCategory(AppStore store) => store.categoryById(_fromRef) != null;

  // ── Type switching ────────────────────────────────────────────────────────

  _Slot _fromSlot(QuickAddType t) => switch (t) {
        QuickAddType.expense => _Slot.account,
        QuickAddType.income => _Slot.incomeCategory,
        QuickAddType.transfer => _Slot.account,
        QuickAddType.rebalance => _Slot.account,
        // Intercepted before the sheet builds (§4); the slot is never read.
        QuickAddType.newBudget => _Slot.none,
        QuickAddType.newGoal => _Slot.none,
        QuickAddType.newTask => _Slot.expenseCategory,
      };

  _Slot _toSlot(QuickAddType t) => switch (t) {
        QuickAddType.expense => _Slot.expenseCategory,
        QuickAddType.income => _Slot.account,
        QuickAddType.transfer => _Slot.account,
        QuickAddType.rebalance => _Slot.account,
        // Intercepted before the sheet builds (§4); the slot is never read.
        QuickAddType.newBudget => _Slot.none,
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
    // The note unfocuses cleanly on a type change (inline-note spec §6): its
    // row may move or vanish with the new config, and the keypad is coming
    // back — the keyboard must not linger under it.
    _noteFocus.unfocus();
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
        'title' => _title.text.trim().isNotEmpty,
        'from' => _fromRef != null,
        'to' => _toRef != null,
        // Rebalance's category row (§4): the picked category lands in _fromRef.
        'category' => _fromRef != null,
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
      // Unfocus before the pop (inline-note spec §2): otherwise the keyboard
      // stays up and the sheet animates out from behind it.
      onCancel: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
      },
      onTypeTap: _showTypeMenu,
      onSave: () => _save(store),
      keypadOpen: _keypadOpen,
      onHeroTap: () {
        _titleFocus.unfocus();
        _noteFocus.unfocus();
        setState(() => _keypadOpen = true);
      },
      onKey: (k) => setState(() {
        _raw = AmountEntry.press(_raw, k);
        // A changed amount can flip the difference's sign, which changes which
        // category list applies; drop a category that no longer fits (§4).
        if (_type == QuickAddType.rebalance) _reconcileRebalanceCategory(store);
      }),
      onBackspace: () => setState(() {
        _raw = AmountEntry.backspace(_raw);
        if (_type == QuickAddType.rebalance) _reconcileRebalanceCategory(store);
      }),
      onDismissKeypad: () => setState(() => _keypadOpen = false),
    );
  }

  FormConfig _config(AppStore store) => switch (_type) {
        QuickAddType.expense => _expense(store),
        QuickAddType.income => _income(store),
        QuickAddType.transfer => _transfer(store),
        QuickAddType.rebalance => _rebalance(store),
        // newBudget and newGoal never render in the sheet — both are intercepted
        // at entry and in the type menu, routing to a full-screen form. These
        // branches are unreachable and only keep the switch exhaustive (§4).
        QuickAddType.newBudget => _expense(store),
        QuickAddType.newGoal => _expense(store),
        QuickAddType.newTask => _task(store),
      };

  // ── Shared field builders ─────────────────────────────────────────────────

  NumericHero _amountHero([String? label]) => NumericHero(
        label: label ?? AppLocalizations.of(context).qaAmount,
        raw: _raw,
        currency: _currency,
        onCurrencyTap: () async {
          final c = await pickCurrency(context, _currency);
          if (c != null && mounted) {
            setState(() {
              _currency = c;
              // A rate is meaningless across currencies — re-propose (021b §3c).
              _entryRateOverride = null;
              _entryRateManual = false;
            });
          }
        },
      );

  /// The proposal for this entry's rate, given the current currency and date
  /// (spec 021b §3a). Null when the currency has no stored rate and no earlier
  /// entry to borrow from — the blocked case (§3b).
  RateProposal _rateProposal(AppStore store) =>
      store.rateProposal(_currency, _date);

  /// The effective per-entry rate: the user's override, else the proposal.
  double? _effectiveEntryRate(AppStore store) =>
      _entryRateOverride ?? _rateProposal(store).rate;

  /// The rate row (spec 021b §3), last in REQUIRED, present only when this
  /// entry's currency differs from the reporting currency.
  FieldSpec _rateField(AppStore store) {
    final l = AppLocalizations.of(context);
    final rate = _effectiveEntryRate(store);
    final proposal = _rateProposal(store);
    // Marker: the user's own rate reads accent; a rate borrowed from an earlier
    // back-dated entry reads secondary; today's stored rate is unmarked. The
    // form kit has no glyph slot, so the state is carried in the value colour.
    final Color? valueColor = rate == null
        ? AppColors.warning
        : (_entryRateManual
            ? AppColors.accent
            : (proposal.source == RateProposalSource.earlierEntry
                ? AppColors.textSecondary
                : null));
    return FieldSpec(
      icon: Icons.currency_exchange_rounded,
      label: '1 ${store.baseCurrency} =',
      value: rate == null
          ? l.curSetRate
          : '${formatRate(rate)} $_currency',
      valueColor: valueColor,
      flashId: 'rate',
      opensSheet: true,
      onTap: () async {
        final v = await promptDecimal(
          context,
          title: AppLocalizations.of(context).qaExchangeRate,
          initial: rate,
          hint: '1 ${store.baseCurrency} = ? $_currency',
        );
        if (v != null && mounted) {
          setState(() {
            _entryRateOverride = v;
            _entryRateManual = true;
          });
        }
      },
    );
  }

  FieldSpec _dateField({String? label}) {
    final l = AppLocalizations.of(context);
    // A real date, never a relative word (spec §1); the year is dropped within
    // the current year. The time follows the device's 12-/24-hour setting.
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_date),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return FieldSpec(
      icon: Icons.event_rounded,
      label: label ?? l.qaDate,
      value: l.dateWithTime(
          dateAbsolute(_date, l, now: StoreScope.read(context).today), time),
      onTap: _pickDate,
      // _pickDate raises the app-native date+time bottom sheet.
      opensSheet: true,
    );
  }

  FieldSpec _tagField() {
    final store = StoreScope.of(context);
    final names = store.tagNames(_tagIds);
    return FieldSpec(
      icon: Icons.sell_rounded,
      label: AppLocalizations.of(context).qaTag,
      value: names.isEmpty ? null : names.map((n) => '#$n').join(' '),
      emptyText: AppLocalizations.of(context).qaNone,
      // showTagPicker raises a bottom sheet.
      opensSheet: true,
      onTap: () => showTagPicker(
        context,
        selected: _tagIds.toSet(),
        // Selections apply as they are made; the field just reflects them.
        onChanged: (ids) {
          if (mounted) setState(() => _tagIds = ids.toList());
        },
      ),
    );
  }

  /// The note is typed in the row (inline-note spec §1): no modal, no
  /// commit-or-discard round trip — the TextField binds straight to [_note],
  /// so it commits as every other field does, on touch. The row itself derives
  /// the unfocused preview (label hidden, newlines collapsed, two lines) from
  /// the controller; [FieldSpec.onTap] fires as editing starts, which is where
  /// the keypad closes so it and the system keyboard are never open together.
  FieldSpec _noteField() {
    final l = AppLocalizations.of(context);
    return FieldSpec(
      icon: Icons.notes_rounded,
      label: l.qaNote,
      emptyText: l.qaAddNote,
      controller: _note,
      focusNode: _noteFocus,
      maxLength: _kNoteLimit,
      counterThreshold: _kNoteCounterThreshold,
      onTap: () => setState(() => _keypadOpen = false),
    );
  }

  /// Repeat as a row in the OPTIONAL card (spec §3): the frequency word on the
  /// right, and the leading icon in the accent when a repeat is set so the form
  /// shows at a glance that the transaction recurs.
  FieldSpec _repeatField() {
    final l = AppLocalizations.of(context);
    return FieldSpec(
      icon: Icons.repeat_rounded,
      label: l.rsRepeat,
      value: _hasRepeat ? txnRepeatWord(_repeatFreq, l) : null,
      emptyText: l.repeatNever,
      iconColor: _hasRepeat ? AppColors.accent : null,
      onTap: _openTxnRepeat,
      // _openTxnRepeat raises the Repeat bottom sheet.
      opensSheet: true,
    );
  }

  /// Split as one full-width action (spec §7): labelled with what it does, and
  /// stating its reason on a line beneath when there is no amount to split.
  FormActionSpec _splitAction(AppStore store) {
    final l = AppLocalizations.of(context);
    return FormActionSpec(
      icon: Icons.call_split_rounded,
      label: l.qaSplitAction,
      enabled: _amount > 0,
      disabledReason: _amount > 0 ? null : l.qaSplitNeedsAmount,
      onTap: () => _openSplit(store),
    );
  }

  /// The transaction form's Repeat chooser — its own sheets (Repeat / Custom /
  /// Ends), distinct from the Planner task editor's [showRepeatSheet].
  Future<void> _openTxnRepeat() async {
    // Planner's Task can't represent a multi-transaction (split) occurrence, so
    // the combination is blocked with a clear message (spec §5).
    if (_hasSplit) {
      _toast("Can't repeat a split transaction");
      return;
    }
    setState(() => _keypadOpen = false);
    final sel = await showTxnRepeatSheet(
      context,
      current: TxnRepeatSelection(
        freq: _repeatFreq,
        weekdays: _repeatWeekdays,
        daysOfMonth: _repeatDaysOfMonth,
        interval: _repeatInterval,
        unit: _repeatFreq == RepeatFrequency.custom ? _repeatUnit : null,
        endDate: _repeatEndDate,
        endCount: _repeatEndCount,
      ),
      date: _date,
    );
    if (sel == null || !mounted) return;
    setState(() {
      _repeatFreq = sel.freq;
      _repeatWeekdays = sel.weekdays;
      _repeatDaysOfMonth = sel.daysOfMonth;
      _repeatInterval = sel.interval;
      _repeatUnit = sel.unit ?? RepeatUnit.month;
      _repeatEndDate = sel.endDate;
      _repeatEndCount = sel.endCount;
    });
  }

  Future<void> _openSplit(AppStore store) async {
    if (_hasRepeat) {
      _toast("Can't split a repeating transaction");
      return;
    }
    if (_amount <= 0) return;
    final income = _type == QuickAddType.income;
    final catType = income ? CategoryType.income : CategoryType.expense;
    final account = store.accountById(income ? _toRef : _fromRef);
    // Not-yet-split: open with a single line carrying the transaction's own
    // category (which may be unset), amount blank (spec §5).
    final currentCategory = income ? _fromRef : _toRef;
    setState(() => _keypadOpen = false);
    final result = await showSplitSheet(
      context,
      total: _amount,
      currency: _currency,
      accountName: account?.name ?? '—',
      categoryType: catType,
      initial: _splitLines ?? [SplitLine(categoryId: currentCategory)],
    );
    if (result == null || !mounted) return;
    // A list shorter than two lines means "no split". That branch used to be
    // unreachable — the sheet could only pop a balanced list of two or more —
    // and the header's Remove now reaches it by popping an empty list. `_toRef`
    // / `_fromRef` still hold the category the row carried before the split, so
    // the row returns to it with nothing to recompute.
    setState(() => _splitLines = result.length >= 2 ? result : null);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The split's lines, listed beneath whichever row carries the count. Null
  /// without a split, so [FieldSpec] renders exactly as it always has.
  List<Widget>? _splitChildRows(AppStore store) {
    if (!_hasSplit) return null;
    return buildSplitChildRows(
      context: context,
      store: store,
      lines: _splitLines!,
      currency: _currency,
      // One destination: the summary row and every line open the same editor.
      onTap: () => _openSplit(store),
    );
  }

  bool _splitBalanced() =>
      _splitLines != null && splitBalanced(_amount, _splitLines!);

  // ── Configs ───────────────────────────────────────────────────────────────

  FormConfig _expense(AppStore store) {
    final from = store.accountById(_fromRef);
    final to = store.categoryById(_toRef);
    return FormConfig(
      typeName: AppLocalizations.of(context).quickAddExpense,
      accent: AppColors.expense,
      accentDim: AppColors.expenseDim,
      hero: _amountHero(),
      groups: [
        FieldGroup(AppLocalizations.of(context).qaGroupRequired.toUpperCase(), [
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: AppLocalizations.of(context).qaFrom,
            value: from?.name,
            emptyText: AppLocalizations.of(context).qaChooseAccount,
            flashId: 'from',
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: widget.fixedFromAccountId != null
                ? null
                : () => _pickAccountInto(store, isFrom: true, title: AppLocalizations.of(context).qaPaymentAccount),
          ),
          FieldSpec(
            icon: Icons.category_rounded,
            label: AppLocalizations.of(context).qaTo,
            // A split replaces the single category with the line count (§2).
            value: _hasSplit
                ? AppLocalizations.of(context).qaSplitCategories(_splitLines!.length)
                : to?.name,
            emptyText: AppLocalizations.of(context).qaChooseCategory,
            flashId: 'to',
            // Both branches raise a bottom sheet (split editor / category picker).
            opensSheet: true,
            onTap: _hasSplit
                ? () => _openSplit(store)
                : () => _pickCategoryInto(CategoryType.expense, isFrom: false),
            // The count says how many; these say which (§1). Absent without a
            // split, so an unsplit row is byte-identical to before.
            childRows: _splitChildRows(store),
          ),
          // The 021b rate row — last in REQUIRED, only for a foreign entry.
          if (_currency != store.baseCurrency) _rateField(store),
        ]),
        FieldGroup(AppLocalizations.of(context).qaGroupOptional.toUpperCase(),
            [_dateField(), _tagField(), _repeatField(), _noteField()]),
      ],
      toggles: const [],
      action: _splitAction(store),
      saveLabel: AppLocalizations.of(context).qaSaveExpense,
      blockers: [
        Blocker(unmet: _amount <= 0, label: AppLocalizations.of(context).qaBlockAmount, flashId: 'amount'),
        Blocker(unmet: _fromRef == null, label: AppLocalizations.of(context).qaBlockAccount, flashId: 'from'),
        Blocker(
            unmet: _toRef == null && !_hasSplit,
            label: AppLocalizations.of(context).qaBlockCategory,
            flashId: 'to'),
        Blocker(
            unmet: _hasSplit && !_splitBalanced(),
            label: AppLocalizations.of(context).qaBlockSplit,
            flashId: 'to'),
        Blocker(
            unmet: _currency != store.baseCurrency &&
                _effectiveEntryRate(store) == null,
            label: AppLocalizations.of(context).qaBlockRate,
            flashId: 'rate'),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _income(AppStore store) {
    final from = store.categoryById(_fromRef);
    final to = store.accountById(_toRef);
    return FormConfig(
      typeName: AppLocalizations.of(context).quickAddIncome,
      accent: AppColors.income,
      accentDim: AppColors.incomeDim,
      hero: _amountHero(),
      groups: [
        FieldGroup(AppLocalizations.of(context).qaGroupRequired.toUpperCase(), [
          FieldSpec(
            icon: Icons.category_rounded,
            label: AppLocalizations.of(context).qaFrom,
            // Income splits the source category, so From carries the count.
            value: _hasSplit
                ? AppLocalizations.of(context).qaSplitCategories(_splitLines!.length)
                : from?.name,
            emptyText: AppLocalizations.of(context).qaChooseCategory,
            flashId: 'from',
            // Both branches raise a bottom sheet (split editor / category picker).
            opensSheet: true,
            onTap: _hasSplit
                ? () => _openSplit(store)
                : () => _pickCategoryInto(CategoryType.income, isFrom: true),
            childRows: _splitChildRows(store),
          ),
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: AppLocalizations.of(context).qaTo,
            value: to?.name,
            emptyText: AppLocalizations.of(context).qaChooseAccount,
            flashId: 'to',
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: () =>
                _pickAccountInto(store, isFrom: false, title: AppLocalizations.of(context).qaIncomeAccount),
          ),
          if (_currency != store.baseCurrency) _rateField(store),
        ]),
        FieldGroup(AppLocalizations.of(context).qaGroupOptional.toUpperCase(),
            [_dateField(), _tagField(), _repeatField(), _noteField()]),
      ],
      toggles: const [],
      action: _splitAction(store),
      saveLabel: AppLocalizations.of(context).qaSaveIncome,
      blockers: [
        Blocker(unmet: _amount <= 0, label: AppLocalizations.of(context).qaBlockAmount, flashId: 'amount'),
        Blocker(
            unmet: _fromRef == null && !_hasSplit,
            label: AppLocalizations.of(context).qaBlockCategory,
            flashId: 'from'),
        Blocker(unmet: _toRef == null, label: AppLocalizations.of(context).qaBlockAccount, flashId: 'to'),
        Blocker(
            unmet: _hasSplit && !_splitBalanced(),
            label: AppLocalizations.of(context).qaBlockSplit,
            flashId: 'from'),
        Blocker(
            unmet: _currency != store.baseCurrency &&
                _effectiveEntryRate(store) == null,
            label: AppLocalizations.of(context).qaBlockRate,
            flashId: 'rate'),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _transfer(AppStore store) {
    final l = AppLocalizations.of(context);
    final from = store.accountById(_fromRef);
    final to = store.accountById(_toRef);
    final cross =
        from != null && to != null && from.currency != to.currency;
    final rate = _rate ?? _defaultRate(from, to);
    // The summary appears only when the two sides differ — a fee exists, or the
    // currencies do (spec §5). It also needs both accounts, to name its rows.
    final showSummary = from != null &&
        to != null &&
        transferShowsSummary(fee: _feeAmount, cross: cross);

    return FormConfig(
      typeName: l.quickAddTransfer,
      accent: AppColors.transfer,
      accentDim: AppColors.transferDim,
      hero: _amountHero(),
      groups: [
        FieldGroup(l.qaGroupRequired.toUpperCase(), [
          FieldSpec(
            icon: Icons.north_east_rounded,
            label: l.qaFrom,
            value: from?.name,
            emptyText: l.qaChooseAccount,
            flashId: 'from',
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: widget.fixedFromAccountId != null
                ? null
                : () => _pickAccountInto(
                      store,
                      isFrom: true,
                      title: l.qaSourceAccount,
                      excludeId: _toRef,
                    ),
          ),
          FieldSpec(
            icon: Icons.south_west_rounded,
            label: l.qaTo,
            value: to?.name,
            emptyText: l.qaChooseAccount,
            flashId: 'to',
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: widget.fixedToAccountId != null
                ? null
                : () => _pickAccountInto(
                      store,
                      isFrom: false,
                      title: l.qaDestinationAccount,
                      excludeId: _fromRef,
                    ),
          ),
        ]),
        // Money order (§1): EXCHANGE (only when currencies differ), then the
        // FEE button/section, then the SUMMARY, then OPTIONAL. The Receives row
        // is gone — the summary answers "arrives"; the rate is typed in its row.
        if (cross) FieldGroup.custom(_exchangeSection(from, to)),
        FieldGroup.custom(_feeSection(store, from)),
        if (showSummary)
          FieldGroup.custom(_summarySection(store, from, to, cross, rate)),
        // No Tag: money moved between your own accounts is not spending and
        // should not enter tag reporting.
        FieldGroup(l.qaGroupOptional.toUpperCase(),
            [_dateField(), _repeatField(), _noteField()]),
      ],
      // The Fee toggle is gone — it is a button that opens the FEE section in
      // place (§3.1); a transfer has no Split, so the toggle bar is empty.
      toggles: const [],
      saveLabel: l.qaSaveTransfer,
      blockers: [
        Blocker(unmet: _amount <= 0, label: l.qaBlockAmount, flashId: 'amount'),
        Blocker(
            unmet: _fromRef == null,
            label: l.qaBlockSourceAccount,
            flashId: 'from'),
        Blocker(
            unmet: _toRef == null,
            label: l.qaBlockDestination,
            flashId: 'to'),
        // A blank or unparseable rate blanks the arriving figure and stops Save
        // (§2). No flashId: the rate lives in a custom section, not a flashable
        // field row.
        Blocker(
            unmet: cross && (_rate == null || _rate! <= 0),
            label: l.trBlockRate),
        // A fee that eats the whole transfer is not a transfer (§3.3).
        Blocker(unmet: !_feeIsValid, label: l.trBlockFeeTooBig),
        // A fee with no category lands in no budget and no report (§3.3).
        Blocker(unmet: !_feeIsComplete, label: l.trBlockFeeCategory),
      ],
      trailing: _editingExtras(),
    );
  }

  // ── Transfer sections (Transfer-fee spec §2/§3/§5) ─────────────────────────

  /// Gross (the hero amount), the source currency's magnitude that leaves.
  double get _grossAmount => _amount;

  /// The typed fee, or null when the field is blank/unparseable (spec §3).
  double? get _feeAmount => double.tryParse(_feeController.text.trim());

  /// The typed rate, or null when blank/unparseable (spec §2).
  double? get _rate => double.tryParse(_rateController.text.trim());

  /// A fee must leave something to transfer (spec §3.3).
  bool get _feeIsValid => transferFeeValid(_grossAmount, _feeAmount);

  /// A non-zero fee must have a category (spec §3.3). A zero/blank fee is the
  /// same as no fee, and needs none.
  bool get _feeIsComplete => transferFeeComplete(_feeAmount, _feeCategoryId);

  /// Deducted first, converted second (spec §4.2). Delegates to the shared pure
  /// rule so the form and its tests never diverge.
  double _arrivingAmount(bool cross, double rate, String toCurrency) =>
      transferArriving(
        gross: _grossAmount,
        fee: _feeAmount,
        cross: cross,
        rate: rate,
        toCurrency: toCurrency,
      );

  Widget _exchangeSection(Account from, Account to) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FormSectionLabel(l.qaExchange),
        TxnCard(children: [
          InRowNumberField(
            icon: Icons.swap_horiz_rounded,
            label: l.qaRate,
            controller: _rateController,
            focusNode: _rateFocus,
            // Live: every parsing keystroke moves the summary (§2).
            onChanged: (_) => setState(() {}),
            numberColor: AppColors.textPrimary,
            prefix: '1 ${from.currency} = ',
            suffix: ' ${to.currency}',
            semanticsLabel: '${l.qaRate}, 1 ${from.currency} = ${to.currency}',
          ),
        ]),
      ],
    );
  }

  Widget _feeSection(AppStore store, Account? from) {
    final l = AppLocalizations.of(context);
    // Before it is opened, the button stands where the section will (§3.1),
    // whether or not the currencies differ.
    if (!_hasFee) {
      return TransferFeeButton(label: l.qaFee, onTap: _addFee);
    }
    // The fee is always charged in the source account's currency (§decisions).
    final feeCurrency = from?.currency ?? _currency;
    final category = store.categoryById(_feeCategoryId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TransferFeeHeader(
          label: l.qaFee,
          removeLabel: l.trRemove,
          onRemove: _removeFee,
        ),
        TxnCard(children: [
          InRowNumberField(
            icon: Icons.payments_rounded,
            label: l.qaAmount,
            controller: _feeController,
            focusNode: _feeFocus,
            onChanged: (_) => setState(() {}),
            numberColor: AppColors.negative,
            suffix: ' $feeCurrency',
            semanticsLabel: '${l.qaAmount}, $feeCurrency',
          ),
          TxnFieldRow(
            icon: category?.icon ?? Icons.shopping_basket_rounded,
            iconColor: category?.color,
            label: l.fieldCategory,
            value: category?.name,
            emptyText: l.eaNotSet,
            opensSheet: true,
            onTap: _pickFeeCategory,
          ),
        ]),
        TransferCaption(_feeBookingText(from, category)),
      ],
    );
  }

  Widget _summarySection(
      AppStore store, Account from, Account to, bool cross, double rate) {
    final l = AppLocalizations.of(context);
    final masked = store.masked;
    final arriving = _arrivingAmount(cross, rate, to.currency);
    final children = <Widget>[
      TransferSummaryCard(rows: [
        TransferSummaryRow(
          label: l.trLeaves(from.name),
          // Force cents: the summary reconciles two exact figures, so it always
          // shows them to the currency's precision ("$2,000.00"), not the
          // headline-rounded form money() gives whole values ≥ 1000.
          value: money(_grossAmount,
              currency: from.currency, masked: masked, forceDecimals: true),
          valueColor: AppColors.negative,
        ),
        TransferSummaryRow(
          label: l.trArrives(to.name),
          caption: _arrivesCaption(masked, cross, rate, from.currency),
          value: money(arriving,
              currency: to.currency, masked: masked, forceDecimals: true),
          valueColor: AppColors.positive,
        ),
      ]),
    ];
    // Below the card, when a fee exists: the account and category it is booked
    // against (§5).
    if ((_feeAmount ?? 0) > 0) {
      children.add(TransferCaption(
          _feeBookingText(from, store.categoryById(_feeCategoryId))));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// The arriving figure appears in no field — it is derived from up to three
  /// (spec §5). The caption shows its work; its money parts mask.
  String? _arrivesCaption(
      bool masked, bool cross, double rate, String sourceCurrency) {
    final net = transferNet(_grossAmount, _feeAmount);
    final l = AppLocalizations.of(context);
    final netStr = money(net, currency: sourceCurrency, masked: masked);
    final grossStr = money(_grossAmount, currency: sourceCurrency, masked: masked);
    final feeStr =
        money(_feeAmount ?? 0, currency: sourceCurrency, masked: masked);
    final rateStr = _rateString(rate);
    return switch (arrivesCaptionShape(fee: _feeAmount, cross: cross)) {
      ArrivesCaptionShape.feeAndRate => l.trCapFeeAndRate(netStr, feeStr, rateStr),
      ArrivesCaptionShape.fee => l.trCapFee(grossStr, feeStr),
      ArrivesCaptionShape.rate => l.trCapRate(rateStr),
      ArrivesCaptionShape.none => null,
    };
  }

  /// The rate for the caption: up to four decimals, trailing zeros trimmed
  /// (`0.9091`, `1.1`), never masked — it is not a monetary amount and is shown
  /// unmasked in its own row above.
  String _rateString(double rate) {
    var s = rate.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  String _feeBookingText(Account? from, Category? category) {
    final l = AppLocalizations.of(context);
    final acct = from?.name ?? '—';
    return category == null
        ? l.trFeeBookedAccount(acct)
        : l.trFeeBookedFull(acct, category.name);
  }

  void _addFee() => setState(() {
        _hasFee = true;
        _keypadOpen = false;
      });

  void _removeFee() => setState(() {
        _hasFee = false;
        _feeController.clear();
        _feeCategoryId = null;
      });

  Future<void> _pickFeeCategory() async {
    setState(() => _keypadOpen = false);
    final c = await pickCategory(context, type: CategoryType.expense);
    if (c == null || !mounted) return;
    setState(() => _feeCategoryId = c.id);
  }

  /// Re-defaults the rate field when the currency pair changes, and clears it
  /// when the two sides match (spec §2 — a rate from a pair no longer selected
  /// is not remembered). A rate typed for the current pair is left untouched.
  void _syncTransferRateField() {
    final store = StoreScope.read(context);
    final from = store.accountById(_fromRef);
    final to = store.accountById(_toRef);
    final cross =
        from != null && to != null && from.currency != to.currency;
    if (!cross) {
      _ratePairKey = null;
      _rateController.clear();
      return;
    }
    final key = '${from.currency}>${to.currency}';
    if (key != _ratePairKey) {
      _ratePairKey = key;
      _rateController.text =
          Fx.rate(from.currency, to.currency).toStringAsFixed(4);
    }
  }

  /// Value that moves on its own — a price, not a payment. Only these two groups
  /// book a revaluation; everywhere else a difference is money that came in or
  /// went out and was never recorded (Rebalance §3).
  bool _isRevaluation(Account a) =>
      a.group == AccountGroup.investments || a.group == AccountGroup.valuables;

  /// The account's balance excluding the record being edited — the baseline a
  /// new balance is compared against (Rebalance §1a). On create there is nothing
  /// to exclude, so this is [AppStore.balanceOf]; on edit, `balanceOf` already
  /// contains the delta being replaced, and subtracting a new balance from it
  /// double-counts the old one, so the editing record's effect is removed first.
  double _baselineBalance(AppStore store, String accountId) {
    final base = store.balanceOf(accountId);
    final editing = widget.editing;
    if (editing == null) return base;
    return base - store.effectOfTxnOn(editing, accountId);
  }

  /// Drops a chosen rebalance category when it no longer belongs to the list the
  /// current difference calls for — an income category stranded on a now-negative
  /// difference, or any category once the account became a revaluation (§4).
  /// A silently retained expense category on an income is the bug this task is
  /// about; the sign flipping is exactly when it happens.
  void _reconcileRebalanceCategory(AppStore store) {
    if (_fromRef == null) return;
    final account = store.accountById(_toRef);
    if (account == null) return;
    if (_isRevaluation(account)) {
      _fromRef = null; // a price change files under no category
      return;
    }
    if (_raw.isEmpty) return; // no difference yet — nothing to reconcile against
    final baseline = _baselineBalance(store, account.id);
    final signed = account.group.isAsset ? _amount : -_amount;
    final diff = signed - baseline;
    final needed = diff >= 0 ? CategoryType.income : CategoryType.expense;
    if (store.categoryById(_fromRef)?.type != needed) _fromRef = null;
  }

  FormConfig _rebalance(AppStore store) {
    final l = AppLocalizations.of(context);
    final account = store.accountById(_toRef);
    final isReval = account != null && _isRevaluation(account);
    // The baseline the new balance is measured against — balanceOf on create,
    // balanceOf minus the editing record on edit (§1a). Rendered by `Current`.
    final baseline =
        account == null ? 0.0 : _baselineBalance(store, account.id);
    final entered = _raw.isEmpty ? null : _amount; // a magnitude (§1d)
    // The keypad cannot type a minus, so the account gives the balance its side:
    // an asset is positive, a liability negative (§1d).
    final newBalance = entered == null || account == null
        ? null
        : (account.group.isAsset ? entered : -entered);
    final diff = newBalance == null ? null : newBalance - baseline;
    // Every figure here is the account's own currency now (§1c) — no _currency.
    final currency = account?.currency ?? _currency;

    return FormConfig(
      typeName: l.quickAddRebalance,
      accent: AppColors.rebalance,
      accentDim: AppColors.rebalanceDim,
      // The user types what the balance *is*, not what changed. The unit is the
      // account's property, so the chip is locked (§2a).
      hero: NumericHero(
        label: l.qaNewBalance,
        raw: _raw,
        currency: currency,
        currencyLocked: true,
      ),
      groups: [
        FieldGroup(l.qaGroupRequired.toUpperCase(), [
          FieldSpec(
            icon: Icons.donut_large_rounded,
            label: l.qaAccount,
            value: account?.name,
            emptyText: l.qaChooseAccount,
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: () => _pickAccountInto(
              store,
              isFrom: false,
              title: l.qaRevaluedAccount,
            ),
          ),
          FieldSpec(
            icon: Icons.menu_book_rounded,
            label: l.qaCurrent,
            // Same account, same unit as the chip two rows up: drop the token,
            // keep the sign and the dim colour (§2c). The spoken value keeps it.
            value: account == null
                ? null
                : money(baseline, currency: currency, withSymbol: false),
            semanticValue: account == null
                ? null
                : money(baseline, currency: currency),
            emptyText: '—',
            valueColor: AppColors.textSecondary,
          ),
          FieldSpec(
            icon: Icons.swap_vert_rounded,
            label: l.qaDifference,
            value: diff == null
                ? null
                : money(diff,
                    currency: currency, withSymbol: false, showSign: true),
            semanticValue: diff == null
                ? null
                : money(diff, currency: currency, showSign: true),
            emptyText: '—',
            valueColor: diff == null
                ? null
                : (diff >= 0 ? AppColors.positive : AppColors.negative),
          ),
          // A difference on anything but an investment or a valuable is money
          // that came in or went out — file it under a category like any entry
          // (§4). Absent for a revaluation: a price change files under nothing.
          if (account != null && !isReval)
            FieldSpec(
              icon: Icons.category_rounded,
              label: l.fieldCategory,
              value: store.categoryById(_fromRef)?.name,
              emptyText: l.qaChooseCategory,
              flashId: 'category',
              // _pickCategoryInto raises the category bottom sheet; the picker's
              // own title names the list. Negative → expense, positive (or not
              // yet typed) → income, chosen at tap time.
              opensSheet: true,
              onTap: () => _pickCategoryInto(
                (diff != null && diff < 0)
                    ? CategoryType.expense
                    : CategoryType.income,
                isFrom: true,
              ),
            ),
        ]),
        FieldGroup(l.qaGroupOptional.toUpperCase(), [
          _dateField(),
          _noteField(),
        ]),
      ],
      // The hint banner is gone (§5a): it merely repeated the Difference row, and
      // its "dated today" wording could contradict the Date row.
      // The Reason row is gone (§5b): §4's Category row is the real version of
      // what it pretended to be.
      toggles: const [],
      // Renders nowhere today, but named correctly anyway (§3): expense/income
      // for a real entry, adjustment for a revaluation.
      saveLabel: isReval
          ? l.qaSaveAdjustment
          : ((diff != null && diff < 0) ? l.qaSaveExpense : l.qaSaveIncome),
      blockers: [
        Blocker(unmet: _toRef == null, label: l.qaBlockAccount),
        Blocker(unmet: _raw.isEmpty, label: l.qaEnterNewBalance),
        Blocker(
          unmet: _raw.isNotEmpty && diff == 0,
          label: l.qaBlockBalanceUnchanged,
        ),
        // Non-revaluation only: a real entry needs a category (§4). Never blocks
        // a revaluation, which has none.
        Blocker(
          unmet: account != null && !isReval && _fromRef == null,
          label: l.qaBlockCategory,
          flashId: 'category',
        ),
      ],
      trailing: _editingExtras(),
    );
  }

  FormConfig _task(AppStore store) {
    final account = store.accountById(_toRef);
    return FormConfig(
      typeName: AppLocalizations.of(context).quickAddNewTask,
      accent: AppColors.task,
      accentDim: AppColors.taskDim,
      // The only type with no amount, so the hero is text (task 004): one 48pt
      // name line whose glyph previews and picks the task's icon.
      hero: TextHero(
        placeholder: AppLocalizations.of(context).qaTaskPlaceholder,
        controller: _title,
        focusNode: _titleFocus,
        semanticsLabel: AppLocalizations.of(context).etTaskTitle,
        icon: _taskIcon,
        onIconTap: _pickTaskIcon,
      ),
      groups: [
        FieldGroup(AppLocalizations.of(context).qaGroupRequired.toUpperCase(), [_dateField(label: AppLocalizations.of(context).qaDue)]),
        FieldGroup(AppLocalizations.of(context).qaGroupOptional.toUpperCase(), [
          // Demoted from Required: most tasks have no amount. When set, the
          // task can later be turned into a transaction in one tap.
          // Typed in place (task 007): the docked keypad writes here, a tap
          // focuses the row instead of opening a sheet, and the currency-neutral
          // icon (§3) sits beside a tappable currency chip.
          FieldSpec(
            icon: Icons.numbers_rounded,
            label: AppLocalizations.of(context).qaAmount,
            raw: _raw,
            currency: _currency,
            emptyText: AppLocalizations.of(context).eaNotSet,
            slotKey: _amountRowKey,
            onTap: _focusAmount,
            onCurrencyTap: _pickTaskCurrency,
            // Task 030 §3: once a category names the direction, the amount is
            // signed and coloured — `+` positive for money coming in, `−`
            // negative for going out. With no category it stays unsigned and
            // neutral, because the direction is not yet a fact.
            amountSign: _hasTaskCategory(store)
                ? (_taskIsPayIn ? '+' : '−')
                : '',
            valueColor: _hasTaskCategory(store)
                ? (_taskIsPayIn ? AppColors.positive : AppColors.negative)
                : null,
          ),
          FieldSpec(
            icon: Icons.account_balance_wallet_rounded,
            label: AppLocalizations.of(context).qaAccount,
            value: account?.name,
            emptyText: AppLocalizations.of(context).eaNotSet,
            // _pickAccountInto raises the account bottom sheet.
            opensSheet: true,
            onTap: () =>
                _pickAccountInto(store, isFrom: false, title: AppLocalizations.of(context).etLinkedAccount),
          ),
          FieldSpec(
            icon: Icons.category_rounded,
            // The row asks for a Category, full stop (task 030 §1): the label is
            // the same in both directions, and the side the user picks in the
            // two-sided sheet is the task's direction. A task with no category
            // keeps today's default — a pay-out (see [_taskIsPayIn]).
            label: AppLocalizations.of(context).fieldCategory,
            value: store.categoryById(_fromRef)?.name,
            emptyText: AppLocalizations.of(context).eaNotSet,
            // _pickCategoryInto raises the two-sided category sheet; Expense
            // opens first, so the common case costs no extra tap (§2).
            opensSheet: true,
            onTap: () => _pickCategoryInto(
              CategoryType.expense,
              isFrom: true,
              types: const [CategoryType.expense, CategoryType.income],
            ),
          ),
          // Repeat moves onto the transaction form's richer chooser (§5): a row
          // in OPTIONAL, not a button in a bar. A recurring bill is the clearest
          // case for "the 1st and the 15th of every month".
          _repeatField(),
          _noteField(),
        ]),
      ],
      // Remind is removed (§4) and Repeat moved into the card (§5), so the
      // toggle bar has nothing left — an empty bar renders nothing.
      toggles: const [],
      saveLabel: AppLocalizations.of(context).qaCreateTask,
      // The due date is a non-null DateTime seeded to today and can never be
      // cleared, so the old `unmet: false` due-date blocker could never fire
      // (§6); only the title can be missing.
      blockers: [
        Blocker(
          unmet: _title.text.trim().isEmpty,
          label: AppLocalizations.of(context).qaBlockNameTask,
          // §5c — an empty-title Save toasts *and* flashes the hero, like amount.
          flashId: 'title',
        ),
      ],
    );
  }

  /// Opens the icon picker (icon-only) for the task's glyph (§5a). The Schedule
  /// row tints the glyph by direction, so this previews the glyph, not colour.
  Future<void> _pickTaskIcon() async {
    final picked = await showCategoryIconPicker(
      context,
      color: AppColors.task,
      selected: _taskIcon,
    );
    if (picked != null && mounted) setState(() => _taskIcon = picked);
  }

  /// The task form's only numeric target (task 007). The title and the note hold
  /// the system keyboard; the keypad and the keyboard are never up together
  /// (inline-note spec §2). The shell's pointer-down has already closed the
  /// keypad by the time this runs on tap-up, so it is set true unconditionally —
  /// as onHeroTap does.
  void _focusAmount() {
    _titleFocus.unfocus();
    _noteFocus.unfocus();
    setState(() => _keypadOpen = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      AppLocalizations.of(context).qaAmount,
      Directionality.of(context),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _amountRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 150));
      }
    });
  }

  /// Opens the currency picker for the task's amount (task 007 §4). The task
  /// form's first currency control — the value otherwise follows the linked
  /// account.
  Future<void> _pickTaskCurrency() async {
    // The shell's pointer-down has already closed the keypad by the time this
    // runs. Changing the unit is not leaving the field, so put it back.
    final wasOpen = _keypadOpen || _type == QuickAddType.newTask;
    final c = await pickCurrency(context, _currency);
    if (!mounted) return;
    setState(() {
      if (c != null) _currency = c;
      _keypadOpen = wasOpen;
    });
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
      // A new revalued account can change its group (revaluation vs not) and its
      // sign, flipping the difference — drop a category that no longer fits, and
      // clear any stale one when the account is now a revaluation (§3/§4).
      if (_type == QuickAddType.rebalance) _reconcileRebalanceCategory(store);
    });
    // A changed source/destination can change the currency pair; keep the rate
    // field in step (spec §2). Harmless for non-transfer types.
    if (_type == QuickAddType.transfer) _syncTransferRateField();
  }

  Future<void> _pickCategoryInto(CategoryType type,
      {required bool isFrom,
      // Task 030 §2: the sides the sheet offers. Empty (every caller but the
      // task form) keeps the single-type sheet; two entries raise the tab strip.
      List<CategoryType> types = const []}) async {
    setState(() => _keypadOpen = false);
    final c = await pickCategory(context, type: type, types: types);
    if (c == null || !mounted) return;
    setState(() => isFrom ? _fromRef = c.id : _toRef = c.id);
  }

  Future<void> _pickDate() async {
    setState(() => _keypadOpen = false);
    // The app-native sheet edits date and time together and returns the full
    // value; the old showDatePicker only touched the date, leaving the time
    // frozen. Bounds are preserved (DateTime(2020)..DateTime(2035)).
    final d = await showDateTimeSheet(
      context,
      initial: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      now: StoreScope.read(context).today,
    );
    if (d == null || !mounted) return;
    setState(() => _date = d);
  }

  double _defaultRate(Account? from, Account? to) {
    if (from == null || to == null) return 1;
    // Prefill the cross rate from the LIVE editable rate table (spec 021a), not
    // the legacy hard-coded one, so a transfer's arrival reflects the rates the
    // user maintains. Falls back to 1 when either currency has no rate (021c
    // would then let the user type the arrival directly).
    final store = StoreScope.read(context);
    return store.convertBetween(1, from.currency, to.currency) ?? 1;
  }

  Future<void> _showTypeMenu() async {
    setState(() => _keypadOpen = false);
    final picked = await showQuickAddTypeMenu(context, current: _type);
    if (!mounted || picked == null || picked == _type) return;
    // New goal and New budget leave this shell for a full-screen form; the four
    // transaction types and New task switch config in place, carrying the
    // amount, date and refs across (§4).
    if (picked == QuickAddType.newGoal || picked == QuickAddType.newBudget) {
      await switchCreationType(context, picked);
      return;
    }
    _switchType(picked);
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
          '${AppLocalizations.of(context).qaCreated(dateTimeLabel(txn.createdAt, AppLocalizations.of(context), now: StoreScope.read(context).today))}'
          '${AppLocalizations.of(context).qaEditedTimes(edits)}',
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
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).qaDeleteEntry,
                        style: const TextStyle(
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
    // The entered transaction is the first occurrence; the series starts at the
    // *next* one. A transient Task computes it through the one true rule.
    final customUnit =
        _repeatFreq == RepeatFrequency.custom ? _repeatUnit : null;
    final firstDue = Task(
      id: '',
      title: '',
      linkedAccountId: '',
      expectedAmount: 0,
      dueDate: _date,
      icon: Icons.repeat_rounded,
      repeats: _repeatFreq,
      weekdays: _repeatWeekdays,
      daysOfMonth: _repeatDaysOfMonth,
      repeatInterval: _repeatInterval,
      repeatUnit: customUnit,
    ).nextOccurrence(_date);
    final task = store.addTask(
      title: note.isNotEmpty
          ? note
          : (store.categoryById(categoryId)?.name ?? AppLocalizations.of(context).qaRecurring),
      linkedAccountId: accountId,
      expectedAmount: expected,
      dueDate: firstDue,
      icon: Icons.repeat_rounded,
      categoryId: categoryId,
      repeats: _repeatFreq,
      weekdays: _repeatWeekdays,
      daysOfMonth: _repeatDaysOfMonth,
      repeatInterval: _repeatInterval,
      repeatUnit: customUnit,
      repeatEndDate: _repeatEndDate,
      repeatEndCount: _repeatEndCount,
    );
    txn.recurrenceTaskId = task.id;
  }

  /// Writes an expense/income — one transaction, or one per split line sharing
  /// a splitGroupId (spec §2). Repeat is blocked while a split is applied.
  void _writeExpenseIncome(AppStore store, {required bool income}) {
    final txnType = income ? TxnType.income : TxnType.expense;
    final note = _note.text.trim();
    // The frozen rate for this entry (spec 021b §1). For a base-currency entry
    // it is 1; otherwise the effective rate, guaranteed present by the blocker.
    final rateToBase =
        _currency == store.baseCurrency ? 1.0 : (_effectiveEntryRate(store) ?? 1.0);
    // §3b asymmetry: filling a BLANK rate teaches the store the currency's rate
    // as well as freezing it here — the user has just told the app something it
    // did not know. Overriding a rate that already exists is local to the entry.
    if (_currency != store.baseCurrency &&
        _entryRateOverride != null &&
        store.rateFor(_currency) == null) {
      store.setRate(_currency, _entryRateOverride!);
    }
    if (_hasSplit) {
      final accountId = income ? _toRef! : _fromRef!;
      String? gid;
      for (var i = 0; i < _splitLines!.length; i++) {
        final line = _splitLines![i];
        final t = store.addTxn(
          type: txnType,
          amount: line.amount ?? 0,
          currency: _currency,
          fromRef: income ? line.categoryId! : accountId,
          toRef: income ? accountId : line.categoryId!,
          date: _date,
          rateToBase: rateToBase,
          tagIds: _tagIds,
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
        rateToBase: rateToBase,
        tagIds: _tagIds,
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
              Text(AppLocalizations.of(context).qaDeleteSplit, style: AppText.rowTitle),
              const SizedBox(height: Insets.sm),
              Text(
                AppLocalizations.of(context).qaLinkedSplit('$count'),
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
                child: Text(AppLocalizations.of(context).qaDeleteAll('$count')),
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(AppLocalizations.of(context).qaDeleteJustLine,
                    style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The entry `_save` is about to write, built once so the overdraft warning in
  /// §3.3 asks about the same figures the write uses (task 011). Delegates to the
  /// pure [buildDraftTxn] so the draft and its parity test share one definition.
  Txn? _draftTxn(AppStore store) => buildDraftTxn(
        store,
        type: _type,
        amount: _amount,
        fromRef: _fromRef,
        toRef: _toRef,
        currency: _currency,
        date: _date,
        feeAmount: _feeAmount,
        editing: widget.editing,
      );

  /// Asset accounts this save would push further below zero (task 011 §3.3).
  /// Three conditions, and the third matters as much as the first two:
  ///
  ///  * the account is an asset — a card going further into debt is what a card
  ///    is for, and warning there would be noise;
  ///  * the result is below zero;
  ///  * the result is *lower* than before. Without this, every later edit to an
  ///    already-overdrawn account warns again, including the entry that is
  ///    paying it back.
  List<Account> _wouldOverdraw(AppStore store, Txn draft, {Txn? replacing}) {
    final result = <Account>[];
    for (final ref in {draft.fromRef, draft.toRef}) {
      final account = store.accountById(ref);
      if (account == null || !account.isAsset) continue;
      final before = replacing == null
          ? store.balanceOf(account.id)
          : store.balanceWithout(account.id, replacing);
      final after = store.balanceIfSaved(account.id, draft, replacing: replacing);
      if (after < 0 && after < before) result.add(account);
    }
    return result;
  }

  Future<void> _save(AppStore store) async {
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

    // Overdraft warning (task 011 §3): after the form is complete, before any
    // write. It warns, never blocks — the entry is true and is recorded either
    // way. Runs for both create and edit; the edited record is taken out first.
    final draft = _draftTxn(store);
    if (draft != null) {
      final l = AppLocalizations.of(context);
      final overdrawn =
          _wouldOverdraw(store, draft, replacing: widget.editing);
      for (final account in overdrawn) {
        final before = widget.editing == null
            ? store.balanceOf(account.id)
            : store.balanceWithout(account.id, widget.editing!);
        final after = store.balanceIfSaved(account.id, draft,
            replacing: widget.editing);
        final ok = await showDestructiveConfirm(
          context,
          title: l.qaOverdrawTitle(account.name),
          message: l.qaOverdrawMessage,
          impact: [
            ImpactLine.lost(
              '${account.name} ${money(before, currency: account.currency)} '
              '→ ${money(after, currency: account.currency)}',
            ),
          ],
          confirmLabel: l.qaOverdrawConfirm,
          cancelLabel: l.qaOverdrawCancel,
          // Saving is not destructive here — the entry is true and the app is
          // recording it. Red would say "this deletes something".
          confirmColor: AppColors.accent,
        );
        if (!ok) return;
        if (!mounted) return;
      }
    }
    // The confirm sheet is the only await above; guard once more so every
    // `context` use in the write paths below is provably after a mounted check.
    if (!mounted) return;

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
        // A cross-currency transfer's destination figure is derived from the
        // net and the rate, so an edit that changes either must re-derive
        // `toAmount`; when the edit makes the two sides share a currency the FX
        // fields are cleared outright.
        double? newRate;
        double? newToAmount;
        var clearExchange = false;
        // Transfer-only: the transfer carries the net, and its fee is a linked
        // expense reconciled here — created, updated or deleted so it always
        // matches the form and never strands (§4.1).
        var transferAmount = _amount;
        String? feeLinkId = editing.feeTxnId;
        var clearFeeLink = false;
        if (_type == QuickAddType.transfer) {
          final from = store.accountById(_fromRef)!;
          final to = store.accountById(_toRef)!;
          final cross = from.currency != to.currency;
          final feeAmt = _feeAmount ?? 0;
          transferAmount = _amount - feeAmt;
          if (cross) {
            newRate = _rate ?? _defaultRate(from, to);
            newToAmount = roundToCurrency(transferAmount * newRate, to.currency);
          } else {
            clearExchange = true;
          }
          final existing = editing.feeTxnId == null
              ? null
              : store.txnById(editing.feeTxnId!);
          if (feeAmt > 0) {
            if (existing != null) {
              store.updateTxn(existing,
                  amount: feeAmt,
                  fromRef: from.id,
                  toRef: _feeCategoryId,
                  date: _date);
              feeLinkId = existing.id;
            } else {
              feeLinkId = store
                  .addTxn(
                    type: TxnType.expense,
                    amount: feeAmt,
                    currency: from.currency,
                    fromRef: from.id,
                    toRef: _feeCategoryId!,
                    date: _date,
                  )
                  .id;
            }
          } else {
            if (existing != null) store.deleteTxn(existing);
            feeLinkId = null;
            clearFeeLink = true;
          }
        }
        store.updateTxn(
          editing,
          // Rebalance edit (§1a): the delta is the new signed balance minus the
          // baseline *excluding this record* — `balanceOf` still contains the
          // delta being replaced, so measuring against it double-counts the old
          // one (a re-save-unchanged would drift the balance). The keypad types a
          // magnitude; the account's side gives it its sign (§1d). This form is
          // only ever reached for a revaluation — an edited income/expense opens
          // its own form — so the type stays a rebalance.
          amount: _type == QuickAddType.rebalance
              ? (store.accountById(_toRef!)!.group.isAsset ? _amount : -_amount) -
                  _baselineBalance(store, _toRef!)
              : (_type == QuickAddType.transfer ? transferAmount : _amount),
          fromRef: _fromRef,
          toRef: _toRef,
          date: _date,
          // Re-freeze the entry's reporting-currency rate (021b §3c): a currency
          // or rate change re-freezes; a plain amount edit keeps the stored rate
          // and updateTxn recomputes amountBase at it. Transfers keep their own
          // frozen rate (021c owns their re-derivation).
          currency: _currency,
          rateToBase: _type == QuickAddType.transfer
              ? null
              : (_currency == store.baseCurrency
                  ? 1.0
                  : (_effectiveEntryRate(store) ?? editing.rateToBase)),
          tagIds: _tagIds,
          note: _note.text.trim(),
          exchangeRate: newRate,
          toAmount: newToAmount,
          clearExchange: clearExchange,
          // A rewritten transfer carries no fee amount of its own; clear the
          // legacy field and point the link at the (possibly new) fee expense.
          clearFee: _type == QuickAddType.transfer,
          feeTxnId: feeLinkId,
          clearFeeLink: clearFeeLink,
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

    // The record type actually written, for the confirmation snackbar (§3): a
    // rebalance form can create an expense or an income, so "Rebalance saved"
    // would be a lie. Null for the types whose QuickAddType names their record.
    TxnType? savedType;

    switch (_type) {
      case QuickAddType.expense:
      case QuickAddType.income:
        _writeExpenseIncome(store, income: income);
      case QuickAddType.transfer:
        final from = store.accountById(_fromRef)!;
        final to = store.accountById(_toRef)!;
        final cross = from.currency != to.currency;
        final rate = _rate ?? _defaultRate(from, to);
        final feeAmt = _feeAmount ?? 0;
        final net = _amount - feeAmt;
        // The fee is money that genuinely leaves, so it is its own expense
        // against its own category (§4); written first so the transfer can hold
        // its id and the two delete/edit together.
        String? feeId;
        if (feeAmt > 0) {
          feeId = store
              .addTxn(
                type: TxnType.expense,
                amount: feeAmt,
                // Always the source account's currency (§decisions).
                currency: from.currency,
                fromRef: from.id,
                toRef: _feeCategoryId!, // guaranteed by _feeIsComplete
                date: _date,
              )
              .id;
        }
        final t = store.addTxn(
          type: TxnType.transfer,
          amount: net, // the transfer carries the net (§4)
          currency: from.currency,
          fromRef: from.id,
          toRef: to.id,
          date: _date,
          exchangeRate: cross ? rate : null,
          toAmount: cross ? roundToCurrency(net * rate, to.currency) : null,
          note: _note.text.trim(),
          feeTxnId: feeId,
        );
        _applyRepeatFor(store, t, income: false, transfer: true);
      case QuickAddType.rebalance:
        final asset = store.accountById(_toRef)!;
        // The delta against the balance *without* this record — on create there
        // is nothing to exclude, so this is `balanceOf` (§1a). The keypad types a
        // magnitude; the account's side signs the new balance (§1d).
        final baseline = _baselineBalance(store, asset.id);
        final signed = asset.group.isAsset ? _amount : -_amount;
        final delta = signed - baseline;
        final note = _note.text.trim().isEmpty
            ? AppLocalizations.of(context).qaBalanceAdjustment
            : _note.text.trim();
        if (_isRevaluation(asset)) {
          // A price change on an investment or a valuable: unrealised, kept out
          // of every income/expense metric — a rebalance carrying the signed
          // delta, the account on both refs (§3).
          store.addTxn(
            type: TxnType.rebalance,
            amount: delta,
            currency: asset.currency,
            fromRef: asset.id,
            toRef: asset.id,
            date: _date,
            note: note,
          );
          savedType = TxnType.rebalance;
        } else if (delta >= 0) {
          // The balance rose: money came in and was never recorded. Booked as
          // income in its category — identical in shape to the Income form's
          // output (§3): positive magnitude, fromRef the category, toRef the
          // account.
          store.addTxn(
            type: TxnType.income,
            amount: delta,
            currency: asset.currency,
            fromRef: _fromRef!, // category, guaranteed by the category blocker
            toRef: asset.id,
            date: _date,
            note: note,
          );
          savedType = TxnType.income;
        } else {
          // The balance fell: money went out and was never recorded. Booked as an
          // expense — identical in shape to the Expense form's output (§3): a
          // positive magnitude, fromRef the account, toRef the category — so it
          // reaches OUT, its category and its budget.
          store.addTxn(
            type: TxnType.expense,
            amount: -delta,
            currency: asset.currency,
            fromRef: asset.id,
            toRef: _fromRef!, // category
            date: _date,
            note: note,
          );
          savedType = TxnType.expense;
        }
      case QuickAddType.newBudget:
        // Unreachable: budgets are created on EditBudgetScreen and are
        // intercepted before the sheet ever saves one (§4).
        return;
      case QuickAddType.newGoal:
        // Unreachable: goals are created on their own full-screen form and are
        // intercepted before the sheet ever saves one.
        return;
      case QuickAddType.newTask:
        // Account is optional on a task, but the store needs somewhere to
        // hang it — fall back to the first account when none was chosen.
        final linked = _toRef ??
            (store.accounts.isEmpty ? null : store.accounts.first.id);
        if (linked == null) return;
        store.addTask(
          title: _title.text.trim(),
          linkedAccountId: linked,
          // Task 030 §3: the side of the chosen category is the sign. An income
          // category means money coming in (positive); an expense category, or
          // no category at all, means going out (negative) — the default every
          // task carried before this was askable.
          expectedAmount: _taskIsPayIn ? _amount : -_amount,
          dueDate: _date,
          icon: _taskIcon,
          categoryId: _fromRef,
          repeats: _repeatFreq,
          weekdays: _repeatWeekdays,
          daysOfMonth: _repeatDaysOfMonth,
          // The task now uses the transaction Repeat chooser (§5), which can set
          // a custom `Every N unit` step and an end condition — persist them so
          // a Custom (e.g. every 3 months) rule round-trips instead of silently
          // collapsing to the every-1-month default.
          repeatInterval: _repeatInterval,
          repeatUnit:
              _repeatFreq == RepeatFrequency.custom ? _repeatUnit : null,
          repeatEndDate: _repeatEndDate,
          repeatEndCount: _repeatEndCount,
          // Remind is removed (§4): nothing schedules a notification, so Quick
          // Add writes no reminder. The model fields stay for a future real
          // implementation; existing data is untouched.
          reminderDaysBefore: null,
          reminderTime: null,
        );
    }

    Navigator.of(context).pop();
    final l = AppLocalizations.of(context);
    // Name what was actually created (§3): the rebalance form's own record type
    // when it differs from the pill, else the QuickAddType's own label.
    final savedLabel = savedType != null ? savedType.label(l) : _type.label(l);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.qaSaved(savedLabel))),
    );
  }
}

/// Cap on the transaction note. No limit exists at the model (`Txn.note` is a
/// plain `String`) or the database (`note TEXT NOT NULL`), so 280 is chosen
/// here: long enough for the few sentences a note ever needs, short enough
/// that the row's two-line preview stays a preview. The inline row enforces it
/// ([MaxLengthEnforcement.enforced]): input stops at the cap; nothing already
/// typed is discarded.
const int _kNoteLimit = 280;

/// The counter stays hidden until this many characters remain, then appears as
/// `used / limit` under the row. A permanent counter reads as a restriction on
/// a free field.
const int _kNoteCounterThreshold = 50;
