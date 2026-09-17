import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/date_time_sheet.dart';
import '../quick_add/pickers.dart';
import '../quick_add/type_menu.dart';
import 'edit_scaffold.dart';
import 'widgets/percent_input_formatter.dart';

/// One screen, two modes (spec §7 / task 022 §3). In **create** mode the budget
/// starts as a draft — a scope, targets, a limit, a period and the two settings
/// are entered. In **edit** mode the budget is fixed: its scope, targets and
/// period are locked (changing them would detach the budget from its spend
/// history) and only the amount-side fields move.
///
/// Task 022 turns the single-point category-monthly form into the full space a
/// [Budget] already supports: any scope (categories / account / tag) and any
/// period (month / week / N days / once). The common case — a monthly, single
/// category budget — still shows five single-line rows (target, limit, every,
/// roll over, warn) so it does not grow beyond Task 005's card.
class EditBudgetScreen extends StatefulWidget {
  const EditBudgetScreen({super.key, this.categoryId, this.budgetId});

  /// The category pre-selected for a new budget (the Budgets tab's per-row `Set`
  /// shortcut), the category to edit its monthly budget (Task 005 back-compat),
  /// or null to open create mode with nothing chosen (the `+` and Quick Add).
  final String? categoryId;

  /// A specific budget to edit — any scope or period (task 022). Takes
  /// precedence over [categoryId]. Null for create and for the category-monthly
  /// edit path.
  final String? budgetId;

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

/// The four answers the `Every` row offers (spec §2a).
enum _PeriodChoice { month, week, days, once }

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  late final AppStore _store = StoreScope.read(context);

  /// The budget being edited, or null in create mode. Latched at construction so
  /// _save's notifyListeners does not flip the mode mid-pop (Task 005 note).
  Budget? _editBudget;
  bool get _isNew => _editBudget == null;

  // ── Draft (create) / working copy (edit) ────────────────────────────────────
  late BudgetScope _scope;
  final Set<String> _targets = {};
  late BudgetPeriod _period;
  late bool _repeats;
  int _lengthDays = 7;
  int _weekday = DateTime.monday; // for the weekly period's reset day
  DateTime? _startDate;
  DateTime? _endDate;

  late final TextEditingController _limit;
  late final TextEditingController _name;
  late bool _rollover;
  late double _warn;

