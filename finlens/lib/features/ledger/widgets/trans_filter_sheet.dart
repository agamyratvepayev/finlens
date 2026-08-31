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
    this.archived = false,
  });

  final String id;
  final String label;
  final int count;

  /// An archived tag still appears in the filter (past rows carry it), marked
  /// subtly rather than hidden (§6). Renders one step dimmer than a live entry.
  final bool archived;

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
    this.rich = false,
    this.hideEmpty = false,
    this.dot = false,
    this.truncateAt = 1 << 30,
    this.moreLabel,
    this.a11yLabel,
  });

  /// Snapshot key the selected ids live under (e.g. 'categories', 'tags').
  final String key;
  final String label;
  final FilterSectionKind kind;

  /// Whether each item shows its count (and dims to 40% when the count is 0).
  final bool showCount;

  /// Whether the header carries a `· n selected` count and a control. The
  /// *legacy* path (scoped sheet) draws a Select all / Clear text button; see
  /// [rich] for the truthful replacement.
  final bool showControls;

  /// Opt-in to the truthful header anatomy (spec §6/§7/§9): the count sits
  /// beside the label, the `[n selected ✕]` badge clears the section, the single
  /// right-hand link is `Select others` (invert), and the truncation strip moves
  /// inside the card. The scoped sheet leaves this false, so its chrome is
  /// byte-for-byte unchanged.
  final bool rich;

  /// Drop items whose count is 0 for the current context instead of dimming
  /// them (spec §1). A filter option guaranteed to return nothing is not an
  /// option. Off by default so the scoped sheet — which shows no counts — is
  /// untouched. The one exception: an already-selected item is always drawn
  /// (dimmed) even at count 0, so a hidden live filter never goes silent.
  final bool hideEmpty;

  /// Chips only: whether to draw the item's colour dot.
  final bool dot;

  /// Beyond this many items the section collapses behind a truncation strip
  /// (bypassed while an in-sheet query is active).
  final int truncateAt;

  /// Builds the `{n} more …` truncation-strip copy (rich sections only).
  final String Function(int hidden)? moreLabel;

  /// Long-form accessibility label for the header (rich sections); the visible
  /// [label] stays short so §7's one-line anatomy fits at 320pt.
  final String? a11yLabel;

  /// The items for the current direction context — counts already
  /// contextualised, order stable across direction changes. [direction] is null
  /// when the sheet has no DIRECTION block.
  final List<FilterChipItem> Function(TxnType? direction) itemsFor;
}

/// A single-select DIRECTION pill (main Ledger). [type] is never null now — the
/// `All` pseudo-option is gone (spec §5.2); the chips toggle, so re-tapping the
/// selected chip clears the direction.
class DirectionOption {
  const DirectionOption(this.label, this.type);
  final String label;
  final TxnType type;
}

/// An ordered slice of the sheet body.
sealed class FilterBlock {
  const FilterBlock();
}

class SectionFilterBlock extends FilterBlock {
  const SectionFilterBlock(this.section);
  final FilterSection section;
}

/// A single explanatory line rendered where a section would be, for a direction
/// that carries no such dimension (spec §5.3 — "Transfers have no category").
/// Renders nothing when [noteFor] returns null for the current direction.
class NoteFilterBlock extends FilterBlock {
  const NoteFilterBlock(this.noteFor);
  final String? Function(TxnType? direction) noteFor;
}

class AmountFilterBlock extends FilterBlock {
  const AmountFilterBlock({
    required this.rangeMin,
    required this.rangeMax,
    this.maxHint = '—',
    this.rangeHint,
    this.hintsFor,
  });

  final double rangeMin;
  final double rangeMax;

  /// Placeholder for an empty MAX field on the *legacy* (scoped) path ('—').
  final String maxHint;

  /// Optional caption under the fields on the legacy path (scoped shows the
  /// period's range).
  final String? rangeHint;

  /// Ledger opt-in (spec §10): direction-contextual, masked-aware placeholder
  /// and header strings. When set, MIN and MAX show the real window bounds, the
  /// range moves to the section header's right slot, and the caption is dropped;
  /// [maxHint]/[rangeHint] are ignored.
  final ({String min, String max, String? header}) Function(TxnType? direction)?
      hintsFor;
}

