import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/fx.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/pickers.dart';
import 'edit_scaffold.dart';
import 'goal_presentation.dart';

/// Opens the unified goal form (§3) — create when [goalId] is null, edit
/// otherwise. Both the Planner "+" and Quick Add's newGoal route here; the
/// numeric-hero sheet cannot host the WATCHING picker or the target↔date pair.
Future<void> openGoalEditor(BuildContext context, {String? goalId}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => EditGoalScreen(goalId: goalId)),
  );
}

/// One form, four kinds (§3). The chosen **source** decides the section, the
/// direction and the default target — the user never picks a type. The source
/// is locked after creation: changing it would invalidate `startAmount`, every
/// rate, the projection and the whole history.
class EditGoalScreen extends StatefulWidget {
  const EditGoalScreen({super.key, this.goalId});

  /// null → create a new goal.
  final String? goalId;

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

/// A chosen WATCHING source, or the request to create a fresh `setAside`
/// account named from the goal.
class _SourceChoice {
  const _SourceChoice.existing(this.source) : isNew = false;
  const _SourceChoice.newAccount()
      : source = null,
        isNew = true;

  final GoalSource? source;
  final bool isNew;
}

/// Which half of the target-date ↔ monthly pair the user typed. The other half
/// is computed from it; `none` is the untouched state where both read "Not set"
/// (§4). The goal itself only ever stores a target *date* — `monthly` is a UI
/// convenience that derives one — so nothing here changes what the Planner reads.
enum _Pair { none, date, monthly }

class _EditGoalScreenState extends State<EditGoalScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Goal? _goal =
      widget.goalId == null ? null : _store.goalById(widget.goalId);

  late final TextEditingController _name =
      TextEditingController(text: _goal?.name ?? '');
  late final TextEditingController _target =
      TextEditingController(text: _initialTargetText());

  String _initialTargetText() {
    final g = _goal;
    if (g == null) return '';
    return g.targetAmount.toStringAsFixed(0);
  }
  final TextEditingController _monthly = TextEditingController();
  late final TextEditingController _note =
      TextEditingController(text: _goal?.note ?? '');

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _monthlyFocus = FocusNode();

  // Source selection (create only — locked on edit).
  bool _createNewAccount = false;
  late GoalSource? _source = _goal?.source;

  // The target-date ↔ monthly pair. `_targetDate` is meaningful when the date
  // is the typed half (or when editing a goal that already carries one); the
  // monthly figure is read from `_monthly` when it is the typed half.
  late DateTime? _targetDate = _goal?.targetDate;
  late _Pair _primary = _goal?.targetDate != null ? _Pair.date : _Pair.none;

  late bool _endsWhenReached = _goal?.endsWhenReached ?? true;

  /// Latches out the monthly controller's listener while we drive its text
  /// programmatically (the derived-display path), so a computed figure is never
  /// mistaken for a user edit that would flip which half is typed.
  bool _syncingMonthly = false;

  bool get _isEditing => _goal != null;