  @override
  void initState() {
    super.initState();

    Budget? edit;
    if (widget.budgetId != null) {
      edit = _store.budgetById(widget.budgetId!);
    } else if (widget.categoryId != null) {
      // Task 005 path: an existing monthly category budget is edited, a fresh
      // one is created.
      edit = _store.monthlyBudgetForCategory(widget.categoryId!);
    }
    _editBudget = edit;

    if (edit != null) {
      _scope = edit.scope;
      _targets.addAll(edit.targets);
      _period = edit.period;
      _repeats = edit.repeats;
      _lengthDays = edit.lengthDays ?? 7;
      _weekday = edit.anchor.weekday;
      if (!edit.repeats) {
        _startDate = edit.anchor;
        _endDate = edit.endedAt ??
            edit.anchor.add(Duration(days: (edit.lengthDays ?? 1) - 1));
      }
      _limit = TextEditingController(
          text: edit.limit > 0 ? edit.limit.toStringAsFixed(0) : '');
      _name = TextEditingController(text: edit.name);
      _rollover = edit.rollover;
      _warn = edit.warnThreshold;
    } else {
      _scope = BudgetScope.categories;
      if (widget.categoryId != null) _targets.add(widget.categoryId!);
      _period = BudgetPeriod.month;
      _repeats = true;
      _limit = TextEditingController();
      _name = TextEditingController();
      _rollover = false;
      _warn = 0.8;
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    _name.dispose();
    super.dispose();
  }

  double get _limitValue => double.tryParse(_limit.text.trim()) ?? 0;

  /// Save is unreachable until the facts a budget cannot exist without are
  /// present: a target, a positive limit, and — when `once` — both dates with
  /// the end not before the start (spec §3).
  bool get _canSave {
    if (_targets.isEmpty || _limitValue <= 0) return false;
    if (!_repeats) {
      if (_startDate == null || _endDate == null) return false;
      if (_endDate!.isBefore(_startDate!)) return false;
    }
    return true;
  }

  /// Task 005's edit path: an unchanged monthly single-category budget. Only
  /// this shape routes through [AppStore.updateBudget] (its category-keyed
  /// history), so the migration and Task-005 tests keep their exact behaviour.
  bool get _isMonthlyCategoryEdit =>
      !_isNew &&
      _editBudget!.scope == BudgetScope.categories &&
      _editBudget!.period == BudgetPeriod.month &&
      _editBudget!.repeats &&
      _editBudget!.targets.length == 1;

  /// The category whose spend history the card shows — only when the budget is a
  /// single expense category (spec §6).
  Category? get _singleCategory {
    if (_scope != BudgetScope.categories || _targets.length != 1) return null;
    return _store.categoryById(_targets.first);
  }

  bool get _showNameRow =>
      _targets.length > 1 || _scope != BudgetScope.categories;

  // ── Spec 5.4 — spend history (single-category budgets only) ──────────────────
  List<(DateTime, double)> get _history {
    final cat = _singleCategory;
    final out = <(DateTime, double)>[];
    if (cat == null) return out;
    for (var i = 0; i < 3; i++) {
      final month = DateTime(_store.period.year, _store.period.month - i);
      out.add((month, _store.spentInCategory(cat.id, month)));
    }
    return out;
  }

  double get _average {
    final months = _history.where((m) => m.$2 > 0).toList();
    if (months.isEmpty) return 0;
    return months.fold(0.0, (sum, m) => sum + m.$2) / months.length;
  }

  double get _suggestion => (_average / 50).ceil() * 50;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final cat = _singleCategory;

    return EditScaffold(
      title: l.ebTitle,
      type: _isNew ? QuickAddType.newBudget : null,
      onTypeTap: _isNew ? _showTypeMenu : null,
      onSave: _canSave ? _save : null,
      children: [
        _card(l, store),
        if (!_isNew && cat != null)
          _historyCard(store.spentInCategory(cat.id, store.period)),
        // A general budget (account / tag / non-monthly, including a finished
        // one-off the reader is done with) is removed here — the category-budget
        // detail owns the monthly path (spec §5c). Task 005's monthly-category
        // edit keeps its Remove in the budget detail's ••• menu, untouched.
        if (!_isNew && !_isMonthlyCategoryEdit) _removeBudgetRow(l),
      ],
    );
  }

  Widget _removeBudgetRow(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, 0, Insets.gutter, Insets.md),
        child: AppCard(
          child: InkWell(
            onTap: _confirmRemove,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: Insets.md),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.negative),
                  const SizedBox(width: Insets.md),
                  Text(l.bdRemoveBudget,
                      style: AppText.body
                          .copyWith(color: AppColors.negative, fontSize: 14.5)),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _confirmRemove() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: Text(l.ebRemoveTitle(_editBudget!.name), style: AppText.rowTitle),
        content:
            Text(l.ebRemoveMsg, style: AppText.body.copyWith(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l.ebRemoveBudget),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _store.archiveBudget(_editBudget!);
    if (mounted) Navigator.of(context).pop();
  }

  // ── The form card — single-line rows in a fixed order (spec §3) ──────────────

