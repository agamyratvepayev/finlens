import 'package:flutter/material.dart';

import '../../core/persistence/sync_store.dart';
import '../../core/sync/store_diff.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

/// The queued sync conflicts, one card each: what the record is, who edited
/// the other side, and the user's mine/theirs choice — the resolution model
/// the user picked over last-writer-wins. Reads the conflict rows async and
/// re-reads after every resolution.
class ConflictScreen extends StatefulWidget {
  const ConflictScreen({super.key});

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen> {
  List<ConflictRow>? _conflicts;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final sync = SyncScope.read(context);
    final rows = await sync.syncStore.readConflicts();
    if (!mounted) return;
    setState(() => _conflicts = rows);
  }

  Future<void> _resolve(ConflictRow conflict, {required bool keepMine}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final sync = SyncScope.read(context);
    await sync.engine?.resolveConflict(conflict, keepMine: keepMine);
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
  }

  Future<void> _resolveAll({required bool keepMine}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final sync = SyncScope.read(context);
    for (final conflict in _conflicts ?? const <ConflictRow>[]) {
      await sync.engine?.resolveConflict(conflict, keepMine: keepMine);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final conflicts = _conflicts;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.syncConflictsTitle,
              showBack: true,
              showEye: false,
              showAdd: false,
            ),
            Expanded(
              child: conflicts == null
                  ? const SizedBox.shrink()
                  : conflicts.isEmpty
                      ? Center(
                          child: Text(
                            l.syncConflictEmpty,
                            style: AppText.body
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(top: Insets.sm),
                          children: [
                            if (conflicts.length > 1)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    Insets.gutter, 0, Insets.gutter, Insets.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _BulkButton(
                                        label: l.syncConflictKeepAllMine,
                                        onTap: _busy
                                            ? null
                                            : () => _resolveAll(keepMine: true),
                                      ),
                                    ),
                                    const SizedBox(width: Insets.sm),
                                    Expanded(
                                      child: _BulkButton(
                                        label: l.syncConflictKeepAllTheirs,
                                        onTap: _busy
                                            ? null
                                            : () =>
                                                _resolveAll(keepMine: false),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final conflict in conflicts)
                              _ConflictCard(
                                conflict: conflict,
                                busy: _busy,
                                onKeepMine: () =>
                                    _resolve(conflict, keepMine: true),
                                onKeepTheirs: () =>
                                    _resolve(conflict, keepMine: false),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  const _BulkButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontSize: 13,
              color: onTap == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.busy,
    required this.onKeepMine,
    required this.onKeepTheirs,
  });

  final ConflictRow conflict;
  final bool busy;
  final VoidCallback onKeepMine;
  final VoidCallback onKeepTheirs;

  /// A human line for a record payload: names for named entities, amount+date
  /// for transactions. Falls back to the record id.
  String _summary(Map<String, Object?>? payload) {
    if (payload == null) return conflict.recordId;
    switch (conflict.entityType) {
      case EntityTypes.txn:
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
        final currency = payload['currency'] as String? ?? '';
        final ms = payload['date'] as int?;
        final date =
            ms == null ? '' : _shortDate(DateTime.fromMillisecondsSinceEpoch(ms));
        final note = payload['note'] as String? ?? '';
        final head = '${money(amount, currency: currency)} · $date';
        return note.isEmpty ? head : '$head · $note';
      case EntityTypes.task:
        return payload['title'] as String? ?? conflict.recordId;
      case EntityTypes.meta:
        return conflict.recordId;
      default:
        return payload['name'] as String? ?? conflict.recordId;
    }
  }

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = _summary(conflict.localPayload ?? conflict.remotePayload);
    final editor = conflict.remoteUpdatedBy ?? '';

    final String remoteLine;
    if (conflict.remoteDeleted) {
      remoteLine = l.syncConflictDeletedRemote(editor);
    } else if (conflict.localDeleted) {
      remoteLine = '${l.syncConflictDeletedLocal} · '
          '${l.syncConflictEditedBy(editor)}';
    } else {
      remoteLine = l.syncConflictEditedBy(editor);
    }

    return AppCard(
      margin:
          const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.body.copyWith(
                  fontSize: 14.5, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              remoteLine,
              style: AppText.caption.copyWith(fontSize: 11.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: _BulkButton(
                    label: l.syncConflictKeepMine,
                    onTap: busy ? null : onKeepMine,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _BulkButton(
                    label: l.syncConflictKeepTheirs,
                    onTap: busy ? null : onKeepTheirs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
