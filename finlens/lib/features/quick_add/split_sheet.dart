import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'pickers.dart';

/// One line of a split: a category and its share of the payment.
class SplitLine {
  SplitLine({this.categoryId, this.amount = 0});

  String? categoryId;
  double amount;

  SplitLine copy() => SplitLine(categoryId: categoryId, amount: amount);
}

/// Cent-rounding tolerance for money equality. The app has no shared epsilon
/// (formatters round to cents), so this mirrors that: two figures are equal
/// when they agree to the nearest cent (spec §2 — reuse the existing rounding).
const double kMoneyEpsilon = 0.005;

/// Divides [total] across [n] lines, giving any rounding remainder to the
/// **first** line so the sum stays exact (spec §2/§5). Works in integer cents.
List<double> splitEvenly(double total, int n) {
  if (n <= 0) return const [];
  final totalCents = (total * 100).round();
  final base = totalCents ~/ n;
  final remainder = totalCents - base * n;
  return [
    for (var i = 0; i < n; i++) ((i == 0 ? base + remainder : base)) / 100,
  ];
}

double splitAssigned(List<SplitLine> lines) =>
    lines.fold(0.0, (sum, l) => sum + l.amount);

double splitRemaining(double total, List<SplitLine> lines) =>
    total - splitAssigned(lines);

/// A split is applicable only with ≥2 lines, every line a real (category +
/// positive amount), and a remainder of exactly zero (spec §2).
bool splitBalanced(double total, List<SplitLine> lines) {
  if (lines.length < 2) return false;
  if (lines.any((l) => l.categoryId == null || l.amount <= 0)) return false;
  return splitRemaining(total, lines).abs() < kMoneyEpsilon;
}

/// Opens the split editor. Returns the applied lines (Apply), an empty list
/// (Remove split), or null (cancelled — no change).
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
  late final bool _wasApplied = widget.initial.length >= 2;
  late final List<SplitLine> _lines = widget.initial.isEmpty
      ? [SplitLine(), SplitLine()]
      : [for (final l in widget.initial) l.copy()];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final remaining = splitRemaining(widget.total, _lines);
    final balanced = splitBalanced(widget.total, _lines);
    final zero = remaining.abs() < kMoneyEpsilon;

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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _linesCard(store),
                    _remainingRow(remaining, zero),
                    _helpers(),
                  ],
                ),
              ),
            ),
            _applyButton(balanced),
            if (_wasApplied)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(<SplitLine>[]),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Remove split',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.negative)),
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Split by category',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    'Total ${money(widget.total, currency: widget.currency)} · '
                    '${widget.accountName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const Text('Done',
                  style: TextStyle(fontSize: 14.5, color: AppColors.accent)),
            ),
          ],
        ),
      );

  Widget _linesCard(AppStore store) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
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
              _lineRow(store, i),
            ],
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            _addRow(),
          ],
        ),
      );

  Widget _lineRow(AppStore store, int index) {
    final line = _lines[index];
    final category = store.categoryById(line.categoryId);
    final color = category?.color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: category == null
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
                final c = await pickCategory(context, type: widget.categoryType);
                if (c != null && mounted) {
                  setState(() => line.categoryId = c.id);
                }
              },
              child: Text(
                category?.name ?? 'Choose category',
                style: TextStyle(
                  fontSize: 14.5,
                  color: category == null
                      ? AppColors.textTertiary
                      : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editAmount(index),
            child: Text(
              money(line.amount, currency: widget.currency),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              color: AppColors.textTertiary,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _lines.removeAt(index)),
              tooltip: 'Remove line',
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow() => InkWell(
        onTap: () => setState(() => _lines.add(SplitLine())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              _DashedTile(
                size: 30,
                color: AppColors.accent,
                child: const Icon(Icons.add_rounded,
                    size: 16, color: AppColors.accentLight),
              ),
              const SizedBox(width: 10),
              const Text('Add category',
                  style: TextStyle(fontSize: 14.5, color: AppColors.accentLight)),
            ],
          ),
        ),
      );

  Widget _remainingRow(double remaining, bool zero) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            const Text('Remaining',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Semantics(
              liveRegion: true,
              child: Text(
                money(remaining, currency: widget.currency, showSign: true),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: zero ? AppColors.positive : AppColors.negative,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _helpers() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(
          children: [
            Expanded(child: _helper('Split evenly', _splitEvenly)),
            const SizedBox(width: 8),
            Expanded(child: _helper('Rest to last', _restToLast)),
          ],
        ),
      );

  Widget _helper(String label, VoidCallback onTap) => Material(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Center(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.accentLight)),
            ),
          ),
        ),
      );

  Widget _applyButton(bool enabled) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: enabled
                  ? 'Apply split'
                  : 'Apply split, unavailable until the remaining is zero',
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
                child: const Text('Apply split',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );

  void _splitEvenly() {
    final shares = splitEvenly(widget.total, _lines.length);
    setState(() {
      for (var i = 0; i < _lines.length; i++) {
        _lines[i].amount = shares[i];
      }
    });
  }

  void _restToLast() {
    if (_lines.isEmpty) return;
    final others = _lines
        .sublist(0, _lines.length - 1)
        .fold(0.0, (sum, l) => sum + l.amount);
    setState(() => _lines.last.amount =
        ((widget.total - others) * 100).round() / 100);
  }

  Future<void> _editAmount(int index) async {
    final controller = TextEditingController(
        text: _lines[index].amount == 0 ? '' : '${_lines[index].amount}');
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: AppText.rowTitle),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
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
                  onSubmitted: (v) =>
                      Navigator.of(sheetContext).pop(double.tryParse(v)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext)
                        .pop(double.tryParse(controller.text)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _lines[index].amount = value);
    }
  }
}

/// A dashed rounded-square tile (the "+ Add category" glyph holder).
class _DashedTile extends StatelessWidget {
  const _DashedTile({required this.size, required this.color, required this.child});

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedSquarePainter(color: color, radius: 9),
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      );
}

class _DashedSquarePainter extends CustomPainter {
  const _DashedSquarePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSquarePainter old) => old.color != color;
}
