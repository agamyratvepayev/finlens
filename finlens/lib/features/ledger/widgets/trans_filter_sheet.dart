import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/models.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/search_fold.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../theme/app_colors.dart';
import '../trans_filter.dart';

/// One selectable value in a group / TAGS section.
class FilterChipItem {
  const FilterChipItem({
    required this.id,
    required this.label,
    required this.count,
    this.color,
    this.icon,
  });

  final String id;
  final String label;
  final int count;

  /// The category's own colour (accounts use their group's colour). Null for
  /// tags, which carry no dot.
  final Color? color;

  /// Only the row-kind sections (main-Ledger CATEGORIES/ACCOUNTS) draw a glyph.
  final IconData? icon;
}

/// How a [FilterSection] lays its items out.
enum FilterSectionKind {
  /// A [Wrap] of pill chips (scoped groups/tags, the TYPE row, main TAGS).
  chips,

  /// A card of icon rows with a trailing check (main CATEGORIES/ACCOUNTS).
  rows,
}

/// A generic, caller-controlled filter section. The sheet stores the selection
/// under [key] in its [FilterSnapshot]; the caller only describes how to render
/// the items and maps the resulting snapshot back to its own model.
class FilterSection {
  const FilterSection({
    required this.key,
    required this.label,
    required this.kind,
    required this.itemsFor,
    this.showCount = false,
    this.showControls = false,
    this.dot = false,
    this.truncateAt = 1 << 30,
  });

  /// Snapshot key the selected ids live under (e.g. 'categories', 'tags').
  final String key;
  final String label;
  final FilterSectionKind kind;

  /// Whether each item shows its count (and dims to 40% when the count is 0).
  final bool showCount;

  /// Whether the header carries a `· n selected` count and a Select all / Clear
  /// text button (spec §3).
  final bool showControls;

  /// Chips only: whether to draw the item's colour dot.
  final bool dot;

  /// Beyond this many items the section collapses behind a `Show all {n}` /
  /// `+{n} more` expander (bypassed while an in-sheet query is active).
  final int truncateAt;

  /// The items for the current direction context — counts already
  /// contextualised, order stable across direction changes. [direction] is null
  /// when the sheet has no DIRECTION block.
  final List<FilterChipItem> Function(TxnType? direction) itemsFor;
}

/// A single-select DIRECTION pill (main Ledger). [type] null == "All".
class DirectionOption {
  const DirectionOption(this.label, this.type);
  final String label;
  final TxnType? type;
}

/// An ordered slice of the sheet body.
sealed class FilterBlock {
  const FilterBlock();
}

class SectionFilterBlock extends FilterBlock {
  const SectionFilterBlock(this.section);
  final FilterSection section;
}

class AmountFilterBlock extends FilterBlock {
  const AmountFilterBlock({
    required this.rangeMin,
    required this.rangeMax,
    this.maxHint = '—',
    this.rangeHint,
  });

  final double rangeMin;
  final double rangeMax;

  /// Placeholder for an empty MAX field ('Any' on the main Ledger, '—' scoped).
  final String maxHint;

  /// Optional caption under the fields (scoped shows the period's range).
  final String? rangeHint;
}

/// The in-progress filter the sheet owns and emits. [selections] is keyed by
/// each section's [FilterSection.key]; [direction] is the single-select
/// DIRECTION value (null == All / no direction block).
@immutable
class FilterSnapshot {
  const FilterSnapshot({
    this.direction,
    this.selections = const {},
    this.min,
    this.max,
  });

  final TxnType? direction;
  final Map<String, Set<String>> selections;
  final double? min;
  final double? max;

  Set<String> sel(String key) => selections[key] ?? const {};

  bool get isActive =>
      direction != null ||
      min != null ||
      max != null ||
      selections.values.any((s) => s.isNotEmpty);
}

