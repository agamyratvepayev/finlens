import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'pickers.dart';
import 'widgets/amount_hero.dart' show AmountEntry, NumericKeypad;

/// One line of a split: a category and its share of the payment.
///
/// [amount] is nullable: `null` means the user has not yet entered a figure
/// (rendered `0.00` in the placeholder colour, spec §5). A typed zero is a real
/// `0`, distinct from blank — the two differ for `Assign the rest` (which fills
/// the first *blank* line) and for the placeholder rendering.
class SplitLine {
  SplitLine({this.categoryId, this.amount});

  String? categoryId;
  double? amount;

  bool get isBlank => amount == null;

  SplitLine copy() => SplitLine(categoryId: categoryId, amount: amount);
}

/// Cent-rounding tolerance for money equality. The app has no shared epsilon
/// (formatters round to cents), so this mirrors that: two figures are equal
/// when they agree to the nearest cent (spec §7 — reuse the existing rounding).
const double kMoneyEpsilon = 0.005;

/// Divides [total] across [n] lines. Each share rounds **down** to the minor
/// unit and the leftover minor units go **one each to the first N lines**, so
/// the shares sum to [total] exactly. Works in integer cents.
///
/// The sum was already exact before — the leftover was handed to line 1 whole —
/// so this is a distribution change, not a correctness fix: $100.00 over seven
/// lines was `14.32, 14.28×6` and is now `14.29×4, 14.28×3`. Both reconcile;
/// the second does not single out the first line for the whole rounding error.
List<double> splitEvenly(double total, int n) {
  if (n <= 0) return const [];
  final totalCents = (total * 100).round();
  final base = totalCents ~/ n;
  final leftover = totalCents - base * n;
  return [for (var i = 0; i < n; i++) (base + (i < leftover ? 1 : 0)) / 100];
}

/// Sum of the assigned shares — a blank line contributes nothing.
double splitAssigned(List<SplitLine> lines) =>
    lines.fold(0.0, (sum, l) => sum + (l.amount ?? 0));

double splitRemaining(double total, List<SplitLine> lines) =>
    total - splitAssigned(lines);

/// Whether the split can be committed: the remainder is exactly zero and **no
/// line is left unassigned** — a line the user created and did not fill is a
/// question, not a zero (spec §8).
///
/// A line explicitly set to `0` is assigned and passes; `null` is not. That is
/// the one change here: the old rule demanded `> 0`, which made an intentional
/// zero share uncommittable.
///
/// The ≥2-line and category requirements are unchanged — a single line is not a
/// split, and what a split writes on save is out of scope.
bool splitBalanced(double total, List<SplitLine> lines) {
  if (lines.length < 2) return false;
  if (lines.any((l) => l.categoryId == null || l.amount == null)) return false;
  return splitRemaining(total, lines).abs() < kMoneyEpsilon;
}

/// Opens the split editor. Returns the applied lines (Done) or null (Cancel —
/// no change). Done is only reachable when the split is balanced, so a non-null
/// result always holds ≥2 valid lines (spec §9).
Future<List<SplitLine>?> showSplitSheet(
  BuildContext context, {
  required double total,
  required String currency,
  required String accountName,
  required CategoryType categoryType,
  required List<SplitLine> initial,
}) {
  return showModalBottomSheet<List<SplitLine>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SplitSheet(
      total: total,
      currency: currency,
      accountName: accountName,
      categoryType: categoryType,
      initial: initial,
    ),
  );
}

class _SplitSheet extends StatefulWidget {
  const _SplitSheet({
    required this.total,
    required this.currency,
    required this.accountName,
    required this.categoryType,
    required this.initial,
  });

  final double total;
  final String currency;
  final String accountName;
  final CategoryType categoryType;
  final List<SplitLine> initial;

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  /// Opens with the existing lines when re-splitting; otherwise a single line —
  /// the transaction's own category — with a blank amount (spec §5). The
  /// caller passes the current category as the single initial line.
  late final List<SplitLine> _lines = widget.initial.isEmpty
      ? [SplitLine()]
      : [for (final l in widget.initial) l.copy()];

  /// The keypad's entry state, one string per line, held in lockstep with
  /// [_lines]. This is the *same* model the amount hero runs on — `AmountEntry`
  /// over a raw digit string — so a keystroke means exactly what it means on the
  /// form. The line's `amount` is derived from it and never set directly.
  ///
  /// Empty string ⇒ the line is unassigned and renders `—` (spec §9). `'0'` is
  /// an assigned zero and renders `$0.00`; the two are deliberately different.
  late final List<String> _raw = [
    for (final l in _lines) _rawOf(l.amount),
  ];

  /// The line being typed into, or null in list mode (spec §1).
  int? _active;

  bool get _entryMode => _active != null;