  Widget _card(AppLocalizations l, AppStore store) {
    final rows = <Widget>[
      _targetRow(l),
      if (_showNameRow) _nameRow(l),
      _BudgetRow(
        icon: Icons.attach_money_rounded,
        label: _period == BudgetPeriod.month && _repeats
            ? l.ebMonthlyLimit
            : l.bgLimit,
        trailing: _limitTrailing(store),
      ),
      _everyRow(l),
      if (!_repeats) _datesRow(l),
      if (_repeats)
        _BudgetRow(
          icon: Icons.repeat_rounded,
          label: l.ebRollOver,
          dense: true,
          trailing: FormSwitch(
            value: _rollover,
            onChanged: (v) => setState(() => _rollover = v),
          ),
        ),
      _BudgetRow(
        icon: Icons.notifications_active_rounded,
        label: l.ebWarnAt,
        trailing: _pickerTrailing(_warnLabel(l)),
        onTap: _pickThreshold,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, 0, Insets.gutter, Insets.md),
      child: AppCard(
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const RowDivider(),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  // ── Target row (spec §1a) ────────────────────────────────────────────────────

  IconData get _scopeIcon => switch (_scope) {
        BudgetScope.categories => Icons.category_rounded,
        BudgetScope.account => Icons.account_balance_wallet_rounded,
        BudgetScope.tag => Icons.sell_rounded,
      };

  String _scopeLabel(AppLocalizations l) => switch (_scope) {
        BudgetScope.categories =>
          _targets.length <= 1 ? l.bgScopeCategory : l.bgTargets,
        BudgetScope.account =>
          _targets.length <= 1 ? l.bgAccountScope : l.bgAccountsScope,
        BudgetScope.tag => _targets.length <= 1 ? l.bgTagScope : l.bgTagsScope,
      };

  String? _nameOf(String id) => switch (_scope) {
        BudgetScope.categories => _store.categoryById(id)?.name,
        BudgetScope.account => _store.accountById(id)?.name,
        BudgetScope.tag => _store.tagById(id)?.name,
      };

  String _targetsValue(AppLocalizations l) {
    final names = [for (final id in _targets) _nameOf(id) ?? id];
    if (names.isEmpty) return l.eaNotSet;
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]}, ${names[1]}';
    return '${names.first} +${names.length - 1}';
  }

  Widget _targetRow(AppLocalizations l) {
    if (_isNew) {
      return _BudgetRow(
        icon: _scopeIcon,
        label: _scopeLabel(l),
        trailing: _pickerTrailing(_targetsValue(l), muted: _targets.isEmpty),
        onTap: _pickTargets,
      );
    }
    // Edit mode: scope + targets are fixed (changing them detaches the history).
    return Semantics(
      enabled: false,
      child: _BudgetRow(
        icon: _scopeIcon,
        label: _scopeLabel(l),
        trailing: _lockedTrailing(_targetsValue(l)),
      ),
    );
  }

  Widget _nameRow(AppLocalizations l) => _BudgetRow(
        icon: Icons.label_outline_rounded,
        label: l.qaName,
        trailing: SizedBox(
          width: 150,
          child: TextField(
            controller: _name,
            textAlign: TextAlign.right,
            style: AppText.body.copyWith(fontSize: 14.5),
            cursorColor: AppColors.accentSoft,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: _targets.isEmpty ? '' : (_nameOf(_targets.first) ?? ''),
              hintStyle: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ),
      );

  // ── Every / Dates (spec §2) ──────────────────────────────────────────────────

  String _everyValue(AppLocalizations l) {
    if (!_repeats) return l.bgEvOnce;
    if (_period == BudgetPeriod.month) return l.bgEvMonth;
    if (_lengthDays == 7) return l.bgEvWeekFrom(weekdayShort(_weekday, l));
    return l.bgEvDays(_lengthDays);
  }

  Widget _everyRow(AppLocalizations l) {
    if (_isNew) {
      return _BudgetRow(
        icon: Icons.event_repeat_rounded,
        label: l.bgEvery,
        trailing: _pickerTrailing(_everyValue(l)),
        onTap: _pickPeriod,
      );
    }
    // The period is fixed once chosen (its history is measured over it).
    return Semantics(
      enabled: false,
      child: _BudgetRow(
        icon: Icons.event_repeat_rounded,
        label: l.bgEvery,
        trailing: _lockedTrailing(_everyValue(l)),
      ),
    );
  }

  String _datesValue(AppLocalizations l) {
    if (_startDate == null || _endDate == null) return l.eaNotSet;
    return '${dayMonth(_startDate!, l)} – ${dayMonth(_endDate!, l)}';
  }

  Widget _datesRow(AppLocalizations l) {
    if (_isNew) {
      return _BudgetRow(
        icon: Icons.date_range_rounded,
        label: l.bgDates,
        trailing: _pickerTrailing(_datesValue(l),
            muted: _startDate == null || _endDate == null),
        onTap: _pickDates,
      );
    }
    return Semantics(
      enabled: false,
      child: _BudgetRow(
        icon: Icons.date_range_rounded,
        label: l.bgDates,
        trailing: _lockedTrailing(_datesValue(l)),
      ),
    );
  }

  // ── Trailing builders (shared with Task 005) ─────────────────────────────────

  Widget _pickerTrailing(String value, {bool muted = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              value,
              style: AppText.body.copyWith(
                fontSize: 14.5,
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textTertiary),
        ],
      );

  Widget _lockedTrailing(String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              style: AppText.body
                  .copyWith(fontSize: 14.5, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.lock_rounded, size: 13, color: AppColors.textTertiary),
        ],
      );

  Widget _limitTrailing(AppStore store) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            child: TextField(
              controller: _limit,
              textAlign: TextAlign.right,
              style: AppText.amount.copyWith(
                color: _limitValue > 0
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
              cursorColor: AppColors.accentSoft,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            currencySymbol(store.baseCurrency),
            style: AppText.amount.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );

  String _warnLabel(AppLocalizations l) {
    final pct = percent(_warn, decimals: 0);
    if (_limitValue <= 0) return pct;
    return '$pct · ${money(_limitValue * _warn)}';
  }

  Widget _historyCard(double currentSpend) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, Insets.sm),
            child: Text(l.ebWhatSpent.toUpperCase(), style: AppText.label),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Column(
              children: [
                for (final (month, amount) in _history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            monthShort(month.month, AppLocalizations.of(context)),
                            style: AppText.body.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          money(amount),
                          style: AppText.amount.copyWith(
                            color: amount > _limitValue
                                ? AppColors.negative
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_average > 0) ...[
                  const RowDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.ebAverage(money(_average.roundToDouble()),
                                money(_suggestion)),
                            style: AppText.caption.copyWith(fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _limit.text = _suggestion.toStringAsFixed(0),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentSoft,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(l.actionUse),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _pickTargets() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickBudgetTargets(
      context,
      initialScope: _scope,
      initialTargets: _targets,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _scope = picked.scope;
      _targets
        ..clear()
        ..addAll(picked.targets);
    });
  }

  Future<void> _pickPeriod() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<({_PeriodChoice choice, int days})>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      builder: (_) => _PeriodSheet(
        initial: !_repeats
            ? _PeriodChoice.once
            : _period == BudgetPeriod.month
                ? _PeriodChoice.month
                : _lengthDays == 7
                    ? _PeriodChoice.week
                    : _PeriodChoice.days,
        initialDays: _lengthDays == 7 ? 14 : _lengthDays,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      switch (result.choice) {
        case _PeriodChoice.month:
          _period = BudgetPeriod.month;
          _repeats = true;
        case _PeriodChoice.week:
          _period = BudgetPeriod.days;
          _lengthDays = 7;
          _repeats = true;
        case _PeriodChoice.days:
          _period = BudgetPeriod.days;
          _lengthDays = result.days.clamp(2, 365);
          _repeats = true;
        case _PeriodChoice.once:
          _period = BudgetPeriod.days;
          _repeats = false;
          _startDate ??= _store.today;
          _endDate ??= _store.today.add(const Duration(days: 13));
      }
    });
  }

  Future<void> _pickDates() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final today = _store.today;
    final first = DateTime(today.year - 5);
    final last = DateTime(today.year + 5, 12, 31);
    final start = await showDateTimeSheet(
      context,
      initial: _startDate ?? today,
      firstDate: first,
      lastDate: last,
      now: _store.now,
    );
    if (!mounted || start == null) return;
    final startDay = DateTime(start.year, start.month, start.day);
    final end = await showDateTimeSheet(
      context,
      initial: (_endDate != null && !_endDate!.isBefore(startDay))
          ? _endDate!
          : startDay,
      firstDate: startDay,
      lastDate: last,
      now: _store.now,
    );
    if (!mounted) return;
    final endDay = end == null
        ? null
        : DateTime(end.year, end.month, end.day);
    setState(() {
      _startDate = startDay;
      if (endDay != null && !endDay.isBefore(startDay)) _endDate = endDay;
    });
  }

  Future<void> _pickThreshold() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      builder: (context) => _WarnThresholdSheet(
        initial: _warn,
        onChanged: (v) => setState(() => _warn = v),
      ),
    );
  }

  Future<void> _showTypeMenu() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showQuickAddTypeMenu(
      context,
      current: QuickAddType.newBudget,
    );
    if (!mounted || picked == null || picked == QuickAddType.newBudget) return;
    await switchCreationType(context, picked);
  }

  String _effectiveName() {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    if (_targets.isNotEmpty) return _nameOf(_targets.first) ?? '';
    return '';
  }

  /// The anchor a create saves with, derived from the chosen period (spec §2a).
  DateTime _anchorForSave() {
    final today = _store.today;
    if (!_repeats) return _startDate ?? today;
    if (_period == BudgetPeriod.month) {
      return DateTime(today.year, today.month, 1);
    }
    if (_lengthDays == 7) {
      // The most recent [_weekday] on or before today, so the week resets on it.
      var d = today;
      while (d.weekday != _weekday) {
        d = d.subtract(const Duration(days: 1));
      }
      return d;
    }
    return today;
  }

  void _save() {
    if (_isMonthlyCategoryEdit) {
      // Task 005's history-preserving path.
      final cat = _store.categoryById(_editBudget!.targets.first);
      if (cat != null) {
        _store.updateBudget(
          cat,
          monthlyBudget: _limitValue,
          rollover: _rollover,
          warnThreshold: _warn,
        );
      }
      Navigator.of(context).pop();
      return;
    }

    if (!_isNew) {
      _store.updateBudgetGeneral(
        _editBudget!,
        name: _effectiveName(),
        limit: _limitValue,
        rollover: _rollover,
        warnThreshold: _warn,
      );
      Navigator.of(context).pop();
      return;
    }

    final lengthDays = _repeats
        ? (_period == BudgetPeriod.month ? null : _lengthDays)
        : (_endDate!.difference(_startDate!).inDays + 1);
    _store.addBudget(
      scope: _scope,
      targets: _targets,
      name: _effectiveName(),
      limit: _limitValue,
      period: _period,
      lengthDays: lengthDays,
      anchor: _anchorForSave(),
      repeats: _repeats,
      rollover: _rollover,
      warnThreshold: _warn,
      endedAt: _repeats ? null : _endDate,
    );
    Navigator.of(context).pop();
  }
}

