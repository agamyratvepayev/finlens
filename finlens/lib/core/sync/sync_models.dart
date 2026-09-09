/// Plain data types for the sync API — hand-written like every model in the
/// app (no codegen).
library;

class AuthUser {
  const AuthUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
        id: '${json['id']}',
        email: json['email'] as String,
        name: json['name'] as String?,
      );
}

class GroupMember {
  const GroupMember({
    required this.email,
    required this.role,
    required this.status,
  });

  final String email;
  final String role; // 'owner' | 'member'
  final String status; // 'invited' | 'active'

  bool get isOwner => role == 'owner';
  bool get isActive => status == 'active';

  factory GroupMember.fromJson(Map<String, Object?> json) => GroupMember(
        email: json['email'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
      );
}

class GroupInfo {
  const GroupInfo({required this.id, required this.role, required this.members});

  final String id;
  final String role;
  final List<GroupMember> members;

  bool get isOwner => role == 'owner';

  factory GroupInfo.fromJson(Map<String, Object?> json) => GroupInfo(
        id: '${json['id']}',
        role: json['role'] as String,
        members: (json['members'] as List? ?? const [])
            .map((m) => GroupMember.fromJson((m as Map).cast<String, Object?>()))
            .toList(),
      );
}

class PendingInvite {
  const PendingInvite({
    required this.groupId,
    required this.ownerEmail,
    this.ownerName,
  });

  final String groupId;
  final String ownerEmail;
  final String? ownerName;

  factory PendingInvite.fromJson(Map<String, Object?> json) => PendingInvite(
        groupId: '${json['groupId']}',
        ownerEmail: json['ownerEmail'] as String,
        ownerName: json['ownerName'] as String?,
      );
}

/// One local change to push: the record's current `*ToMap` payload plus the
/// server version it was based on (0 = new record).
class RecordChange {
  const RecordChange({
    required this.entityType,
    required this.recordId,
    required this.baseVersion,
    required this.deleted,
    this.payload,
  });

  final String entityType;
  final String recordId;
  final int baseVersion;
  final bool deleted;
  final Map<String, Object?>? payload;

  Map<String, Object?> toJson() => {
        'entityType': entityType,
        'recordId': recordId,
        'baseVersion': baseVersion,
        'deleted': deleted,
        if (payload != null) 'payload': payload,
      };
}

/// A server-acknowledged write.
class AppliedRecord {
  const AppliedRecord({
    required this.entityType,
    required this.recordId,
    required this.version,
  });

  final String entityType;
  final String recordId;
  final int version;

  factory AppliedRecord.fromJson(Map<String, Object?> json) => AppliedRecord(
        entityType: json['entityType'] as String,
        recordId: json['recordId'] as String,
        version: json['version'] as int,
      );
}

/// The server's side of a version conflict, shown to the user for resolution.
class RemoteConflict {
  const RemoteConflict({
    required this.entityType,
    required this.recordId,
    required this.serverVersion,
    required this.serverDeleted,
    this.serverPayload,
    this.updatedByEmail,
    this.updatedAt,
  });

  final String entityType;
  final String recordId;
  final int serverVersion;
  final bool serverDeleted;
  final Map<String, Object?>? serverPayload;
  final String? updatedByEmail;
  final DateTime? updatedAt;

  factory RemoteConflict.fromJson(Map<String, Object?> json) => RemoteConflict(
        entityType: json['entityType'] as String,
        recordId: json['recordId'] as String,
        serverVersion: json['serverVersion'] as int,
        serverDeleted: json['serverDeleted'] as bool,
        serverPayload: (json['serverPayload'] as Map?)?.cast<String, Object?>(),
        updatedByEmail: json['updatedByEmail'] as String?,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

/// A record pulled from the server (someone else's change, or the echo of our
/// own push — the engine's shadow makes echoes no-ops).
class RemoteChange {
  const RemoteChange({
    required this.entityType,
    required this.recordId,
    required this.version,
    required this.deleted,
    this.payload,
  });

  final String entityType;
  final String recordId;
  final int version;
  final bool deleted;
  final Map<String, Object?>? payload;

  factory RemoteChange.fromJson(Map<String, Object?> json) => RemoteChange(
        entityType: json['entityType'] as String,
        recordId: json['recordId'] as String,
        version: json['version'] as int,
        deleted: json['deleted'] as bool,
        payload: (json['payload'] as Map?)?.cast<String, Object?>(),
      );
}

class SyncResponse {
  const SyncResponse({
    required this.cursor,
    required this.applied,
    required this.conflicts,
    required this.changes,
  });

  final int cursor;
  final List<AppliedRecord> applied;
  final List<RemoteConflict> conflicts;
  final List<RemoteChange> changes;

  factory SyncResponse.fromJson(Map<String, Object?> json) => SyncResponse(
        cursor: json['cursor'] as int,
        applied: (json['applied'] as List? ?? const [])
            .map((e) => AppliedRecord.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        conflicts: (json['conflicts'] as List? ?? const [])
            .map((e) =>
                RemoteConflict.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        changes: (json['changes'] as List? ?? const [])
            .map((e) => RemoteChange.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );
}

class SignInResult {
  const SignInResult({
    required this.token,
    required this.user,
    required this.invites,
  });

  final String token;
  final AuthUser user;
  final List<PendingInvite> invites;
}

class MeResult {
  const MeResult({required this.user, this.group, required this.invites});

  final AuthUser user;
  final GroupInfo? group;
  final List<PendingInvite> invites;
}

/// Where the sync stack currently stands, for the More screen's status line.
enum SyncStatus { signedOut, idle, syncing, offline, error, conflicts }
