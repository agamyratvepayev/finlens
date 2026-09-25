import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A recorded clip and the MIME type to declare when sending it.
class VoiceClip {
  const VoiceClip({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Thin wrapper over the `record` plugin for the voice-entry flow: check/prompt
/// the mic permission, record a short clip to a temp file, then hand back its
/// bytes. WAV/16 kHz mono is chosen because it is universally accepted by speech
/// models and stays small enough to base64 into a JSON body for short clips.
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  /// Whether the mic permission is granted; requests it if not yet decided.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> isRecording() => _recorder.isRecording();

  /// Begins recording to a fresh temp file. Assumes permission was granted.
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/finlens_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(_config, path: _path!);
  }

  /// Stops recording and returns the clip, or null if nothing was captured.
  /// Deletes the temp file once its bytes are read.
  Future<VoiceClip?> stop() async {
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {
      // A leftover temp file is harmless; ignore delete failures.
    }
    if (bytes.isEmpty) return null;
    return VoiceClip(bytes: bytes, mimeType: 'audio/wav');
  }

  /// Aborts an in-progress recording without returning a clip.
  Future<void> cancel() async {
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {
      // Nothing to clean up if it was not recording.
    }
    final path = _path;
    _path = null;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  void dispose() => _recorder.dispose();
}