/// The `Every` sheet (spec §2a): four choices. `Every … days` reveals a number
/// field (2–365); the other three commit immediately. Dates for `Once` are
/// entered on the form's own Dates row, not here (spec §2b).
class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.initial, required this.initialDays});

  final _PeriodChoice initial;
  final int initialDays;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late _PeriodChoice _choice = widget.initial;
  late final TextEditingController _days =
      TextEditingController(text: '${widget.initialDays}');

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  int get _daysValue => (int.tryParse(_days.text.trim()) ?? 0);

  void _commit(_PeriodChoice c) {
    if (c == _PeriodChoice.days) {
      // Reveal the field first; commit on Done.
      setState(() => _choice = c);
      return;
    }
    Navigator.of(context).pop((choice: c, days: 14));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.lg),
            Text(l.bgEvery, style: AppText.rowTitle),
            const SizedBox(height: Insets.sm),
            _option(l.bgPeriodMonth, _PeriodChoice.month),
            _option(l.bgPeriodWeek, _PeriodChoice.week),
            _option(l.bgPeriodDays, _PeriodChoice.days),
            if (_choice == _PeriodChoice.days)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.sm),
                child: Row(
                  children: [
                    Expanded(child: Text(l.bgPeriodDays, style: AppText.body)),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _days,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        style: AppText.body,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          helperText: l.bgDaysHint,
                          helperStyle: AppText.caption
                              .copyWith(color: AppColors.textTertiary),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    TextButton(
                      onPressed: (_daysValue >= 2 && _daysValue <= 365)
                          ? () => Navigator.of(context).pop(
                              (choice: _PeriodChoice.days, days: _daysValue))
                          : null,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentLight),
                      child: Text(l.actionDone),
                    ),
                  ],
                ),
              ),
            const RowDivider(),
            _option(l.bgPeriodOnce, _PeriodChoice.once,
                subtitle: l.bgPeriodOnceHint),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }

  Widget _option(String label, _PeriodChoice choice, {String? subtitle}) {
    final marked = _choice == choice;
    return ListTile(
      title: Text(label, style: AppText.body),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style:
                  AppText.caption.copyWith(color: AppColors.textSecondary)),
      trailing: marked
          ? const Icon(Icons.check_rounded,
              size: 18, color: AppColors.accentSoft)
          : null,
      onTap: () => _commit(choice),
    );
  }
}

