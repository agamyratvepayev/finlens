import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Spec §5 — the opening-balance sheet.
///
/// A small sheet, **not** the transaction editor: an opening balance has no
/// category, direction, description or note, so the fields those carry would be
/// wrong here. Just an amount (in the account's own currency) and the date its
/// history begins. Saving recomputes every running balance on the account at
/// once, because balances are derived from this one floor.
void showOpeningBalanceSheet(BuildContext context, String accountId) {
  final store = StoreScope.read(context);
  final account = store.accountById(accountId);
  if (account == null) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (_) => _OpeningBalanceSheet(accountId: accountId),
  );
}

class _OpeningBalanceSheet extends StatefulWidget {
  const _OpeningBalanceSheet({required this.accountId});

  final String accountId;

  @override
  State<_OpeningBalanceSheet> createState() => _OpeningBalanceSheetState();
}

class _OpeningBalanceSheetState extends State<_OpeningBalanceSheet> {
  late final AppStore _store = StoreScope.read(context);
  late final Account _account = _store.accountById(widget.accountId)!;

  late final double _originalAmount = _account.startingBalance.abs();
  late final DateTime _originalDate = _dayOf(
    _account.openingDate ?? AppStore.today,
  );

  late final TextEditingController _amount =
      TextEditingController(text: _plain(_originalAmount));
  late DateTime _date = _originalDate;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _plain(double v) {
    final a = v.abs();
    if ((a - a.roundToDouble()).abs() < 0.005) return a.round().toString();
    return a.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Parsed magnitude, or null when the field is not a valid non-negative
  /// number. Commas (thousands separators) are tolerated.
  double? get _parsedAmount {
    final text = _amount.text.trim().replaceAll(',', '');
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    if (v == null || v < 0) return null;
    return v;
  }

  /// The earliest transaction on the account — the ceiling the opening date may
  /// not exceed (spec §5). Null when the account has no transactions.
  DateTime? get _earliestTxn =>
      _store.earliestTxnDateForAccount(_account.id);

  /// True when the chosen date sits after the first transaction — a floor above
  /// what rests on it. Blocked inline rather than accepted and reordered (§5).
  bool get _dateTooLate {
    final earliest = _earliestTxn;
    return earliest != null && _date.isAfter(_dayOf(earliest));
  }

  bool get _changed {
    final v = _parsedAmount;
    if (v == null) return false;
    final amountChanged = (v - _originalAmount).abs() >= 0.005;
    final dateChanged = _date != _originalDate;
    return amountChanged || dateChanged;
  }

  bool get _canSave => _parsedAmount != null && !_dateTooLate && _changed;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      // An opening balance cannot be dated into the future; the app's reference
      // "today" is the ceiling for the picker itself. The earliest-transaction
      // rule is enforced inline below so an invalid choice is shown, not hidden.
      lastDate: AppStore.today,
    );
    if (picked != null) {
      setState(() => _date = _dayOf(picked));
    }
  }

  void _save() {
    final v = _parsedAmount;
    if (v == null) return;
    _store.setOpeningBalance(_account, amount: v, date: _date);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        // Lift the sheet above the keyboard while the amount is focused.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Insets.md),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.obTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_account.name} · ${_account.currency}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // The card: Amount over Date, split by a hairline (spec §5).
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: AppColors.sheetCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _amountRow(l),
                  const Divider(height: 1, thickness: 1, color: AppColors.bg),
                  _dateRow(l),
                ],
              ),
            ),
            if (_dateTooLate)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l.obDateTooLate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.negative,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                l.obShiftsNote,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SizedBox(
                height: 47,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.saveDisabledBg,
                    disabledForegroundColor: AppColors.saveDisabledFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l.actionSave,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              l.qaAmount,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            currencySymbol(_account.currency),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              cursorColor: AppColors.accent,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(AppLocalizations l) {
    return InkWell(
      onTap: _pickDate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                l.qaDate,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                dayMonthYear(_date, l),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.formChevron,
            ),
          ],
        ),
      ),
    );
  }
}
