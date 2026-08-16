import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import 'edit_scaffold.dart';

/// Spec 5.6 — progress on top, three separate exits at the bottom.
///
/// "Reached", "gave up" and "created by mistake" are genuinely different
/// states: the saved money ends up somewhere different in each, and collapsing
/// them into one Delete button would corrupt the goal-success metric.
class EditGoalScreen extends StatefulWidget {
  const EditGoalScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Goal _goal = _store.goalById(widget.goalId)!;

  late final TextEditingController _name =
      TextEditingController(text: _goal.name);
  late final TextEditingController _target = TextEditingController(
    text: _goal.targetAmount.toStringAsFixed(0),
  );
  late final TextEditingController _contribution = TextEditingController(
    text: (_goal.autoContributeAmount ?? 50).toStringAsFixed(0),
  );

  late GoalType _type = _goal.type;
  late DateTime? _targetDate = _goal.targetDate;
  late String _linkedAccountId = _goal.linkedAccountId;
  late bool _autoContribute = _goal.autoContribute;
  late final int _contributeDay = _goal.autoContributeDay;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _contribution.dispose();
    super.dispose();
  }

  double get _targetValue => double.tryParse(_target.text.trim()) ?? 0;

  int get _monthsLeft => _targetDate == null
      ? 0
      : (_targetDate!.year - AppStore.today.year) * 12 +
          (_targetDate!.month - AppStore.today.month);

  double? get _perMonth {
    if (_targetDate == null || _monthsLeft <= 0) return null;
    return ((_targetValue - _goal.saved) / _monthsLeft).clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final linked = store.accountById(_linkedAccountId);

    return EditScaffold(
      title: 'Edit goal',
      onSave: _name.text.trim().isNotEmpty && _targetValue > 0 ? _save : null,
      header: _progressHeader(),
      children: [
        FormSection(
          children: [
            TextFieldRow(
              icon: _goal.icon,
              label: 'Goal name',
              controller: _name,
              trailing: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SectionLabelSmall('Type'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            0,
            Insets.gutter,
            Insets.lg,
          ),
          child: SegmentedPicker<GoalType>(
            values: GoalType.values,
            labelOf: (t) => t.label,
            selected: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
        ),
        FormSection(
          children: [
            TextFieldRow(
              icon: Icons.attach_money_rounded,
              label: 'Target amount',
              controller: _target,
              hint: '0',
            ),
            FormRow(
              icon: Icons.event_rounded,
              label: 'Target date',
              // Spec 5.6 — the monthly figure recalculates the moment either
              // the amount or the date changes.
              subtitle: _perMonth == null
                  ? 'No target date set'
                  : '${money(_perMonth!)}/mo to stay on track',
              value: _targetDate == null ? 'Not set' : monthYear(_targetDate!),
              showChevron: true,
              onTap: _pickTargetDate,
            ),
            FormRow(
              icon: Icons.savings_rounded,
              label: 'Money kept in',
              subtitle: linked?.name ?? 'Select account',
              showChevron: true,
              onTap: () async {
                final a = await pickAccount(
                  context,
                  title: 'Money kept in',
                  filter: (a) => a.isAsset,
                );
                if (a != null) setState(() => _linkedAccountId = a.id);
              },
            ),
            ToggleRow(
              icon: Icons.repeat_rounded,
              label: 'Auto contribute',
              subtitle: _autoContribute
                  ? '${money(double.tryParse(_contribution.text) ?? 0)} '
                      'on the ${ordinal(_contributeDay)}'
                  : 'Creates a monthly transfer into this goal',
              value: _autoContribute,
              onChanged: (v) => setState(() => _autoContribute = v),
            ),
            if (_autoContribute)
              TextFieldRow(
                icon: Icons.attach_money_rounded,
                label: 'Monthly contribution',
                controller: _contribution,
                hint: '0',
              ),
          ],
        ),
        // ── The three exits (spec 5.6) ──
        FormSection(
          children: [
            FormRow(
              icon: Icons.flag_rounded,
              label: 'Mark as reached',
              subtitle: 'Money is spent, goal is done',
              showChevron: true,
              onTap: _markReached,
            ),
            FormRow(
              icon: Icons.pause_circle_rounded,
              label: 'Give up for now',
              subtitle: 'Keeps the ${money(_goal.saved)}, stops tracking',
              showChevron: true,
              onTap: _giveUp,
            ),
          ],
        ),
        DestructiveRow(
          label: 'Delete goal',
          subtitle: 'As if it never existed',
          onTap: _delete,
        ),
      ],
    );
  }

  Widget _progressHeader() {
    final remaining = (_targetValue - _goal.saved).clamp(0, double.infinity);
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
            children: [
              AmountText(
                _goal.saved,
                style: AppText.amountLarge.copyWith(fontSize: 18),
                color: AppColors.positive,
              ),
              Text(' saved', style: AppText.caption),
              const Spacer(),
              AmountText(
                remaining.toDouble(),
                style: AppText.amountLarge.copyWith(fontSize: 18),
              ),
              Text(' to go', style: AppText.caption),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ProgressBar(
            value: _targetValue <= 0 ? 0 : _goal.saved / _targetValue,
            color: AppColors.goal,
            height: 7,
          ),
        ],
      ),
    );
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(AppStore.today.year + 1),
      firstDate: AppStore.today,
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _save() {
    _store.updateGoal(
      _goal,
      name: _name.text.trim(),
      type: _type,
      targetAmount: _targetValue,
      targetDate: _targetDate,
      linkedAccountId: _linkedAccountId,
      autoContribute: _autoContribute,
      autoContributeAmount: double.tryParse(_contribution.text.trim()),
      autoContributeDay: _contributeDay,
    );
    Navigator.of(context).pop();
  }

  Future<void> _markReached() async {
    final ok = await showDestructiveConfirm(
      context,
      title: 'Mark ${_goal.name} as reached?',
      message: 'Congratulations — this moves the goal into your archive as a '
          'success.',
      impact: [
        ImpactLine.kept(
          'Recorded as reached after ${_goal.durationMonths ?? _monthsSinceCreated} '
          'months, feeding your goal-performance stats.',
        ),
        const ImpactLine.kept('Past transactions stay in your Ledger.'),
        const ImpactLine.lost('It leaves the Goals list and stops tracking.'),
        if (_goal.autoContribute)
          const ImpactLine.lost('The monthly auto-contribution stops.'),
      ],
      confirmLabel: 'Mark as reached',
      cancelLabel: 'Not yet',
    );
    if (!ok || !mounted) return;
    _store.markGoalReached(_goal);
    Navigator.of(context).pop();
  }

  int get _monthsSinceCreated =>
      (AppStore.today.year - _goal.createdAt.year) * 12 +
      (AppStore.today.month - _goal.createdAt.month);

  Future<void> _giveUp() async {
    final ok = await showDestructiveConfirm(
      context,
      title: 'Give up on ${_goal.name}?',
      message: 'Tracking stops, but the money you already put aside stays '
          'exactly where it is.',
      impact: [
        ImpactLine.kept(
          'The ${money(_goal.saved)} stays in '
          '${_store.accountById(_linkedAccountId)?.name ?? 'your account'}.',
        ),
        const ImpactLine.kept('You can restore it later from the Archive.'),
        const ImpactLine.lost('It leaves the Goals list.'),
        if (_goal.autoContribute)
          const ImpactLine.lost('The monthly auto-contribution stops.'),
      ],
      confirmLabel: 'Give up for now',
    );
    if (!ok || !mounted) return;
    _store.abandonGoal(_goal);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDestructiveConfirm(
      context,
      title: 'Delete ${_goal.name}?',
      message: 'Use this only when the goal was created by mistake — it leaves '
          'no trace in your history.',
      impact: [
        const ImpactLine.kept('Your account balances do not change.'),
        const ImpactLine.lost('It will not appear in the Archive.'),
        const ImpactLine.lost('It is excluded from goal-performance stats.'),
        if (_goal.autoContribute)
          const ImpactLine.lost('The recurring transfer rule is cancelled.'),
      ],
      confirmLabel: 'Delete goal',
    );
    if (!ok || !mounted) return;
    _store.deleteGoal(_goal);
    Navigator.of(context).pop();
  }
}
