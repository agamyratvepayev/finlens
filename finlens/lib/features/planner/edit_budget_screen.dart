import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'edit_scaffold.dart';

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
    text: (_category.monthlyBudget ?? 0).toStringAsFixed(0),
  );
  late bool _rollover = _category.budgetRollover;
  late double _warn = _category.warnThreshold;

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
    final spent = store.spentInCategory(_category.id, store.period);

    return EditScaffold(
      title: 'Edit budget',
      onSave: _limitValue > 0 ? _save : null,
      children: [
        FormSection(
          children: [
            // Spec 5.4 — changing the category would mean a different budget.
            FormRow(
              icon: _category.icon,
              label: _category.name,
              subtitle: 'Category',
              locked: true,
            ),
            TextFieldRow(
              icon: Icons.attach_money_rounded,
              label: 'Monthly limit',
              controller: _limit,
              hint: '0',
              trailing: Text(
                currencySymbol('USD'),
                style: AppText.amount.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ToggleRow(
              icon: Icons.repeat_rounded,
              label: 'Roll over unspent',
              subtitle: 'Add leftovers to next month',
              value: _rollover,
              onChanged: (v) => setState(() => _rollover = v),
            ),
            FormRow(
              icon: Icons.notifications_active_rounded,
              label: 'Warn me at',
              subtitle: '${money(_limitValue * _warn)} spent',
              value: percent(_warn, decimals: 0),
              showChevron: true,
              onTap: _pickThreshold,
            ),
          ],
        ),
        _historyCard(spent),
        DestructiveRow(label: 'Remove budget', onTap: _confirmRemove),
      ],
    );
  }

  Widget _historyCard(double currentSpend) {
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
            child: Text('WHAT YOU ACTUALLY SPENT', style: AppText.label),
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
                            monthShort(month.month),
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
                            'You average ${money(_average.roundToDouble())}. '
                            'Try ${money(_suggestion)}?',
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
                          child: const Text('Use'),
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
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Insets.lg),
            const Text('Warn me at', style: AppText.rowTitle),
            const SizedBox(height: Insets.md),
            for (final t in const [0.5, 0.7, 0.8, 0.9, 1.0])
              ListTile(
                title: Text(percent(t, decimals: 0), style: AppText.body),
                trailing: t == _warn
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.accentSoft,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(t),
              ),
            const SizedBox(height: Insets.md),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _warn = picked);
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
    final newTotal = _store.totalBudget - (_category.effectiveLimit ?? 0);

    final ok = await showDestructiveConfirm(
      context,
      title: 'Remove ${_category.name} budget?',
      message: 'You\'ll stop tracking a limit for this category.',
      impact: [
        ImpactLine.kept(
          'The ${_category.name} category stays. Your $count '
          '${count == 1 ? 'transaction is' : 'transactions are'} untouched.',
        ),
        const ImpactLine.lost(
          'Warnings and progress bars for this category disappear.',
        ),
        ImpactLine.lost(
          'Total monthly budget drops from ${money(_store.totalBudget)} '
          'to ${money(newTotal)}.',
        ),
      ],
      confirmLabel: 'Remove budget',
    );

    if (!ok || !mounted) return;
    _store.removeBudget(_category);
    Navigator.of(context).pop();
  }
}
