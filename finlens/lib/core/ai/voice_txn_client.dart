import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_config.dart';

/// Why a voice-parse call failed. The UI branches on this to show the right
/// message, never on raw status codes. Mirrors the sync feature's approach in
/// `core/sync/api_client.dart`.
enum VoiceAiErrorKind {
  /// No connectivity / timeout — worth a retry.
  network,

  /// 401 — the app token is wrong/missing (a build/config problem).
  unauthorized,

  /// 429 — too many requests; the user should wait.
  rateLimited,

  /// The model could not produce a usable transaction from the audio.
  unparsable,

  /// Anything else the server rejected or returned malformed.
  server,
}

class VoiceAiException implements Exception {
  const VoiceAiException(this.kind, [this.message]);

  final VoiceAiErrorKind kind;
  final String? message;

  @override
  String toString() =>
      'VoiceAiException(${kind.name}${message == null ? '' : ': $message'})';
}

/// A transaction the AI heard, as a set of *proposals* for the Quick Add form.
/// Every field can be absent — a null id or amount just means "the user fills
/// this in". Nothing here is written to the store; the user reviews and saves.
class VoiceTxnDraft {
  const VoiceTxnDraft({
    required this.isIncome,
    this.amount,
    this.currency,
    this.categoryId,
    this.accountId,
    this.note = '',
    this.date,
    this.confidence = 0,
  });

  /// income when true, expense when false — the only two types the AI targets.
  final bool isIncome;
  final double? amount;
  final String? currency;

  /// Category id, already validated against the catalog by the server (a
  /// hallucinated id arrives as null).
  final String? categoryId;

  /// Account id, likewise validated server-side.
  final String? accountId;
  final String note;
  final DateTime? date;
  final double confidence;

  factory VoiceTxnDraft.fromJson(Map<String, Object?> j) {
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    DateTime? asDate(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    return VoiceTxnDraft(
      isIncome: j['type'] == 'income',
      amount: asDouble(j['amount']),
      currency: j['currency'] as String?,
      categoryId: j['categoryId'] as String?,
      accountId: j['accountId'] as String?,
      note: (j['note'] as String?)?.trim() ?? '',
      date: asDate(j['date']),
      confidence: asDouble(j['confidence']) ?? 0,
    );
  }
}

/// Posts recorded audio to our backend's `/api/v1/ai/parse-transaction` proxy
/// and returns a [VoiceTxnDraft]. Holds no state beyond its HTTP client.
class VoiceTxnClient {
  VoiceTxnClient({
    this.baseUrl = kAiBaseUrl,
    this.appToken = kAiProxyToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String appToken;
  final http.Client _client;

  // Audio round-trips through Gemini — allow more than the sync client's 15s.
  static const Duration _timeout = Duration(seconds: 30);

  Future<VoiceTxnDraft> parse({
    required Uint8List audio,
    required String mimeType,
    required String locale,
    required Map<String, Object?> catalog,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/ai/parse-transaction');
    final body = <String, Object?>{
      'audioBase64': base64Encode(audio),
      'mimeType': mimeType,
      'locale': locale,
      'catalog': catalog,
    };

    http.Response res;
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'x-app-token': appToken,
          'content-type': 'application/json',
        })
        ..body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      res = await http.Response.fromStream(streamed).timeout(_timeout);
    } on SocketException {
      throw const VoiceAiException(VoiceAiErrorKind.network);
    } on TimeoutException {
      throw const VoiceAiException(VoiceAiErrorKind.network);
    } on http.ClientException {
      throw const VoiceAiException(VoiceAiErrorKind.network);
    }

    Map<String, Object?>? decoded;
    try {
      decoded = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
          .cast<String, Object?>();
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final draft = decoded?['draft'];
      if (draft is! Map) {
        throw const VoiceAiException(VoiceAiErrorKind.server, 'malformed body');
      }
      return VoiceTxnDraft.fromJson(draft.cast<String, Object?>());
    }

    final message = switch (decoded?['error']) {
      Map error => error['message'] as String?,
      _ => decoded?['message'] as String?,
    };
    throw VoiceAiException(
      switch (res.statusCode) {
        401 => VoiceAiErrorKind.unauthorized,
        429 => VoiceAiErrorKind.rateLimited,
        422 => VoiceAiErrorKind.unparsable,
        _ => VoiceAiErrorKind.server,
      },
      message,
    );
  }

  void close() => _client.close();
}
