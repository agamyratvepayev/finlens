import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'sync_config.dart';
import 'sync_models.dart';

/// Why an API call failed — the engine and UI branch on this, never on raw
/// status codes.
enum SyncApiErrorKind {
  /// No connectivity / timeout — retry later, not an error state.
  network,

  /// 401 — token expired or revoked; the user must sign in again.
  unauthorized,

  /// 403 — not (or no longer) an active member of the group.
  forbidden,

  /// 409 — state conflict (already in a group, already invited, …).
  conflict,

  /// Anything else the server rejected or returned malformed.
  server,
}

class SyncApiException implements Exception {
  const SyncApiException(this.kind, [this.message]);

  final SyncApiErrorKind kind;
  final String? message;

  @override
  String toString() => 'SyncApiException(${kind.name}${message == null ? '' : ': $message'})';
}

/// Thin typed HTTP client over the FinLens API. Holds no state beyond the
/// bearer token supplied per call site via [token].
class SyncApiClient {
  SyncApiClient({this.baseUrl = kSyncBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      if (token != null) 'authorization': 'Bearer $token',
      if (body != null) 'content-type': 'application/json',
    };
    http.Response res;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      res = await http.Response.fromStream(streamed).timeout(_timeout);
    } on SocketException {
      throw const SyncApiException(SyncApiErrorKind.network);
    } on TimeoutException {
      throw const SyncApiException(SyncApiErrorKind.network);
    } on http.ClientException {
      throw const SyncApiException(SyncApiErrorKind.network);
    }

    Map<String, Object?>? decoded;
    try {
      decoded = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
          .cast<String, Object?>();
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded == null) {
        throw const SyncApiException(SyncApiErrorKind.server, 'malformed body');
      }
      return decoded;
    }

    final message = switch (decoded?['error']) {
      Map error => error['message'] as String?,
      _ => decoded?['message'] as String?,
    };
    throw SyncApiException(
      switch (res.statusCode) {
        401 => SyncApiErrorKind.unauthorized,
        403 => SyncApiErrorKind.forbidden,
        409 => SyncApiErrorKind.conflict,
        _ => SyncApiErrorKind.server,
      },
      message,
    );
  }

  Future<SignInResult> signInWithGoogle(String idToken) async {
    final json = await _request('POST', '/auth/google', body: {'idToken': idToken});
    return SignInResult(
      token: json['token'] as String,
      user: AuthUser.fromJson((json['user'] as Map).cast<String, Object?>()),
      invites: (json['invites'] as List? ?? const [])
          .map((e) => PendingInvite.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
    );
  }

  Future<MeResult> me(String token) async {
    final json = await _request('GET', '/me', token: token);
    return MeResult(
      user: AuthUser.fromJson((json['user'] as Map).cast<String, Object?>()),
      group: json['group'] == null
          ? null
          : GroupInfo.fromJson((json['group'] as Map).cast<String, Object?>()),
      invites: (json['invites'] as List? ?? const [])
          .map((e) => PendingInvite.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
    );
  }

  Future<GroupInfo> createGroup(String token) async {
    final json = await _request('POST', '/groups', token: token, body: {});
    return GroupInfo.fromJson((json['group'] as Map).cast<String, Object?>());
  }

  Future<GroupMember> addMember(String token, String groupId, String email) async {
    final json = await _request(
      'POST',
      '/groups/$groupId/members',
      token: token,
      body: {'email': email},
    );
    return GroupMember.fromJson((json['member'] as Map).cast<String, Object?>());
  }

  Future<void> removeMember(String token, String groupId, String email) async {
    await _request(
      'DELETE',
      '/groups/$groupId/members/${Uri.encodeComponent(email)}',
      token: token,
    );
  }

  Future<GroupInfo> acceptInvite(String token, String groupId) async {
    final json =
        await _request('POST', '/groups/$groupId/accept', token: token, body: {});
    return GroupInfo.fromJson((json['group'] as Map).cast<String, Object?>());
  }

  Future<void> declineInvite(String token, String groupId) async {
    await _request('POST', '/groups/$groupId/decline', token: token, body: {});
  }

  Future<void> leaveGroup(String token, String groupId) async {
    await _request('POST', '/groups/$groupId/leave', token: token, body: {});
  }

  Future<SyncResponse> sync(
    String token,
    String groupId,
    int cursor,
    List<RecordChange> changes,
  ) async {
    final json = await _request(
      'POST',
      '/groups/$groupId/sync',
      token: token,
      body: {
        'cursor': cursor,
        'changes': changes.map((c) => c.toJson()).toList(),
      },
    );
    return SyncResponse.fromJson(json);
  }
}
