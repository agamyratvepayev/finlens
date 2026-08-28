import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../quick_add/pickers.dart';
import '../quick_add/widgets/amount_hero.dart';

/// §10 — the one sheet the row tick and the detail button both open. The tick no
/// longer writes anything on tap: one extra tap buys a Ledger entry that needs
/// no correcting, a real pay date, and a correctly-signed credit-card payment.
Future<MarkPaidResult?> showMarkPaidSheet(
  BuildContext context, {
  required Task task,
}) {
  return showModalBottomSheet<MarkPaidResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MarkPaidSheet(task: task),
  );
}

/// The snackbar with a mandatory Undo (§10.3) — follows the app's existing
/// delete-with-undo pattern. Undo reverses the Txn, the due date, the status and
/// any remembered amount through the store.
void showMarkPaidUndoBar(
  BuildContext context,
  AppStore store,
  MarkPaidResult result,
) {
  final l = AppLocalizations.of(context);
  final next = result.task.isRecurring
      ? l.mpRecordedNext(result.task.title, dayMonth(result.task.dueDate, l))
      : l.mpRecorded(result.task.title);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(next),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l.actionUndo,
          onPressed: () => store.undoMarkTaskPaid(result),
        ),
      ),
    );
}

class _MarkPaidSheet extends StatefulWidget {
  const _MarkPaidSheet({required this.task});

  final Task task;

  @override
  State<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<_MarkPaidSheet> {
  late final AppStore _store = StoreScope.read(context);
  late final Task _task = widget.task;
  late final bool _payOut = _task.isPayOut;

  late String _raw = AmountEntry.fromDouble(_task.expectedAmount.abs());
  late DateTime _date = AppStore.today;

  /// The account the money leaves (pay-out) or lands in (pay-in).
  late String _fromAccountId = _task.linkedAccountId;

  /// The destination: a category id, or an account id for a liability payment.
  late String? _toRef = _payOut
      ? (_task.payToAccountId ?? _task.categoryId)
      : _task.categoryId;
  late bool _toIsAccount = _payOut && _task.payToAccountId != null;

  bool _remember = false;

  double get _amount => AmountEntry.value(_raw);

  String get _currency =>
      _store.accountById(_fromAccountId)?.currency ?? 'USD';

  bool get _differs =>
      (_amount - _task.expectedAmount.abs()).abs() >= 0.005;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Insets.md),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.sheetGrabber,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                _payOut ? l.mpTitlePaid : l.mpTitleReceived,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                l.mpSubtitle(_task.title, dayMonth(_task.dueDate, l)),
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: Insets.lg),
              // The numeric hero — centred, editable, in the source currency.
              Center(
                child: Text(
                  money(_amount, currency: _currency,
                      forceDecimals: _amount % 1 != 0, masked: _store.masked),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (_differs) ...[
                const SizedBox(height: 3),
                Center(
                  child: Text(
                    l.mpExpected(money(_task.expectedAmount.abs(),
                        currency: _currency, masked: _store.masked)),
                    style: AppText.caption.copyWith(
                        fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              NumericKeypad(
                onKey: (k) => setState(() => _raw = AmountEntry.press(_raw, k)),
                onBackspace: () =>
                    setState(() => _raw = AmountEntry.backspace(_raw)),
              ),
              const SizedBox(height: Insets.md),
              _fieldCard(context, l),
              if (_task.isRecurring && _differs) _rememberRow(l),
              const SizedBox(height: Insets.md),
              _confirmButton(context, l),
              const SizedBox(height: Insets.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldCard(BuildContext context, AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.fieldCard,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        children: [
          _row(
            l.mpDate,
            dayMonth(_date, l),
            onTap: _pickDate,
          ),
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),
          _row(
            _payOut ? l.mpFrom : l.mpInto,
            _store.accountById(_fromAccountId)?.name ?? '—',
            onTap: _pickFromAccount,
          ),
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),
          _row(
            _payOut ? l.mpTo : l.fieldCategory,
            _destinationName(l),
            subtitle: _toIsAccount ? l.mpTransferNoCategory : null,
            onTap: _pickDestination,
          ),
        ],
      ),
    );
  }

  Widget _row(String key, String value, {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(key,
                  style: AppText.rowSubtitle.copyWith(fontSize: 13.5)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        style: AppText.caption.copyWith(
                            fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.formChevron),
          ],
        ),
      ),
    );
  }

  Widget _rememberRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, Insets.md, 16, 0),
      child: AppCard(
        child: SwitchListTile(
          value: _remember,
          onChanged: (v) => setState(() => _remember = v),
          activeThumbColor: AppColors.accent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          title: Text(
            l.mpRemember(money(_amount, currency: _currency, masked: _store.masked)),
            style: AppText.rowTitle.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _confirmButton(BuildContext context, AppLocalizations l) {
    final enabled = _amount > 0 && _toRef != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 47,
        child: FilledButton(
          onPressed: enabled ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.saveDisabledBg,
            disabledForegroundColor: AppColors.saveDisabledFg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md)),
          ),
          child: Text(
            l.mpConfirm(money(_amount, currency: _currency, masked: _store.masked)),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _destinationName(AppLocalizations l) {
    if (_toRef == null) return l.fieldSelectCategory;
    if (_toIsAccount) return _store.accountById(_toRef)?.name ?? '—';
    return _store.categoryById(_toRef)?.name ?? '—';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute));
    }
  }

  Future<void> _pickFromAccount() async {
    final a = await pickAccount(context,
        title: _payOut ? _l.mpFrom : _l.mpInto);
    if (a != null) setState(() => _fromAccountId = a.id);
  }

  AppLocalizations get _l => AppLocalizations.of(context);

  Future<void> _pickDestination() async {
    if (!_payOut) {
      final c = await pickCategory(context, type: CategoryType.income);
      if (c != null) {
        setState(() {
          _toRef = c.id;
          _toIsAccount = false;
        });
      }
      return;
    }
    final picked = await pickPayOutDestination(context, _store);
    if (picked != null) {
      setState(() {
        _toRef = picked.id;
        _toIsAccount = picked.isAccount;
      });
    }
  }

  void _confirm() {
    final result = _store.markTaskPaid(
      _task,
      amount: _amount,
      date: _date,
      fromAccountId: _fromAccountId,
      toRef: _toRef!,
      rememberAmount: _task.isRecurring && _differs && _remember,
    );
    Navigator.of(context).pop(result);
  }
}

