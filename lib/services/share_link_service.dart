import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../models/note_model.dart';

class ShareLink {
  final String id;
  final String token;
  final String noteId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool revoked;

  ShareLink({
    required this.id,
    required this.token,
    required this.noteId,
    required this.createdAt,
    this.expiresAt,
    this.revoked = false,
  });

  String get url =>
      '${AppConfig.supabaseUrl}/functions/v1/shared-note?token=$token';

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isActive => !revoked && !isExpired;

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: json['id'] as String,
        token: json['token'] as String,
        noteId: json['note_id'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'] as String),
        revoked: json['revoked'] as bool? ?? false,
      );
}

/// Creates revocable public links for a note.
///
/// The note is snapshotted into `shared_notes`; the public page is rendered by
/// the `shared-note` Edge Function, which reads the snapshot with the service
/// role and never exposes the table itself.
class ShareLinkService {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  ShareLinkService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<ShareLink> create(Note note, {Duration? expiresIn}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Sign in to create a share link');

    final token = _uuid.v4().replaceAll('-', '');
    final expiresAt =
        expiresIn == null ? null : DateTime.now().add(expiresIn).toUtc();

    final row = await _client
        .from('shared_notes')
        .insert({
          'user_id': user.id,
          'note_id': note.id,
          'token': token,
          'snapshot': note.toJson(),
          'expires_at': expiresAt?.toIso8601String(),
        })
        .select()
        .single();

    return ShareLink.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ShareLink>> listForNote(String noteId) async {
    try {
      final rows = await _client
          .from('shared_notes')
          .select()
          .eq('note_id', noteId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) =>
              ShareLink.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('ShareLinkService list failed: $e');
      return [];
    }
  }

  Future<void> revoke(String id) async {
    await _client.from('shared_notes').update({'revoked': true}).eq('id', id);
  }
}
