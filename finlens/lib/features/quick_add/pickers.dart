import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// Shell shared by every picker and create sheet: a drag handle, a title bar
/// and a scrollable body that never exceeds 88% of the screen.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, ScrollController) builder,
  double initialSize = 0.7,
  List<Widget> actions = const [],
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: Insets.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.lg,
              Insets.gutter,
              Insets.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: AppText.title.copyWith(fontSize: 19)),
                ),
                ...actions,
              ],
            ),
          ),
          Expanded(child: builder(context, controller)),
        ],
      ),
    ),
  );
}

/// Spec 4.2 — account picker. The "＋ New account" row lives at the *end of the
/// list*, appearing exactly when the search turns up nothing.
Future<Account?> pickAccount(
  BuildContext context, {
  String title = 'Select account',
  bool Function(Account)? filter,
  String? excludeId,
}) {
  return showAppSheet<Account>(
    context,
    title: title,
    builder: (context, controller) => _AccountPickerBody(
      controller: controller,
      filter: filter,
      excludeId: excludeId,
    ),
  );
}

class _AccountPickerBody extends StatefulWidget {
  const _AccountPickerBody({
    required this.controller,
    this.filter,
    this.excludeId,
  });

  final ScrollController controller;
  final bool Function(Account)? filter;
  final String? excludeId;

  @override
  State<_AccountPickerBody> createState() => _AccountPickerBodyState();
}

