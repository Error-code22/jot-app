import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackType { bug, feature }

class FeedbackItem {
  final String id;
  final String userId;
  final FeedbackType type;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;

  FeedbackItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.status = 'open',
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
    id: j['id'],
    userId: j['user_id'],
    type: j['type'] == 'bug' ? FeedbackType.bug : FeedbackType.feature,
    title: j['title'],
    description: j['description'],
    status: j['status'] ?? 'open',
    createdAt: DateTime.parse(j['created_at']),
  );
}

/// Service for submitting and retrieving bug reports and feature requests.
class FeedbackService {
  final SupabaseClient _client;

  FeedbackService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Submit a bug report or feature request.
  Future<void> submit({
    required FeedbackType type,
    required String title,
    required String description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('feedback').insert({
      'user_id': user.id,
      'type': type == FeedbackType.bug ? 'bug' : 'feature',
      'title': title,
      'description': description,
    });
  }

  /// Get all feedback submitted by the current user.
  Future<List<FeedbackItem>> getMyFeedback() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('feedback')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((j) => FeedbackItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('FeedbackService getMyFeedback error: $e');
      return [];
    }
  }
}
