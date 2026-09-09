import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/persistence/backup_codec.dart';
import '../../core/store/app_store.dart';
import '../../core/sync/api_client.dart';
import '../../core/sync/sync_controller.dart';
import '../../core/sync/sync_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/destructive_sheet.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/screen_header.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'conflict_screen.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// More ▸ Account: who is signed in, the sync status + manual "Sync now", and
/// the family group — activate it, invite members by email, accept an invite
/// (with the automatic pre-join backup), leave. All state comes from
/// [SyncScope]; the engine is reached through the controller.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _inviteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _apiErrorText(AppLocalizations l, Object error) {
    if (error is SyncApiException) {
      return error.kind == SyncApiErrorKind.network
          ? l.syncErrorNetwork
          : l.syncErrorGeneric;
    }
    return l.syncErrorGeneric;
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(_apiErrorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final l = AppLocalizations.of(context);
    final sync = SyncScope.read(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.syncSignOutConfirmTitle,
      message: l.syncSignOutConfirmMsg,
      impact: const [],
      confirmLabel: l.syncSignOut,
    );
    if (!ok || !mounted) return;
    await _guarded(() async {
      await sync.signOut();
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _activateGroup() => _guarded(() async {
        final sync = SyncScope.read(context);
        await sync.createGroup();
        // The empty shadow makes the first sync the initial upload of the
        // owner's existing records.
        await sync.engine?.initialPush();
      });

  Future<void> _invite() async {
    final l = AppLocalizations.of(context);
    final email = _inviteController.text.trim();
    if (!_emailRe.hasMatch(email)) {
      _toast(l.syncEmailInvalid);
      return;
    }
    await _guarded(() async {
      await SyncScope.read(context).addMember(email);
      _inviteController.clear();
      if (mounted) _toast(l.syncMemberAdded);
    });
  }

  Future<void> _removeMember(GroupMember member) async {
    final l = AppLocalizations.of(context);
    final sync = SyncScope.read(context);
    final ok = await showDestructiveConfirm(
      context,
      title: l.syncRemoveMemberTitle(member.email),
      message: l.syncRemoveMemberMsg,
      impact: const [],
      confirmLabel: l.syncRemove,
    );
    if (!ok || !mounted) return;
    await _guarded(() => sync.removeMember(member.email));
  }

  Future<void> _leaveGroup({required bool isOwner}) async {
    final l = AppLocalizations.of(context);
    final sync = SyncScope.read(context);
    final ok = await showDestructiveConfirm(
      context,
      title: isOwner ? l.syncDeleteGroup : l.syncLeaveGroup,
      message: isOwner ? l.syncDeleteGroupMsg : l.syncLeaveGroupMsg,
      impact: const [],
      confirmLabel: isOwner ? l.syncDeleteGroup : l.syncLeaveGroup,
    );
    if (!ok || !mounted) return;
    await _guarded(() => sync.leaveGroup());
  }

  /// Accept an invite: back the current data up to a user-chosen file first
  /// (skipped when the store is empty; cancelling the save aborts the join),
  /// then replace it with the group's records.
  Future<void> _acceptInvite(PendingInvite invite) async {
    final l = AppLocalizations.of(context);
    final store = StoreScope.read(context);
    final sync = SyncScope.read(context);

    final ok = await showDestructiveConfirm(
      context,
      title: l.syncJoinWarnTitle,
      message: l.syncJoinWarnMsg,
      impact: const [],
      confirmLabel: l.syncJoinAction,
    );
    if (!ok || !mounted) return;

    final hasData = store.snapshotAccounts.isNotEmpty ||
        store.snapshotTxns.isNotEmpty ||
        store.snapshotCategories.isNotEmpty ||
        store.snapshotGoals.isNotEmpty ||
        store.snapshotTasks.isNotEmpty ||
        store.snapshotTags.isNotEmpty;
    if (hasData) {
      final now = DateTime.now();
      final stamp = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final path = await FilePicker.saveFile(
        dialogTitle: l.moreBackup,
        fileName: 'finlens-pre-join-$stamp.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(
          utf8.encode(encodeBackup(store, exportedAt: now)),
        ),
      );
      // Cancelling the safety backup cancels the join — replacing data with
      // no copy anywhere is exactly the accident this dialog exists to stop.
      if (path == null || !mounted) return;
    }

    await _guarded(() async {
      await sync.acceptInvite(invite.groupId);
      await sync.engine?.initialPullReplace();
    });
  }

  Future<void> _declineInvite(PendingInvite invite) =>
      _guarded(() => SyncScope.read(context).declineInvite(invite.groupId));

  // ── build ─────────────────────────────────────────────────────────────────

  static String _timeStamp(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _statusLine(AppLocalizations l, SyncController sync) {
    switch (sync.status) {
      case SyncStatus.syncing:
        return l.syncStatusSyncing;
      case SyncStatus.offline:
        return l.syncStatusOffline;
      case SyncStatus.error:
        return l.syncStatusError;
      case SyncStatus.conflicts:
        return l.syncConflictsTitle;
      case SyncStatus.signedOut:
      case SyncStatus.idle:
        final at = sync.lastSyncedAt;
        return at == null ? l.syncStatusIdle : l.syncLastSynced(_timeStamp(at));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sync = SyncScope.of(context);
    final group = sync.group;
    final isOwner = group?.isOwner ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: l.syncAccountTitle,
              showBack: true,
              showEye: false,
              showAdd: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: Insets.sm),
                children: [
                  // Account.
                  SectionLabel(l.moreAccount),
                  FormSection(children: [
                    FormRow(
                      icon: Icons.account_circle_rounded,
                      label: sync.user?.email ?? '',
                      subtitle: sync.user?.name,
                    ),
                  ]),

                  // Pending invites.
                  for (final invite in sync.invites) ...[
                    SectionLabel(l.syncInviteTitle),
                    FormSection(children: [
                      FormRow(
                        icon: Icons.mail_rounded,
                        label: l.syncInviteBody(
                            invite.ownerName ?? invite.ownerEmail),
                        subtitle: invite.ownerEmail,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, 0, Insets.md, Insets.md),
                        child: Row(children: [
                          Expanded(
                            child: _ActionButton(
                              label: l.syncAcceptInvite,
                              accent: true,
                              onTap:
                                  _busy ? null : () => _acceptInvite(invite),
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: _ActionButton(
                              label: l.syncDeclineInvite,
                              onTap:
                                  _busy ? null : () => _declineInvite(invite),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ],

                  // Sync status + manual sync + conflicts (in-group only).
                  if (group != null) ...[
                    SectionLabel(l.syncNow),
                    if (sync.conflictCount > 0)
                      GestureDetector(
                        onTap: () => Navigator.of(context, rootNavigator: true)
                            .push(MaterialPageRoute(
                          builder: (_) => const ConflictScreen(),
                        )),
                        child: NoticeBanner(
                          text: l.syncConflictsBanner(sync.conflictCount),
                        ),
                      ),
                    FormSection(children: [
                      FormRow(
                        icon: Icons.sync_rounded,
                        label: l.syncNow,
                        subtitle: _statusLine(l, sync),
                        onTap: _busy || sync.status == SyncStatus.syncing
                            ? null
                            : () => SyncScope.read(context).engine?.syncNow(),
                      ),
                    ]),
                  ],

                  // Group.
                  SectionLabel(l.syncGroupTitle),
                  if (group == null)
                    FormSection(children: [
                      FormRow(
                        icon: Icons.group_add_rounded,
                        label: l.syncActivateGroup,
                        subtitle: l.syncActivateGroupDesc,
                        onTap: _busy ? null : _activateGroup,
                        showChevron: true,
                      ),
                    ])
                  else ...[
                    FormSection(children: [
                      for (final member in group.members)
                        FormRow(
                          icon: member.isOwner
                              ? Icons.star_rounded
                              : Icons.person_rounded,
                          label: member.email,
                          value: member.isActive
                              ? l.syncMemberActive
                              : l.syncMemberInvited,
                          valueColor: member.isActive
                              ? AppColors.positive
                              : AppColors.textTertiary,
                          onTap: isOwner && !member.isOwner && !_busy
                              ? () => _removeMember(member)
                              : null,
                        ),
                      if (isOwner)
                        TextFieldRow(
                          icon: Icons.person_add_alt_rounded,
                          label: l.syncAddMember,
                          controller: _inviteController,
                          hint: l.syncAddMemberHint,
                          trailing: IconButton(
                            icon: const Icon(Icons.send_rounded,
                                size: 18, color: AppColors.accent),
                            onPressed: _busy ? null : _invite,
                          ),
                        ),
                    ]),
                    DestructiveRow(
                      label: isOwner ? l.syncDeleteGroup : l.syncLeaveGroup,
                      onTap: () => _leaveGroup(isOwner: isOwner),
                    ),
                  ],

                  // Sign out.
                  DestructiveRow(
                    label: l.syncSignOut,
                    onTap: _signOut,
                  ),
                  const SizedBox(height: Insets.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact filled button pair (Accept/Decline) — token colours only, sized
/// for two-across at 320 pt.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.onTap, this.accent = false});

  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        decoration: BoxDecoration(
          color: accent ? AppColors.accent : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.body.copyWith(
              fontSize: 13,
              color: onTap == null
                  ? AppColors.textTertiary
                  : (accent ? Colors.white : AppColors.textPrimary),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
