import 'package:flutter/material.dart';

import '../../core/l10n/enum_labels.dart';
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
import '../quick_add/pickers.dart';

/// Spec 1.5 — identity & credit details on top, visibility & removal below.
class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({super.key, required this.accountId});

  final String accountId;

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late final AppStore _store = StoreScope.read(context);
  late final Account _account = _store.accountById(widget.accountId)!;

  late final TextEditingController _name =
      TextEditingController(text: _account.name);
  late final TextEditingController _limit = TextEditingController(
    text: _account.creditLimit == null
        ? ''
        : _account.creditLimit!.toStringAsFixed(0),
  );

  late AccountGroup _group = _account.group;
  late String _currency = _account.currency;
  late bool _hidden = _account.hidden;
  late int? _statementDay = _account.statementDay;
  late int? _paymentDue = _account.paymentDue;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.sm,
                Insets.sm,
                Insets.sm,
                Insets.sm,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Edit account', style: AppText.rowTitle),
                    ),
                  ),
                  TextButton(
                    onPressed: _name.text.trim().isEmpty ? null : _save,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSoft,
                      textStyle: AppText.button,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Insets.xxl),
                children: [
                  FormSection(
                    children: [
                      TextFieldRow(
                        icon: Icons.badge_rounded,
                        label: 'Name',
                        controller: _name,
                        trailing: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      FormRow(
                        icon: Icons.folder_rounded,
                        label: 'Group',
                        value: _group.label(AppLocalizations.of(context)),
                        showChevron: true,
                        onTap: _pickGroup,
                      ),
                      FormRow(
                        icon: Icons.language_rounded,
                        label: 'Currency',
                        value: _currency,
                        showChevron: true,
                        onTap: () async {
                          final c = await pickCurrency(context, _currency);
                          if (c != null) setState(() => _currency = c);
                        },
                      ),
                      // Spec 1.5 / 6.2 — ledger integrity: a past balance is
                      // never edited directly, only corrected by a transaction.
                      FormRow(
                        icon: Icons.lock_clock_rounded,
                        label: 'Starting balance',
                        subtitle:
                            'To fix the balance, add a transaction instead',
                        locked: true,
                        value: money(
                          _account.startingBalance,
                          currency: _currency,
                        ),
                      ),
                    ],
                  ),
                  // Conditional rows — credit fields only where they apply.
                  if (_group.hasCreditLimit || _group.hasStatement)
                    FormSection(
                      children: [
                        if (_group.hasCreditLimit)
                          TextFieldRow(
                            icon: Icons.speed_rounded,
                            label: 'Credit limit',
                            controller: _limit,
                            hint: '0',
                            trailing: Text(
                              currencySymbol(_currency),
                              style: AppText.amount.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (_group.hasStatement) ...[
                          FormRow(
                            icon: Icons.receipt_long_rounded,
                            label: 'Statement day',
                            value: _statementDay == null
                                ? 'Not set'
                                : ordinalDay(_statementDay!, AppLocalizations.of(context)),
                            showChevron: true,
                            onTap: () async {
                              final d = await _pickDay('Statement day');
                              if (d != null) setState(() => _statementDay = d);
                            },
                          ),
                          FormRow(
                            icon: Icons.event_available_rounded,
                            label: 'Payment due',
                            value: _paymentDue == null
                                ? 'Not set'
                                : ordinalDay(_paymentDue!, AppLocalizations.of(context)),
                            showChevron: true,
                            onTap: () async {
                              final d = await _pickDay('Payment due');
                              if (d != null) setState(() => _paymentDue = d);
                            },
                          ),
                        ],
                      ],
                    ),
                  FormSection(
                    children: [
                      ToggleRow(
                        icon: Icons.visibility_off_rounded,
                        label: 'Hide from Balance',
                        subtitle:
                            'Stays in your totals, disappears from the lists',
                        value: _hidden,
                        onChanged: (v) => setState(() => _hidden = v),
                      ),
                    ],
                  ),
                  DestructiveRow(
                    label: 'Remove this account',
                    subtitle: store.txnsForAccount(_account.id).isEmpty
                        ? 'Permanently deletes this account'
                        : 'Has history — it will be archived, not erased',
                    onTap: _confirmRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickDay(String title) {
    return showAppSheet<int>(
      context,
      title: title,
      initialSize: 0.6,
      builder: (context, controller) => GridView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          0,
          Insets.gutter,
          Insets.xxl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: Insets.sm,
          crossAxisSpacing: Insets.sm,
        ),
        itemCount: 28,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.of(context).pop(i + 1),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: AppText.body),
          ),
        ),
      ),
    );
  }

  Future<void> _pickGroup() async {
    final picked = await showAppSheet<AccountGroup>(
      context,
      title: 'Group',
      initialSize: 0.65,
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
                for (var i = 0; i < AccountGroup.values.length; i++) ...[
                  if (i > 0) const RowDivider(indent: Insets.md),
                  FormRow(
                    icon: AccountGroup.values[i].icon,
                    label: AccountGroup.values[i].label(AppLocalizations.of(context)),
                    onTap: () =>
                        Navigator.of(context).pop(AccountGroup.values[i]),
                    trailing: AccountGroup.values[i] == _group
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
    if (picked != null) setState(() => _group = picked);
  }

  void _save() {
    _store.updateAccount(
      _account,
      name: _name.text.trim(),
      group: _group,
      currency: _currency,
      creditLimit: double.tryParse(_limit.text.trim()),
      statementDay: _statementDay,
      paymentDue: _paymentDue,
      hidden: _hidden,
    );
    Navigator.of(context).pop();
  }

  /// Spec 1.5 / 6.2 — Hide vs Remove, spelled out in concrete terms.
  Future<void> _confirmRemove() async {
    final count = _store.txnsForAccount(_account.id).length;
    final balance = _store.balanceOf(_account.id);
    final archiving = count > 0;

    final ok = await showDestructiveConfirm(
      context,
      title: 'Remove ${_account.name}?',
      message: archiving
          ? 'This account has history, so it is archived rather than erased.'
          : 'This account has no transactions and can be deleted outright.',
      impact: [
        if (archiving)
          ImpactLine.kept(
            'Your $count ${count == 1 ? 'transaction stays' : 'transactions stay'} '
            'in the Ledger, untouched.',
          ),
        ImpactLine.lost(
          '${_account.group.label(AppLocalizations.of(context))} drops by '
          '${money(balance.abs(), currency: _currency)}.',
        ),
        ImpactLine.lost('It disappears from every account picker.'),
        if (!archiving)
          const ImpactLine.lost('This cannot be undone.'),
      ],
      confirmLabel: archiving ? 'Archive account' : 'Remove account',
    );

    if (!ok || !mounted) return;
    _store.removeAccount(_account);
    // Pop Edit Account and the now-empty Account Detail behind it.
    Navigator.of(context)
      ..pop()
      ..pop();
  }
}