/// The in-progress filter the sheet owns and emits. [selections] is keyed by
/// each section's [FilterSection.key]; [direction] is the single-select
/// DIRECTION value (null == no direction block / cleared).
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
/// blocks, mapping the [FilterSnapshot] to and from [TransFilter]. None of the
/// Ledger-only capabilities (DIRECTION, hideEmpty, the rich header, real-bound
/// amount placeholders) is opted into here, so the scoped sheet renders exactly
/// as before.
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
/// search, row sections, per-item counts, the rich truthful header) is opt-in
/// through the parameters.
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

  Set<String> _selFor(String key) => _sel.putIfAbsent(key, () => {});

  bool get _querying =>
      widget.searchable && foldSearch(_query.trim()).isNotEmpty;

  FilterSection? _sectionByKey(String key) {
    for (final b in widget.blocks) {
      if (b is SectionFilterBlock && b.section.key == key) return b.section;
    }
    return null;
  }

  /// The raw working selection as a snapshot — the truth used for counting and
  /// the "is this filtering?" test. [drop] empties one section's selection for
  /// the derived-active test (spec §8).
  FilterSnapshot _rawSnapshot({String? drop}) => FilterSnapshot(
        direction: _direction,
        selections: {
          for (final e in _sel.entries)
            e.key: (e.key == drop ? <String>{} : {...e.value}),
        },
        min: _min,
        max: _max,
      );

  /// The snapshot handed to the caller (persisted / applied to the list behind).
  /// A section whose selection covers *every* item for the current direction is
  /// normalised to an empty set **iff** emptying it does not change the result
  /// (spec §8). That collapses a complete account selection (which never
  /// narrows anything) so a later-added account is not silently excluded, while
  /// leaving a complete *category* selection intact — emptying it would re-admit
  /// transfers/revaluations, so it is a real filter and must persist as one.
  FilterSnapshot _emitSnapshot() {
    final live = widget.matchCount(_rawSnapshot());
    final out = <String, Set<String>>{};
    for (final e in _sel.entries) {
      var ids = {...e.value};
      final section = _sectionByKey(e.key);
      if (section != null && ids.isNotEmpty) {
        final all = {for (final i in section.itemsFor(_direction)) i.id};
        final complete = all.isNotEmpty && ids.length == all.length &&
            ids.containsAll(all);
        if (complete &&
            widget.matchCount(_rawSnapshot(drop: e.key)) == live) {
          ids = {};
        }
      }
      out[e.key] = ids;
    }
    return FilterSnapshot(
      direction: _direction,
      selections: out,
      min: _min,
      max: _max,
    );
  }

  /// Every change applies immediately to the screen behind (spec §2) and
  /// redraws the sheet's own controls.
  void _apply(VoidCallback change, {bool haptic = true}) {
    if (haptic) HapticFeedback.selectionClick();
    setState(change);
    widget.onChanged(_emitSnapshot());
  }

  int get _liveCount => widget.matchCount(_rawSnapshot());

  /// Whether removing this section's selection would change the result (spec
  /// §8). Derived rather than declared: the old rule (`n > 0 && n < total`)
  /// guessed from the selection's shape and was wrong for categories and tags,
  /// where a complete selection still drops the rows that carry no category/tag
  /// at all. One extra count per section per build — at fixture size this is not
  /// measurable, and it is right for every section without a per-section flag.
  bool _sectionFilters(FilterSection s) {
    if (_selFor(s.key).isEmpty) return false;
    return widget.matchCount(_rawSnapshot(drop: s.key)) != _liveCount;
  }

  bool get _isActive =>
      _direction != null ||
      _min != null ||
      _max != null ||
      widget.blocks.any(
          (b) => b is SectionFilterBlock && _sectionFilters(b.section));

  bool get _rangeError => _min != null && _max != null && _min! > _max!;

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
        if (b is SectionFilterBlock &&
            b.section.kind == FilterSectionKind.rows)
          b.section.label.toLowerCase(),
    ];
    final l = AppLocalizations.of(context);
    return labels.isEmpty ? l.actionSearch : l.ldgSearchWithin(labels.join(', '));
  }

  /// Total item matches across the searchable (row) sections — the `N results`
  /// count shown on the field (spec §11).
  int _searchResultCount() {
    final folded = foldSearch(_query.trim());
    var n = 0;
    for (final b in widget.blocks) {
      if (b is! SectionFilterBlock) continue;
      final s = b.section;
      if (s.kind != FilterSectionKind.rows) continue;
      for (final i in _visibleBase(s)) {
        if (foldSearch(i.label).contains(folded)) n++;
      }
    }
    return n;
  }

  /// Whether a body block is drawn given the current query. While a query is
  /// active only the searchable (row) sections show — DIRECTION, TAGS, AMOUNT
  /// and the note line hide, because a query narrows *lists*, not transactions
  /// (spec §11).
  bool _showBlock(FilterBlock b) {
    if (_querying) {
      return b is SectionFilterBlock &&
          b.section.kind == FilterSectionKind.rows;
    }
    if (b is NoteFilterBlock) return b.noteFor(_direction) != null;
    return true;
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
                      if (widget.direction != null && !_querying)
                        _directionSection(),
                      for (final b in widget.blocks)
                        if (_showBlock(b)) _block(b),
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
          // placement and disabled treatment (spec §2).
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

  /// The header Reset — 35% opacity and non-interactive when nothing filters.
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
    final results = _querying ? _searchResultCount() : 0;
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
            if (_querying) ...[
              // The running result count across every searchable section (§11).
              Text(
                AppLocalizations.of(context).ldgNResults('$results'),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 6),
            ],
            if (_query.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // The field's own ✕ clears the query only (the header ✕ closes
                // the sheet).
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
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
        NoteFilterBlock() => _noteLine(b),
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
        _sectionLabel(AppLocalizations.of(context).ldgDirection.toUpperCase(),
            first: true),
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

  /// A DIRECTION pill (spec §5.2): the chips are toggles now — re-tapping the
  /// selected one clears the direction, so there is no separate `All` cell. The
  /// selected chip carries a trailing ✕ so the way back is visible where the
  /// selection is.
  Widget _dirChip(DirectionOption o) {
    final selected = _direction == o.type;
    final color = o.type.color;
    return GestureDetector(
      onTap: () =>
          _apply(() => _direction = _direction == o.type ? null : o.type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint(color, 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              o.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Opacity(
                opacity: 0.75,
                child: Icon(Icons.close_rounded,
                    size: 11, color: AppColors.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Note line (spec §5.3) ──────────────────────────────────────────────────

  Widget _noteLine(NoteFilterBlock b) {
    final text = b.noteFor(_direction);
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
      ),
    );
  }

  // ── Group / TAGS / row sections ────────────────────────────────────────────

  /// The section's items after [FilterSection.hideEmpty] but before any query —
  /// count-0 items are dropped unless selected (the live-filter exception, §1).
  List<FilterChipItem> _visibleBase(FilterSection s) {
    final all = s.itemsFor(_direction);
    if (!s.hideEmpty) return all;
    final sel = _selFor(s.key);
    return all.where((i) => i.count > 0 || sel.contains(i.id)).toList();
  }

  Widget _section(FilterSection s) {
    final folded = foldSearch(_query.trim());
    final querying = widget.searchable && folded.isNotEmpty;
    final base = _visibleBase(s);
    final items = querying
        ? base.where((i) => foldSearch(i.label).contains(folded)).toList()
        : base;

    // A section with no visible items disappears with its header (spec §1) — and
    // likewise while a query is active with no match.
    if (items.isEmpty) return const SizedBox.shrink();

    final selected = _selFor(s.key);
    final expanded = _expanded[s.key] ?? false;
    // Truncation is bypassed while querying so every match shows.
    final showAll = querying || expanded || items.length <= s.truncateAt;
    final shown = showAll ? items : items.take(s.truncateAt).toList();
    final hiddenItems = showAll ? const <FilterChipItem>[] : items.sublist(shown.length);
    final hiddenSelected =
        hiddenItems.where((i) => selected.contains(i.id)).length;

    final highlight = querying ? folded : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(s, items, selected),
        if (s.kind == FilterSectionKind.chips)
          _chips(s, shown, selected, highlight)
        else
          _rows(s, shown, selected, highlight,
              strip: (s.rich && hiddenItems.isNotEmpty)
                  ? _truncationStrip(s, hiddenItems.length, hiddenSelected)
                  : null),
        // Non-rich (legacy scoped) truncation, and rich *chips*, keep the strip
        // below the section. Rich *rows* carry it inside the card (above).
        if (hiddenItems.isNotEmpty &&
            !querying &&
            (!s.rich || s.kind == FilterSectionKind.chips))
          if (s.rich)
            _truncationStrip(s, hiddenItems.length, hiddenSelected)
          else
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 2),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded[s.key] = true),
                child: Text(
                  s.kind == FilterSectionKind.rows
                      ? AppLocalizations.of(context).ldgShowAll('${items.length}')
                      : '+${hiddenItems.length} more',
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

  /// The card-bottom / below-section truncation strip (spec §9): the *remaining*
  /// count, centred, quiet; a `· N selected` accent tail when hidden rows carry
  /// selections, so nothing is ever selected silently off-screen.
  Widget _truncationStrip(FilterSection s, int hidden, int hiddenSelected) {
    final more = s.moreLabel?.call(hidden) ?? '+$hidden more';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded[s.key] = true),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        margin: EdgeInsets.only(top: s.kind == FilterSectionKind.chips ? 4 : 0),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$more '),
              const TextSpan(text: '⌄'),
              if (hiddenSelected > 0)
                TextSpan(
                  text:
                      '  · ${AppLocalizations.of(context).ldgNHiddenSelected('$hiddenSelected')}',
                  style: const TextStyle(color: AppColors.accent),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
      FilterSection s, List<FilterChipItem> items, Set<String> selected) {
    if (s.rich) return _richHeader(s, items, selected);
    if (!s.showControls) return _sectionLabel(s.label);
    return _legacyControlHeader(s, selected.length);
  }

  /// Spec §7 anatomy: `LABEL · n [badge]` on the left, one link (`Select
  /// others`) or nothing on the right.
  Widget _richHeader(
      FilterSection s, List<FilterChipItem> items, Set<String> selected) {
    final l = AppLocalizations.of(context);
    final querying = widget.searchable && foldSearch(_query.trim()).isNotEmpty;

    // The count beside the label: item count normally, match count under query.
    final countText = querying ? l.ldgNMatches('${items.length}') : '${items.length}';

    // Completeness is measured against the section's full item list for the
    // current direction (the same list "all" would fill).
    final allIds = {for (final i in s.itemsFor(_direction)) i.id};
    final complete = allIds.isNotEmpty &&
        selected.length >= allIds.length &&
        allIds.every(selected.contains);

    // The visible ids the Select-others link inverts over (matches under a
    // query, every visible item otherwise). Shown only for a non-empty proper
    // subset — from empty it would be "select all" and from complete "clear".
    final visibleIds = [for (final i in items) i.id];
    final visSelected = visibleIds.where(selected.contains).length;
    final showOthers = visSelected > 0 && visSelected < visibleIds.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
      child: Row(
        children: [
          // Label and count are separate Text widgets (not one rich span) so
          // the count sits beside the label yet the label stays findable on its
          // own. The count belongs here, never pushed to the right edge where it
          // would align with the amount column and read as an amount (spec §7).
          Flexible(
            child: Semantics(
              label: s.a11yLabel,
              child: Text(
                s.label,
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
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text(
              '· $countText',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          // The badge is a button: tapping it clears only this section. Hidden
          // while a query is up (§7) — the selection it would clear may be
          // off-screen behind the query.
          if (selected.isNotEmpty && !querying) ...[
            const SizedBox(width: 6),
            _SectionBadge(
              label: complete
                  ? l.ldgAllSelected
                  : l.ldgNSelected('${selected.length}'),
              semanticsLabel: l.ldgClearSection(s.label),
              onTap: () => _apply(() => _selFor(s.key).clear()),
            ),
          ],
          const Spacer(),
          if (showOthers)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _apply(() {
                final sel = _selFor(s.key);
                for (final id in visibleIds) {
                  sel.contains(id) ? sel.remove(id) : sel.add(id);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  l.ldgSelectOthers,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The legacy scoped header — Select all / Clear + `· all` / `· n selected`.
  /// Kept byte-for-byte so the scoped sheet is unchanged.
  Widget _legacyControlHeader(FilterSection s, int selectedCount) {
    final all = s.itemsFor(_direction);
    final folded = foldSearch(_query.trim());
    final querying = widget.searchable && folded.isNotEmpty;
    final visibleIds = (querying
            ? all.where((i) => foldSearch(i.label).contains(folded))
            : all)
        .map((i) => i.id)
        .toList();

    final sel = _sel[s.key] ?? const <String>{};
    final complete = selectedCount > 0 && selectedCount >= all.length;
    final showClear = querying
        ? visibleIds.isNotEmpty && visibleIds.every(sel.contains)
        : selectedCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              s.label,
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
                  _apply(() => querying
                      ? _selFor(s.key).removeAll(visibleIds)
                      : _selFor(s.key).clear());
                } else {
                  _apply(() => _selFor(s.key).addAll(visibleIds));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  showClear
                      ? AppLocalizations.of(context).ldgClear
                      : AppLocalizations.of(context).ldgSelectAll,
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

  Widget _chips(FilterSection s, List<FilterChipItem> items, Set<String> sel,
      String? highlight) {
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final i in items)
          _FilterChip(
            label: i.label,
            highlight: highlight,
            selected: sel.contains(i.id),
            dotColor: s.dot ? i.color : null,
            count: s.showCount ? i.count : null,
            dim: (s.showCount && i.count == 0) || i.archived,
            onTap: () => _apply(() => _toggle(_selFor(s.key), i.id)),
          ),
      ],
    );
  }

  Widget _rows(FilterSection s, List<FilterChipItem> items, Set<String> sel,
      String? highlight,
      {Widget? strip}) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const RowDivider(indent: 48),
            _PickRow(
              item: items[i],
              highlight: highlight,
              selected: sel.contains(items[i].id),
              dim: items[i].count == 0,
              onTap: () => _apply(() => _toggle(_selFor(s.key), items[i].id)),
            ),
          ],
          if (strip != null) ...[
            const RowDivider(indent: 0),
            strip,
          ],
        ],
      ),
    );
  }

  static void _toggle(Set<String> set, String id) =>
      set.contains(id) ? set.remove(id) : set.add(id);

  // ── AMOUNT ─────────────────────────────────────────────────────────────────

  Widget _amountSection(AmountFilterBlock b) {
    final hints = b.hintsFor?.call(_direction);
    final minHint = hints?.min ?? '—';
    final maxHint = hints?.max ?? b.maxHint;
    final headerRange = hints?.header;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AMOUNT · $min – $max — the range moves here (spec §10), replacing the
        // separate caption below the fields.
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
          child: Row(
            children: [
              Text(
                l.ldgAmount.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.07 * 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (headerRange != null) ...[
                const Spacer(),
                Text(
                  headerRange,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _AmountField(
                key: const ValueKey('filter-min'),
                keyLabel: l.ldgMin.toUpperCase(),
                controller: _minCtrl,
                focusNode: _minFocus,
                focused: _minFocus.hasFocus,
                error: false,
                hint: minHint,
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
                keyLabel: l.ldgMax.toUpperCase(),
                controller: _maxCtrl,
                focusNode: _maxFocus,
                focused: _maxFocus.hasFocus,
                error: _rangeError,
                hint: maxHint,
                onChanged: (v) => _apply(() => _max = _parse(v), haptic: false),
              ),
            ),
          ],
        ),
        // Legacy caption (scoped only — the rich path carries the range in the
        // header instead).
        if (b.hintsFor == null && b.rangeHint != null)
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

/// The `[n selected ✕]` / `[all ✕]` pill in a rich section header — a button
/// that clears its section (spec §7).
class _SectionBadge extends StatelessWidget {
  const _SectionBadge({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: AppColors.tint(AppColors.accent, 0.16),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentLight,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.close_rounded,
                  size: 11, color: AppColors.accentLight),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label with the matched run highlighted behind [AppColors.accent] at 32%
/// (spec §11). Falls back to a plain [Text] when there is no query — so the row
/// stays findable by its label and only the search path pays for the rich span.
/// [foldSearch] preserves offsets 1:1, so the folded index is a valid offset
/// into the original label.
Widget _highlightLabel(
  String label,
  String? highlightFolded, {
  required TextStyle style,
  int? maxLines,
  TextOverflow overflow = TextOverflow.clip,
}) {
  final idx = (highlightFolded == null || highlightFolded.isEmpty)
      ? -1
      : foldSearch(label).indexOf(highlightFolded);
  if (idx < 0) {
    return Text(label, style: style, maxLines: maxLines, overflow: overflow);
  }
  final end = idx + highlightFolded!.length;
  return Text.rich(
    TextSpan(
      children: [
        if (idx > 0) TextSpan(text: label.substring(0, idx)),
        TextSpan(
          text: label.substring(idx, end),
          style: TextStyle(
            backgroundColor: AppColors.tint(AppColors.accent, 0.32),
          ),
        ),
        if (end < label.length) TextSpan(text: label.substring(end)),
      ],
    ),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlight,
    this.dotColor,
    this.count,
    this.dim = false,
  });

  final String label;
  final String? highlight;
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
                _highlightLabel(
                  label,
                  highlight,
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
    this.highlight,
  });

  final FilterChipItem item;
  final String? highlight;
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
              child: _highlightLabel(
                item.label,
                highlight,
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
    // stays live and the row remains selectable (the count-0-but-selected case).
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
