import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/txn_row.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;
import '../quick_add/pickers.dart';
import '../quick_add/quick_add_sheet.dart';
import 'transfer_detail_screen.dart';

/// Spec 2.1 — every entry in chronological order, under a monthly
/// In / Out / Left over summary.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  TxnType? _filter;
  String? _accountFilter;
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final entries = _entries(store);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            title: 'Ledger',
            onAdd: () => showQuickAdd(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              children: [
                _MonthSummary(store: store),
                const SizedBox(height: Insets.md),
                _filterChips(store),
                if (_accountFilter != null || _categoryFilter != null)
                  _activeFilterBanner(store),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing here yet',
                      message: _filter == null
                          ? 'Entries you add will appear in this list.'
                          : 'No ${_filter!.label.toLowerCase()} entries this month.',
                      action: FilledButton.icon(
                        onPressed: () => showQuickAdd(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add an entry'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  ..._grouped(context, store, entries),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Txn> _entries(AppStore store) {
    return store.txnsInMonth(store.period).where((t) {
      if (_filter != null && t.type != _filter) return false;
      if (_accountFilter != null &&
          t.fromRef != _accountFilter &&
          t.toRef != _accountFilter) {
        return false;
      }
      if (_categoryFilter != null &&
          t.fromRef != _categoryFilter &&
          t.toRef != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Spec 2.1 — type chips narrow the list; the icon on the right opens the
  /// advanced filters (date range / account / category).
  Widget _filterChips(AppStore store) {
    final options = <(String, TxnType?)>[
      ('All', null),
      for (final t in TxnType.values) (t.label, t),
    ];

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: Insets.sm),
              itemBuilder: (context, i) {
                final (label, type) = options[i];
                final selected = _filter == type;
                final color = type?.color ?? AppColors.accentSoft;
                return GestureDetector(
                  onTap: () => setState(() => _filter = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.tint(color, 0.18)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: selected ? color : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 19),
            color: (_accountFilter ?? _categoryFilter) != null
                ? AppColors.accentSoft
                : AppColors.textSecondary,
            onPressed: () => _showAdvancedFilters(store),
          ),
        ],
      ),
    );
  }

  Widget _activeFilterBanner(AppStore store) {
    final label = _accountFilter != null
        ? store.refName(_accountFilter!)
        : store.refName(_categoryFilter!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        0,
      ),
      child: Row(
        children: [
          Chip(
            label: Text('Filtered: $label'),
            labelStyle: AppText.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
            backgroundColor: AppColors.tint(AppColors.accent, 0.18),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            onDeleted: () => setState(() {
              _accountFilter = null;
              _categoryFilter = null;
            }),
            deleteIconColor: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Future<void> _showAdvancedFilters(AppStore store) async {
    await showAppSheet<void>(
      context,
      title: 'Filters',
      initialSize: 0.5,
      builder: (sheetContext, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          0,
          Insets.gutter,
          Insets.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                FormRow(
                  icon: Icons.event_rounded,
                  label: 'Month',
                  value: monthYearLong(store.period),
                  showChevron: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickMonth(store);
                  },
                ),
                const RowDivider(indent: Insets.md),
                FormRow(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Account',
                  value: _accountFilter == null
                      ? 'Any'
                      : store.refName(_accountFilter!),
                  showChevron: true,
                  onTap: () async {
                    final a = await pickAccount(sheetContext);
                    if (a == null) return;
                    setState(() {
                      _accountFilter = a.id;
                      _categoryFilter = null;
                    });
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
                const RowDivider(indent: Insets.md),
                FormRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: _categoryFilter == null
                      ? 'Any'
                      : store.refName(_categoryFilter!),
                  showChevron: true,
                  onTap: () async {
                    final c = await pickCategory(
                      sheetContext,
                      type: CategoryType.expense,
                    );
                    if (c == null) return;
                    setState(() {
                      _categoryFilter = c.id;
                      _accountFilter = null;
                    });
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          TextButton(
            onPressed: () {
              setState(() {
                _accountFilter = null;
                _categoryFilter = null;
                _filter = null;
              });
              Navigator.of(sheetContext).pop();
            },
            child: const Text('Clear all filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(AppStore store) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: store.period,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) store.period = picked;
  }

  /// The day-group total. Unsigned like the scoped ledger's day total, with the
  /// direction named in words for assistive tech. NOTE: this figure renders in
  /// neutral grey (textTertiary), not the red/green the scoped ledger uses — so
  /// without a sign a negative total shows no visible negativity cue. Reported,
  /// not changed: colouring it would be outside this task's formatting-only
  /// scope. See §1's "neutral keeps its sign" caveat.
  Widget _dayTotal(AppStore store, List<Txn> txns) {
    final net = txns.fold<double>(0, (sum, t) {
      return switch (t.type) {
        TxnType.expense => sum - t.amount,
        TxnType.income => sum + t.amount,
        // Transfers and revaluations move nothing net (spec 6.2).
        _ => sum,
      };
    });
    return Semantics(
      label: '${net < 0 ? 'Net out' : 'Net in'}, '
          '${money(net, signless: true, masked: store.masked)}',
      excludeSemantics: true,
      child: AmountText(
        net,
        signless: true,
        style: AppText.label.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, AppStore store, List<Txn> entries) {
    final groups = <String, List<Txn>>{};
    for (final t in entries) {
      groups.putIfAbsent(dateGroupLabel(t.date).toUpperCase(), () => []).add(t);
    }

    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.lg,
            Insets.gutter,
            Insets.sm,
          ),
          child: Row(
            children: [
              Expanded(child: Text(entry.key, style: AppText.label)),
              _dayTotal(store, entry.value),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: AppCard(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  TxnRow(
                    txn: entry.value[i],
                    // A transfer has no category key and must never open the
                    // editor on a tap (spec §5): it opens its own read-only
                    // detail. Other row types keep their existing tap-to-edit.
                    onTap: () => entry.value[i].type == TxnType.transfer
                        ? Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TransferDetailScreen(
                                txnId: entry.value[i].id,
                                backLabel: 'Ledger',
                              ),
                            ),
                          )
                        : showQuickAdd(context, editing: entry.value[i]),
                    onEdit: () => showQuickAdd(context, editing: entry.value[i]),
                    onCopy: () => showQuickAdd(context, copyOf: entry.value[i]),
                    onDelete: () async {
                      final ok = await confirmDeleteTxn(context, entry.value[i]);
                      if (ok && context.mounted) {
                        store.deleteTxn(entry.value[i]);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

/// Spec 2.1 — In / Out / Left over, where Left over = (In − Out) / In.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final income = store.monthIncome(store.period);
    final expense = store.monthExpense(store.period);
    final leftOver = store.monthLeftOverFraction(store.period);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickMonth(context),
                    child: Row(
                      children: [
                        Text(
                          monthYearLong(store.period),
                          style: AppText.rowTitle.copyWith(fontSize: 16),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => store.shiftPeriod(-1),
                ),
                const SizedBox(width: Insets.xs),
                _StepButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => store.shiftPeriod(1),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                _Metric(label: 'In', value: income, color: AppColors.positive),
                _Metric(label: 'Out', value: expense, color: AppColors.negative),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Left over', style: AppText.label),
                      const SizedBox(height: 4),
                      Text(
                        income <= 0 ? '—' : percent(leftOver, decimals: 0),
                        style: AppText.amountLarge.copyWith(
                          fontSize: 18,
                          color: leftOver < 0
                              ? AppColors.negative
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: store.period,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) store.period = picked;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
              value,
              style: AppText.amountLarge.copyWith(fontSize: 18),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
