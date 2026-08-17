import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/models.dart';
import '../../../core/utils/formatters.dart';
import '../../../theme/app_colors.dart';
import '../trans_filter.dart';

/// One selectable value in the CATEGORIES/ACCOUNTS or TAGS section.
class FilterChipItem {
  const FilterChipItem({
    required this.id,
    required this.label,
    required this.count,
    this.color,
  });

  final String id;
  final String label;
  final int count;

  /// The category's own colour (accounts use their group's colour). Null for
  /// tags, which carry no dot.
  final Color? color;
}

/// The scoped-ledger filter sheet (spec §2). No Apply/Cancel: every change is
/// pushed to [onChanged] immediately and applied to the screen behind; `Done`
/// only closes. The live count and the empty [Reset] disabling are computed
/// from [facts], the resolved facts of the screen's current period rows.
Future<void> showTransFilterSheet(
  BuildContext context, {
  required String groupSectionLabel,
  required List<FilterChipItem> groups,
  required List<FilterChipItem> tags,
  required double rangeMin,
  required double rangeMax,
  required int total,
  required List<TxnFacts> facts,
  required TransFilter initial,
  required ValueChanged<TransFilter> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _TransFilterSheet(
      groupSectionLabel: groupSectionLabel,
      groups: groups,
      tags: tags,
      rangeMin: rangeMin,
      rangeMax: rangeMax,
      total: total,
      facts: facts,
      initial: initial,
      onChanged: onChanged,
    ),
  );
}

class _TransFilterSheet extends StatefulWidget {
  const _TransFilterSheet({
    required this.groupSectionLabel,
    required this.groups,
    required this.tags,
    required this.rangeMin,
    required this.rangeMax,
    required this.total,
    required this.facts,
    required this.initial,
    required this.onChanged,
  });

  final String groupSectionLabel;
  final List<FilterChipItem> groups;
  final List<FilterChipItem> tags;
  final double rangeMin;
  final double rangeMax;
  final int total;
  final List<TxnFacts> facts;
  final TransFilter initial;
  final ValueChanged<TransFilter> onChanged;

  @override
  State<_TransFilterSheet> createState() => _TransFilterSheetState();
}

class _TransFilterSheetState extends State<_TransFilterSheet> {
  late TransFilter _filter = widget.initial;
  late final TextEditingController _minCtrl =
      TextEditingController(text: _fmt(_filter.min));
  late final TextEditingController _maxCtrl =
      TextEditingController(text: _fmt(_filter.max));
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();
  bool _groupsExpanded = false;

  @override
  void initState() {
    super.initState();
    _minFocus.addListener(() => setState(() {}));
    _maxFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  void _apply(TransFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  int get _liveCount => widget.facts.where(_filter.matches).length;

  bool get _rangeError =>
      _filter.min != null && _filter.max != null && _filter.min! > _filter.max!;

  void _reset() {
    _minCtrl.clear();
    _maxCtrl.clear();
    _apply(TransFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: ColoredBox(
            color: AppColors.surfaceAlt,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _grabber(),
                _header(),
                _liveCountLine(),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    children: [
                      _typeSection(),
                      _groupSection(),
                      _amountSection(),
                      if (widget.tags.isNotEmpty) _tagSection(),
                    ],
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.sheetGrabber,
          borderRadius: BorderRadius.circular(999),
        ),
      );

  Widget _header() {
    final canReset = _filter.isActive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 4),
      child: Row(
        children: [
          const Text(
            'Filter',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            enabled: canReset,
            label: 'Reset filter',
            child: Opacity(
              opacity: canReset ? 1 : 0.35,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canReset ? _reset : null,
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveCountLine() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          child: Text(
            '$_liveCount of ${widget.total} transactions',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.fromLTRB(2, first ? 8 : 13, 2, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.07 * 11,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _typeSection() {
    const labels = {
      TxnType.expense: 'Expense',
      TxnType.income: 'Income',
      TxnType.transfer: 'Transfer',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TYPE', first: true),
        _ChipWrap(
          children: [
            for (final e in labels.entries)
              _FilterChip(
                label: e.value,
                selected: _filter.types.contains(e.key),
                horizontalPadding: 11,
                onTap: () => _apply(_filter.toggleType(e.key)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _groupSection() {
    if (widget.groups.isEmpty) return const SizedBox.shrink();
    final showAll = _groupsExpanded || widget.groups.length <= 8;
    final shown = showAll ? widget.groups : widget.groups.take(8).toList();
    final hidden = widget.groups.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(widget.groupSectionLabel),
        _ChipWrap(
          children: [
            for (final g in shown)
              _FilterChip(
                label: g.label,
                selected: _filter.groupIds.contains(g.id),
                horizontalPadding: 10,
                dotColor: g.color,
                onTap: () => _apply(_filter.toggleGroup(g.id)),
              ),
          ],
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _groupsExpanded = true),
              child: Text(
                '+$hidden more',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _amountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('AMOUNT'),
        Row(
          children: [
            Expanded(
              child: _AmountField(
                keyLabel: 'MIN',
                controller: _minCtrl,
                focusNode: _minFocus,
                focused: _minFocus.hasFocus,
                error: false,
                onChanged: (v) => _apply(_filter.withMin(_parse(v))),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            ),
            Expanded(
              child: _AmountField(
                keyLabel: 'MAX',
                controller: _maxCtrl,
                focusNode: _maxFocus,
                focused: _maxFocus.hasFocus,
                // The MAX is the bound below the MIN, so it carries the error.
                error: _rangeError,
                onChanged: (v) => _apply(_filter.withMax(_parse(v))),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            'Transactions here range '
            '${money(widget.rangeMin, signless: true)} – '
            '${money(widget.rangeMax, signless: true)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _tagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TAGS'),
        _ChipWrap(
          children: [
            for (final t in widget.tags)
              _FilterChip(
                label: t.label,
                selected: _filter.tags.contains(t.id),
                horizontalPadding: 11,
                onTap: () => _apply(_filter.toggleTag(t.id)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _footer() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(16, 11, 16, 13 + bottom),
      child: SizedBox(
        width: double.infinity,
        height: 47,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  double? _parse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
}

/// A Wrap whose 6pt column gap and 8pt row gap follow spec §2. Row spacing is
/// achieved through each chip's 4pt transparent top/bottom inset (see
/// [_FilterChip]) with `runSpacing: 0`, so the extended hit areas meet inside
/// the 8pt gap without overlapping — the reason the gap must not shrink to 6.
class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 0, children: children);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.horizontalPadding,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final double horizontalPadding;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 4pt transparent inset top+bottom: a ~24pt chip below the comfortable
        // tap size grows to a 32pt hit area, and the two insets provide the 8pt
        // inter-row gap (spec §2).
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.sheetCard,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.sheetAccountName,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.keyLabel,
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.error,
    required this.onChanged,
  });

  final String keyLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.negative
        : (focused ? AppColors.accent : Colors.transparent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sheetCard,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Text(
            keyLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              cursorColor: AppColors.accent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '—',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
