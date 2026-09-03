import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The multi-select tag picker (§2). Replaces Quick Add's single free-text
/// field: it selects several existing tags, creates new ones inline, and shows
/// the running selection as removable chips.
///
/// Ordering is by `lastUsedAt`, newest first — never by count. A tag used thirty
/// times last year is useless today; the one used yesterday is not, so recency
/// lets finished tags sink on their own. Archived tags never appear here — that
/// is precisely what archiving means.
///
/// The ceiling on tags per transaction (§7). A tagged transaction is counted
/// under every tag it carries, so tag-by-tag totals overcount as the count per
/// transaction rises; and without a ceiling nothing stops a wall of labels that
/// mean nothing. At the cap the unselected rows and the create row disable —
/// dimmed, not removed — so a swap is still two taps.
const int kMaxTagsPerTxn = 5;

/// Selections apply as they are made (through [onChanged]); Done only closes.
Future<void> showTagPicker(
  BuildContext context, {
  required Set<String> selected,
  required ValueChanged<Set<String>> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TagPickerSheet(initial: selected, onChanged: onChanged),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.initial, required this.onChanged});

  final Set<String> initial;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late final Set<String> _selected = {...widget.initial};
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _atCap => _selected.length >= kMaxTagsPerTxn;

  void _emit() => widget.onChanged({..._selected});

  void _toggle(String id) {
    // Deselecting is always allowed; selecting a new one is refused at the cap
    // (§7). The row is already disabled there — this guards a stray tap.
    final selecting = !_selected.contains(id);
    if (selecting && _atCap) return;
    setState(() {
      selecting ? _selected.add(id) : _selected.remove(id);
    });
    _emit();
  }

  void _create(AppStore store, String raw) {
    if (_atCap) return; // create auto-selects, so it too is capped (§7)
    final tag = store.createTag(raw);
    if (tag == null) return;
    setState(() {
      _selected.add(tag.id);
      _searchCtrl.clear();
      _query = '';
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);

    // One O(n) pass for the per-tag usage counts, not a query per row.
    final counts = store.tagUsageCounts();

    final q = _query.trim();
    final folded = foldTag(q);
    final active = store.activeTags; // newest use first, archived excluded
    final matches = q.isEmpty
        ? active
        : active.where((t) => foldTag(t.name).contains(folded)).toList();
    final exactActive = active.any((t) => foldTag(t.name) == folded);
    final showCreate = q.isNotEmpty && !exactActive;

    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.82;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                _header(l),
                _chips(store),
                const SizedBox(height: Insets.md),
                _searchField(l),
                const SizedBox(height: Insets.sm),
                Flexible(
                  child: _list(store, l, matches, counts,
                      showCreate: showCreate, createText: q),
                ),
                // At the cap, one line explains why the unselected rows and the
                // create row went dim — silently ignoring taps is forbidden (§7).
                if (_atCap) ...[
                  const SizedBox(height: Insets.sm),
                  Text(
                    l.tagCapReached,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textTertiary),
                  ),
                ],
                const SizedBox(height: Insets.md),
                _doneButton(l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    return Row(
      children: [
        Text(
          l.tagsTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        // Empty on the right when nothing is selected — not "0 selected" (§2).
        if (_selected.isNotEmpty)
          Text(
            l.tagSelectedCount(_selected.length),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  /// The selected chips row. Absent when nothing is selected; the sheet reserves
  /// nothing for it and animates the first chip in, so the layout never jumps.
  Widget _chips(AppStore store) {
    final tags = <Tag>[
      for (final id in _selected) ?store.tagById(id),
    ];
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: tags.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: Insets.md),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in tags) _chip(t)],
              ),
            ),
    );
  }

  Widget _chip(Tag t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(t.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 5, 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '#${t.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.accentLight),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.close_rounded,
                size: 14, color: AppColors.accentLight),
          ],
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textTertiary),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textCapitalization: TextCapitalization.none,
              style: AppText.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l.tagSearchOrCreate,
                hintStyle: const TextStyle(
                    fontSize: 15, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    AppStore store,
    AppLocalizations l,
    List<Tag> matches,
    Map<String, int> counts, {
    required bool showCreate,
    required String createText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: matches.length + (showCreate ? 1 : 0),
        itemBuilder: (context, i) {
          if (showCreate && i == 0) {
            return _createRow(store, l, createText);
          }
          final t = matches[i - (showCreate ? 1 : 0)];
          return _tagRow(t, counts[t.id] ?? 0);
        },
      ),
    );
  }

  Widget _createRow(AppStore store, AppLocalizations l, String text) {
    // Disabled at the cap: shown, dimmed, non-tappable — never removed (§7).
    final disabled = _atCap;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: disabled ? null : () => _create(store, text),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  l.tagCreate(text.trim().replaceFirst(RegExp(r'^#'), '')),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagRow(Tag t, int count) {
    final selected = _selected.contains(t.id);
    // Unselected rows disable at the cap; selected rows stay tappable so a swap
    // is two taps (§7).
    final disabled = _atCap && !selected;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: disabled ? null : () => _toggle(t.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
          children: [
            Expanded(
              child: Text(
                '#${t.name}',
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              '$count',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(width: Insets.sm),
            SizedBox(
              width: 20,
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.accent)
                  : null,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _doneButton(AppLocalizations l) {
    return SizedBox(
      height: 47,
      child: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(l.actionDone,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