/// The pay-out `To` picker: expense categories **and** liability accounts, in
/// two labelled groups — the choice of an account is what makes the payment a
/// transfer (§10.4).
Future<({String id, bool isAccount})?> pickPayOutDestination(
  BuildContext context,
  AppStore store,
) {
  final l = AppLocalizations.of(context);
  final categories = store.categoriesOfType(CategoryType.expense);
  final liabilities = [
    for (final g in AccountGroup.liabilities) ...store.accountsIn(g),
  ];
  return showAppSheet<({String id, bool isAccount})>(
    context,
    title: l.mpChooseDestination,
    initialSize: 0.7,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: Insets.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.xs),
          child: Text(l.fieldCategory.toUpperCase(), style: AppText.label),
        ),
        for (final c in categories)
          ListTile(
            leading: IconTile(c.icon, color: c.color, size: 30),
            title: Text(c.name, style: AppText.rowTitle),
            onTap: () =>
                Navigator.of(context).pop((id: c.id, isAccount: false)),
          ),
        if (liabilities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, Insets.xs),
            child: Text(l.mpPayOffGroup, style: AppText.label),
          ),
          for (final a in liabilities)
            ListTile(
              leading: IconTile(a.displayIcon, color: a.color, size: 30),
              title: Text(a.name, style: AppText.rowTitle),
              subtitle: Text(l.mpTransferNoCategory,
                  style: AppText.caption.copyWith(fontSize: 11)),
              onTap: () =>
                  Navigator.of(context).pop((id: a.id, isAccount: true)),
            ),
        ],
      ],
    ),
  );
}
