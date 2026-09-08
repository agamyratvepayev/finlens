import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../persistence/sync_store.dart';
import 'api_client.dart';
import 'sync_config.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

/// Auth + group state for the sync feature, deliberately OUTSIDE [AppStore]:
/// the persister snapshots the whole database on every AppStore notification,
/// and a syncing/offline status flicker must not trigger full DB rewrites.
/// Distributed via [SyncScope], mirroring StoreScope's `of`/`read` contract.
class SyncController extends ChangeNotifier {
  SyncController(this._syncStore, this._api);

  final SyncStore _syncStore;
  final SyncApiClient _api;

  String? _token;
  AuthUser? _user;
  GroupInfo? _group;
  List<PendingInvite> _invites = const [];
  SyncStatus _status = SyncStatus.signedOut;
  DateTime? _lastSyncedAt;
  int _conflictCount = 0;
  bool _googleReady = false;

  String? get token => _token;
  AuthUser? get user => _user;
  GroupInfo? get group => _group;
  List<PendingInvite> get invites => _invites;
  SyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get conflictCount => _conflictCount;
  bool get isSignedIn => _token != null;
  bool get isInGroup => _group != null;

  SyncStore get syncStore => _syncStore;
  SyncApiClient get api => _api;

  /// Set once in `main()` after both objects exist (the engine also needs the
  /// controller, so neither can own the other in its constructor). Null only
  /// in the brief window before wiring completes.
  SyncEngine? engine;

