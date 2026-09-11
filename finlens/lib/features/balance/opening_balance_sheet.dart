import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../quick_add/widgets/amount_hero.dart';

/// Spec §5 — the opening-balance sheet.
///
/// A small sheet, **not** the transaction editor: an opening balance has no
/// category, direction, description or note, so the fields those carry would be
/// wrong here. Just an amount (in the account's own currency) and the date its
/// history begins. Saving recomputes every running balance on the account at
/// once, because balances are derived from this one floor.
///
/// The amount is typed on the app's own [NumericKeypad] driving an
/// [AmountEntry] raw string — the same inline-entry path Quick Add (and the
/// task-8 New account sheet) use. The system keyboard is gone, and with it the
/// comma key that used to turn `500,0` into `5,000`: a keypad has no comma, so
/// the ambiguity that lost money cannot be typed.
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

  // The amount is held as the literal keys the user pressed ("500", "500.",
  // "500.5") rather than a double, so the display can tell typed digits apart
  // from the decimal padding they have not reached yet (the task-11 dim rule).
  // Seeded from the existing floor via [AmountEntry.fromDouble].
  late String _amountRaw = AmountEntry.fromDouble(_originalAmount);

  /// Whether the docked keypad is open and writing to the amount. Starts closed
  /// so a seeded value shows all-bright from the first frame (§4), never pale.
  bool _amountFocused = false;

  late DateTime _date = _originalDate;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The entered magnitude, or null when nothing has been typed. The keypad has
  /// no minus key, so the value can never be negative; the empty guard is what
  /// keeps `_canSave` off until a figure exists (same as the old field).
  double? get _enteredAmount =>
      _amountRaw.isEmpty ? null : AmountEntry.value(_amountRaw);

  /// The earliest transaction on the account — the ceiling the opening date may
  /// not exceed (spec §5). Null when the account has no transactions.
  DateTime? get _earliestTxn => _store.earliestTxnDateForAccount(_account.id);

  /// True when the chosen date sits after the first transaction — a floor above
  /// what rests on it. Blocked inline rather than accepted and reordered (§5).
  bool get _dateTooLate {
    final earliest = _earliestTxn;
    return earliest != null && _date.isAfter(_dayOf(earliest));
  }

  bool get _changed {
    final v = _enteredAmount;
    if (v == null) return false;
    final amountChanged = (v - _originalAmount).abs() >= 0.005;
    final dateChanged = _date != _originalDate;
    return amountChanged || dateChanged;
  }

  bool get _canSave => _enteredAmount != null && !_dateTooLate && _changed;

  void _focusAmount() {
    if (!_amountFocused) setState(() => _amountFocused = true);
  }

  void _pressKey(String key) =>
      setState(() => _amountRaw = AmountEntry.press(_amountRaw, key));

  void _backspace() =>
      setState(() => _amountRaw = AmountEntry.backspace(_amountRaw));

  Future<void> _pickDate() async {
    // The keypad and the date picker are never up together (§4): opening the
    // picker closes the keypad first.
    if (_amountFocused) setState(() => _amountFocused = false);
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
    final v = _enteredAmount;
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
        // Harmless with the keypad (no system keyboard here), but keeps the
        // sheet lifted should any platform inset ever appear.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The content scrolls when the screen is short or text is scaled up;
            // Save and the keypad below stay pinned and reachable (§4).
            Flexible(
              child: SingleChildScrollView(
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
                          _AmountField(
                            label: l.qaAmount,
                            raw: _amountRaw,
                            currency: _account.currency,
                            focused: _amountFocused,
                            onTap: _focusAmount,
                          ),
                          const Divider(
                              height: 1, thickness: 1, color: AppColors.bg),
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
                  ],
                ),
              ),
            ),
            // Save sits directly above the keypad — the arrangement the keypad's
            // own doc comment prescribes and task 8 uses.
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
            if (_amountFocused) ...[
              NumericKeypad(onKey: _pressKey, onBackspace: _backspace),
              // The home-indicator inset below the keys is the sheet shell's.
              const SizedBox(height: Insets.sm),
            ],
          ],
        ),
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