/// One row of the budget form. A single line: leading icon, label, trailing.
/// Every row is capped to the same height by [_kMinHeight], so they measure
/// equal even though a switch is taller than a line of text; [dense] only trims
/// the switch row's padding so its taller control still lands inside that box.
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dense;

  static const double _kMinHeight = 48;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: dense ? Insets.xs : Insets.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(icon, size: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontSize: 14.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Insets.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// The five preset thresholds. Task 22 widens the picker with a sixth, custom
/// row; the presets themselves — values, order, formatting — are untouched.
const _warnPresets = [0.5, 0.7, 0.8, 0.9, 1.0];

/// Spec (task 22) — the warn-threshold picker: five presets plus a Custom row.
class _WarnThresholdSheet extends StatefulWidget {
  const _WarnThresholdSheet({required this.initial, required this.onChanged});

  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<_WarnThresholdSheet> createState() => _WarnThresholdSheetState();
}

class _WarnThresholdSheetState extends State<_WarnThresholdSheet> {
  late final TextEditingController _custom = TextEditingController(
    text: _isPreset(widget.initial) ? '' : _pct(widget.initial).toString(),
  );

  late double? _selected = widget.initial;

  static int _pct(double v) => (v * 100).round();
  static bool _isPreset(double v) => _warnPresets.any((p) => _pct(p) == _pct(v));

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _pickPreset(double t) {
    _custom.clear();
    setState(() => _selected = t);
    widget.onChanged(t);
  }

  void _onCustomChanged(String text) {
    if (text.isEmpty) {
      setState(() {
        _selected = _isPreset(widget.initial) ? widget.initial : null;
      });
      if (_selected != null) widget.onChanged(_selected!);
      return;
    }
    final v = int.parse(text) / 100;
    setState(() => _selected = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedPct = _selected == null ? null : _pct(_selected!);
    final customMarked = _selected != null && !_isPreset(_selected!);

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.lg),
            Text(l.ebWarnAt, style: AppText.rowTitle),
            const SizedBox(height: Insets.md),
            for (final t in _warnPresets)
              ListTile(
                title: Text(percent(t, decimals: 0), style: AppText.body),
                trailing: selectedPct == _pct(t)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.accentSoft,
                      )
                    : null,
                onTap: () => _pickPreset(t),
              ),
            const RowDivider(),
            _customRow(l, customMarked),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
  }

  Widget _customRow(AppLocalizations l, bool marked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
      child: Row(
        children: [
          Expanded(child: Text(l.ebWarnCustom, style: AppText.body)),
          SizedBox(
            width: 96,
            child: Semantics(
              label: l.ebWarnCustom,
              child: TextField(
                key: const Key('warnThresholdCustomField'),
                controller: _custom,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: AppText.body,
                inputFormatters: [PercentInputFormatter(_onReject)],
                onChanged: _onCustomChanged,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: '%',
                  helperText: l.ebWarnRange,
                  helperStyle: AppText.caption
                      .copyWith(color: AppColors.textTertiary),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.sm, vertical: Insets.sm),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 18 + Insets.sm,
            child: marked
                ? const Padding(
                    padding: EdgeInsets.only(left: Insets.sm),
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentSoft,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  void _onReject() => HapticFeedback.lightImpact();
}