  static DateTime get _today => AppStore.today;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
    _target.addListener(_onTargetChanged);
    _monthly.addListener(_onMonthlyChanged);
    _monthlyFocus.addListener(_onMonthlyFocusChanged);
    // Seed the (derived) monthly readout when editing a dated goal.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMonthlyDisplay());
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _monthly.dispose();
    _note.dispose();
    _nameFocus.dispose();
    _monthlyFocus.dispose();
    super.dispose();
  }

  // ── Derived values ──────────────────────────────────────────────────────

  double get _targetValue => double.tryParse(_target.text.trim()) ?? 0;

  double? get _typedMonthly {
    final r = double.tryParse(_monthly.text.trim());
    return (r != null && r > 0) ? r : null;
  }

  bool get _hasSource => _isEditing || _createNewAccount || _source != null;

  /// The source's own currency — the goal's amounts live in it and cannot be
  /// chosen apart from it (§5.3). A new account and an income category both fall
  /// back to the base currency, as does the untouched state.
  String get _sourceCurrency {
    if (_createNewAccount) return Fx.baseCurrency;
    final s = _isEditing ? _goal!.source : _source;
    if (s == null || s.isCategory) return Fx.baseCurrency;
    return _store.accountById(s.id)?.currency ?? Fx.baseCurrency;
  }

  /// The source's balance at creation — a goal watching an existing account
  /// starts from where that account already stands. A new account and an income
  /// category start from zero.
  double get _startAmount {
    if (_createNewAccount) return 0;
    final s = _isEditing ? _goal!.source : _source;
    if (s == null || s.isCategory) return 0;
    return _store.balanceOnInBase(s.id, _today);
  }

  /// The pair state, resolved to what is actually usable: a `monthly`/`date`
  /// half with no valid figure behind it reads as `none` (so the caption and
  /// the dimming never claim a derivation that has no input yet).
  _Pair get _effectivePair {
    switch (_primary) {
      case _Pair.date:
        return _targetDate == null ? _Pair.none : _Pair.date;
      case _Pair.monthly:
        return _typedMonthly == null ? _Pair.none : _Pair.monthly;
      case _Pair.none:
        return _Pair.none;
    }
  }

  /// Months between now and [date], never negative.
  int _monthsTo(DateTime date) =>
      (date.year - _today.year) * 12 + (date.month - _today.month);

  double _perMonthFromDate(DateTime date) {
    final months = _monthsTo(date);
    final gap = (_targetValue - _startAmount).abs();
    if (months <= 0) return gap;
    return gap / months;
  }

  DateTime _dateFromRate(double rate) {
    final gap = (_targetValue - _startAmount).abs();
    final months = (gap / rate).ceil().clamp(1, 1200);
    return DateTime(_today.year, _today.month + months, _today.day);
  }

  /// The effective target date the goal will store — typed directly, or the one
  /// the monthly figure implies. Null in the untouched state.
  DateTime? get _effectiveTargetDate {
    switch (_effectivePair) {
      case _Pair.date:
        return _targetDate;
      case _Pair.monthly:
        return _dateFromRate(_typedMonthly!);
      case _Pair.none:
        return null;
    }
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _targetValue > 0 &&
      _hasSource &&
      // Target and date are a pair; a normal goal needs one. A refillable fund
      // may skip the date.
      (_effectiveTargetDate != null || !_endsWhenReached);

  // ── Listeners / pair mechanics ──────────────────────────────────────────

  void _onNameChanged() => setState(() {});

  void _onTargetChanged() {
    // A new gap re-derives whichever half is computed.
    _syncMonthlyDisplay();
    setState(() {});
  }

  void _onMonthlyChanged() {
    if (_syncingMonthly) return;
    // A real keystroke in the monthly field makes it the typed half; clearing
    // it returns the pair to "Not set" (§10).
    setState(() {
      _primary = _monthly.text.trim().isEmpty ? _Pair.none : _Pair.monthly;
    });
  }

  void _onMonthlyFocusChanged() {
    // Tapping into the monthly field (even a derived one) makes it the typed
    // half (§5.2). Its current text — the derived figure — becomes the seed.
    if (_monthlyFocus.hasFocus && _primary != _Pair.monthly) {
      setState(() => _primary = _Pair.monthly);
    }
  }

  /// Drives the monthly field's text from the derived figure whenever monthly
  /// is *not* the typed half. Latched so this never trips [_onMonthlyChanged].
  void _syncMonthlyDisplay() {
    if (_primary == _Pair.monthly) return;
    final d = _primary == _Pair.date && _targetDate != null
        ? _perMonthFromDate(_targetDate!)
        : null;
    final text = d == null ? '' : d.round().toString();
    if (_monthly.text == text) return;
    _syncingMonthly = true;
    _monthly.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncingMonthly = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final code = _sourceCurrency;
    final effective = _effectivePair;

    return EditScaffold(
      title: _isEditing ? l.egTitle : l.goalNewTitle,
      onSave: _canSave ? _save : null,
      header: _isEditing ? _progressHeader(l) : null,
      children: [
        // ── Name ──
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.flag_rounded,
              label: l.egGoalName,
              controller: _name,
              focusNode: _nameFocus,
              hint: l.qaExampleGoal,
              trailing: _nameClear(),
            ),
          ],
        ),

        // ── Source (§2/§3) ──
        FormSection(
          children: [
            if (_isEditing)
              FormRow(
                icon: Icons.visibility_rounded,
                label: l.goalSource,
                value: _store.refName(_goal!.source.id),
                // Locked after creation — the padlock and its line explain why
                // (§10, unchanged).
                subtitle: l.goalSourceLocked,
                enabled: false,
                locked: true,
              )
            else
              _LineRow(
                icon: Icons.visibility_rounded,
                label: l.goalSource,
                value: Text(
                  _sourceLabel(l),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.amount.copyWith(
                    color: _sourceChosen
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: _pickSource,
              ),
          ],
        ),
        if (!_isEditing && _twoGoalsWarning(l) != null)
          NoticeBanner(text: _twoGoalsWarning(l)!),

        // ── Target amount · Target date · Monthly (§5) ──
        FormSection(
          children: [
            _LineRow(
              icon: Icons.adjust_rounded,
              label: l.egTargetAmount,
              value: _amountValue(
                controller: _target,
                dim: false,
                hint: '0',
                token: _currencyChip(l, code),
              ),
            ),
            _LineRow(
              icon: Icons.event_rounded,
              label: l.egTargetDate,
              dimLabel: effective == _Pair.monthly,
              onTap: _pickTargetDate,
              value: _dateValue(l, derived: effective == _Pair.monthly),
            ),
            _LineRow(
              icon: Icons.speed_rounded,
              label: l.goalMonthly,
              dimLabel: effective == _Pair.date,
              value: _amountValue(
                controller: _monthly,
                focusNode: _monthlyFocus,
                dim: _primary != _Pair.monthly,
                hint: l.eaNotSet,
                token: _currencyCode(code),
              ),
            ),
          ],
        ),
        _PairCaption(text: _pairCaption(l)),

        // ── Options ──
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.notes_rounded,
              label: l.goalNoteLabel,
              controller: _note,
              hint: l.goalNoteHint,
            ),
            ToggleRow(
              icon: Icons.check_circle_rounded,
              label: l.goalDoneOnceReached,
              subtitle: l.goalDoneOnceReachedDesc,
              value: _endsWhenReached,
              onChanged: (v) => setState(() => _endsWhenReached = v),
            ),
          ],
        ),

        if (_isEditing)
          DestructiveRow(
            label: l.egDeleteGoal,
            subtitle: l.goalDeleteRowDesc,
            onTap: _delete,
          ),
      ],
    );
  }

  // ── Name clear button (§1) ─────────────────────────────────────────────────

  /// A 22pt clear button in a 44pt hit area, in a slot reserved whether or not
  /// it shows — so the field text never shifts. Present only when there is
  /// something to clear; clears the field and keeps focus.
  Widget _nameClear() {
    if (_name.text.isEmpty) return const SizedBox(width: 44, height: 44);
    return SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _name.clear();
          _nameFocus.requestFocus();
        },
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Value slots ────────────────────────────────────────────────────────────

  /// An inline editable amount (§5.1) with its currency [token] pinned to the
  /// card's right edge; the number sits to its left. Right-aligned so the token
  /// shares one edge across all three rows.
  Widget _amountValue({
    required TextEditingController controller,
    FocusNode? focusNode,
    required bool dim,
    required String hint,
    required Widget token,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: AppColors.accentSoft,
            style: AppText.amount.copyWith(
              color: dim ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: AppText.amount.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        token,
      ],
    );
  }

  Widget _dateValue(AppLocalizations l, {required bool derived}) {
    final d = _effectiveTargetDate;
    return Text(
      d == null ? l.eaNotSet : monthYear(d, l),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.amount.copyWith(
        color: (derived || d == null)
            ? AppColors.textSecondary
            : AppColors.textPrimary,
      ),
    );
  }

  /// The locked currency chip on Target amount (§5.3): a bordered pill with a
  /// small padlock and the source's code. Not a button — a tap explains that
  /// the currency follows the source.
  Widget _currencyChip(AppLocalizations l, String code) {
    return Semantics(
      label: '$code · ${l.goalCurrencyLockedHint}',
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(l.goalCurrencyLockedHint),
              behavior: SnackBarBehavior.floating,
            ));
        },
        child: Tooltip(
          message: l.goalCurrencyLockedHint,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded,
                    size: 10, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(code,
                    style:
                        AppText.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The same code as plain text on Monthly (§5.3) — no border, no lock — so the
  /// figure is unambiguous while the target row alone carries the "locked" cue.
  Widget _currencyCode(String code) => Text(
        code,
        style: AppText.caption.copyWith(color: AppColors.textTertiary),
      );

  String _pairCaption(AppLocalizations l) {
    switch (_effectivePair) {
      case _Pair.date:
        return l.goalPairHintFromDate;
      case _Pair.monthly:
        return l.goalPairHintFromMonthly;
      case _Pair.none:
        return l.goalPairHintEither;
    }
  }

  // ── Header (edit only) ──────────────────────────────────────────────────

  Widget _progressHeader(AppLocalizations l) {
    final m = _store.goalMetrics(_goal!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.sm,
        Insets.gutter,
        Insets.md,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountText.balance(
                m.current,
                style: AppText.amountLarge.copyWith(fontSize: 18),
                color: goalBarColor(m),
              ),
              Text(' ${l.goalOfWord} ${money(m.target)}', style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ProgressBar(value: m.progress, color: goalBarColor(m), height: 7),
        ],
      ),
    );
  }

  // ── Source ───────────────────────────────────────────────────────────────

  bool get _sourceChosen => _createNewAccount || _source != null;

  String _sourceLabel(AppLocalizations l) {
    if (_isEditing) return _store.refName(_goal!.source.id);
    if (_createNewAccount) {
      return l.goalNewAccountNamed(
        _name.text.trim().isEmpty ? l.goalUntitled : _name.text.trim(),
      );
    }
    final s = _source;
    if (s == null) return l.eaNotSet;
    return _store.refName(s.id);
  }

  /// Two goals may watch one account — the user might be tracking two
  /// milestones on one pot. Warn at creation, never block.
  String? _twoGoalsWarning(AppLocalizations l) {
    final s = _source;
    if (s == null || !s.isAccount) return null;
    final already = _store.goals.any((g) => g.source == s);
    return already ? l.goalTwoOnAccount : null;
  }

  Future<void> _pickSource() async {
    final choice = await showAppSheet<_SourceChoice>(
      context,
      title: AppLocalizations.of(context).goalWatching,
      builder: (sheetContext, controller) =>
          _SourcePicker(store: _store, controller: controller),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice.isNew) {
        _createNewAccount = true;
        _source = null;
      } else {
        _createNewAccount = false;
        _source = choice.source;
        // A liability or a receivable falls to zero — default its target to 0.
        final s = choice.source!;
        if (s.isAccount) {
          final acc = _store.accountById(s.id);
          if (acc != null &&
              (acc.isLiability || acc.group == AccountGroup.receivables)) {
            _target.text = '0';
          }
        }
      }
    });
    // Changing the source changes the symbol, never the digits (§5.3) — so the
    // amounts are untouched; only the derived monthly readout is refreshed.
    _syncMonthlyDisplay();
  }

  // ── Target date / rate ─────────────────────────────────────────────────────

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveTargetDate ?? DateTime(_today.year + 1),
      firstDate: _today,
      lastDate: DateTime(2040),
    );
    if (picked == null || !mounted) return;
    _monthlyFocus.unfocus();
    setState(() {
      _targetDate = picked;
      _primary = _Pair.date;
    });
    _syncMonthlyDisplay();
  }

  // ── Save / delete ──────────────────────────────────────────────────────────

  void _save() {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final note = _note.text.trim();
    final date = _effectiveTargetDate;

    if (_isEditing) {
      _store.updateGoal(
        _goal!,
        name: name,
        targetAmount: _targetValue,
        targetDate: date,
        clearTargetDate: date == null,
        endsWhenReached: _endsWhenReached,
        note: note,
      );
      Navigator.of(context).pop();
      return;
    }

    // Resolve the source, creating the setAside account if the user chose New.
    final GoalSource source;
    if (_createNewAccount) {
      final acc = _store.addAccount(
        name: name.isEmpty ? l.goalUntitled : name,
        group: AccountGroup.setAside,
        currency: Fx.baseCurrency,
        startingBalance: 0,
      );
      source = GoalSource.account(acc.id);
    } else {
      source = _source!;
    }

    _store.addGoal(
      name: name,
      source: source,
      targetAmount: _targetValue,
      targetDate: date,
      endsWhenReached: _endsWhenReached,
      note: note,
    );
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final goal = _goal!;
    final ok = await confirmGoalDelete(context, _store, goal);
    if (!ok || !mounted) return;
    _store.deleteGoal(goal);
    Navigator.of(context).pop();
  }
}

