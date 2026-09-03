import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'pickers.dart';

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

/// Divides [total] across [n] lines, giving any rounding remainder to the
/// **first** line so the sum stays exact (spec §7). Works in integer cents.
List<double> splitEvenly(double total, int n) {
  if (n <= 0) return const [];
  final totalCents = (total * 100).round();
  final base = totalCents ~/ n;
  final remainder = totalCents - base * n;
  return [
    for (var i = 0; i < n; i++) ((i == 0 ? base + remainder : base)) / 100,
  ];
}

/// Sum of the assigned shares — a blank line contributes nothing.
double splitAssigned(List<SplitLine> lines) =>
    lines.fold(0.0, (sum, l) => sum + (l.amount ?? 0));

double splitRemaining(double total, List<SplitLine> lines) =>
    total - splitAssigned(lines);

/// Whether the split can be committed (spec §8): ≥2 lines, every line has a
/// category and an amount greater than zero, and the shares sum exactly to the
/// total.
bool splitBalanced(double total, List<SplitLine> lines) {
  if (lines.length < 2) return false;
  if (lines.any((l) => l.categoryId == null || (l.amount ?? 0) <= 0)) {
    return false;
  }
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final masked = store.masked;
    final remaining = splitRemaining(widget.total, _lines);
    final over = remaining < -kMoneyEpsilon;

    return SafeArea(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _linesCard(store, masked, over),
                    _helpers(remaining),
                    _statusRow(remaining, masked),
                  ],
                ),
              ),
            ),
            _doneButton(),
            const SizedBox(height: 10),
          ],
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
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

    final amountText = line.isBlank
        ? money(0, currency: widget.currency,
            forceDecimals: true, masked: masked)
        : money(line.amount!, currency: widget.currency,
            forceDecimals: true, masked: masked);

    return Semantics(
      container: true,
      label: '${missing ? l.ssChooseCategory : category.name}, $amountText',
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
              onTap: () => _editAmount(index),
              child: Text(
                amountText,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: line.isBlank
                      ? AppColors.textTertiary
                      : amountOver
                          ? AppColors.negative
                          : Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                color: removable
                    ? AppColors.textTertiary
                    : AppColors.textTertiary.withValues(alpha: 0.3),
                icon: const Icon(Icons.close_rounded),
                // The last remaining line cannot be removed (spec §5).
                onPressed:
                    removable ? () => setState(() => _lines.removeAt(index)) : null,
                tooltip: l.ssRemoveLine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A normal accent list row — no dashed border (spec §5).
  Widget _addRow() => InkWell(
        onTap: () => setState(() => _lines.add(SplitLine())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              const SizedBox(
                width: 30,
                child: Icon(Icons.add_rounded,
                    size: 18, color: AppColors.accentLight),
              ),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context).ssAddLine,
                  style: const TextStyle(
                      fontSize: 14.5, color: AppColors.accentLight)),
            ],
          ),
        ),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _helpers(double remaining) {
    final l = AppLocalizations.of(context);
    // Split evenly needs ≥2 lines; Assign the rest needs a positive remainder.
    final canEven = _lines.length >= 2;
    final canRest = remaining > kMoneyEpsilon;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          Expanded(child: _helper(l.ssSplitEvenly, canEven, _splitEvenly)),
          const SizedBox(width: 8),
          Expanded(child: _helper(l.ssAssignRest, canRest, _assignTheRest)),
        ],
      ),
    );
  }

  /// A grey secondary button (spec §6): the one accent action in this region is
  /// `Add a line`. Disabled rather than hidden so the row never reflows.
  Widget _helper(String label, bool enabled, VoidCallback onTap) => Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: AppColors.sheetCard,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Center(
                  child: Text(label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.toggleOffFg)),
                ),
              ),
            ),
          ),
        ),
      );

  // ── Status line ────────────────────────────────────────────────────────────

  /// At most one message, by the §8 priority. Nothing at all when the split is
  /// valid, and never a zero remainder.
  Widget _statusRow(double remaining, bool masked) {
    final l = AppLocalizations.of(context);
    final over = remaining < -kMoneyEpsilon;
    final under = remaining > kMoneyEpsilon;

    String? word;
    String? figure;
    Color color;
    if (over) {
      word = l.ssOverTotalBy;
      figure = money(remaining.abs(), currency: widget.currency, masked: masked);
      color = AppColors.negative;
    } else if (under) {
      word = l.ssLeftToAssign;
      figure = money(remaining, currency: widget.currency, masked: masked);
      color = AppColors.warning;
    } else if (_lines.length < 2) {
      // Balanced sum, but a single line is not a split.
      word = l.ssAddAnotherLine;
      figure = null;
      color = AppColors.textSecondary;
    } else {
      // Valid — no line at all.
      return const SizedBox.shrink();
    }

    final semantics = figure == null ? word : '$word $figure';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
        liveRegion: true,
        excludeSemantics: true,
        label: semantics,
        child: Row(
          children: [
            Expanded(
              child: Text(word,
                  style: TextStyle(fontSize: 13, color: color)),
            ),
            if (figure != null) ...[
              const SizedBox(width: 12),
              Text(
                figure,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
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
        _lines[i].amount = shares[i];
      }
    });
  }

  /// Puts the unassigned remainder into the first blank line, or — if every
  /// line already has an amount — into a new, uncategorised line (spec §7). It
  /// never overwrites a typed amount.
  void _assignTheRest() {
    final remaining = ((widget.total - splitAssigned(_lines)) * 100).round() / 100;
    if (remaining <= 0) return;
    setState(() {
      final blank = _lines.indexWhere((l) => l.isBlank);
      if (blank >= 0) {
        _lines[blank].amount = remaining;
      } else {
        _lines.add(SplitLine(amount: remaining));
      }
    });
  }

  Future<void> _editAmount(int index) async {
    // The editor owns its own controller (see [_AmountEditor]): disposing it
    // here, right after the future resolves on Navigator.pop, would tear the
    // controller out while the route's exit animation still has the TextField
    // mounted and listening — the '_dependents.isEmpty' assertion crash.
    // A single-element list distinguishes "Done with a (possibly cleared)
    // value" from a scrim dismissal (null → no change).
    final result = await showModalBottomSheet<List<double?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      builder: (_) => _AmountEditor(initial: _lines[index].amount),
    );
    if (result != null && mounted) {
      setState(() => _lines[index].amount = result.first);
    }
  }
}

/// The amount-entry sheet body. A [StatefulWidget] so it owns its
/// [TextEditingController] for the widget's whole lifetime and disposes it in
/// [dispose] — which Flutter calls only after the route is fully gone, so the
/// TextField is never listening to a dead controller (the split-sheet crash).
class _AmountEditor extends StatefulWidget {
  const _AmountEditor({required this.initial});

  final double? initial;

  @override
  State<_AmountEditor> createState() => _AmountEditorState();
}

class _AmountEditorState extends State<_AmountEditor> {
  late final TextEditingController _controller = TextEditingController(
      text: (widget.initial == null || widget.initial == 0)
          ? ''
          : '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Empty input clears the line back to blank; typing is never blocked, so an
  // over-total figure is accepted and flagged by the sheet (spec §8).
  void _submit() =>
      Navigator.of(context).pop(<double?>[double.tryParse(_controller.text)]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).qaAmount, style: AppText.rowTitle),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                cursorColor: AppColors.accent,
                style: AppText.body.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.fieldCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(AppLocalizations.of(context).actionDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
