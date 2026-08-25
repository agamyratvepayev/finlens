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
import '../quick_add/quick_add_sheet.dart';
import 'opening_balance_sheet.dart';

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
    final l = AppLocalizations.of(context);

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
                    child: Text(l.actionCancel),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(l.eaEditAccount, style: AppText.rowTitle),
                    ),
                  ),
                  TextButton(
                    onPressed: _name.text.trim().isEmpty ? null : _save,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSoft,
                      textStyle: AppText.button,
                    ),
                    child: Text(l.actionSave),
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
                        label: l.eaName,
                        controller: _name,
                        trailing: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      FormRow(
                        icon: Icons.folder_rounded,
                        label: l.eaGroup,
                        value: _group.label(AppLocalizations.of(context)),
                        showChevron: true,
                        onTap: _pickGroup,
                      ),
                      FormRow(
                        icon: Icons.language_rounded,
                        label: l.eaCurrency,
                        value: _currency,
                        showChevron: true,
                        onTap: () async {
                          final c = await pickCurrency(context, _currency);
                          if (c != null) setState(() => _currency = c);
                        },
                      ),
                      // The opening balance — the floor the running-balance
                      // column is built on (spec §5/§6). Editable here so it can
                      // be restored after a delete, when the swipe menu that
                      // reached it is gone. Opens the small opening-balance
                      // sheet, never the transaction editor.
                      FormRow(
                        icon: Icons.flag_rounded,
                        label: l.obTitle,
                        value: _account.hasOpeningReceipt
                            ? money(
                                _account.startingBalance.abs(),
                                currency: _currency,
                              )
                            : l.obNotSet,
                        showChevron: true,
                        onTap: () =>
                            showOpeningBalanceSheet(context, _account.id),
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
                            label: l.eaCreditLimit,
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
                            label: l.eaStatementDay,
                            value: _statementDay == null
                                ? l.eaNotSet
                                : ordinalDay(_statementDay!, AppLocalizations.of(context)),
                            showChevron: true,
                            onTap: () async {
                              final d = await _pickDay(AppLocalizations.of(context).eaStatementDay);
                              if (d != null) setState(() => _statementDay = d);
                            },
                          ),
                          FormRow(
                            icon: Icons.event_available_rounded,
                            label: l.eaPaymentDue,
                            value: _paymentDue == null
                                ? l.eaNotSet
                                : ordinalDay(_paymentDue!, AppLocalizations.of(context)),
                            showChevron: true,
                            onTap: () async {
                              final d = await _pickDay(AppLocalizations.of(context).eaPaymentDue);
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
                        label: l.eaHideFromBalance,
                        subtitle:
                            l.eaHideDesc,
                        value: _hidden,
                        onChanged: (v) => setState(() => _hidden = v),
                      ),
                    ],
                  ),
                  // The label follows the case, as the sub-label already does:
                  // an account with history is archived (reversible), one
                  // without is deleted outright. "Archive" is the honest word
                  // for the common case (spec 6.2 / §3).
                  DestructiveRow(
                    label: store.txnsForAccount(_account.id).isEmpty
                        ? l.eaRemoveThisAccount
                        : l.eaArchiveThisAccount,
                    subtitle: store.txnsForAccount(_account.id).isEmpty
                        ? l.eaRemovePermanent
                        : l.eaRemoveHasHistory,
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
      title: AppLocalizations.of(context).eaGroup,
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

  /// Spec 1.5 / 6.2 / §3 — Hide vs Archive vs Delete, spelled out in concrete
  /// terms. A closed account holds nothing: a non-zero balance must be moved
  /// out first, so archiving never drops money from net worth unexplained.
  Future<void> _confirmRemove() async {
    final count = _store.txnsForAccount(_account.id).length;
    final balance = _store.balanceOf(_account.id);
    final archiving = count > 0;
    final l = AppLocalizations.of(context);

    // §3 — the guard: an account being archived (it has history) with anything
    // still in it is blocked; Move money is offered instead of the impact list.
    // != 0 covers a debt as well as cash. A no-history account is a true
    // delete, not an archive, so it is exempt.
    if (archiving && balance.abs() >= 0.005) {
      await _promptMoveMoney(balance);
      return;
    }

    final ok = await showDestructiveConfirm(
      context,
      title: l.eaRemoveTitle(_account.name),
      message: archiving ? l.eaArchivedMsg : l.eaDeleteMsg,
      impact: [
        // The "{group} drops by {balance}" line is gone: that state is now
        // unreachable — archiving is only permitted at a zero balance (§3).
        if (archiving) ImpactLine.kept(l.eaTxnStays(count)),
        ImpactLine.lost(l.eaDisappearsPicker),
        if (!archiving) ImpactLine.lost(l.eaCannotUndo),
      ],
      confirmLabel: archiving ? l.eaArchiveAccount : l.eaRemoveAccount,
    );

    if (!ok || !mounted) return;
    _store.removeAccount(_account);
    // Pop Edit Account and the now-empty Account Detail behind it.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  /// §3 — the "move it out first" sheet, shown instead of the archive impact
  /// list when the account still holds a balance. Move money opens the ordinary
  /// transfer flow with this account pre-filled as the source; the figure is in
  /// the account's own currency and masks with the privacy eye. A debt reads
  /// "settle" rather than "move out".
  Future<void> _promptMoveMoney(double balance) async {
    final l = AppLocalizations.of(context);
    final isDebt = balance < 0;
    final figure =
        money(balance.abs(), currency: _currency, masked: _store.masked);

    final move = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.xl, Insets.lg, Insets.xl, Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(
                isDebt ? l.eaSettleTitle(figure) : l.eaMoveOutTitle(figure),
                style: AppText.title.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                isDebt ? l.eaSettleMsg(figure) : l.eaMoveOutMsg(figure),
                style: AppText.caption.copyWith(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.xl),
              // The account and its balance, echoed like an impact row.
              Row(
                children: [
                  IconTile(_account.displayIcon,
                      color: _account.color, size: 34),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      _account.name,
                      style: AppText.body.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    figure,
                    style: AppText.amount.copyWith(
                      color: isDebt
                          ? AppColors.negative
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  textStyle: AppText.button,
                ),
                child: Text(l.eaMoveMoney),
              ),
              const SizedBox(height: Insets.sm),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size.fromHeight(46),
                  textStyle: AppText.button,
                ),
                child: Text(l.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );

    if (move != true || !mounted) return;
    // The ordinary transfer flow, this account pre-filled as the source. The
    // move is a real transaction the user performs and can see in the Ledger —
    // archiving never moves money as a side effect. When they return at $0, the
    // same action shows the normal impact list and proceeds.
    showQuickAdd(
      context,
      type: QuickAddType.transfer,
      fixedFromAccountId: _account.id,
    );
  }
}