/// One 48pt form line (§5/§6): leading glyph, a label that yields first, and a
/// value pinned right. A new row shape — added rather than repurposing
/// [FormRow]/[TextFieldRow], so every other screen using those is untouched. The
/// height is a *minimum*: it grows with text scale instead of clipping (§10).
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.dimLabel = false,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// The value slot — right-aligned static text or an inline field.
  final Widget value;

  /// An optional element at the far right (a chevron for the source picker).
  final Widget? trailing;

  /// A derived row dims its label as well as its value (§5.2).
  final bool dimLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  icon,
                  size: 18,
                  color: dimLabel
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontSize: 14.5,
                    color: dimLabel
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(flex: 5, child: value),
              if (trailing != null) ...[
                const SizedBox(width: 2),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The single caption under the trio (§4): one line, one job, never two.
class _PairCaption extends StatelessWidget {
  const _PairCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + Insets.xs,
        0,
        Insets.gutter,
        Insets.md,
      ),
      child: Text(
        text,
        style: AppText.caption.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// The delete confirmation counts what stays (§5): the account, its balance and
/// its transactions are untouched. It never offers to move the money — that is a
/// transfer, and bundling a side effect into a delete is how users lose track.
Future<bool> confirmGoalDelete(
  BuildContext context,
  AppStore store,
  Goal goal,
) async {
  final l = AppLocalizations.of(context);
  final impact = <ImpactLine>[];
  if (goal.source.isAccount) {
    final acc = store.accountById(goal.source.id);
    if (acc != null) {
      impact.add(ImpactLine.kept(l.goalDeleteAccountStays(
        acc.name,
        money(store.balanceOf(acc.id).abs()),
      )));
      impact.add(
          ImpactLine.kept(l.goalDeleteTxnStay(store.txnsForAccount(acc.id).length)));
    }
  } else {
    impact.add(ImpactLine.kept(l.goalDeleteCategoryStays));
  }
  return showDestructiveConfirm(
    context,
    title: l.goalDeleteTitle(goal.name),
    message: l.goalDeleteBody,
    impact: impact,
    confirmLabel: l.egDeleteGoal,
  );
}

/// The WATCHING picker (§3): `New · …` first, then existing accounts grouped as
/// the account pickers group them, then income categories. With neither, an
/// empty state sits under the create row (§8.2).
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.store, required this.controller});

  final AppStore store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final incomeCategories = store.categoriesOfType(CategoryType.income);
    final hasAccounts =
        AccountGroup.values.any((g) => store.accountsIn(g).isNotEmpty);
    final empty = !hasAccounts && incomeCategories.isEmpty;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        // 1 · New account, named from the goal.
        _SourceTile(
          icon: Icons.add_rounded,
          color: AppColors.accent,
          title: l.goalNewAccountOption,
          subtitle: l.goalNewAccountOptionDesc,
          // A description, not a value — it belongs beneath the title (§8.1).
          descriptive: true,
          onTap: () =>
              Navigator.of(context).pop(const _SourceChoice.newAccount()),
        ),
        // 1b · Nothing to watch — a goal needs one real source (§8.2).
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.md),
            child: EmptyState(
              icon: Icons.visibility_off_rounded,
              title: l.goalSourceEmptyTitle,
              message: l.goalSourceEmptyMsg,
              iconBackdrop: true,
            ),
          ),
        // 2 · Existing accounts, grouped.
        for (final group in AccountGroup.values)
          if (store.accountsIn(group).isNotEmpty) ...[
            SectionLabelSmall(group.label(l)),
            for (final a in store.accountsIn(group))
              _SourceTile(
                icon: a.displayIcon,
                color: a.color,
                title: a.name,
                subtitle: money(store.balanceOf(a.id).abs(), currency: a.currency),
                onTap: () => Navigator.of(context)
                    .pop(_SourceChoice.existing(GoalSource.account(a.id))),
              ),
          ],
        // 3 · Income categories.
        if (incomeCategories.isNotEmpty) ...[
          SectionLabelSmall(l.goalIncomeCategories),
          for (final c in incomeCategories)
            _SourceTile(
              icon: c.icon,
              color: c.color,
              title: c.name,
              subtitle: null,
              onTap: () => Navigator.of(context)
                  .pop(_SourceChoice.existing(GoalSource.category(c.id))),
            ),
        ],
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.descriptive = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// True when [subtitle] is a description of the row rather than a value for
  /// it. A description goes under the title (and may run two lines); a value —
  /// an account's balance — sits beside it (§8.1).
  final bool descriptive;

  @override
  Widget build(BuildContext context) {
    final describe = descriptive && subtitle != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter,
          vertical: Insets.sm,
        ),
        child: Row(
          children: [
            IconTile(icon, color: color, size: 34),
            const SizedBox(width: Insets.md),
            Expanded(
              child: describe
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.rowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppText.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(
                      title,
                      style: AppText.rowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (subtitle != null && !descriptive) ...[
              const SizedBox(width: Insets.sm),
              Text(subtitle!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