class _AccountPickerBodyState extends State<_AccountPickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final all = store.visibleAccounts
        .where((a) => a.id != widget.excludeId)
        .where((a) => widget.filter?.call(a) ?? true)
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();

    final grouped = <AccountGroup, List<Account>>{};
    for (final a in all) {
      grouped.putIfAbsent(a.group, () => []).add(a);
    }

    return Column(
      children: [
        _SearchBar(
          hint: 'Search accounts',
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.sm,
              Insets.gutter,
              Insets.xxl,
            ),
            children: [
              if (all.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Text(
                    'No account matches "$_query".',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, Insets.md, 4, Insets.sm),
                  child: Text(entry.key.label.toUpperCase(), style: AppText.label),
                ),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _pickRow(
                          context,
                          icon: entry.value[i].displayIcon,
                          color: entry.value[i].color,
                          title: entry.value[i].name,
                          // Spec 3.2 — the current balance is previewed on the
                          // right so the user picks with context.
                          trailing: AmountText(
                            store.balanceOf(entry.value[i].id),
                            currency: entry.value[i].currency,
                            style: AppText.amount.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(entry.value[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              _CreateRow(
                label: 'New account',
                onTap: () async {
                  final created = await showNewAccountSheet(
                    context,
                    initialName: _query,
                  );
                  if (created != null && context.mounted) {
                    Navigator.of(context).pop(created);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Spec 4.1 — category picker with the same contextual-create tail.
Future<Category?> pickCategory(
  BuildContext context, {
  required CategoryType type,
  String? title,
}) {
  return showAppSheet<Category>(
    context,
    title: title ??
        (type == CategoryType.expense
            ? 'Expense category'
            : 'Income category'),
    builder: (context, controller) =>
        _CategoryPickerBody(controller: controller, type: type),
  );
}

class _CategoryPickerBody extends StatefulWidget {
  const _CategoryPickerBody({required this.controller, required this.type});

  final ScrollController controller;
  final CategoryType type;

  @override
  State<_CategoryPickerBody> createState() => _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends State<_CategoryPickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.trim().toLowerCase();
    final items = store
        .categoriesOfType(widget.type)
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        _SearchBar(
          hint: 'Search categories',
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.md,
              Insets.gutter,
              Insets.xxl,
            ),
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                  child: Text(
                    'No category matches "$_query".',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              if (items.isNotEmpty)
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const RowDivider(indent: Insets.md),
                        _pickRow(
                          context,
                          icon: items[i].icon,
                          color: items[i].color,
                          title: items[i].name,
                          // Spec 3.2/3.3 — spent-of-budget for expenses,
                          // yearly total for income.
                          trailing: _categoryPreview(store, items[i]),
                          onTap: () => Navigator.of(context).pop(items[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: Insets.md),
              _CreateRow(
                label: 'New category',
                onTap: () async {
                  final created = await showNewCategorySheet(
                    context,
                    type: widget.type,
                    initialName: _query,
                  );
                  if (created != null && context.mounted) {
                    Navigator.of(context).pop(created);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryPreview(AppStore store, Category c) {
    if (widget.type == CategoryType.income) {
      final yearly = store.earnedInCategory(c.id, store.period) * 12;
      return Text(
        '${moneyCompact(yearly)}/yr',
        style: AppText.amount.copyWith(color: AppColors.textSecondary),
      );
    }
    final spent = store.spentInCategory(c.id, store.period);
    final limit = c.effectiveLimit;
    return Text(
      limit == null
          ? money(spent)
          : '${money(spent)} / ${money(limit)}',
      style: AppText.amount.copyWith(
        color: limit != null && spent > limit
            ? AppColors.negative
            : AppColors.textSecondary,
      ),
    );
  }
}

Widget _pickRow(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  Widget? trailing,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          IconTile(icon, color: color, size: 32),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              title,
              style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// The contextual-create tail row (spec 4 — "the last row of the picker").
class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.tint(AppColors.accent, 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              const IconTile(
                Icons.add_rounded,
                color: AppColors.accentSoft,
                size: 32,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  label,
                  style: AppText.rowTitle.copyWith(color: AppColors.accentSoft),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.accentSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                style: AppText.body,
                cursorColor: AppColors.accentSoft,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contextual create: New Category (spec 4.1) ──────────────────────────────

const _categoryIcons = <IconData>[
  Icons.shopping_basket_rounded,
  Icons.home_rounded,
  Icons.play_circle_rounded,
  Icons.local_shipping_rounded,
  Icons.shopping_bag_rounded,
  Icons.self_improvement_rounded,
  Icons.local_cafe_rounded,
  Icons.favorite_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.flight_rounded,
  Icons.subscriptions_rounded,
];

Future<Category?> showNewCategorySheet(
  BuildContext context, {
  required CategoryType type,
  String initialName = '',
}) {
  return showAppSheet<Category>(
    context,
    title: 'New category',
    initialSize: 0.85,
    builder: (context, controller) => _NewCategoryForm(
      controller: controller,
      type: type,
      initialName: initialName,
    ),
  );
}

class _NewCategoryForm extends StatefulWidget {
  const _NewCategoryForm({
    required this.controller,
    required this.type,
    required this.initialName,
  });

  final ScrollController controller;
  final CategoryType type;
  final String initialName;

  @override
  State<_NewCategoryForm> createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<_NewCategoryForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final _budget = TextEditingController();
  IconData _icon = _categoryIcons.first;
  Color _color = AppColors.categoryPalette.first;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: Insets.lg),
            children: [
              FormSection(
                children: [
                  TextFieldRow(
                    icon: Icons.label_rounded,
                    label: 'Category name',
                    controller: _name,
                    hint: 'e.g. Groceries',
                    autofocus: widget.initialName.isEmpty,
                  ),
                ],
              ),
              const SectionLabelSmall('Icon'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: AppCard(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Wrap(
                    spacing: Insets.md,
                    runSpacing: Insets.md,
                    children: [
                      for (final icon in _categoryIcons)
                        GestureDetector(
                          onTap: () => setState(() => _icon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: icon == _icon
                                  ? AppColors.tint(_color, 0.22)
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: icon == _icon
                                  ? Border.all(color: _color, width: 1.5)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              size: 20,
                              color: icon == _icon
                                  ? _color
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SectionLabelSmall('Colour'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: AppCard(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final c in AppColors.categoryPalette)
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: c == _color
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: c == _color
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              if (widget.type == CategoryType.expense)
                FormSection(
                  children: [
                    TextFieldRow(
                      icon: Icons.attach_money_rounded,
                      label: 'Monthly budget (optional)',
                      controller: _budget,
                      hint: '0',
                    ),
                  ],
                ),
              const InfoNote(
                'This category will also appear in Planner → Expense Budget, '
                'because the budget is a field on the category itself.',
              ),
            ],
          ),
        ),
        _SheetFooter(
          label: 'Create & select',
          enabled: _valid,
          onPressed: () {
            final created = store.addCategory(
              name: _name.text.trim(),
              type: widget.type,
              icon: _icon,
              color: _color,
              monthlyBudget: double.tryParse(_budget.text.trim()),
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }
}

// ── Contextual create: New Account (spec 4.2) ───────────────────────────────

Future<Account?> showNewAccountSheet(
  BuildContext context, {
  AccountGroup? group,
  String initialName = '',
}) {
  return showAppSheet<Account>(
    context,
    title: 'New account',
    initialSize: 0.85,
    builder: (context, controller) => _NewAccountForm(
      controller: controller,
      group: group ?? AccountGroup.spendable,
      initialName: initialName,
    ),
  );
}

class _NewAccountForm extends StatefulWidget {
  const _NewAccountForm({
    required this.controller,
    required this.group,
    required this.initialName,
  });

  final ScrollController controller;
  final AccountGroup group;
  final String initialName;

  @override
  State<_NewAccountForm> createState() => _NewAccountFormState();
}

class _NewAccountFormState extends State<_NewAccountForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final _starting = TextEditingController();
  final _limit = TextEditingController();
  late AccountGroup _group = widget.group;
  String _currency = 'USD';
  bool _countAsSpendable = true;

  @override
  void dispose() {
    _name.dispose();
    _starting.dispose();
    _limit.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _starting.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final starting = double.tryParse(_starting.text.trim()) ?? 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: Insets.lg),
            children: [
              FormSection(
                children: [
                  TextFieldRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Account name',
                    controller: _name,
                    hint: 'e.g. Main Checking',
                    autofocus: widget.initialName.isEmpty,
                  ),
                ],
              ),
              const SectionLabelSmall('Group'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final g in AccountGroup.values)
                      GestureDetector(
                        onTap: () => setState(() => _group = g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md,
                            vertical: Insets.sm,
                          ),
                          decoration: BoxDecoration(
                            color: g == _group
                                ? AppColors.tint(g.color, 0.22)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            border: Border.all(
                              color: g == _group
                                  ? g.color
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(g.icon, size: 15, color: g.color),
                              const SizedBox(width: 6),
                              Text(
                                g.label,
                                style: AppText.caption.copyWith(
                                  fontSize: 12.5,
                                  color: g == _group
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              FormSection(
                children: [
                  FormRow(
                    icon: Icons.language_rounded,
                    label: 'Currency',
                    value: _currency,
                    showChevron: true,
                    onTap: () async {
                      final picked = await pickCurrency(context, _currency);
                      if (picked != null) setState(() => _currency = picked);
                    },
                  ),
                  TextFieldRow(
                    icon: Icons.savings_rounded,
                    label: 'Starting balance',
                    controller: _starting,
                    hint: '0',
                    trailing: Text(
                      currencySymbol(_currency),
                      style: AppText.amount.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_group.hasCreditLimit)
                    TextFieldRow(
                      icon: Icons.speed_rounded,
                      label: 'Credit limit',
                      controller: _limit,
                      hint: '0',
                    ),
                  // Spec 4.2 — group-specific toggle.
                  if (_group == AccountGroup.spendable)
                    ToggleRow(
                      icon: Icons.bolt_rounded,
                      label: 'Count toward money I can spend now',
                      value: _countAsSpendable,
                      onChanged: (v) => setState(() => _countAsSpendable = v),
                    ),
                ],
              ),
              const InfoNote(
                'Enter this once. From now on the balance is calculated from '
                'your transactions.',
              ),
              if (starting > 0)
                InfoNote(
                  'Adds ${money(starting, currency: _currency)} to Balance → '
                  '${_group.label} as an opening-balance entry.',
                ),
            ],
          ),
        ),
        _SheetFooter(
          label: 'Create & select',
          enabled: _valid,
          onPressed: () {
            final created = store.addAccount(
              name: _name.text.trim(),
              group: _group,
              currency: _currency,
              startingBalance: starting,
              creditLimit: double.tryParse(_limit.text.trim()),
              countAsSpendable: _countAsSpendable,
            );
            Navigator.of(context).pop(created);
          },
        ),
      ],
    );
  }
}

Future<String?> pickCurrency(BuildContext context, String current) {
  const codes = ['USD', 'EUR', 'TRY', 'GBP', 'JPY'];
  return showAppSheet<String>(
    context,
    title: 'Currency',
    initialSize: 0.5,
    builder: (context, controller) => ListView(
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
              for (var i = 0; i < codes.length; i++) ...[
                if (i > 0) const RowDivider(indent: Insets.md),
                FormRow(
                  label: '${codes[i]}  ${currencySymbol(codes[i])}',
                  onTap: () => Navigator.of(context).pop(codes[i]),
                  trailing: codes[i] == current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.accentSoft,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Small uppercase label used inside sheets.
class SectionLabelSmall extends StatelessWidget {
  const SectionLabelSmall(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + Insets.xs,
        Insets.sm,
        Insets.gutter,
        Insets.sm,
      ),
      child: Text(text.toUpperCase(), style: AppText.label),
    );
  }
}

/// Sticky primary action at the bottom of a sheet.
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.gutter,
        Insets.md,
        Insets.gutter,
        Insets.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceHigh,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppText.button,
        ),
        child: Text(label),
      ),
    );
  }
}