  /// Restores the persisted session (token, group id/role, last-synced stamp)
  /// so the UI opens signed-in without a network round-trip. Fresh membership
  /// state arrives later via [refresh].
  Future<void> hydrate() async {
    _token = await _syncStore.getMeta(SyncStore.kAuthToken);
    final email = await _syncStore.getMeta(SyncStore.kUserEmail);
    final groupId = await _syncStore.getMeta(SyncStore.kGroupId);
    final role = await _syncStore.getMeta(SyncStore.kGroupRole);
    final lastSynced = await _syncStore.getMeta(SyncStore.kLastSyncedAt);
    if (_token != null && email != null) {
      _user = AuthUser(
        id: '',
        email: email,
        name: await _syncStore.getMeta(SyncStore.kUserName),
      );
      if (groupId != null && role != null) {
        _group = GroupInfo(id: groupId, role: role, members: const []);
      }
      _status = SyncStatus.idle;
    }
    if (lastSynced != null) {
      _lastSyncedAt =
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(lastSynced) ?? 0);
    }
    _conflictCount = (await _syncStore.readConflicts()).length;
    notifyListeners();
  }

  Future<void> _ensureGoogleInit() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
    );
    _googleReady = true;
  }

  /// Interactive "Continue with Google". Returns the pending invites so the
  /// caller can immediately offer them. Throws [SyncApiException] on API
  /// failure and [GoogleSignInException] when the Google flow itself fails.
  Future<List<PendingInvite>> signIn() async {
    await _ensureGoogleInit();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const SyncApiException(
          SyncApiErrorKind.server, 'Google returned no id-token');
    }
    final result = await _api.signInWithGoogle(idToken);
    _token = result.token;
    _user = result.user;
    _invites = result.invites;
    _status = SyncStatus.idle;
    await _syncStore.setMeta(SyncStore.kAuthToken, result.token);
    await _syncStore.setMeta(SyncStore.kUserEmail, result.user.email);
    await _syncStore.setMeta(SyncStore.kUserName, result.user.name);
    notifyListeners();
    await refresh();
    return _invites;
  }

  /// Drops the session. Local data stays untouched — the store simply stops
  /// syncing. Group bookkeeping is cleared so a different account cannot push
  /// into the previous account's group.
  Future<void> signOut() async {
    try {
      await _ensureGoogleInit();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google sign-out is best-effort; the server token is what matters.
    }
    _token = null;
    _user = null;
    _group = null;
    _invites = const [];
    _status = SyncStatus.signedOut;
    _conflictCount = 0;
    await _syncStore.setMeta(SyncStore.kAuthToken, null);
    await _syncStore.setMeta(SyncStore.kUserEmail, null);
    await _syncStore.setMeta(SyncStore.kUserName, null);
    await _syncStore.clearGroupState();
    notifyListeners();
  }

  /// Re-fetches user/group/invites from the server. Network failures leave the
  /// hydrated state in place (offline-first).
  Future<void> refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final me = await _api.me(token);
      _user = me.user;
      _invites = me.invites;
      await _applyGroup(me.group);
      notifyListeners();
    } on SyncApiException catch (e) {
      if (e.kind == SyncApiErrorKind.unauthorized) {
        await _handleUnauthorized();
      }
      // network/server: keep whatever we had.
    }
  }

  Future<GroupInfo> createGroup() async {
    final group = await _api.createGroup(_requireToken());
    await _applyGroup(group);
    notifyListeners();
    return group;
  }

  Future<GroupMember> addMember(String email) async {
    final member =
        await _api.addMember(_requireToken(), _requireGroup().id, email);
    await refresh();
    return member;
  }

  Future<void> removeMember(String email) async {
    await _api.removeMember(_requireToken(), _requireGroup().id, email);
    await refresh();
  }

  Future<GroupInfo> acceptInvite(String groupId) async {
    final group = await _api.acceptInvite(_requireToken(), groupId);
    _invites = _invites.where((i) => i.groupId != groupId).toList();
    await _applyGroup(group);
    notifyListeners();
    return group;
  }

  Future<void> declineInvite(String groupId) async {
    await _api.declineInvite(_requireToken(), groupId);
    _invites = _invites.where((i) => i.groupId != groupId).toList();
    notifyListeners();
  }

  /// Leaves (member) or dissolves (owner) the group. Local data is kept and
  /// becomes personal again.
  Future<void> leaveGroup() async {
    await _api.leaveGroup(_requireToken(), _requireGroup().id);
    await _applyGroup(null);
    notifyListeners();
  }

  /// Called by the engine when the server said 403 — the user was removed from
  /// the group on another device.
  Future<void> handleRemovedFromGroup() async {
    await _applyGroup(null);
    _status = SyncStatus.idle;
    notifyListeners();
  }

  Future<void> _handleUnauthorized() async {
    _token = null;
    _status = SyncStatus.signedOut;
    await _syncStore.setMeta(SyncStore.kAuthToken, null);
    notifyListeners();
  }

  Future<void> _applyGroup(GroupInfo? group) async {
    final left = _group != null && group == null;
    _group = group;
    if (group == null) {
      if (left) await _syncStore.clearGroupState();
    } else {
      await _syncStore.setMeta(SyncStore.kGroupId, group.id);
      await _syncStore.setMeta(SyncStore.kGroupRole, group.role);
    }
  }

  /// The engine reports status transitions through these so every screen sees
  /// one consistent state machine.
  void reportStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  Future<void> reportSynced() async {
    _lastSyncedAt = DateTime.now();
    await _syncStore.setMeta(
      SyncStore.kLastSyncedAt,
      '${_lastSyncedAt!.millisecondsSinceEpoch}',
    );
    reportStatus(SyncStatus.idle);
  }

  Future<void> refreshConflictCount() async {
    _conflictCount = (await _syncStore.readConflicts()).length;
    if (_conflictCount > 0) {
      _status = SyncStatus.conflicts;
    } else if (_status == SyncStatus.conflicts) {
      _status = SyncStatus.idle;
    }
    notifyListeners();
  }

  Future<void> handleUnauthorized() => _handleUnauthorized();

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw const SyncApiException(SyncApiErrorKind.unauthorized);
    }
    return token;
  }

  GroupInfo _requireGroup() {
    final group = _group;
    if (group == null) {
      throw const SyncApiException(SyncApiErrorKind.forbidden, 'no group');
    }
    return group;
  }
}

/// Mirror of `StoreScope` for the sync controller — same `of`/`read` contract:
/// `of` subscribes (use in `build`), `read` does not (use in callbacks).
class SyncScope extends InheritedNotifier<SyncController> {
  const SyncScope({
    super.key,
    required SyncController controller,
    required super.child,
  }) : super(notifier: controller);

  static SyncController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SyncScope>();
    assert(scope != null, 'No SyncScope found in context');
    return scope!.notifier!;
  }

  /// Read without subscribing — for callbacks that only mutate.
  static SyncController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SyncScope>();
    assert(scope != null, 'No SyncScope found in context');
    return scope!.notifier!;
  }

  /// Null-tolerant variants for code that must work when the feature is
  /// disabled (kSyncEnabled false → no SyncScope in the tree).
  static SyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;

  static SyncController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
