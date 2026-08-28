import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/store/app_store.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../balance/balance_screen.dart' show EmptyState;

/// More → Tags (§3). Sits directly beneath Categories and matches its row shape.
///
/// Two sections — IN USE, then ARCHIVED. Archiving takes a tag out of circulation
/// without touching its transactions: they keep it and keep matching it in the
/// filter. That reversible, lossless move is why in-use tags offer Archive, not
/// Delete — Delete appears only for a tag on no transactions, where it costs
/// nothing (§4).
class TagManagementScreen extends StatelessWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = AppLocalizations.of(context);
    final inUse = store.activeTags;
    final archived = store.archivedTags;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.tagsTitle,
              showBack: true,
              showEye: false,
              onAdd: () => _showCreateSheet(context, store),
            ),
            Expanded(
              child: (inUse.isEmpty && archived.isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: EmptyState(
                        icon: Icons.tag_rounded,
                        title: l.tagsTitle,
                        message: l.tagArchiveFootnote,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: Insets.xxl),
                      children: [
                        if (inUse.isNotEmpty) ...[
                          SectionLabel(l.tagSectionInUse),
                          _card([for (final t in inUse) _row(context, store, t)]),
                        ],
                        if (archived.isNotEmpty) ...[
                          SectionLabel(l.tagSectionArchived),
                          _card([
                            for (final t in archived) _row(context, store, t),
                          ]),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.gutter,
                            Insets.md,
                            Insets.gutter,
                            0,
                          ),
                          child: Text(
                            l.tagArchiveFootnote,
                            style: AppText.caption.copyWith(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> rows) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const RowDivider(indent: Insets.md),
                rows[i],
              ],
            ],
          ),
        ),
      );

  Widget _row(BuildContext context, AppStore store, Tag tag) {
    final l = AppLocalizations.of(context);
    final count = store.txnCountForTag(tag.id);
    final subtitle = count == 0
        ? l.tagNeverUsed
        : l.tagUsageLine(count, dayMonth(tag.lastUsedAt, l));
    final row = InkWell(
      onTap: () => _showTagActions(context, store, tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.md, vertical: Insets.md),
        child: Row(
          children: [
            IconTile(Icons.tag_rounded, color: AppColors.tagDot, size: 34),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${tag.name}',
                    style: AppText.rowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.rowSubtitle.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
    // An archived tag renders the whole card at 45% opacity (§3).
    return tag.archived ? Opacity(opacity: 0.45, child: row) : row;
  }
}

// ── Row action sheet (§4) ─────────────────────────────────────────────────────

Future<void> _showTagActions(
    BuildContext context, AppStore store, Tag tag) async {
  final l = AppLocalizations.of(context);
  final count = store.txnCountForTag(tag.id);
  final canDelete = count == 0;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Insets.sm),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
              child: Text('#${tag.name}', style: AppText.rowTitle),
            ),
            const RowDivider(indent: 0),
            _action(
              sheetContext,
              icon: Icons.edit_rounded,
              label: l.tagActionRename,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameSheet(context, store, tag);
              },
            ),
            // Archived: Restore, plus Delete only when unused.
            // In use (active), ≥1 txn: Archive (reversible, lossless).
            // In use (active), 0 txn: Delete — a typo costs nothing (§4).
            if (tag.archived)
              _action(
                sheetContext,
                icon: Icons.unarchive_rounded,
                label: l.actionRestore,
                onTap: () {
                  store.restoreTag(tag);
                  Navigator.of(sheetContext).pop();
                },
              ),
            if (!tag.archived && !canDelete)
              _action(
                sheetContext,
                icon: Icons.archive_rounded,
                label: l.tagActionArchive,
                onTap: () {
                  store.archiveTag(tag);
                  Navigator.of(sheetContext).pop();
                },
              ),
            if (canDelete)
              _action(
                sheetContext,
                icon: Icons.delete_outline_rounded,
                label: l.actionDelete,
                destructive: true,
                onTap: () {
                  store.deleteTag(tag);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      );
    },
  );
}

Widget _action(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool destructive = false,
}) {
  final color = destructive ? AppColors.negative : AppColors.textPrimary;
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.gutter, vertical: Insets.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Insets.md),
          Text(label, style: AppText.body.copyWith(color: color, fontSize: 16)),
        ],
      ),
    ),
  );
}

// ── Rename + merge sheet (§5) ─────────────────────────────────────────────────

void _showRenameSheet(BuildContext context, AppStore store, Tag tag) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RenameTagSheet(store: store, tag: tag),
  );
}

void _showCreateSheet(BuildContext context, AppStore store) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RenameTagSheet(store: store, tag: null),
  );
}

/// One sheet for both create (tag == null) and rename/merge. Kept together so the
/// `#`-prefixed field, the sanitiser and the merge warning have a single home.
class _RenameTagSheet extends StatefulWidget {
  const _RenameTagSheet({required this.store, required this.tag});

  final AppStore store;
  final Tag? tag;

  @override
  State<_RenameTagSheet> createState() => _RenameTagSheetState();
}

class _RenameTagSheetState extends State<_RenameTagSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.tag?.name ?? '');
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.tag?.name ?? '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Strip a single leading `#`; reject empty or any further `#` (§7).
  String? _sanitize(String raw) {
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    s = s.trim();
    if (s.isEmpty || s.contains('#')) return null;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final creating = widget.tag == null;
    final clean = _sanitize(_text);
    final valid = clean != null;

    // Merge is only possible when renaming an existing tag onto a *different*
    // existing tag's folded name (§5).
    final Tag? mergeTarget =
        (!creating && valid) ? widget.store.mergeTargetFor(widget.tag!, clean) : null;
    final merging = mergeTarget != null;
    final mergeCount =
        merging ? widget.store.txnCountForTag(mergeTarget.id) : 0;

    final title = creating
        ? l.tagNewTitle
        : l.tagRenameTitle(widget.tag!.name);
    final buttonLabel = merging
        ? l.tagMergeButton(mergeTarget.name)
        : (creating ? l.actionSave : l.tagActionRename);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.md, Insets.gutter, Insets.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.rowTitle),
                if (!creating) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.tagRenameSubtitle(widget.store.txnCountForTag(widget.tag!.id)),
                    style: AppText.caption,
                  ),
                ],
                const SizedBox(height: Insets.md),
                _field(l),
                // The merge warning is announced before the button (§8): it
                // precedes the button in the tree and is a Semantics liveRegion.
                if (merging) ...[
                  const SizedBox(height: Insets.md),
                  _mergeWarning(l, mergeTarget.name, mergeCount),
                ],
                const SizedBox(height: Insets.lg),
                SizedBox(
                  height: 47,
                  child: FilledButton(
                    onPressed: valid ? () => _submit(clean) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          merging ? AppColors.warning : AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Text('#',
              style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) => setState(() => _text = v),
              onSubmitted: (_) {
                final c = _sanitize(_text);
                if (c != null) _submit(c);
              },
              style: AppText.body.copyWith(fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l.tagNameHint,
                hintStyle: const TextStyle(
                    fontSize: 16, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mergeWarning(AppLocalizations l, String target, int count) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.warning),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                l.tagMergeWarning(target, count),
                style: AppText.caption.copyWith(
                    color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(String clean) {
    if (widget.tag == null) {
      widget.store.createTag(clean);
    } else {
      widget.store.renameTag(widget.tag!, clean);
    }
    Navigator.of(context).pop();
  }
}
