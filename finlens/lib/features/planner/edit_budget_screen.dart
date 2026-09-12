import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'edit_scaffold.dart';
import 'widgets/percent_input_formatter.dart';

/// Spec 5.4 — the category is locked; the limit is the only truly editable
/// field, flanked by three months of actuals to base it on.
class EditBudgetScreen extends StatefulWidget {
  const EditBudgetScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Category _category = _store.categoryById(widget.categoryId)!;

  late final TextEditingController _limit = TextEditingController(
    text: (_store.monthlyLimitOf(_category) ?? 0).toStringAsFixed(0),
  );
  late bool _rollover = _store.rolloverOf(_category);
  late double _warn = _store.warnThresholdOf(_category);

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double get _limitValue => double.tryParse(_limit.text.trim()) ?? 0;

  /// Spec 5.4 — the last three months of actual spend, and a limit suggested
  /// from their average. Budgets usually fail because the limit was a guess.
  List<(DateTime, double)> get _history {
    final out = <(DateTime, double)>[];
    for (var i = 0; i < 3; i++) {
      final month = DateTime(_store.period.year, _store.period.month - i);
      out.add((month, _store.spentInCategory(_category.id, month)));
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
    final spent = store.spentInCategory(_category.id, store.period);

    return EditScaffold(
      title: l.ebTitle,
      onSave: _limitValue > 0 ? _save : null,
      children: [
        FormSection(
          children: [
            // Spec 5.4 — changing the category would mean a different budget.
            FormRow(
              icon: _category.icon,
              label: _category.name,
              subtitle: l.fieldCategory,
              locked: true,
            ),
            TextFieldRow(
              icon: Icons.attach_money_rounded,
              label: l.ebMonthlyLimit,
              controller: _limit,
              hint: '0',
              trailing: Text(
                // The limit is a base-currency figure by design (see the note
                // above Budget.limit): spend is summed through Fx.toBase, so the
                // marker names the base, not a fixed dollar.
                currencySymbol(store.baseCurrency),
                style: AppText.amount.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ToggleRow(
              icon: Icons.repeat_rounded,
              label: l.ebRollOver,
              subtitle: l.ebRollOverDesc,
              value: _rollover,
              onChanged: (v) => setState(() => _rollover = v),
            ),
            FormRow(
              icon: Icons.notifications_active_rounded,
              label: l.ebWarnAt,
              subtitle: '${money(_limitValue * _warn)} ${l.ebSpent}',
              value: percent(_warn, decimals: 0),
              showChevron: true,
              // _pickThreshold raises a bottom sheet.
              opensSheet: true,
              onTap: _pickThreshold,
            ),
          ],
        ),
        _historyCard(spent),
        DestructiveRow(
            label: l.ebRemoveBudget, onTap: _confirmRemove, opensSheet: true),
      ],
    );
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
                            // Rounded: the point is a graspable figure to
                            // base a limit on, not accounting precision.
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

  Future<void> _pickThreshold() async {
    // isScrollControlled so the custom row can lift clear of the keyboard
    // instead of being pushed under it (spec §4, rotate/resize case).
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

  void _save() {
    _store.updateBudget(
      _category,
      monthlyBudget: _limitValue,
      rollover: _rollover,
      warnThreshold: _warn,
    );
    Navigator.of(context).pop();
  }

  /// Spec 5.5 — the critical distinction: a budget is not a category.
  Future<void> _confirmRemove() async {
    final count = _store.txnCountForCategory(_category.id);
    final newTotal = _store.totalBudget - (_store.effectiveLimitOf(_category) ?? 0);

    final l = AppLocalizations.of(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.ebRemoveTitle(_category.name),
      message: l.ebRemoveMsg,
      impact: [
        ImpactLine.kept(l.ebCategoryStays(_category.name, count)),
        ImpactLine.lost(l.ebWarningsDisappear),
        ImpactLine.lost(l.ebTotalDrops(
            money(_store.totalBudget), money(newTotal))),
      ],
      confirmLabel: l.ebRemoveBudget,
    );

    if (!ok || !mounted) return;
    _store.removeBudget(_category);
    Navigator.of(context).pop();
  }
}

/// The five preset thresholds. Task 22 widens the picker with a sixth, custom
/// row; the presets themselves — values, order, formatting — are untouched.
const _warnPresets = [0.5, 0.7, 0.8, 0.9, 1.0];

/// Spec (task 22) — the warn-threshold picker: five presets plus a Custom row.
/// The bound is 1–100 because the warning only fires while the budget is *not*
/// yet over (`!over &&` in all three consumers), so a threshold above 100%
/// could never fire and 0% would fire the instant a budget exists.
///
/// The selection lives here as a fraction; `onChanged` commits it to the parent
/// live (as tapping a preset always did), so the budget's main Save writes it.
class _WarnThresholdSheet extends StatefulWidget {
  const _WarnThresholdSheet({required this.initial, required this.onChanged});

  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<_WarnThresholdSheet> createState() => _WarnThresholdSheetState();
}

class _WarnThresholdSheetState extends State<_WarnThresholdSheet> {
  // Seeded with the current value only when it is *not* one of the five, so a
  // stored 73% opens visible against the Custom row instead of no mark at all.
  late final TextEditingController _custom = TextEditingController(
    text: _isPreset(widget.initial) ? '' : _pct(widget.initial).toString(),
  );

  // The live selection, in fraction form. Null only when the field has been
  // emptied and the stored value was itself custom — i.e. no row left to mark.
  late double? _selected = widget.initial;

  static int _pct(double v) => (v * 100).round();
  static bool _isPreset(double v) => _warnPresets.any((p) => _pct(p) == _pct(v));

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _pickPreset(double t) {
    // Clear the field so a stale number never sits beside a mark that has moved
    // to a preset (spec §1e). controller.clear() bypasses the formatter, so no
    // spurious haptic fires.
    _custom.clear();
    setState(() => _selected = t);
    widget.onChanged(t);
  }

  void _onCustomChanged(String text) {
    if (text.isEmpty) {
      // Emptied: return to the stored preset, or to no mark. Never commit a
      // null or a zero (spec §4).
      setState(() {
        _selected = _isPreset(widget.initial) ? widget.initial : null;
      });
      if (_selected != null) widget.onChanged(_selected!);
      return;
    }
    // The formatter guarantees a 1..100 integer here.
    final v = int.parse(text) / 100;
    setState(() => _selected = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedPct = _selected == null ? null : _pct(_selected!);
    // A typed preset marks the preset, not Custom (spec §1e): Custom is marked
    // only while the live value is not one of the five.
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
            // Label the field and let the 1–100 helper be announced, not left
            // as mute decoration (spec §4, screen-reader case).
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
          // Reserve the mark's width whether or not it shows, so the field
          // doesn't shift when the mark arrives or leaves.
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

  // A rejected keystroke gets a light bump — a physical "you hit the wall",
  // paired with the visible 1–100 hint so the rule reads as well as feels
  // (spec §1c). lightImpact, matching swipe_actions.dart; no third weight.
  void _onReject() => HapticFeedback.lightImpact();
}
