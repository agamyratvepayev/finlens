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

class _EditGoalScreenState extends State<EditGoalScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Goal? _goal =
      widget.goalId == null ? null : _store.goalById(widget.goalId);

  late final TextEditingController _name =
      TextEditingController(text: _goal?.name ?? '');
  late final TextEditingController _target = TextEditingController(
    text: _goal?.targetAmount.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _note =
      TextEditingController(text: _goal?.note ?? '');

  // Source selection (create only — locked on edit).
  bool _createNewAccount = false;
  late GoalSource? _source = _goal?.source;

  late DateTime? _targetDate = _goal?.targetDate;
  late bool _endsWhenReached = _goal?.endsWhenReached ?? true;

  bool get _isEditing => _goal != null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _targetValue => double.tryParse(_target.text.trim()) ?? 0;

  bool get _hasSource => _isEditing || _createNewAccount || _source != null;

  /// The source's balance at creation — a goal watching an existing account
  /// starts from where that account already stands (§1). A new account and an
  /// income category start from zero.
  double get _startAmount {
    if (_createNewAccount) return 0;
    final s = _isEditing ? _goal!.source : _source;
    if (s == null || s.isCategory) return 0;
    return _store.balanceOnInBase(s.id, AppStore.today);
  }

  /// The monthly figure the target date implies (§3). Null until a date is set.
  double? get _perMonth {
    if (_targetDate == null) return null;
    final months = (_targetDate!.year - AppStore.today.year) * 12 +
        (_targetDate!.month - AppStore.today.month);
    final gap = (_targetValue - _startAmount).abs();
    if (months <= 0) return gap;
    return gap / months;
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _targetValue > 0 &&
      _hasSource &&
      // Target and date are a pair; a normal goal needs one. A refillable fund
      // (§4) may skip the date.
      (_targetDate != null || !_endsWhenReached);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return EditScaffold(
      title: _isEditing ? l.egTitle : l.goalNewTitle,
      onSave: _canSave ? _save : null,
      header: _isEditing ? _progressHeader(l) : null,
      children: [
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.flag_rounded,
              label: l.egGoalName,
              controller: _name,
              hint: l.qaExampleGoal,
              trailing: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),

        // ── WATCHING (§3) ──
        SectionLabelSmall(l.goalWatching),
        FormSection(
          children: [
            FormRow(
              icon: Icons.visibility_rounded,
              label: l.goalSource,
              value: _sourceLabel(l),
              subtitle: _isEditing ? l.goalSourceLocked : null,
              showChevron: !_isEditing,
              // Locked after creation — greyed, non-tappable (§3).
              enabled: !_isEditing,
              locked: _isEditing,
              onTap: _isEditing ? null : _pickSource,
            ),
          ],
        ),
        if (!_isEditing && _twoGoalsWarning(l) != null)
          NoticeBanner(text: _twoGoalsWarning(l)!),

        // ── Target + date pair (§3) ──
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.attach_money_rounded,
              label: l.egTargetAmount,
              controller: _target,
              hint: '0',
            ),
            FormRow(
              icon: Icons.event_rounded,
              label: l.egTargetDate,
              value: _targetDate == null
                  ? l.eaNotSet
                  : monthYear(_targetDate!, l),
              subtitle: _perMonth == null
                  ? l.goalSetDateHint
                  : l.goalPerMonth(money(_perMonth!)),
              showChevron: true,
              onTap: _pickTargetDate,
            ),
            // Tap the monthly figure to enter the rate instead; the form then
            // computes the date (§3). Either input satisfies the pair.
            FormRow(
              icon: Icons.speed_rounded,
              label: l.goalMonthly,
              value: _perMonth == null ? l.goalEnterRate : money(_perMonth!),
              showChevron: true,
              onTap: _promptMonthly,
            ),
          ],
        ),

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

  String _sourceLabel(AppLocalizations l) {
    if (_isEditing) return _store.refName(_goal!.source.id);
    if (_createNewAccount) {
      return l.goalNewAccountNamed(
        _name.text.trim().isEmpty ? l.goalUntitled : _name.text.trim(),
      );
    }
    final s = _source;
    if (s == null) return l.goalChooseSource;
    return _store.refName(s.id);
  }

  /// Two goals may watch one account — the user might be tracking two
  /// milestones on one pot. Warn at creation, never block (§9).
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
        // A liability or a receivable falls to zero — default its target to $0.
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
  }

  // ── Target date / rate ─────────────────────────────────────────────────────

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(AppStore.today.year + 1),
      firstDate: AppStore.today,
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _promptMonthly() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: _perMonth == null ? '' : _perMonth!.toStringAsFixed(0),
    );
    final rate = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: Text(l.goalMonthlyPromptTitle, style: AppText.rowTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: '0', prefixText: r'$ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(double.tryParse(controller.text.trim())),
            child: Text(l.actionDone),
          ),
        ],
      ),
    );
    controller.dispose();
    if (rate == null || rate <= 0 || !mounted) return;
    // date = created + ⌈gap / rate⌉ months.
    final gap = (_targetValue - _startAmount).abs();
    final months = (gap / rate).ceil().clamp(1, 1200);
    setState(() => _targetDate = DateTime(
          AppStore.today.year,
          AppStore.today.month + months,
          AppStore.today.day,
        ));
  }

  // ── Save / delete ──────────────────────────────────────────────────────────

  void _save() {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final note = _note.text.trim();

    if (_isEditing) {
      _store.updateGoal(
        _goal!,
        name: name,
        targetAmount: _targetValue,
        targetDate: _targetDate,
        clearTargetDate: _targetDate == null,
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
      targetDate: _targetDate,
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
/// the account pickers group them, then income categories.
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.store, required this.controller});

  final AppStore store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final incomeCategories = store.categoriesOfType(CategoryType.income);

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
          onTap: () =>
              Navigator.of(context).pop(const _SourceChoice.newAccount()),
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
                subtitle: money(store.balanceOf(a.id).abs()),
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
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                title,
                style: AppText.rowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: Insets.sm),
              Text(subtitle!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
