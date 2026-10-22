import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Records voice notes, stores them locally, and mirrors them to Supabase
/// Storage so other devices can play them.
///
/// No third-party transcription is performed: the audio never leaves the
/// user's Supabase project.
class AudioService {
  AudioService({AudioRecorder? recorder, SupabaseClient? client})
      : _recorder = recorder ?? AudioRecorder(),
        _client = client ?? Supabase.instance.client;

  static const bucket = 'note-audio';
  final AudioRecorder _recorder;
  final SupabaseClient _client;
  final _uuid = const Uuid();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Microphone permission check failed: $e');
      return false;
    }
  }

  Future<String> startRecording() async {
    if (_isRecording) {
      throw StateError('A recording is already in progress');
    }
    if (!await hasPermission()) {
      throw Exception('Microphone permission was not granted');
    }

    final directory = await getApplicationDocumentsDirectory();
    final audioDirectory = Directory('${directory.path}/jot_audio');
    if (!await audioDirectory.exists()) {
      await audioDirectory.create(recursive: true);
    }

    final path =
        '${audioDirectory.path}/rec_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6)}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _isRecording = true;
    return path;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    return _recorder.stop();
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recorder.cancel();
  }

  /// Uploads a local recording and returns a public URL, or null when the
  /// upload cannot be completed (offline / bucket missing). The local file is
  /// always kept as a fallback.
  Future<String?> upload(String localPath, String userId) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final objectPath = '$userId/${_uuid.v4()}.m4a';
      await _client.storage.from(bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: false,
            ),
          );
      return _client.storage.from(bucket).getPublicUrl(objectPath);
    } catch (e) {
      debugPrint('Audio upload skipped: $e');
      return null;
    }
  }

  Future<void> delete(String reference) async {
    try {
      if (reference.startsWith('http')) {
        // Best-effort; we store public URLs, so derive the object path.
        final marker = '/object/public/$bucket/';
        final index = reference.indexOf(marker);
        if (index != -1) {
          final objectPath =
              Uri.decodeComponent(reference.substring(index + marker.length));
          await _client.storage.from(bucket).remove([objectPath]);
        }
      } else {
        final file = File(reference);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      debugPrint('Audio delete failed: $e');
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