/// The scoped-ledger filter sheet (spec §2). Signature-compatible with the
/// original: the scoped call sites are unchanged. Internally it builds the
/// generic [showFilterSheet] with one group section + the TYPE / AMOUNT / TAGS
/// blocks, mapping the [FilterSnapshot] to and from [TransFilter].
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
  final l = AppLocalizations.of(context);
  final typeOptions = [
    (TxnType.expense, l.txnTypeExpense),
    (TxnType.income, l.txnTypeIncome),
    (TxnType.transfer, l.txnTypeTransfer),
  ];

  TransFilter fromSnapshot(FilterSnapshot s) => TransFilter(
        types: {
          for (final t in TxnType.values)
            if (s.sel('types').contains(t.name)) t,
        },
        groupIds: {...s.sel('group')},
        tags: {...s.sel('tags')},
        min: s.min,
        max: s.max,
      );

  return showFilterSheet(
    context,
    total: total,
    initial: FilterSnapshot(
      selections: {
        'types': {for (final t in initial.types) t.name},
        'group': {...initial.groupIds},
        'tags': {...initial.tags},
      },
      min: initial.min,
      max: initial.max,
    ),
    onChanged: (s) => onChanged(fromSnapshot(s)),
    matchCount: (s) {
      final f = fromSnapshot(s);
      return facts.where(f.matches).length;
    },
    blocks: [
      SectionFilterBlock(FilterSection(
        key: 'types',
        label: l.ldgType.toUpperCase(),
        kind: FilterSectionKind.chips,
        itemsFor: (_) => [
          for (final o in typeOptions)
            FilterChipItem(id: o.$1.name, label: o.$2, count: 0),
        ],
      )),
      SectionFilterBlock(FilterSection(
        key: 'group',
        label: groupSectionLabel,
        kind: FilterSectionKind.chips,
        dot: true,
        showControls: true,
        truncateAt: 8,
        itemsFor: (_) => groups,
      )),
      AmountFilterBlock(
        rangeMin: rangeMin,
        rangeMax: rangeMax,
        rangeHint: l.ldgRangeHint(money(rangeMin, signless: true),
            money(rangeMax, signless: true)),
      ),
      if (tags.isNotEmpty)
        SectionFilterBlock(FilterSection(
          key: 'tags',
          label: l.ldgTags.toUpperCase(),
          kind: FilterSectionKind.chips,
          showControls: true,
          itemsFor: (_) => tags,
        )),
    ],
  );
}