/// The inline amount row: the number and its currency token, typed on the
/// docked keypad. Modelled on the task-8 New account row (focus outline, caret,
/// minHeight swap) but rendering the token from the currency's own metadata
/// rather than an editable code chip — the currency is fixed to the account's.
///
/// The dim rule (task 11): pale means "not yet typed".
///   - empty            → the whole `0.00` placeholder is dim;
///   - focused + typed  → typed digits bright, the decimal padding still dim;
///   - filled, unfocused → all bright.
class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.label,
    required this.raw,
    required this.currency,
    required this.focused,
    required this.onTap,
  });

  final String label;
  final String raw;
  final String currency;
  final bool focused;
  final VoidCallback onTap;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField>
    with SingleTickerProviderStateMixin {
  /// Caret blink, same 1050 ms period as the Quick Add hero's. Runs only while
  /// the row holds focus so an unfocused row costs nothing.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  static const _labelStyle =
      TextStyle(fontSize: 14, color: AppColors.textSecondary);
  static const _tokenStyle = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary);

  @override
  void initState() {
    super.initState();
    if (widget.focused) _blink.repeat();
  }

  @override
  void didUpdateWidget(_AmountField old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) _blink.repeat();
    if (!widget.focused && old.focused) _blink.stop();
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static double _measure(String s, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  /// Splits the display into what the user actually typed (grouped) and the
  /// decimal remainder that is only there to hold the column, using the
  /// currency's own [CurrencyDef.decimals]. The caret lands between the two.
  ({String typed, String rest}) _parts(CurrencyDef def) {
    final raw = widget.raw;
    final zeros = def.decimals > 0 ? '.${'0' * def.decimals}' : '';
    if (raw.isEmpty) return (typed: '', rest: '0$zeros');
    final dot = raw.indexOf('.');
    final wholeSrc = dot < 0 ? raw : raw.substring(0, dot);
    final whole = _group(wholeSrc.isEmpty ? '0' : wholeSrc);
    if (dot < 0) return (typed: whole, rest: zeros);
    final decs = raw.substring(dot + 1);
    final pad = def.decimals - decs.length;
    return (typed: '$whole.$decs', rest: pad > 0 ? '0' * pad : '');
  }

  /// The token side ([CurrencyDef.symbolBefore]) and spacing (symbol flush, code
  /// spaced) both come from the def — never a hard-coded currency (spec §7a).
  List<InlineSpan> _tokenAround(
    CurrencyDef def,
    List<InlineSpan> number,
  ) {
    final gap = def.tokenIsSymbol ? '' : ' ';
    final token = TextSpan(text: def.token, style: _tokenStyle);
    return def.symbolBefore
        ? [
            token,
            if (gap.isNotEmpty) TextSpan(text: gap, style: _tokenStyle),
            ...number,
          ]
        : [
            ...number,
            if (gap.isNotEmpty) TextSpan(text: gap, style: _tokenStyle),
            token,
          ];
  }

  String _plain(({String typed, String rest}) parts, CurrencyDef def) {
    final number = '${parts.typed}${parts.rest}';
    final gap = def.tokenIsSymbol ? '' : ' ';
    return def.symbolBefore
        ? '${def.token}$gap$number'
        : '$number$gap${def.token}';
  }

  @override
  Widget build(BuildContext context) {
    final def = currencyDef(widget.currency);
    final focused = widget.focused;
    final filled = widget.raw.isNotEmpty;
    final parts = _parts(def);

    // Task 11 brightness. The typed digits are always bright once present; the
    // decimal padding is dim while typing and bright once the row is unfocused.
    final restColor =
        (filled && !focused) ? AppColors.textPrimary : AppColors.textTertiary;
    const typedStyle = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()]);
    final restStyle = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: restColor,
        fontFeatures: const [FontFeature.tabularFigures()]);

    final number = <InlineSpan>[
      if (parts.typed.isNotEmpty)
        TextSpan(text: parts.typed, style: typedStyle),
      if (focused)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedBuilder(
            animation: _blink,
            builder: (context, _) => Opacity(
              opacity: _blink.value < 0.5 ? 1 : 0,
              child: Container(
                width: 2,
                height: 17,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      if (parts.rest.isNotEmpty) TextSpan(text: parts.rest, style: restStyle),
    ];

    final amount = Text.rich(
      TextSpan(children: _tokenAround(def, number)),
      textAlign: TextAlign.right,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    return Semantics(
      button: true,
      focused: focused,
      label:
          '${widget.label} ${money(AmountEntry.value(widget.raw), currency: widget.currency)}',
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          // Focused: an accent outline inset inside the card. The margin/padding
          // swap keeps the content in place and the tap target at ≥44 pt.
          margin: focused ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: focused
              ? BoxDecoration(
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.55),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          constraints: BoxConstraints(minHeight: focused ? 38 : 44),
          padding: EdgeInsets.symmetric(
              horizontal: focused ? 14 - 3 : 14, vertical: focused ? 9 : 12),
          child: LayoutBuilder(
            builder: (context, c) {
              final scaler = MediaQuery.textScalerOf(context);
              final labelW = _measure(widget.label, _labelStyle, scaler);
              final amountW = _measure(_plain(parts, def), restStyle, scaler) +
                  (focused ? 4 : 0); // caret column
              // One line only if the label and the amount both fit with a little
              // breathing room between them; otherwise stack (§4, 200% text).
              final oneLine = labelW + 16 + amountW <= c.maxWidth;

              if (oneLine) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(widget.label,
                          style: _labelStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    amount,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label, style: _labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [Flexible(child: amount)],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
