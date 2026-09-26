import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/auto_pill.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import '../quick_add/type_menu.dart';
import '../quick_add/widgets/form_kit.dart';
import 'budget_actions.dart';
import 'edit_scaffold.dart';
import 'widgets/percent_input_formatter.dart';
import 'widgets/runs_sheet.dart';

/// One screen, two modes (spec §7 / task 022 §3, reworked in task 067.1). In
/// **create** mode the budget starts as a draft — a name, a scope, targets, a
/// limit, a period, a run window and the two settings are entered. In **edit**
/// mode the budget is fixed: its scope, targets and period are locked (changing
/// them would detach the budget from its spend history) and only the amount-side
/// fields, the note and the end of a repeating run move (§6e).
///
/// Task 067.1 makes the form read like the goal and schedule forms: it opens
/// with the name (derived and marked `auto` until typed), then "Spending on" in
/// its own card, the limit named after its period, the period, a Runs row that
/// says from / until / no end for every period, and a note.
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

/// The four answers the `Period` row offers (spec §2a / §5).
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

  /// The run window (§6). [_from] is FROM for every period (first-of-month kept
  /// as the first of that month). [_until] is the one-off's inclusive end
  /// ([endedAt]) or a repeating budget's rounded end ([runsUntil]); null means
  /// no end (repeating only). [_runsTouched] drives the row's value colour.
  late DateTime _from;
  DateTime? _until;
  bool _runsTouched = false;

  late final TextEditingController _limit;
  late final TextEditingController _name;

  /// The editor's name is seeded once, in [didChangeDependencies] — not
  /// [initState] — because deciding "stored name == the derived one?" reads
  /// [AppLocalizations], and an inherited lookup in initState throws (task 070
  /// A2). This latches that one-time seed.
  bool _nameSeeded = false;
  late final TextEditingController _note;
  final FocusNode _nameFocus = FocusNode();
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
      if (edit.repeats) {
        _from = edit.period == BudgetPeriod.month
            ? DateTime(edit.anchor.year, edit.anchor.month)
            : DateTime(edit.anchor.year, edit.anchor.month, edit.anchor.day);
        _until = edit.runsUntil;
      } else {
        _from = DateTime(edit.anchor.year, edit.anchor.month, edit.anchor.day);
        _until = edit.endedAt ??
            edit.anchor.add(Duration(days: (edit.lengthDays ?? 1) - 1));
      }
      // An existing window is a set value, not an untouched default.
      _runsTouched = true;
      _limit = TextEditingController(
          text: edit.limit > 0 ? edit.limit.toStringAsFixed(0) : '');
      // The name is seeded in didChangeDependencies (§A2): comparing it to the
      // derived name needs AppLocalizations, which initState cannot read.
      _name = TextEditingController();
      _note = TextEditingController(text: edit.note);
      _rollover = edit.rollover;
      _warn = edit.warnThreshold;
    } else {
      _scope = BudgetScope.categories;
      if (widget.categoryId != null) _targets.add(widget.categoryId!);
      _period = BudgetPeriod.month;
      _repeats = true;
      _limit = TextEditingController();
      _name = TextEditingController();
      _note = TextEditingController();
      _rollover = false;
      _warn = 0.8;
      _resetRunsDefault();
    }
    _name.addListener(_onNameChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the editor's name once (§A2). A stored name equal to the derived one
    // reads as `auto`, so the field opens empty; a custom name prefills.
    final edit = _editBudget;
    if (edit != null && !_nameSeeded) {
      _nameSeeded = true;
      if (edit.name != _derivedName()) _name.text = edit.name;
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    _name.dispose();
    _note.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  double get _limitValue => double.tryParse(_limit.text.trim()) ?? 0;

  DateTime get _today => _store.today;

  /// The whole-day stride a repeating days-period budget resets on (7 for a
  /// week, N for every-N-days). Zero in month / once modes, where it is unused.
  int get _strideDays => _period == BudgetPeriod.days ? _lengthDays : 0;

  /// Save is unreachable until the facts a budget cannot exist without are
  /// present: a target, a positive limit, and — when `once` — both dates with
  /// the end not before the start (spec §3).
  bool get _canSave {
    if (_targets.isEmpty || _limitValue <= 0) return false;
    if (!_repeats) {
      if (_until == null) return false;
      if (_until!.isBefore(_from)) return false;
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

    // Creation shares Quick Add's edge (16 pt) with the name as the hero;
    // editing keeps the standard gutter and draws the name as the first card row.
    final cardMargin = _isNew
        ? const EdgeInsets.fromLTRB(kFormMargin, 0, kFormMargin, Insets.md)
        : null;

    return EditScaffold(
      title: l.ebTitle,
      type: _isNew ? QuickAddType.newBudget : null,
      onTypeTap: _isNew ? _showTypeMenu : null,
      onSave: _canSave ? _save : null,
      hero: _isNew ? _nameHero(l) : null,
      children: [
        // ── Name (edit only — creation draws it as the hero above) ──
        if (!_isNew)
          FormSection(
            margin: cardMargin,
            children: [_nameField(l, pinned: false)],
          ),

        // ── Spending on / from / tagged (§4) ──
        FormSection(
          margin: cardMargin,
          children: [_spendingRow(l)],
        ),

        // ── The budget (§5 / §6) ──
        FormSection(
          margin: cardMargin,
          children: [
            _limitRow(l, store),
            _periodRow(l),
            _runsRow(l),
            if (_repeats)
              ToggleRow(
                icon: Icons.repeat_rounded,
                label: l.ebRollOver,
                value: _rollover,
                onChanged: (v) => setState(() => _rollover = v),
              ),
            FormRow(
              icon: Icons.notifications_active_rounded,
              label: l.ebWarnAt,
              value: _warnLabel(l),
              showChevron: true,
              opensSheet: true,
              onTap: _pickThreshold,
            ),
          ],
        ),

        // ── Note (§7) ──
        FormSection(
          margin: cardMargin,
          children: [
            NoteRow(
              icon: Icons.notes_rounded,
              controller: _note,
              hint: l.goalNoteHint,
              semanticsLabel: l.goalNoteLabel,
            ),
          ],
        ),

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

  // ── Name (§3) ────────────────────────────────────────────────────────────────

  /// The name the budget takes when the user types nothing (§3): a single
  /// target's name, or `{first} + {n − 1}`, or null with none chosen.
  String? _derivedName() {
    if (_targets.isEmpty) return null;
    final first = _nameOf(_targets.first) ?? _targets.first;
    if (_targets.length == 1) return first;
    return AppLocalizations.of(context)
        .bgAutoNameMore(first, _targets.length - 1);
  }

  /// The creation name hero, in Quick Add's pinned geometry — byte-identical to
  /// the field the goal / schedule forms draw (§3).
  Widget _nameHero(AppLocalizations l) => _nameField(l, pinned: true);

  Widget _nameField(AppLocalizations l, {required bool pinned}) {
    final derived = _derivedName();
    final s = formScale(context);
    return NameField(
      controller: _name,
      focusNode: _nameFocus,
      hint: derived ?? l.qaExampleCategory,
      semanticsLabel: l.qaName,
      leadingIcon: Icons.donut_large_rounded,
      // The `auto` pill sits where the clear button will once a name is typed
      // (§3); with no target chosen there is no derived name and no pill.
      emptyTrailing: derived == null ? null : const AutoPill(),
      surface: pinned ? AppColors.surfaceAlt : null,
      radius: pinned ? 14 : 12,
      scale: pinned ? s : 1.0,
      textScale: pinned ? formTextScale(context) : 1.0,
      fixedHeight: pinned ? 48 * s : null,
      horizontalPadding: pinned ? kRowPadding : Insets.md,
      iconColumn: pinned ? kIconColumn : RowMetrics.iconColumn,
      iconGap: pinned ? kIconGap : RowMetrics.iconGap,
    );
  }

  String _effectiveName() {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    return _derivedName() ?? '';
  }

  // ── Spending on (§4) ─────────────────────────────────────────────────────────

  IconData get _scopeIcon => switch (_scope) {
        BudgetScope.categories => Icons.category_rounded,
        BudgetScope.account => Icons.account_balance_wallet_rounded,
        BudgetScope.tag => Icons.sell_rounded,
      };

  /// The row says what the budget watches, not the scope's noun (§4).
  String _spendingLabel(AppLocalizations l) => switch (_scope) {
        BudgetScope.categories => l.bgSpendingOn,
        BudgetScope.account => l.bgSpendingFrom,
        BudgetScope.tag => l.bgSpendingTagged,
      };

  String? _nameOf(String id) => switch (_scope) {
        BudgetScope.categories => _store.categoryById(id)?.name,
        BudgetScope.account => _store.accountById(id)?.name,
        BudgetScope.tag => _store.tagById(id)?.name,
      };

  String _targetsValue(AppLocalizations l) {
    final names = [for (final id in _targets) _nameOf(id) ?? id];
    if (names.isEmpty) {
      // One imperative per scope: the row says which thing to choose, and the
      // scope is what decides (task 043 §3).
      return switch (_scope) {
        BudgetScope.categories => l.emptyChooseCategories,
        BudgetScope.account => l.emptyChooseAccount,
        BudgetScope.tag => l.emptyChooseTags,
      };
    }
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]}, ${names[1]}';
    return '${names.first} +${names.length - 1}';
  }

  Widget _spendingRow(AppLocalizations l) {
    final empty = _targets.isEmpty;
    if (_isNew) {
      return FormRow(
        icon: _scopeIcon,
        label: _spendingLabel(l),
        value: _targetsValue(l),
        valueColor: empty ? AppColors.textSecondary : AppColors.textPrimary,
        showChevron: true,
        opensSheet: true,
        onTap: _pickTargets,
      );
    }
    // Edit mode: scope + targets are fixed (changing them detaches the history).
    return FormRow(
      icon: _scopeIcon,
      label: _spendingLabel(l),
      value: _targetsValue(l),
      enabled: false,
      locked: true,
    );
  }

  // ── Limit (§5) ─────────────────────────────────────────────────────────────

  String _limitLabel(AppLocalizations l) {
    if (_period == BudgetPeriod.month && _repeats) return l.ebMonthlyLimit;
    if (_period == BudgetPeriod.days && _repeats && _lengthDays == 7) {
      return l.bgWeeklyLimit;
    }
    return l.bgLimit;
  }

  Widget _limitRow(AppLocalizations l, AppStore store) => FormRow(
        icon: Icons.attach_money_rounded,
        label: _limitLabel(l),
        trailing: _limitTrailing(store),
      );

  Widget _limitTrailing(AppStore store) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            child: TextField(
              key: const Key('budgetLimitField'),
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
            currencyDef(store.baseCurrency).token,
            style: AppText.amount.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );

  // ── Period (§5) ─────────────────────────────────────────────────────────────

  String _periodPhrase(AppLocalizations l) {
    if (!_repeats) return l.bgPeriodOnce;
    if (_period == BudgetPeriod.month) return l.bgPeriodMonth;
    if (_lengthDays == 7) return l.bgPeriodWeek;
    return l.bgPeriodEveryDays(_lengthDays);
  }

  Widget _periodRow(AppLocalizations l) {
    if (_isNew) {
      return FormRow(
        icon: Icons.event_repeat_rounded,
        label: l.bgPeriod,
        value: _periodPhrase(l),
        valueColor: AppColors.textPrimary,
        showChevron: true,
        opensSheet: true,
        onTap: _pickPeriod,
      );
    }
    // The period is fixed once chosen (its history is measured over it).
    return FormRow(
      icon: Icons.event_repeat_rounded,
      label: l.bgPeriod,
      value: _periodPhrase(l),
      enabled: false,
      locked: true,
    );
  }

  // ── Runs (§6) ────────────────────────────────────────────────────────────────

  /// The most recent [weekday] on or before today, so a weekly window resets on
  /// its FROM day (§6b).
  DateTime _mostRecentWeekday(int weekday) {
    var d = DateTime(_today.year, _today.month, _today.day);
    while (d.weekday != weekday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  /// A new budget, or a period switch, seeds the window with that period's
  /// default (§6b).
  void _resetRunsDefault() {
    _runsTouched = false;
    switch (_period) {
      case BudgetPeriod.month:
        _from = DateTime(_today.year, _today.month);
        _until = null;
      case BudgetPeriod.days:
        if (_repeats && _lengthDays == 7) {
          _from = _mostRecentWeekday(DateTime.monday);
          _until = null;
        } else if (_repeats) {
          _from = DateTime(_today.year, _today.month, _today.day);
          _until = null;
        } else {
          _from = DateTime(_today.year, _today.month, _today.day);
          _until = _from.add(const Duration(days: 13));
        }
    }
  }

  String _runsValue(AppLocalizations l) {
    if (!_repeats) {
      // A one-off always names a concrete window, with its year.
      return _dayRange(l, _from, _until!, showYear: true);
    }
    if (_period == BudgetPeriod.month) {
      if (_until == null) {
        final thisMonth = DateTime(_today.year, _today.month);
        return _from == thisMonth
            ? l.bgRunsThisMonthNoEnd
            : l.bgRunsFromNoEnd(monthYear(_from, l));
      }
      return _monthRange(l, _from, _until!);
    }
    // Weekly / every-N-days.
    if (_until == null) {
      final todayDay = DateTime(_today.year, _today.month, _today.day);
      return _from == todayDay
          ? l.bgRunsTodayNoEnd
          : l.bgRunsFromNoEnd('${weekdayShort(_from.weekday, l)} ${dayMonth(_from, l)}');
    }
    final crossesYear =
        _from.year != _today.year || _until!.year != _today.year;
    return _dayRange(l, _from, _until!, showYear: crossesYear);
  }

  /// `1 – 15 Oct 2026` · `28 Sep – 3 Oct 2026` · `28 Dec 2026 – 3 Jan 2027`,
  /// dropping the year when [showYear] is false and both ends fall this year.
  String _dayRange(AppLocalizations l, DateTime a, DateTime b,
      {required bool showYear}) {
    final sameMonth = a.year == b.year && a.month == b.month;
    final sameYear = a.year == b.year;
    if (!showYear) {
      if (sameMonth) return '${a.day} – ${b.day} ${monthShort(a.month, l)}';
      return '${dayMonth(a, l)} – ${dayMonth(b, l)}';
    }
    if (sameMonth) {
      return '${a.day} – ${b.day} ${monthShort(a.month, l)} ${a.year}';
    }
    if (sameYear) return '${dayMonth(a, l)} – ${dayMonth(b, l)} ${a.year}';
    return '${dayMonthYear(a, l)} – ${dayMonthYear(b, l)}';
  }

  /// `Jan – Jun 2027` within a year, `Nov 2026 – Feb 2027` across one.
  String _monthRange(AppLocalizations l, DateTime a, DateTime b) {
    if (a.year == b.year) {
      return '${monthShort(a.month, l)} – ${monthShort(b.month, l)} ${a.year}';
    }
    return '${monthYear(a, l)} – ${monthYear(b, l)}';
  }

  Widget _runsRow(AppLocalizations l) {
    // A one-off's window is locked when editing, as Dates was (§6e).
    final locked = !_isNew && !_repeats;
    return FormRow(
      icon: Icons.date_range_rounded,
      label: l.bgRuns,
      value: _runsValue(l),
      valueColor: _runsTouched ? AppColors.textPrimary : AppColors.textSecondary,
      enabled: !locked,
      locked: locked,
      trailing: locked
          ? null
          : const Icon(Icons.chevron_right_rounded,
              size: RowMetrics.chevronSize, color: AppColors.textQuaternary),
      onTap: locked ? null : _pickRuns,
    );
  }

  Future<void> _pickRuns() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l = AppLocalizations.of(context);
    final result = await showRunsSheet(
      context,
      mode: _period == BudgetPeriod.month ? RunsMode.months : RunsMode.days,
      once: !_repeats,
      strideDays: _strideDays == 0 ? 30 : _strideDays,
      today: _today,
      initialFrom: _from,
      initialUntil: _until,
      // FROM is locked when editing a repeating budget (§6e); a new budget may
      // move it freely.
      fromLocked: !_isNew,
      subtitle: _repeats ? _periodPhrase(l) : l.bgRunsOnceSub,
    );
    if (!mounted || result == null) return;
    setState(() {
      _from = result.from;
      _until = result.until;
      _runsTouched = true;
    });
  }

  // ── Trailing / warn label ────────────────────────────────────────────────────

  String _warnLabel(AppLocalizations l) {
    final pct = percent(_warn, decimals: 0);
    if (_limitValue <= 0) return pct;
    return '$pct · ${money(_limitValue * _warn)}';
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
    // One remove path for both screens (task 067.3 §4c). Unchanged text/effect;
    // this screen pops itself after removal.
    final removed = await confirmAndRemoveBudget(context, _store, _editBudget!);
    if (removed && mounted) Navigator.of(context).pop();
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
      }
      // A new period resets the run window to that period's default (§5 / §6b).
      _resetRunsDefault();
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

  // ── Save (§8) ────────────────────────────────────────────────────────────────

  /// The anchor a create saves with, derived from FROM and the period (§6d).
  DateTime _anchorForSave() {
    if (!_repeats) return _from;
    if (_period == BudgetPeriod.month) {
      return DateTime(_from.year, _from.month, 1);
    }
    return _from;
  }

  void _save() {
    final name = _effectiveName();
    final note = _note.text.trim();

    if (_isMonthlyCategoryEdit) {
      // Task 005's history-preserving path. Resolve the budget once, up front.
      final budget = _editBudget!;
      final cat = _store.categoryById(budget.targets.first);
      if (cat != null) {
        _store.updateBudget(
          cat,
          monthlyBudget: _limitValue,
          rollover: _rollover,
          warnThreshold: _warn,
        );
      }
      _store.setBudgetName(budget, name);
      _store.setBudgetNote(budget, note);
      _store.setBudgetRunsUntil(budget, _until);
      Navigator.of(context).pop();
      return;
    }

    if (!_isNew) {
      final budget = _editBudget!;
      _store.updateBudgetGeneral(
        budget,
        name: name,
        limit: _limitValue,
        rollover: _rollover,
        warnThreshold: _warn,
      );
      _store.setBudgetNote(budget, note);
      if (budget.repeats) _store.setBudgetRunsUntil(budget, _until);
      Navigator.of(context).pop();
      return;
    }

    final lengthDays = _repeats
        ? (_period == BudgetPeriod.month ? null : _lengthDays)
        : (_until!.difference(_from).inDays + 1);
    _store.addBudget(
      scope: _scope,
      targets: _targets,
      name: name,
      limit: _limitValue,
      period: _period,
      lengthDays: lengthDays,
      anchor: _anchorForSave(),
      repeats: _repeats,
      rollover: _rollover,
      warnThreshold: _warn,
      endedAt: _repeats ? null : _until,
      runsUntil: _repeats ? _until : null,
      note: note,
    );
    Navigator.of(context).pop();
  }
}

/// The `Period` sheet (spec §5 / D.4): four choices on one card. `Every … days`
/// reveals a number field (2–365); the other three commit immediately. The run
/// window is entered on the form's own Runs row, not here.
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
      top: false,
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.bgPeriod,
                        style: AppText.rowTitle.copyWith(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(l.actionCancel,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: Insets.md),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.sheetCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _option(l.bgPeriodMonth, l.bgPeriodMonthHint,
                      _PeriodChoice.month),
                  _divider(),
                  _option(
                      l.bgPeriodWeek, l.bgPeriodWeekHint, _PeriodChoice.week),
                  _divider(),
                  _option(
                      l.bgPeriodDays, l.bgPeriodDaysHint, _PeriodChoice.days),
                  if (_choice == _PeriodChoice.days) _daysField(l),
                  _divider(),
                  _option(
                      l.bgPeriodOnce, l.bgPeriodOnceHint, _PeriodChoice.once),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Divider(
            height: 0.5, thickness: 0.5, color: AppColors.sheetRowDivider),
      );

  Widget _daysField(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, Insets.sm),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  helperText: l.bgDaysHint,
                  helperStyle:
                      AppText.caption.copyWith(color: AppColors.textTertiary),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            TextButton(
              onPressed: (_daysValue >= 2 && _daysValue <= 365)
                  ? () => Navigator.of(context)
                      .pop((choice: _PeriodChoice.days, days: _daysValue))
                  : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.accentLight),
              child: Text(l.actionDone),
            ),
          ],
        ),
      );

  Widget _option(String label, String subtitle, _PeriodChoice choice) {
    final marked = _choice == choice;
    return InkWell(
      onTap: () => _commit(choice),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: AppText.body.copyWith(
                            fontSize: 15,
                            fontWeight:
                                marked ? FontWeight.w600 : FontWeight.w400)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (marked)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.accentLight),
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