/// The unified filter sheet. Both the main Ledger and the scoped screens drive
/// it; every capability beyond the scoped baseline (DIRECTION row, in-sheet
/// search, row sections, per-item counts) is opt-in through the parameters.
Future<void> showFilterSheet(
  BuildContext context, {
  required List<FilterBlock> blocks,
  required FilterSnapshot initial,
  required int total,
  required ValueChanged<FilterSnapshot> onChanged,
  required int Function(FilterSnapshot) matchCount,
  List<DirectionOption>? direction,
  bool searchable = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _FilterSheet(
      blocks: blocks,
      initial: initial,
      total: total,
      onChanged: onChanged,
      matchCount: matchCount,
      direction: direction,
      searchable: searchable,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.blocks,
    required this.initial,
    required this.total,
    required this.onChanged,
    required this.matchCount,
    required this.direction,
    required this.searchable,
  });

  final List<FilterBlock> blocks;
  final FilterSnapshot initial;
  final int total;
  final ValueChanged<FilterSnapshot> onChanged;
  final int Function(FilterSnapshot) matchCount;
  final List<DirectionOption>? direction;
  final bool searchable;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  // Working state — the single source of truth while the sheet is open.
  TxnType? _direction;
  final Map<String, Set<String>> _sel = {};
  double? _min;
  double? _max;

  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();

  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Per-section expander state (keyed by [FilterSection.key]).
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _direction = widget.initial.direction;
    widget.initial.selections.forEach((k, v) => _sel[k] = {...v});
    _min = widget.initial.min;
    _max = widget.initial.max;
    _minCtrl = TextEditingController(text: _fmt(_min));
    _maxCtrl = TextEditingController(text: _fmt(_max));
    _minFocus.addListener(() => setState(() {}));
    _maxFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  FilterSnapshot _snapshot() => FilterSnapshot(
        direction: _direction,
        selections: {for (final e in _sel.entries) e.key: {...e.value}},
        min: _min,
        max: _max,
      );

  /// Every change applies immediately to the screen behind (spec §2) and
  /// redraws the sheet's own controls.
  void _apply(VoidCallback change, {bool haptic = true}) {
    if (haptic) HapticFeedback.selectionClick();
    setState(change);
    widget.onChanged(_snapshot());
  }

  int get _liveCount => widget.matchCount(_snapshot());

  /// A section narrows the list only when its selection is a *proper, non-empty
  /// subset* of the items available for the current direction. Both an empty
  /// selection and a complete one show every item, so neither is a filter —
  /// counting a complete selection as active is exactly the Select-all defect
  /// this removes: the list stays at "24 of 24" while Reset and the funnel light
  /// up over a selection that changed nothing.
  ///
  /// Completeness is measured against [FilterSection.itemsFor] — the same list
  /// Select all fills from — so the two can never disagree. A section with no
  /// items for the current direction has an empty selection (n == 0) and never
  /// filters, so a zero length is safe.
  ///
  /// Known limitation (accepted, per spec §1): a selection saved while complete
  /// is stored as an explicit id set, not as "all". If a category/account is
  /// created afterwards the stored set is no longer complete, so it silently
  /// becomes a real filter and hides the new item. On the Ledger tab this is
  /// short-lived — the filter is a session lens reset on every period change; on
  /// the scoped screens it persists. Normalising a complete selection to an
  /// empty one on write would fix it but would make Select all visibly inert
  /// again — the defect being removed — so the behaviour is left as-is.
  bool _sectionFilters(FilterSection s) {
    final n = _selFor(s.key).length;
    return n > 0 && n < s.itemsFor(_direction).length;
  }

  bool get _isActive =>
      _direction != null ||
      _min != null ||
      _max != null ||
      widget.blocks.any(
          (b) => b is SectionFilterBlock && _sectionFilters(b.section));

  bool get _rangeError => _min != null && _max != null && _min! > _max!;

  Set<String> _selFor(String key) => _sel.putIfAbsent(key, () => {});

  void _reset() {
    _minCtrl.clear();
    _maxCtrl.clear();
    _apply(() {
      _direction = null;
      for (final s in _sel.values) {
        s.clear();
      }
      _min = null;
      _max = null;
    });
  }

  double? _parse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String get _searchPlaceholder {
    final labels = [
      for (final b in widget.blocks)
        if (b is SectionFilterBlock) b.section.label.toLowerCase(),
    ];
    final l = AppLocalizations.of(context);
    return labels.isEmpty ? l.actionSearch : l.ldgSearchWithin(labels.join(', '));
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
                if (widget.searchable) _searchField(),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    children: [
                      if (widget.direction != null) _directionSection(),
                      for (final b in widget.blocks) _block(b),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 8, 8),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).filterTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Reset lives in the header — matching the Balance filter sheet's
          // placement and disabled treatment (spec §2). A dim text button reads
          // as "unavailable" here; dimming it in the footer beside the loud
          // filled button read as "broken", and hiding it there resized the
          // primary button on the first selection.
          _resetButton(),
          const SizedBox(width: 12),
          // Immediate-apply means there is no cancel: ✕ closes with the current
          // filter already applied — identical outcome to Show … .
          Semantics(
            button: true,
            label: AppLocalizations.of(context).actionClose,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.sheetCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The header Reset — same text style and accent as before, 35% opacity and
  /// non-interactive when nothing filters. Placement, size and disabled
  /// treatment match [balance_filter_sheet]'s header Reset (spec §2).
  Widget _resetButton() {
    final canReset = _isActive;
    return Semantics(
      button: true,
      enabled: canReset,
      label: AppLocalizations.of(context).ldgResetFilter,
      child: Opacity(
        opacity: canReset ? 1 : 0.35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canReset ? _reset : null,
          child: Text(
            AppLocalizations.of(context).actionReset,
            style: const TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.sheetCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('filter-search'),
                controller: _searchCtrl,
                cursorColor: AppColors.accent,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: _searchPlaceholder,
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
                // The query is sheet-local: it narrows the sections, never the
                // list behind, and is forgotten on close.
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // The field's own ✕ clears the query only (two controls, two
                // jobs — the header ✕ closes the sheet).
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _block(FilterBlock b) => switch (b) {
        SectionFilterBlock(:final section) => _section(section),
        AmountFilterBlock() => _amountSection(b),
      };

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

  // ── DIRECTION (main Ledger) ────────────────────────────────────────────────

  Widget _directionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(AppLocalizations.of(context).ldgDirection.toUpperCase(), first: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in widget.direction!) _dirChip(o),
          ],
        ),
      ],
    );
  }

  Widget _dirChip(DirectionOption o) {
    final selected = _direction == o.type;
    final color = o.type?.color ?? AppColors.accentSoft;
    return GestureDetector(
      onTap: () => _apply(() => _direction = o.type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint(color, 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          o.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Group / TAGS sections ──────────────────────────────────────────────────

  Widget _section(FilterSection s) {
    final all = s.itemsFor(_direction);
    final folded = foldSearch(_query.trim());
    final querying = widget.searchable && folded.isNotEmpty;
    final items = querying
        ? all.where((i) => foldSearch(i.label).contains(folded)).toList()
        : all;

    // A section with no matches hides entirely while a query is active.
    if (querying && items.isEmpty) return const SizedBox.shrink();

    final selected = _sel[s.key] ?? const {};
    final expanded = _expanded[s.key] ?? false;
    // Truncation is bypassed while querying so every match shows.
    final showAll = querying || expanded || items.length <= s.truncateAt;
    final shown = showAll ? items : items.take(s.truncateAt).toList();
    final hidden = items.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(s, selected.length, querying ? items.length : null),
        if (s.kind == FilterSectionKind.chips)
          _chips(s, shown, selected)
        else
          _rows(s, shown, selected),
        if (hidden > 0 && !querying)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded[s.key] = true),
              child: Text(
                s.kind == FilterSectionKind.rows
                    ? AppLocalizations.of(context).ldgShowAll('${items.length}')
                    : '+$hidden more',
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

  Widget _sectionHeader(FilterSection s, int selectedCount, int? matchCount) {
    if (!s.showControls) {
      return _sectionLabel(matchCount == null ? s.label : '${s.label} · $matchCount');
    }
    final all = s.itemsFor(_direction);
    final folded = foldSearch(_query.trim());
    final querying = widget.searchable && folded.isNotEmpty;
    // Select all / Clear target the *visible* items — every item normally, only
    // the matches while a query is active (spec §3/§4, the "select everything
    // named X" workflow).
    final visibleIds = (querying
            ? all.where((i) => foldSearch(i.label).contains(folded))
            : all)
        .map((i) => i.id)
        .toList();

    final sel = _sel[s.key] ?? const <String>{};
    // Complete against the same list Select all fills from, so "· all" and
    // "not a filter" (see [_sectionFilters]) agree. Partial otherwise.
    final complete = selectedCount > 0 && selectedCount >= all.length;
    // With a query up, the toggle follows the visible matches: Select all while
    // any visible match is unselected, Clear once they all are — mirroring how
    // the two operate. Without a query, any selection offers Clear (spec §4).
    final showClear = querying
        ? visibleIds.isNotEmpty && visibleIds.every(sel.contains)
        : selectedCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              matchCount == null ? s.label : '${s.label} · $matchCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.07 * 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              // "· all" over "· 14 selected": the number carries nothing when it
              // equals the total, and the word says this section isn't narrowing
              // anything (spec §4).
              child: Text(
                complete ? '· all' : '· $selectedCount selected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          const Spacer(),
          Semantics(
            button: true,
            label: showClear
                ? AppLocalizations.of(context).ldgClearSelection(s.label)
                : AppLocalizations.of(context).ldgSelectAllIn(s.label),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (showClear) {
                  // Clear only the visible matches under a query, so selections
                  // the query is hiding survive (spec §4); otherwise clear all.
                  _apply(() => querying
                      ? _selFor(s.key).removeAll(visibleIds)
                      : _selFor(s.key).clear());
                } else {
                  // Add (not replace) so selections hidden by the query survive:
                  // Select all adds the remaining visible matches only.
                  _apply(() => _selFor(s.key).addAll(visibleIds));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  showClear ? AppLocalizations.of(context).ldgClear : AppLocalizations.of(context).ldgSelectAll,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(FilterSection s, List<FilterChipItem> items, Set<String> sel) {
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final i in items)
          _FilterChip(
            label: i.label,
            selected: sel.contains(i.id),
            dotColor: s.dot ? i.color : null,
            count: s.showCount ? i.count : null,
            dim: s.showCount && i.count == 0,
            onTap: () => _apply(() => _toggle(_selFor(s.key), i.id)),
          ),
      ],
    );
  }

  Widget _rows(FilterSection s, List<FilterChipItem> items, Set<String> sel) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const RowDivider(indent: 48),
            _PickRow(
              item: items[i],
              selected: sel.contains(items[i].id),
              dim: items[i].count == 0,
              onTap: () => _apply(() => _toggle(_selFor(s.key), items[i].id)),
            ),
          ],
        ],
      ),
    );
  }

  static void _toggle(Set<String> set, String id) =>
      set.contains(id) ? set.remove(id) : set.add(id);

  // ── AMOUNT ─────────────────────────────────────────────────────────────────

  Widget _amountSection(AmountFilterBlock b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(AppLocalizations.of(context).ldgAmount.toUpperCase()),
        Row(
          children: [
            Expanded(
              child: _AmountField(
                key: const ValueKey('filter-min'),
                keyLabel: AppLocalizations.of(context).ldgMin.toUpperCase(),
                controller: _minCtrl,
                focusNode: _minFocus,
                focused: _minFocus.hasFocus,
                error: false,
                hint: '—',
                onChanged: (v) => _apply(() => _min = _parse(v), haptic: false),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—',
                  style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
            ),
            Expanded(
              child: _AmountField(
                key: const ValueKey('filter-max'),
                keyLabel: AppLocalizations.of(context).ldgMax.toUpperCase(),
                controller: _maxCtrl,
                focusNode: _maxFocus,
                focused: _maxFocus.hasFocus,
                error: _rangeError,
                hint: b.maxHint,
                onChanged: (v) => _apply(() => _max = _parse(v), haptic: false),
              ),
            ),
          ],
        ),
        if (b.rangeHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              b.rangeHint!,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }

  // ── Sticky footer ──────────────────────────────────────────────────────────

  Widget _footer() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final l = AppLocalizations.of(context);
    // When the result is everything the button's only job is to close, so it
    // says Done; the count returns the moment it means something (spec §3).
    // Keyed off the outcome (_liveCount), not _isActive, on purpose: an amount
    // range that happens to match every transaction leaves Reset live (a filter
    // is set) while the button reads Done (the result is everything).
    final label = _liveCount < widget.total
        ? l.ldgShowCountOf('$_liveCount', '${widget.total}')
        : l.actionDone;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(16, 11, 16, 13 + bottom),
      child: SizedBox(
        width: double.infinity,
        height: 47,
        child: FilledButton(
          // Closing on a zero result is legitimate — the list's empty state
          // explains — so the button stays enabled at 0.
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
    this.count,
    this.dim = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;
  final int? count;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final chip = Semantics(
      button: true,
      toggled: selected,
      label: count == null ? label : '$label, $count',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 4pt transparent inset provides the 8pt inter-row gap (see original).
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '· $count',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // Zero-count items dim to 40% but stay selectable.
    return dim ? Opacity(opacity: 0.4, child: chip) : chip;
  }
}

/// One CATEGORIES / ACCOUNTS row (main Ledger): glyph, name, count, check.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.item,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  final FilterChipItem item;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconTile(
              item.icon ?? Icons.circle,
              color: item.color ?? AppColors.textTertiary,
              size: 30,
              iconSize: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${item.count}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
    // Dim the visuals only — Opacity does not absorb taps, so the InkWell
    // stays live and the row remains selectable (spec §4/§5).
    return dim ? Opacity(opacity: 0.4, child: row) : row;
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    super.key,
    required this.keyLabel,
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.error,
    required this.hint,
    required this.onChanged,
  });

  final String keyLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool error;
  final String hint;
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
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textTertiary),
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
