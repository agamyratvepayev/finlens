import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/auto_pill.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/typed_date_sheet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/creation_host.dart';
import '../quick_add/pickers.dart';
import '../quick_add/type_menu.dart';
import '../quick_add/widgets/amount_hero.dart' show CurrencyChip;
import '../quick_add/widgets/form_kit.dart';
import 'edit_scaffold.dart';
import 'goal_presentation.dart';

/// Opens the unified goal form (§3) — create when [goalId] is null, edit
/// otherwise. The numeric-hero sheet cannot host the WATCHING picker or the
/// target↔date pair, so a goal always lives on this full-screen form.
///
/// Creating a goal opens a creation session (task 056): one route hosts the goal
/// editor alongside Quick Add and the budget editor, so switching type keeps
/// every form's input. Editing an existing goal has nothing to switch to, so it
/// is pushed directly.
Future<void> openGoalEditor(BuildContext context, {String? goalId}) {
  if (goalId == null) {
    return openCreationSession(context, type: QuickAddType.newGoal);
  }
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

class _EditGoalScreenState extends State<EditGoalScreen>
    with SingleTickerProviderStateMixin {
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

  /// The period the pace is stated in (§5). Chosen from the pace row's own
  /// sheet; recomputes the derived half whenever it changes.
  late GoalPace _pace = _goal?.pace ?? GoalPace.month;

  late bool _endsWhenReached = _goal?.endsWhenReached ?? true;

  /// Creation only (§6): which row a failed Save is flashing — 'name',
  /// 'source', 'target' or 'date' — with a pulse behind it and a message under
  /// its card. Null when nothing is flashing.
  String? _flashTarget;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Latches out the monthly controller's listener while we drive its text
  /// programmatically (the derived-display path), so a computed figure is never
  /// mistaken for a user edit that would flip which half is typed.
  bool _syncingMonthly = false;

  bool get _isEditing => _goal != null;

  DateTime get _today => _store.today;

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
    _pulse.dispose();
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
    if (_createNewAccount) return _store.baseCurrency;
    final s = _isEditing ? _goal!.source : _source;
    if (s == null || s.isCategory) return _store.baseCurrency;
    return _store.accountById(s.id)?.currency ?? _store.baseCurrency;
  }

  /// The source's balance at creation — a goal watching an existing account
  /// starts from where that account already stands. A new account and an income
  /// category start from zero.
  double get _startAmount {
    if (_createNewAccount) return 0;
    final s = _isEditing ? _goal!.source : _source;
    if (s == null || s.isCategory) return 0;
    // An account goal is measured in the account's own currency (021d §2b), so
    // its starting figure is the native balance, not a converted one.
    return _store.balanceOn(s.id, _today);
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

  /// Whole periods of the current [_pace] between today and [date] (§5c). One
  /// rule per pace, so day/week/month/quarter/year all share the arithmetic.
  int _periodsTo(DateTime date) {
    switch (_pace) {
      case GoalPace.day:
        return DateTime(date.year, date.month, date.day)
            .difference(DateTime(_today.year, _today.month, _today.day))
            .inDays;
      case GoalPace.week:
        return DateTime(date.year, date.month, date.day)
                .difference(DateTime(_today.year, _today.month, _today.day))
                .inDays ~/
            7;
      case GoalPace.month:
        return _monthsTo(date);
      case GoalPace.quarter:
        return _monthsTo(date) ~/ 3;
      case GoalPace.year:
        return _monthsTo(date) ~/ 12;
    }
  }

  /// The pace figure a target date implies: the gap over the periods left,
  /// or the whole gap when under one period remains (§5c).
  double _perPeriodFromDate(DateTime date) {
    final periods = _periodsTo(date);
    final gap = (_targetValue - _startAmount).abs();
    if (periods <= 0) return gap;
    return gap / periods;
  }

  /// The date a pace figure implies: today plus ⌈gap / rate⌉ periods (§5c).
  DateTime _dateFromRate(double rate) {
    final gap = (_targetValue - _startAmount).abs();
    final n = (gap / rate).ceil().clamp(1, 4000);
    switch (_pace) {
      case GoalPace.day:
        return DateTime(_today.year, _today.month, _today.day + n);
      case GoalPace.week:
        return DateTime(_today.year, _today.month, _today.day + n * 7);
      case GoalPace.month:
        return DateTime(_today.year, _today.month + n, _today.day);
      case GoalPace.quarter:
        return DateTime(_today.year, _today.month + n * 3, _today.day);
      case GoalPace.year:
        return DateTime(_today.year + n, _today.month, _today.day);
    }
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

  void _onNameChanged() => setState(_clearFlashIfFixed);

  void _onTargetChanged() {
    // A new gap re-derives whichever half is computed.
    _syncMonthlyDisplay();
    setState(_clearFlashIfFixed);
  }

  void _onMonthlyChanged() {
    if (_syncingMonthly) return;
    // A real keystroke in the monthly field makes it the typed half; clearing
    // it returns the pair to "Not set" (§10).
    setState(() {
      _primary = _monthly.text.trim().isEmpty ? _Pair.none : _Pair.monthly;
      _clearFlashIfFixed();
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
        ? _perPeriodFromDate(_targetDate!)
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

    // In creation the name field is the session's hero — one 48·s line under the
    // nav bar (§5b) — and the cards below it sit at [kFormMargin] so the whole
    // screen shares one edge (§5c). Editing keeps the name as a row in the first
    // card and every card at the standard gutter.
    final cardMargin = _isEditing
        ? null
        : const EdgeInsets.fromLTRB(kFormMargin, 0, kFormMargin, Insets.md);

    return EditScaffold(
      title: _isEditing ? l.egTitle : l.goalNewTitle,
      // Creating a goal is reachable from the type menu, so it must be able to
      // reopen it; editing an existing goal has nothing to switch to (§2).
      type: _isEditing ? null : QuickAddType.newGoal,
      onTypeTap: _isEditing ? null : _showTypeMenu,
      // Creation always answers (§6): Save is enabled (accent) and, on a
      // missing field, flashes it instead of saving. Editing keeps the
      // disabled-when-invalid TextButton.
      onSave: _isEditing ? (_canSave ? _save : null) : _saveOrFlash,
      header: _isEditing ? _progressHeader(l) : null,
      hero: _isEditing ? null : _nameHero(l),
      children: [
        // ── Name (edit only — creation draws it as the hero above) ──
        if (_isEditing)
          FormSection(
            margin: cardMargin,
            children: [
              NameField(
                controller: _name,
                focusNode: _nameFocus,
                hint: l.qaExampleGoal,
                semanticsLabel: l.egGoalName,
                leadingIcon: Icons.flag_rounded,
              ),
            ],
          ),

        // ── Source (§2/§3) ──
        FormSection(
          margin: cardMargin,
          children: [
            if (_isEditing)
              FormRow(
                icon: Icons.visibility_rounded,
                label: l.goalWatching,
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
                label: l.goalWatching,
                value: _sourceValue(l),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onTap: _pickSource,
                flash: _flashTarget == 'source',
                pulse: _pulse,
              ),
          ],
        ),
        if (_flashTarget == 'source') _blockerLine(l.goalBlockSource, cardMargin),
        if (!_isEditing && _twoGoalsWarning(l) != null)
          NoticeBanner(
            text: _twoGoalsWarning(l)!,
            margin: cardMargin,
          ),

        // ── Target amount · Target date · Monthly (§5) ──
        FormSection(
          margin: cardMargin,
          children: [
            _LineRow(
              icon: Icons.adjust_rounded,
              label: l.egTargetAmount,
              flash: _flashTarget == 'target',
              pulse: _pulse,
              value: _amountValue(
                controller: _target,
                dim: false,
                hint: '0',
                token: _staticChip(l, code),
              ),
            ),
            _LineRow(
              icon: Icons.event_rounded,
              label: l.egTargetDate,
              dimLabel: effective == _Pair.monthly,
              flash: _flashTarget == 'date',
              pulse: _pulse,
              onTap: _pickTargetDate,
              // The date is the computed half when the pace is typed → it wears
              // the `auto` pill (§5e).
              value: _dateValue(l, computed: effective == _Pair.monthly),
            ),
            _LineRow(
              icon: Icons.speed_rounded,
              // The label IS the period, with an accent chevron opening the
              // pace sheet (§5b); tapping it never focuses the amount.
              label: _paceLabel(l),
              labelWidget: _paceLabelWidget(l, dim: effective == _Pair.date),
              dimLabel: effective == _Pair.date,
              onTap: _pickPace,
              value: _amountValue(
                controller: _monthly,
                focusNode: _monthlyFocus,
                dim: _primary != _Pair.monthly,
                // The same 0 Target amount uses (task 061): an empty amount is
                // a zero in its unit, never a sentence.
                hint: '0',
                token: _staticChip(l, code),
                // The pace is the computed half when the date is typed → pill.
                auto: effective == _Pair.date,
              ),
            ),
          ],
        ),
        if (_flashTarget == 'target')
          _blockerLine(l.goalBlockTarget, cardMargin)
        else if (_flashTarget == 'date')
          _blockerLine(l.goalBlockDateOrPace, cardMargin),

        // ── Options ──
        FormSection(
          margin: cardMargin,
          children: [
            NoteRow(
              icon: Icons.notes_rounded,
              controller: _note,
              hint: l.goalNoteHint,
              semanticsLabel: l.goalNoteLabel,
            ),
            // No subtitle: every row in this card is one line, and this one is
            // understood without a second (task 041). `goalDoneOnceReachedDesc`
            // had no other caller and is deleted.
            ToggleRow(
              icon: Icons.check_circle_rounded,
              label: l.goalDoneOnceReached,
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
            opensSheet: true,
          ),
      ],
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
    bool auto = false,
  }) {
    return Row(
      // Baseline, not centre (task 041). Centre matches the two children's line
      // boxes, and the token is 11.5pt beside a ~17pt figure, so its glyphs fell
      // below the number's optical centre. A unit written beside a number sits
      // on that number's baseline.
      //
      // Only *this* Row. _LineRow's Row keeps CrossAxisAlignment.center: baseline
      // applied one level up aligns the label, the icon and the value to each
      // other and collapses the row's vertical centring — which is the very
      // defect §8 exists to fix. Verified: doing so lifts the Monthly row's
      // content ~15pt and breaks the even pitch between the three rows.
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
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
        if (auto) ...[
          const SizedBox(width: Insets.sm),
          _autoPill(),
        ],
      ],
    );
  }

  Widget _dateValue(AppLocalizations l, {required bool computed}) {
    final d = _effectiveTargetDate;
    final text = Text(
      d == null ? l.emptyPickDate : dayMonthYear(d, l),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.amount.copyWith(
        color: (computed || d == null)
            ? AppColors.textSecondary
            : AppColors.textPrimary,
      ),
    );
    if (!computed) return text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(child: text),
        const SizedBox(width: Insets.sm),
        _autoPill(),
      ],
    );
  }

  /// The app's plain currency chip (§3): the source's code, no chevron and no
  /// padlock. Tapping it explains that amounts follow the source's currency.
  Widget _staticChip(AppLocalizations l, String code) => CurrencyChip(
        currency: code,
        showIndicator: false,
        semanticsHint: l.goalCurrencyLockedHint,
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(l.goalCurrencyLockedHint),
              behavior: SnackBarBehavior.floating,
            ));
        },
      );

  /// The `auto` pill on the computed half (§5e).
  Widget _autoPill() => const AutoPill();

  // ── Pace ─────────────────────────────────────────────────────────────────

  /// The pace period's own label — the row's title (§5b).
  String _paceLabel(AppLocalizations l) => switch (_pace) {
        GoalPace.day => l.goalDaily,
        GoalPace.week => l.goalWeekly,
        GoalPace.month => l.goalMonthly,
        GoalPace.quarter => l.goalQuarterly,
        GoalPace.year => l.goalYearly,
      };

  /// The pace label with a small accent chevron after it, marking it a chooser.
  Widget _paceLabelWidget(AppLocalizations l, {required bool dim}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _paceLabel(l),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                fontSize: 14.5,
                color: dim ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 3),
          // The pace chevron is 10, not 14 (task 070 B8).
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 10, color: AppColors.accentLight),
        ],
      );

  /// The creation name field, wrapped so a missing-name Save flashes it (§6).
  Widget _nameHero(AppLocalizations l) {
    final field = NameField(
      controller: _name,
      focusNode: _nameFocus,
      hint: l.qaExampleGoal,
      semanticsLabel: l.egGoalName,
      leadingIcon: Icons.flag_rounded,
      // Quick Add's pinned geometry, so the field is byte-identical to the one
      // Schedule / the transaction types draw (§5b).
      surface: AppColors.surfaceAlt,
      radius: 14,
      scale: formScale(context),
      textScale: formTextScale(context),
      fixedHeight: 48 * formScale(context),
      horizontalPadding: kRowPadding,
      iconColumn: kIconColumn,
      iconGap: kIconGap,
    );
    if (_flashTarget != 'name') return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.tint(
                  AppColors.negative, 0.12 * _LineRow._hump(_pulse.value)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
          child: field,
        ),
        _blockerLine(l.qaBlockNameGoal, const EdgeInsets.only(left: kFormMargin)),
      ],
    );
  }

  /// The message under a flashed row's card (§D.3): 6 pt below, negative.
  Widget _blockerLine(String message, EdgeInsetsGeometry? cardMargin) {
    final left = (cardMargin is EdgeInsets ? cardMargin.left : Insets.gutter) +
        Insets.xs;
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 6, Insets.gutter, 0),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12.5, color: AppColors.negative),
      ),
    );
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

  /// The WATCHING row's value (§1). A picked existing account shows its coloured
  /// chip and full name; a not-yet-created account shows only "New account" —
  /// no goal name, no "New ·" prefix, nothing that could truncate; an income
  /// category shows its name; the untouched state shows "Not set". The goal's
  /// name lives two rows above, so this row never restates it.
  Widget _sourceValue(AppLocalizations l) {
    // Existing account → coloured chip + name. The name is the information, so
    // it alone ellipsises when an account is long-named; the chip never shrinks.
    if (!_createNewAccount && _source != null && _source!.isAccount) {
      final acc = _store.accountById(_source!.id);
      if (acc != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _accountChip(acc),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                acc.name,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.amount.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        );
      }
    }

    final String text;
    if (_createNewAccount) {
      // The whole value — a not-yet-created account has no colour and no name
      // worth carrying; the picker already said it is "named from the goal".
      text = l.goalNewAccountOption;
    } else if (_source != null) {
      // An income-category source: its name, no chip — a category is not an
      // account and carries no chip elsewhere on this screen.
      text = _store.refName(_source!.id);
    } else {
      // The empty value is the app's shared "Choose account" imperative (§2a),
      // not the retired "Choose source".
      text = l.emptyChooseAccount;
    }
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.amount.copyWith(
        color: _sourceChosen ? AppColors.textPrimary : AppColors.textTertiary,
      ),
    );
  }

  /// The 20pt account chip carried before an existing account's name: a tinted
  /// square holding the account's own glyph in its own colour, matching how the
  /// picker and Balance draw an account.
  Widget _accountChip(Account acc) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tint(acc.color, 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(acc.displayIcon, size: 11, color: acc.color),
    );
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
      builder: (sheetContext, controller) => _SourcePicker(
          store: _store,
          controller: controller,
          goalName: _name.text.trim()),
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
      _clearFlashIfFixed();
    });
    // Changing the source changes the symbol, never the digits (§5.3) — so the
    // amounts are untouched; only the derived monthly readout is refreshed.
    _syncMonthlyDisplay();
  }

  // ── Target date / rate ─────────────────────────────────────────────────────

  Future<void> _pickTargetDate() async {
    final picked = await showTypedDateSheet(
      context,
      // Seed the field with the target if one is set; otherwise leave it empty
      // and open the calendar on next year (the old picker's initialDate).
      initialDate: _effectiveTargetDate,
      firstDate: _today,
      lastDate: DateTime(2040),
      initialMonth: DateTime(_today.year + 1),
    );
    if (picked == null || !mounted) return;
    _monthlyFocus.unfocus();
    setState(() {
      _targetDate = picked;
      _primary = _Pair.date;
      _clearFlashIfFixed();
    });
    _syncMonthlyDisplay();
  }

  /// The period sheet (§5d): pick day / week / month / quarter / year. Keeps
  /// whichever half the user typed and recomputes the other.
  Future<void> _pickPace() async {
    _monthlyFocus.unfocus();
    final picked = await showAppSheet<GoalPace>(
      context,
      title: AppLocalizations.of(context).goalPaceTitle,
      contentSized: true,
      cancelLabel: AppLocalizations.of(context).actionCancel,
      builder: (sheetContext, controller) {
        final l = AppLocalizations.of(sheetContext);
        // The date drives the per-period figures — only when it is known.
        final date = _effectiveTargetDate;
        final gap = (_targetValue - _startAmount).abs();
        String? amountFor(GoalPace p) {
          if (date == null || gap <= 0) return null;
          final saved = _pace;
          _pace = p;
          final periods = _periodsTo(date);
          _pace = saved;
          final per = periods <= 0 ? gap : gap / periods;
          final rounded = per.round();
          final prefix = (per - rounded).abs() > 0.005 ? '~' : '';
          return '$prefix${money(rounded.toDouble(), currency: _sourceCurrency)}';
        }

        return ListView(
          controller: controller,
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Insets.xxl),
          children: [
            if (date != null && gap > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.gutter, 0, Insets.gutter, Insets.sm),
                child: Text(
                  l.goalPaceToGo(
                      money(gap, currency: _sourceCurrency),
                      dayMonthYear(date, l)),
                  style: AppText.caption.copyWith(color: AppColors.textTertiary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              child: AppCard(
                color: AppColors.sheetCard,
                child: Column(
                  children: [
                    for (final entry in <(GoalPace, String)>[
                      (GoalPace.day, l.goalEveryDay),
                      (GoalPace.week, l.goalEveryWeek),
                      (GoalPace.month, l.goalEveryMonth),
                      (GoalPace.quarter, l.goalEveryQuarter),
                      (GoalPace.year, l.goalEveryYear),
                    ]) ...[
                      if (entry.$1 != GoalPace.day)
                        const RowDivider(indent: Insets.md),
                      _PaceOption(
                        label: entry.$2,
                        amount: amountFor(entry.$1),
                        selected: entry.$1 == _pace,
                        onTap: () => Navigator.of(sheetContext).pop(entry.$1),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _pace = picked);
    // Keep the typed half; the other recomputes off the new period.
    _syncMonthlyDisplay();
  }

  // ── Type switch (create only) ───────────────────────────────────────────────

  Future<void> _showTypeMenu() async {
    // The name field may hold the keyboard; it must not linger over the sheet.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showQuickAddTypeMenu(
      context,
      current: QuickAddType.newGoal,
    );
    if (!mounted || picked == null || picked == QuickAddType.newGoal) return;
    await switchCreationType(context, picked);
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
        pace: _pace,
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
        currency: _store.baseCurrency,
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
      pace: _pace,
      endsWhenReached: _endsWhenReached,
      note: note,
    );
    Navigator.of(context).pop();
  }

  /// §6 — creation Save always answers: it saves, or flashes the first missing
  /// field and names it. The order is name → source → target → date/pace.
  void _saveOrFlash() {
    final missing = _firstMissing();
    if (missing != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _flashTarget = missing);
      _pulse.forward(from: 0);
      return;
    }
    _save();
  }

  /// The first unmet requirement, in §6's order, or null when the goal is ready.
  String? _firstMissing() {
    if (_name.text.trim().isEmpty) return 'name';
    if (!_hasSource) return 'source';
    if (_targetValue <= 0) return 'target';
    if (_endsWhenReached && _effectiveTargetDate == null) return 'date';
    return null;
  }

  /// Whether the currently-flashed field is still missing — so a correction
  /// clears the flash rather than leaving a stale red label.
  bool _stillMissing(String t) => switch (t) {
        'name' => _name.text.trim().isEmpty,
        'source' => !_hasSource,
        'target' => _targetValue <= 0,
        'date' => _endsWhenReached && _effectiveTargetDate == null,
        _ => false,
      };

  void _clearFlashIfFixed() {
    if (_flashTarget != null && !_stillMissing(_flashTarget!)) {
      _flashTarget = null;
    }
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
    this.labelWidget,
    this.dimLabel = false,
    this.onTap,
    this.flash = false,
    this.pulse,
  });

  final IconData icon;
  final String label;

  /// An optional rich label (the pace row's period name + accent chevron, §5b).
  /// When set it replaces the plain [label] Text; [label] still carries the
  /// semantics and the ellipsis budget lives in the widget itself.
  final Widget? labelWidget;

  /// The value slot — right-aligned static text or an inline field.
  final Widget value;

  /// An optional element at the far right (a chevron for the source picker).
  final Widget? trailing;

  /// A derived row dims its label as well as its value (§5.2).
  final bool dimLabel;
  final VoidCallback? onTap;

  /// Creation-Save flash (§6): the row pulses [AppColors.negative] behind it and
  /// its icon and label turn negative until the missing field is filled.
  final bool flash;
  final Animation<double>? pulse;

  // Two triangular humps across t ∈ [0,1], matching Quick Add's field flash.
  static double _hump(double t) {
    final phase = (t * 2) % 1.0;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = flash
        ? AppColors.negative
        : (dimLabel ? AppColors.textTertiary : AppColors.textSecondary);
    final labelColor = flash
        ? AppColors.negative
        : (dimLabel ? AppColors.textSecondary : AppColors.textPrimary);
    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              // Task 042: the icon column is the glyph (18), so the gap is the
              // gap and the text starts at the shared 42.
              width: 18,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              flex: 4,
              child: labelWidget ??
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      fontSize: 14.5,
                      color: labelColor,
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
    );
    if (flash && pulse != null) {
      content = AnimatedBuilder(
        animation: pulse!,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            color:
                AppColors.tint(AppColors.negative, 0.12 * _hump(pulse!.value)),
          ),
          child: child,
        ),
        child: content,
      );
    }
    return InkWell(onTap: onTap, child: content);
  }
}

/// One 46 pt row in the pace sheet (§5d): the period name, its per-period
/// amount when a date is known, and a check when it is the current pace.
class _PaceOption extends StatelessWidget {
  const _PaceOption({
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (amount != null)
                Text(amount!,
                    style: AppText.caption.copyWith(
                        fontSize: 13.5, color: AppColors.textSecondary)),
              SizedBox(
                width: 24,
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.accentLight)
                    : null,
              ),
            ],
          ),
        ),
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
        formatAmount(store.balanceOf(acc.id), null, kind: AmountKind.magnitude),
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
  const _SourcePicker({
    required this.store,
    required this.controller,
    required this.goalName,
  });

  final AppStore store;
  final ScrollController controller;

  /// The goal's current name — shown in quotes under the New-account row (§2b),
  /// omitted while empty.
  final String goalName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final incomeCategories = store.categoriesOfType(CategoryType.income);
    // One flat list in the app's account order — no per-group labels (§2b).
    final accounts = [
      for (final group in AccountGroup.values) ...store.accountsIn(group),
    ];
    final empty = accounts.isEmpty && incomeCategories.isEmpty;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        // 1 · New savings account, named from the goal (§2b).
        _SourceTile(
          icon: Icons.add_rounded,
          color: AppColors.accent,
          title: l.goalNewAccountOption,
          subtitle: goalName.isEmpty ? null : l.goalNewAccountFor(goalName),
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
        // 2 · Every account, one ACCOUNTS section (§2b/§D.6).
        if (accounts.isNotEmpty) ...[
          SectionLabelSmall(l.goalSourceAccounts),
          for (final a in accounts)
            _SourceTile(
              icon: a.displayIcon,
              color: a.color,
              title: a.name,
              subtitle: formatAmount(store.balanceOf(a.id), a.currency,
                  kind: AmountKind.magnitude),
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
