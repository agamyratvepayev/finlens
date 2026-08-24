import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final linked = store.accountById(_linkedAccountId);

    return EditScaffold(
      title: l.egTitle,
      onSave: _name.text.trim().isNotEmpty && _targetValue > 0 ? _save : null,
      header: _progressHeader(),
      children: [
        FormSection(
          children: [
            TextFieldRow(
              icon: _goal.icon,
              label: l.egGoalName,
              controller: _name,
              trailing: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        SectionLabelSmall(l.egType),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            0,
            Insets.gutter,
            Insets.lg,
          ),
          child: SegmentedPicker<GoalType>(
            values: GoalType.values,
            labelOf: (t) => t.label(AppLocalizations.of(context)),
            selected: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
        ),
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
              // Spec 5.6 — the monthly figure recalculates the moment either
              // the amount or the date changes.
              subtitle: _perMonth == null
                  ? l.plNoTargetDate
                  : l.egPerMonthTrack(money(_perMonth!)),
              value: _targetDate == null
                  ? l.eaNotSet
                  : monthYear(_targetDate!, AppLocalizations.of(context)),
              showChevron: true,
              onTap: _pickTargetDate,
            ),
            FormRow(
              icon: Icons.savings_rounded,
              label: l.egMoneyKeptIn,
              subtitle: linked?.name ?? l.fieldSelectAccount,
              showChevron: true,
              onTap: () async {
                final a = await pickAccount(
                  context,
                  title: l.egMoneyKeptIn,
                  filter: (a) => a.isAsset,
                );
                if (a != null) setState(() => _linkedAccountId = a.id);
              },
            ),
            ToggleRow(
              icon: Icons.repeat_rounded,
              label: l.egAutoContribute,
              subtitle: _autoContribute
                  ? l.egAutoContributeOn(
                      money(double.tryParse(_contribution.text) ?? 0),
                      ordinalDay(_contributeDay, l))
                  : l.egAutoContributeDesc,
              value: _autoContribute,
              onChanged: (v) => setState(() => _autoContribute = v),
            ),
            if (_autoContribute)
              TextFieldRow(
                icon: Icons.attach_money_rounded,
                label: l.egMonthlyContribution,
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
              label: l.egMarkReached,
              subtitle: l.egMarkReachedDesc,
              showChevron: true,
              onTap: _markReached,
            ),
            FormRow(
              icon: Icons.pause_circle_rounded,
              label: l.egGiveUp,
              subtitle: l.egKeepsStops(money(_goal.saved)),
              showChevron: true,
              onTap: _giveUp,
            ),
          ],
        ),
        DestructiveRow(
          label: l.egDeleteGoal,
          subtitle: l.egDeleteGoalDesc,
          onTap: _delete,
        ),
      ],
    );
  }

  Widget _progressHeader() {
    final l = AppLocalizations.of(context);
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
              Text(' ${l.egSaved}', style: AppText.caption),
              const Spacer(),
              AmountText(
                remaining.toDouble(),
                style: AppText.amountLarge.copyWith(fontSize: 18),
              ),
              Text(' ${l.egToGo}', style: AppText.caption),
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
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.egMarkReachedTitle(_goal.name),
      message: l.egMarkReachedMsg,
      impact: [
        ImpactLine.kept(l.egReachedAfter(
            _goal.durationMonths ?? _monthsSinceCreated)),
        ImpactLine.kept(l.egPastTxnStay),
        ImpactLine.lost(l.egLeavesStops),
        if (_goal.autoContribute) ImpactLine.lost(l.egAutoStops),
      ],
      confirmLabel: l.egMarkReached,
      cancelLabel: l.egNotYet,
    );
    if (!ok || !mounted) return;
    _store.markGoalReached(_goal);
    Navigator.of(context).pop();
  }

  int get _monthsSinceCreated =>
      (AppStore.today.year - _goal.createdAt.year) * 12 +
      (AppStore.today.month - _goal.createdAt.month);

  Future<void> _giveUp() async {
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.egGiveUpTitle(_goal.name),
      message: l.egGiveUpMsg,
      impact: [
        ImpactLine.kept(l.egSavedStaysIn(
          money(_goal.saved),
          _store.accountById(_linkedAccountId)?.name ?? l.egYourAccount,
        )),
        ImpactLine.kept(l.egRestoreLater),
        ImpactLine.lost(l.egLeavesList),
        if (_goal.autoContribute) ImpactLine.lost(l.egAutoStops),
      ],
      confirmLabel: l.egGiveUp,
    );
    if (!ok || !mounted) return;
    _store.abandonGoal(_goal);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.egDeleteTitle(_goal.name),
      message: l.egDeleteMsg,
      impact: [
        ImpactLine.kept(l.egBalancesUnchanged),
        ImpactLine.lost(l.egNotInArchive),
        ImpactLine.lost(l.egExcludedStats),
        if (_goal.autoContribute) ImpactLine.lost(l.egRecurringCancelled),
      ],
      confirmLabel: l.egDeleteGoal,
    );
    if (!ok || !mounted) return;
    _store.deleteGoal(_goal);
    Navigator.of(context).pop();
  }
}
