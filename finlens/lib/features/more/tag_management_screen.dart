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
import '../quick_add/pickers.dart';

/// More → Tags (§4). Every tag is a chip, not a row: the 34 pt purple tile the
/// old rows carried was identical on every tag and so said nothing — the name is
/// the content, and a name is a chip. Two `Wrap`s — IN USE (ending in a dashed
/// "+ New" chip) and ARCHIVED (at 45 % opacity, absent when empty).
///
/// Tapping a chip opens the edit sheet directly (§4.2): the old two-sheet
/// tap → actions → rename detour is gone. The row subtitle it dropped
/// (`3 transactions · last 2 Aug`) reappears in that sheet, where it is the
/// reason the destructive control says Archive rather than Delete.
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
            // The header `+` is gone — the create chip replaces it (§4.1).
            ScreenHeader(
              title: l.tagsTitle,
              showBack: true,
              showEye: false,
              showAdd: false,
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
                        SectionLabel(l.tagSectionInUse),
                        _wrap(context, [
                          for (final t in inUse)
                            _TagChip(
                              tag: t,
                              onTap: () => _showEditTag(context, store, t),
                            ),
                          _NewTagChip(
                            onTap: () => _showCreateTag(context, store),
                          ),
                        ]),
                        if (archived.isNotEmpty) ...[
                          SectionLabel(l.tagSectionArchived),
                          Opacity(
                            opacity: 0.45,
                            child: _wrap(context, [
                              for (final t in archived)
                                _TagChip(
                                  tag: t,
                                  onTap: () => _showEditTag(context, store, t),
                                ),
                            ]),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Insets.gutter, Insets.md, Insets.gutter, 0),
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

  Widget _wrap(BuildContext context, List<Widget> chips) => Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.gutter, Insets.sm, Insets.gutter, 0),
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
}

/// A tag chip: `#name` on a pill of [AppColors.chipBg], the `#` in
/// [AppColors.tagDot].
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onTap});

  final Tag tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '#${tag.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '#',
                  style: TextStyle(color: AppColors.tagDot, fontSize: 13.5),
                ),
                TextSpan(
                  text: tag.name,
                  style: const TextStyle(
                      color: AppColors.chipText, fontSize: 13.5),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// The create chip, last in the IN USE wrap (§4.1): a dashed accent pill + "New".
class _NewTagChip extends StatelessWidget {
  const _NewTagChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).tagNewTitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: CustomPaint(
          painter: _DashedPillPainter(color: AppColors.accent),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 15, color: AppColors.accent),
                SizedBox(width: 3),
                Text('New',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed 1 pt pill border — Flutter has no dashed border built in.
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;
  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

// ── Create + edit sheets (§4.2 / §5) ─────────────────────────────────────────

void _showCreateTag(BuildContext context, AppStore store) {
  final l = AppLocalizations.of(context);
  showAppSheet<void>(
    context,
    title: l.tagNewTitle,
    initialSize: 0.55,
    cancelLabel: l.actionCancel,
    builder: (context, controller) =>
        _TagSheetBody(store: store, tag: null, controller: controller),
  );
}

void _showEditTag(BuildContext context, AppStore store, Tag tag) {
  final l = AppLocalizations.of(context);
  showAppSheet<void>(
    context,
    title: l.tagEditTitle,
    initialSize: 0.55,
    cancelLabel: l.actionCancel,
    builder: (context, controller) =>
        _TagSheetBody(store: store, tag: tag, controller: controller),
  );
}

/// One body for create (tag == null) and edit. Edit adds the usage caption and
/// the destructive control; an archived tag's name field is read-only, because
/// renaming it would silently relabel transactions already filed under it — the
/// same reasoning as the locked category Type (§3.1/§5).
class _TagSheetBody extends StatefulWidget {
  const _TagSheetBody({
    required this.store,
    required this.tag,
    required this.controller,
  });

  final AppStore store;
  final Tag? tag;
  final ScrollController controller;

  @override
  State<_TagSheetBody> createState() => _TagSheetBodyState();
}

class _TagSheetBodyState extends State<_TagSheetBody> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.tag?.name ?? '');
  String _text = '';

  bool get _creating => widget.tag == null;
  bool get _archived => widget.tag?.archived ?? false;

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

  /// Strip a single leading `#`; reject empty or any further `#`.
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
    final store = widget.store;
    final tag = widget.tag;
    final clean = _sanitize(_text);
    final valid = clean != null;

    // Merge only when renaming an existing tag onto a *different* existing tag.
    final Tag? mergeTarget = (!_creating && valid && !_archived)
        ? store.mergeTargetFor(tag!, clean)
        : null;
    final merging = mergeTarget != null;

    final count = tag == null ? 0 : store.txnCountForTag(tag.id);
    final used = count > 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
            children: [
              _field(l),
              if (!_creating) ...[
                const SizedBox(height: Insets.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    used ? l.tagUsageLine(count, dayMonth(tag!.lastUsedAt, l))
                         : l.tagNeverUsed,
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
              if (merging) ...[
                const SizedBox(height: Insets.md),
                _mergeWarning(l, mergeTarget.name, store.txnCountForTag(mergeTarget.id)),
              ],
              if (!_creating) ...[
                const SizedBox(height: Insets.lg),
                if (_archived) ...[
                  _actionRow(
                    label: l.tagRestoreThis,
                    color: AppColors.accentSoft,
                    onTap: () {
                      store.restoreTag(tag!);
                      Navigator.of(context).pop();
                    },
                  ),
                  if (!used)
                    _actionRow(
                      label: l.actionDeletePermanent,
                      color: AppColors.negative,
                      onTap: () {
                        store.deleteTag(tag!);
                        Navigator.of(context).pop();
                      },
                    ),
                ] else if (used)
                  _actionRow(
                    label: l.tagArchiveThis,
                    color: AppColors.negative,
                    subtitle: l.tagArchiveMsg(count),
                    onTap: () {
                      store.archiveTag(tag!);
                      Navigator.of(context).pop();
                    },
                  )
                else
                  _actionRow(
                    label: l.tagDeleteThis,
                    color: AppColors.negative,
                    subtitle: l.tagDeleteMsg,
                    onTap: () {
                      store.deleteTag(tag!);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ],
          ),
        ),
        // Save is offered for create and for a live rename/merge; an archived
        // tag's name can't change, so it has no Save.
        if (!_archived)
          _footer(
            label: merging
                ? l.tagMergeButton(mergeTarget.name)
                : l.actionSave,
            color: merging ? AppColors.warning : AppColors.accent,
            enabled: valid,
            onPressed: () => _submit(clean!),
          ),
      ],
    );
  }

  Widget _field(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Text('#',
              style: TextStyle(fontSize: 16, color: AppColors.tagDot)),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: !_archived,
              readOnly: _archived,
              enabled: !_archived,
              onChanged: (v) => setState(() => _text = v),
              onSubmitted: (_) {
                final c = _sanitize(_text);
                if (c != null && !_archived) _submit(c);
              },
              style: AppText.body.copyWith(fontSize: 16),
              cursorColor: AppColors.accentSoft,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l.tagNameHint,
                hintStyle:
                    const TextStyle(fontSize: 16, color: AppColors.textTertiary),
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
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required String label,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.md, vertical: Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: AppText.body.copyWith(
                              fontSize: 14.5,
                              color: color,
                              fontWeight: FontWeight.w500)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: AppText.caption.copyWith(fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter,
          Insets.md + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: AppColors.surfaceHigh,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppText.button,
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
