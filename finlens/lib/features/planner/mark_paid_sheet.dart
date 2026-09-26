import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/arithmetic.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/typed_date_sheet.dart';
import '../../shared/widgets/undo_bar.dart';
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
  // The shared undo bar (persist:false) so it dismisses (task 070 A4).
  showUndoBar(
    context,
    message: next,
    onUndo: () => store.undoMarkTaskPaid(result),
  );
}

/// Undo a completed payment at any time (§6b) — the durable path, opened from a
/// completed row in the tab and in History. It states in concrete figures what
/// is undone (the ImpactLine sheet), and confirms in **accent**, not red:
/// undoing is a correction, not a destruction. On confirm it walks the store's
/// [AppStore.undoTaskPayment], which reverses from the [Txn] alone.
Future<void> showUndoPaymentSheet(
  BuildContext context,
  AppStore store,
  ScheduleEvent event,
) async {
  final txn = event.txn;
  if (txn == null) return;
  final l = AppLocalizations.of(context);
  final task = event.task;
  final received = event.outcome == ScheduleOutcome.received;

  final accountId = txn.type == TxnType.income ? txn.toRef : txn.fromRef;
  final account = store.accountById(accountId)?.name ?? '—';
  final amountStr = money(event.amountInBase,
      masked: store.masked, forceDecimals: event.amountInBase % 1 != 0);

  final today = store.today;
  final d = event.date;
  final when =
      (d.year == today.year && d.month == today.month && d.day == today.day)
          ? l.schToday
          : dayMonth(d, l);

  final due = txn.recurrenceDueDate;
  final impact = <ImpactLine>[
    if (due != null) ImpactLine.kept(l.mpUndoGoesBack(task.title, dayMonth(due, l))),
    ImpactLine.kept(l.mpUndoAccountBack(account, amountStr)),
    ImpactLine.lost(l.mpUndoEntryDeleted),
    ImpactLine.lost(l.mpUndoNoteLost),
    if (due == null) ImpactLine.lost(l.mpUndoKeepsDate(task.title)),
  ];

  final ok = await showDestructiveConfirm(
    context,
    title: l.mpUndoTitle,
    message: received
        ? l.mpUndoReceivedLine(when, account, amountStr)
        : l.mpUndoPaidLine(when, account, amountStr),
    impact: impact,
    confirmLabel: l.mpUndoConfirm,
    confirmColor: AppColors.accent,
  );
  if (ok && context.mounted) store.undoTaskPayment(txn);
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

  // Prefilled with THIS occurrence's expected amount (task 064 §7c): a month
  // with its own override starts from it, not from the series' usual figure.
  late Expression _expr = Expression.ofRaw(
      AmountEntry.fromDouble(_task.amountOn(_task.dueDate).abs()));
  late DateTime _date = _store.today;

  /// The account the money leaves (pay-out) or lands in (pay-in).
  late String _fromAccountId = _task.linkedAccountId;

  /// The destination: a category id, or an account id for a liability payment.
  late String? _toRef = _payOut
      ? (_task.payToAccountId ?? _task.categoryId)
      : _task.categoryId;
  late bool _toIsAccount = _payOut && _task.payToAccountId != null;

  bool _remember = false;

  int get _precision => currencyDef(_currency).decimals;

  /// The committed amount, resolving a pending expression silently (spec §5).
  double get _amount => _expr.value(_precision) ?? 0;

  /// While an operator is pending the field shows the expression, never the
  /// answer (spec decision #1 — no live result strip).
  bool get _showExpr => _expr.hasOperator;

  String get _currency =>
      _store.accountById(_fromAccountId)?.currency ?? _store.baseCurrency;

  // Against the occurrence's own expectation (task 064): confirming a month's
  // override as-is is not a deviation and must not offer to rewrite the usual.
  bool get _differs =>
      (_amount - _task.amountOn(_task.dueDate).abs()).abs() >= 0.005;

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
                // One verb for every kind (task 064 §6a): "done" is true
                // whether the item was paid, received or earned.
                l.tdMarkDone,
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
              // A pending expression shows as typed and scrolls; `=` resolves it.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: Center(
                  child: Text(
                    _showExpr
                        ? expressionDisplay(_expr)
                        : money(_amount,
                            currency: _currency,
                            forceDecimals: _amount % 1 != 0,
                            masked: _store.masked),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (_differs) ...[
                const SizedBox(height: 3),
                Center(
                  child: Text(
                    l.mpExpected(formatAmount(
                        _task.amountOn(_task.dueDate), _currency,
                        kind: AmountKind.magnitude, masked: _store.masked)),
                    style: AppText.caption.copyWith(
                        fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              NumericKeypad(
                onKey: (k) => setState(
                    () => _expr = _expr.pressDigit(k, maxDecimals: 2)),
                onBackspace: () => setState(() => _expr = _expr.backspace()),
                onOperator: (op) =>
                    setState(() => _expr = _expr.pressOperator(op)),
                onEquals: () =>
                    setState(() => _expr = _expr.evaluated(_precision)),
                canResolve: _expr.canResolve(_precision),
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
            l.mpRemember(_showExpr
                ? expressionDisplay(_expr)
                : money(_amount, currency: _currency, masked: _store.masked)),
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
            l.mpConfirm(_showExpr
                ? expressionDisplay(_expr)
                : money(_amount, currency: _currency, masked: _store.masked)),
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
    final picked = await showTypedDateSheet(
      context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute));
    }
  }

  /// Clears the destination ref if it no longer resolves after a picker closes
  /// (task 033 §5). `_toRef` is polymorphic — an account or a category by
  /// [_toIsAccount] — so it is checked against the matching lookup. Archived
  /// items still resolve and are kept. `_fromAccountId` is non-nullable and
  /// cannot be cleared to a placeholder; its row already renders "—".
  void _dropDeletedRefs() {
    if (_toRef != null &&
        (_toIsAccount
            ? _store.accountById(_toRef) == null
            : _store.categoryById(_toRef) == null)) {
      _toRef = null;
      _toIsAccount = false;
    }
  }

  Future<void> _pickFromAccount() async {
    // The row above still reads From / Into (mpFrom / mpInto, line 190); the
    // *sheet* names what the list holds, and reuses Quick Add's keys rather
    // than inventing a third pair for the same two concepts.
    final a = await pickAccount(context,
        title: _payOut ? _l.qaPaymentAccount : _l.qaIncomeAccount);
    // Re-validate even on cancel — the picker can delete a ref (§5).
    if (!mounted) return;
    setState(() {
      _dropDeletedRefs();
      if (a != null) _fromAccountId = a.id;
    });
  }

  AppLocalizations get _l => AppLocalizations.of(context);

  Future<void> _pickDestination() async {
    if (!_payOut) {
      final c = await pickCategory(context, type: CategoryType.income);
      // Re-validate even on cancel — the picker can delete a ref (§5).
      if (!mounted) return;
      setState(() {
        _dropDeletedRefs();
        if (c != null) {
          _toRef = c.id;
          _toIsAccount = false;
        }
      });
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
///
/// Task 063 §5c: full height, titled after the row that opened it, with a
/// search filtering both groups. The old content-sized hug tracked the list's
/// length — a store with few or no expense categories opened a stub of a sheet
/// showing just the unconditional CATEGORY heading. Group labels now render
/// only over rows that exist.
Future<({String id, bool isAccount})?> pickPayOutDestination(
  BuildContext context,
  AppStore store,
) {
  final l = AppLocalizations.of(context);
  return showAppSheet<({String id, bool isAccount})>(
    context,
    title: l.etPaidTo,
    cancelLabel: l.actionCancel,
    // Full available height — showAppSheet clamps this to its computed
    // ceiling (window − status bar − 44 pt barrier).
    initialSize: 1.0,
    builder: (context, controller) =>
        _PayOutDestinationBody(controller: controller),
  );
}

class _PayOutDestinationBody extends StatefulWidget {
  const _PayOutDestinationBody({required this.controller});

  final ScrollController controller;

  @override
  State<_PayOutDestinationBody> createState() =>
      _PayOutDestinationBodyState();
}

class _PayOutDestinationBodyState extends State<_PayOutDestinationBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    bool matches(String name) => q.isEmpty || name.toLowerCase().contains(q);

    final categories = store
        .categoriesOfType(CategoryType.expense)
        .where((c) => matches(c.name))
        .toList();
    final liabilities = [
      for (final g in AccountGroup.liabilities) ...store.accountsIn(g),
    ].where((a) => matches(a.name)).toList();

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 10),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            decoration: BoxDecoration(
              color: AppColors.sheetCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body.copyWith(fontSize: 14.5),
              cursorColor: AppColors.accentSoft,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l.qaSearchCategories,
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.only(bottom: Insets.xxl),
            children: [
              if (categories.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.md, Insets.gutter, Insets.xs),
                  child: Text(l.fieldCategory.toUpperCase(),
                      style: AppText.label),
                ),
                for (final c in categories)
                  _row(
                    icon: c.icon,
                    color: c.color,
                    name: c.name,
                    onTap: () => Navigator.of(context)
                        .pop((id: c.id, isAccount: false)),
                  ),
              ],
              if (liabilities.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.lg, Insets.gutter, Insets.xs),
                  child: Text(l.mpPayOffGroup, style: AppText.label),
                ),
                for (final a in liabilities)
                  _row(
                    icon: a.displayIcon,
                    color: a.color,
                    name: a.name,
                    caption: l.mpTransferNoCategory,
                    onTap: () => Navigator.of(context)
                        .pop((id: a.id, isAccount: true)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// One 52 pt destination row (§D.4): a 30 pt tile, the name, and — for a
  /// liability — the transfer caption that used to sit on the form row.
  Widget _row({
    required IconData icon,
    required Color color,
    required String name,
    String? caption,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: Row(
            children: [
              IconTile(icon, color: color, size: 30),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowTitle),
                    if (caption != null)
                      Text(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