  /// Keys per line, so the active line can be scrolled into view.
  final Map<int, GlobalKey> _lineKeys = {};
  GlobalKey _keyFor(int i) => _lineKeys.putIfAbsent(i, () => GlobalKey());

  /// `AmountEntry.fromDouble` returns '' for zero, which would render an
  /// assigned zero as unassigned. An assigned zero is '0'.
  static String _rawOf(double? v) =>
      v == null ? '' : (v == 0 ? '0' : AmountEntry.fromDouble(v));

  /// Writes a line's amount through the raw entry state, so the two can never
  /// disagree.
  void _setAmount(int i, double? v) {
    _raw[i] = _rawOf(v);
    _lines[i].amount = v;
  }

  void _onKey(String k) {
    final i = _active;
    if (i == null) return;
    setState(() {
      _raw[i] = AmountEntry.press(_raw[i], k);
      _lines[i].amount =
          _raw[i].isEmpty ? null : AmountEntry.value(_raw[i]);
    });
  }

  void _onBackspace() {
    final i = _active;
    if (i == null) return;
    setState(() {
      _raw[i] = AmountEntry.backspace(_raw[i]);
      _lines[i].amount =
          _raw[i].isEmpty ? null : AmountEntry.value(_raw[i]);
    });
  }

  /// Opens the keypad on [i], or closes it when [i] is already active.
  void _activate(int? i) {
    setState(() => _active = (i != null && i == _active) ? null : i);
    if (_active != null) _scrollActiveIntoView();
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[_active]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 180), alignment: 0.5);
      }
    });
  }

  /// Leaves the split behind: pops an empty list, which the form already reads
  /// as "no split" (`result.length >= 2 ? result : null`). Not `Reset` — that
  /// word is taken by two other sheets where it clears selections *in place and
  /// leaves the sheet open*; this closes the sheet and changes the form.
  ///
  /// No confirmation and no undo bar, deliberately: nothing has been committed
  /// to the store — this is a modal over an unsaved form — and the split is
  /// reconstructible from the form in two taps. The category the row held
  /// before the split is untouched, so the row returns to it on its own.
  void _removeSplit() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(const <SplitLine>[]);
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _raw.removeAt(index);
      _lineKeys.clear();
      // Deleting the active line closes the keypad (spec §3); deleting an
      // earlier one keeps it open on the same line, which has shifted down.
      if (_active == index) {
        _active = null;
      } else if (_active != null && _active! > index) {
        _active = _active! - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final masked = store.masked;
    final remaining = splitRemaining(widget.total, _lines);
    final over = remaining < -kMoneyEpsilon;

    // Everything above the bottom block is identical in both modes; only the
    // tail swaps (spec §1). The list is the one flexible child, so the keypad
    // takes its height from the lines rather than from the sheet.
    return SafeArea(
      child: ConstrainedBox(
        // The keypad makes the sheet tall; cap it so it never runs past the
        // status bar, and let the list absorb the difference.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top -
              44,
        ),
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sheetGrabber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _header(),
              _totalRow(masked),
              Flexible(
                child: SingleChildScrollView(
                  child: _linesCard(store, masked, over),
                ),
              ),
              _statusRow(remaining, masked),
              if (_entryMode)
                NumericKeypad(onKey: _onKey, onBackspace: _onBackspace)
              else ...[
                _splitEvenlyButton(),
                _doneButton(),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header · Total ─────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context).ssSplit,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )),
            ),
            // Only when the sheet opened on an existing split. While one is
            // being created, Cancel already means "never mind", and two
            // controls doing one job is the redundancy this removes.
            if (widget.initial.length >= 2) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeSplit,
                child: Semantics(
                  button: true,
                  // "Remove" alone is ambiguous in a sheet whose every line
                  // carries a "Remove line" control, so the reader hears the
                  // full phrase — the shape the filter sheet's Reset uses.
                  label: AppLocalizations.of(context).ssRemoveSplitA11y,
                  child: Text(AppLocalizations.of(context).ssRemove,
                      style: const TextStyle(
                          fontSize: 14.5, color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 16),
            ],
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Never animate out from behind an open keypad.
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: Semantics(
                button: true,
                label: AppLocalizations.of(context).actionCancel,
                child: Text(AppLocalizations.of(context).actionCancel,
                    style: const TextStyle(
                        fontSize: 14.5, color: AppColors.accentLight)),
              ),
            ),
          ],
        ),
      );

  Widget _totalRow(bool masked) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Text(AppLocalizations.of(context).ssTotal,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            _dimmedAmount(widget.total, masked),
          ],
        ),
      );

  /// The total with its decimal portion dimmed, matching the app's amount
  /// treatment (spec §4). Masked amounts have no decimal to dim.
  Widget _dimmedAmount(double value, bool masked) {
    final text = money(value, currency: widget.currency,
        forceDecimals: true, masked: masked);
    final dot = text.lastIndexOf('.');
    final whole = dot < 0 ? text : text.substring(0, dot);
    final frac = dot < 0 ? '' : text.substring(dot);
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        children: [
          TextSpan(text: whole),
          if (frac.isNotEmpty)
            TextSpan(
                text: frac,
                style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Lines ──────────────────────────────────────────────────────────────────

  Widget _linesCard(AppStore store, bool masked, bool over) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _lines.length; i++) ...[
              if (i > 0)
                Container(
                    height: 1, color: Colors.white.withValues(alpha: 0.07)),
              _lineRow(store, i, masked, over),
            ],
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            _addRow(),
          ],
        ),
      );

  Widget _lineRow(AppStore store, int index, bool masked, bool over) {
    final l = AppLocalizations.of(context);
    final line = _lines[index];
    final category = store.categoryById(line.categoryId);
    final missing = category == null;
    final color = category?.color ?? AppColors.warning;
    // When the whole split exceeds the total, the amounts that carry the overage
    // render red so the user does not have to hunt for them (spec §8). A blank
    // line has nothing to flag.
    final amountOver = over && !line.isBlank;
    final removable = _lines.length > 1;

    final active = _active == index;
    // An entry surface cannot hide the number being entered: the line under the
    // keypad shows its digits even while privacy masking is on (spec §11).
    final lineMasked = masked && !active;
    // `—` means *not filled in yet*; `$0.00` is a claim that this category was
    // assigned zero, and the two are different things (spec §9).
    final amountText = line.isBlank
        ? '—'
        : money(line.amount!, currency: widget.currency,
            forceDecimals: true, masked: lineMasked);
    final amountLabel = line.isBlank ? l.ssUnassignedA11y : amountText;
    final name = missing ? l.ssChooseCategory : category.name;

    return Semantics(
      container: true,
      selected: active,
      label: active
          ? l.ssActiveLineA11y(name)
          : '$name, $amountLabel',
      child: Container(
        key: _keyFor(index),
        color: active ? AppColors.surfaceHigh : null,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: missing
                    ? AppColors.surfaceHigh
                    : Color.alphaBlend(
                        color.withValues(alpha: 0.18), AppColors.sheetCard),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(category?.icon ?? Icons.category_rounded,
                  size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final c =
                      await pickCategory(context, type: widget.categoryType);
                  if (c != null && mounted) {
                    setState(() => line.categoryId = c.id);
                  }
                },
                // A line with no category names the fault in place, in amber —
                // no separate status line (spec §8).
                child: Text(
                  missing ? l.ssChooseCategory : category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: missing ? AppColors.warning : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tapping another line moves the active line and leaves the
              // keypad open; tapping the active line again closes it (spec §3).
              onTap: () => _activate(index),
              child: Text(
                amountText,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: line.isBlank
                      ? AppColors.textSecondary
                      : amountOver
                          ? AppColors.negative
                          : Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // The active line hides its ✕: the delete control would sit under
            // the finger that is typing, and a mis-tap there destroys the line
            // and its amount (spec §3). The slot is held so nothing reflows.
            SizedBox(
              width: 44,
              height: 44,
              child: active
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 15,
                      color: removable
                          ? AppColors.textTertiary
                          : AppColors.textTertiary.withValues(alpha: 0.3),
                      icon: const Icon(Icons.close_rounded),
                      // The last remaining line cannot be removed (spec §5).
                      onPressed: removable ? () => _removeLine(index) : null,
                      tooltip: l.ssRemoveLine,
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// The card's last row, so it scrolls with the lines and stays reachable with
  /// the keypad open (spec §2). Its tile is a dashed accent outline where a
  /// category line carries a filled colour tile.
  Widget _addRow() => InkWell(
        onTap: _addLine,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              CustomPaint(
                painter: const _DashedTilePainter(),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.add_rounded,
                      size: 16, color: AppColors.accentLight),
                ),
              ),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context).ssAddLine,
                  style: const TextStyle(
                      fontSize: 14.5, color: AppColors.accentLight)),
            ],
          ),
        ),
      );

  /// A line you just created has no amount and you are about to type one, so
  /// picking the category leaves it active with the keypad open (spec §2).
  Future<void> _addLine() async {
    final c = await pickCategory(context, type: widget.categoryType);
    if (c == null || !mounted) return;
    setState(() {
      _lines.add(SplitLine(categoryId: c.id));
      _raw.add('');
      _active = _lines.length - 1;
    });
    _scrollActiveIntoView();
  }

  // ── Split evenly ───────────────────────────────────────────────────────────

  /// `Split evenly` is about *all* lines, so it needs no active line and lives
  /// in list mode only — where, because there is never an active line, it can
  /// never overwrite a number the user is halfway through typing (spec §6).
  ///
  /// `Assign the rest` was its neighbour and is gone: it is about *one* line,
  /// and without an active line "the rest" of what is ambiguous. It is now a tap
  /// on the remainder figure itself (spec §5).
  Widget _splitEvenlyButton() {
    final l = AppLocalizations.of(context);
    final enabled = _lines.length >= 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: l.ssSplitEvenly,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: AppColors.sheetCard,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? _splitEvenly : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(l.ssSplitEvenly,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.toggleOffFg)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── The remainder line — the sheet's verdict ───────────────────────────────

  /// Three states and no fourth (spec §5): under, exact, over. Present in both
  /// modes, and interactive only when there is a remainder *and* a line to put
  /// it on — which is entry mode.
  ///
  /// The over-assigned magnitude prints positive: the word carries the
  /// direction, and a minus sign in front of a figure the user is being warned
  /// about reads as an amount rather than a state.
  Widget _statusRow(double remaining, bool masked) {
    final l = AppLocalizations.of(context);
    final over = remaining < -kMoneyEpsilon;
    final under = remaining > kMoneyEpsilon;

    final String word;
    String? figure;
    final Color color;
    if (over) {
      word = l.ssOverAssignedBy;
      figure = money(remaining.abs(), currency: widget.currency, masked: masked);
      color = AppColors.negative;
    } else if (under) {
      word = l.ssLeftToAssign;
      figure = money(remaining, currency: widget.currency, masked: masked);
      color = AppColors.warning;
    } else {
      word = l.ssFullyAssigned;
      color = AppColors.positive;
    }

    // `Assign the rest`: only with a remainder to assign and a line to assign it
    // to, and shown on the figure itself so "the rest of what?" is answered by
    // the number under the finger (spec §5).
    final canAssign = under && _entryMode;
    final activeName = _entryMode
        ? StoreScope.of(context)
                .categoryById(_lines[_active!].categoryId)
                ?.name ??
            l.ssChooseCategory
        : '';

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // The label ellipsises; the figure never shrinks or wraps (spec §10).
          Expanded(
            child: Text(word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: color)),
          ),
          const SizedBox(width: 12),
          if (figure != null)
            Text(
              figure,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Icon(Icons.check_rounded, size: 16, color: color),
          if (canAssign)
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
        ],
      ),
    );

    if (!canAssign) {
      return Semantics(
        liveRegion: true,
        excludeSemantics: true,
        label: figure == null ? word : '$word $figure',
        child: row,
      );
    }
    return Semantics(
      liveRegion: true,
      button: true,
      excludeSemantics: true,
      label: l.ssAssignRestA11y(figure!, activeName),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _assignTheRest,
        child: row,
      ),
    );
  }

  // ── Done ───────────────────────────────────────────────────────────────────

  Widget _doneButton() {
    final enabled = splitBalanced(widget.total, _lines);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: SizedBox(
          width: double.infinity,
          height: 45,
          child: Semantics(
            button: true,
            enabled: enabled,
            label: AppLocalizations.of(context).actionDone,
            child: FilledButton(
              onPressed:
                  enabled ? () => Navigator.of(context).pop(_lines) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: Text(AppLocalizations.of(context).actionDone,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Overwrites every amount — including hand-typed ones — with an even share,
  /// giving the leftover minor units to the first line so the sum reconciles
  /// exactly (spec §7). Categories are untouched.
  void _splitEvenly() {
    final shares = splitEvenly(widget.total, _lines.length);
    setState(() {
      for (var i = 0; i < _lines.length; i++) {
        _setAmount(i, shares[i]);
      }
    });
  }

  /// Adds the remainder to the **active** line — added, not replaced, so a line
  /// that already carries an amount grows by the rest rather than losing it
  /// (spec §5/§11). Only reachable in entry mode, where "the rest" has a line to
  /// mean something about. The keypad stays open.
  void _assignTheRest() {
    final i = _active;
    if (i == null) return;
    final remaining =
        ((widget.total - splitAssigned(_lines)) * 100).round() / 100;
    if (remaining <= 0) return;
    setState(() => _setAmount(i, (_lines[i].amount ?? 0) + remaining));
  }
}

/// The dashed accent outline on `+ Add a line`'s tile — the one place the card
/// says "this row makes a new thing" rather than "this row is a thing". Uses
/// the existing accent token and the tile geometry of a category line; no new
/// colour, radius or size is introduced.
class _DashedTilePainter extends CustomPainter {
  const _DashedTilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.accentLight;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );
    // 3-on / 3-off around the rounded rect.
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 3).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedTilePainter oldDelegate) => false;
}
