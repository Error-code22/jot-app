import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/note_model.dart';
import '../models/user_model.dart' as jot;
import '../models/auth_state.dart';
import 'i_auth_service.dart';
import 'i_remote_storage_service.dart';

/// Supabase-based implementation of auth and remote storage.
/// Replaces the broken Firebase + Telegram stack.
class SupabaseService implements IAuthService, IRemoteStorageService {
  final SupabaseClient _client;
  
  final _authStateController = StreamController<AuthState>.broadcast();
  StreamSubscription<AuthState>? _authSubscription;
  
  SupabaseService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        final user = session.user;
        _authStateController.add(AuthState(
          status: AuthStatus.authenticated,
          user: jot.User(
            uid: user.id,
            email: user.email ?? '',
            displayName: user.userMetadata?['display_name'] as String?,
            photoUrl: user.userMetadata?['avatar_url'] as String?,
            createdAt: DateTime.parse(user.createdAt),
          ),
        ));
      } else if (event == AuthChangeEvent.signedOut) {
        _authStateController.add(AuthState(
          status: AuthStatus.unauthenticated,
        ));
      }
    });
  }

  // ── Auth Methods ────────────────────────────────────────────────────────

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        return AuthResult(
          success: true,
          user: jot.User(
            uid: response.user!.id,
            email: response.user!.email ?? '',
            displayName: response.user!.userMetadata?['display_name'] as String?,
            createdAt: DateTime.parse(response.user!.createdAt),
          ),
        );
      }
      return AuthResult(success: false, errorMessage: 'Sign in failed');
    } on AuthException catch (e) {
      return AuthResult(success: false, errorMessage: e.message);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<AuthResult> signUpWithEmail(String email, String password, {String? displayName}) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      
      if (response.user != null) {
        return AuthResult(
          success: true,
          user: jot.User(
            uid: response.user!.id,
            email: response.user!.email ?? '',
            displayName: displayName,
            createdAt: DateTime.parse(response.user!.createdAt),
          ),
        );
      }
      return AuthResult(success: false, errorMessage: 'Sign up failed');
    } on AuthException catch (e) {
      return AuthResult(success: false, errorMessage: e.message);
    } catch (e) {
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<bool> restoreSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        final user = session.user;
        _authStateController.add(AuthState(
          status: AuthStatus.authenticated,
          user: jot.User(
            uid: user.id,
            email: user.email ?? '',
            displayName: user.userMetadata?['display_name'] as String?,
            createdAt: DateTime.parse(user.createdAt),
          ),
        ));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Session restore error: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _authStateController.add(AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  jot.User? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return jot.User(
      uid: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.parse(user.createdAt),
    );
  }

  @override
  bool isAuthenticated() => _client.auth.currentSession != null;

  @override
  Future<AuthResult> signInWithGmail() async {
    return AuthResult(
      success: false,
      errorMessage: 'Google Sign-In is not configured yet. Please use email and password.',
    );
  }

  // ── Remote Storage Methods ──────────────────────────────────────────────

  @override
  Future<Note> uploadNote(Note note) async {
    try {
      await _client.from('notes').upsert(note.toSupabase());
      return note;
    } catch (e) {
      debugPrint('Supabase uploadNote error: $e');
      rethrow;
    }
  }

  @override
  Future<Note?> downloadNote(String userId, String noteId) async {
    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('id', noteId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) return null;
      return Note.fromSupabase(response);
    } catch (e) {
      debugPrint('Supabase downloadNote error: $e');
      return null;
    }
  }

  @override
  Future<List<Note>> downloadAllNotes(String userId) async {
    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .order('modified_at', ascending: false);
      
      return (response as List).map((json) => Note.fromSupabase(json)).toList();
    } catch (e) {
      debugPrint('Supabase downloadAllNotes error: $e');
      return [];
    }
  }

  @override
  Future<void> deleteNote(String userId, String noteId, {String? remoteId}) async {
    try {
      await _client
          .from('notes')
          .delete()
          .eq('id', noteId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Supabase deleteNote error: $e');
    }
  }

  @override
  Stream<List<Note>> watchNotes(String userId) {
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('modified_at', ascending: false)
        .map((data) => data.map((json) => Note.fromSupabase(json)).toList());
  }

  @override
  Future<void> batchUploadNotes(List<Note> notes) async {
    for (final note in notes) {
      await uploadNote(note);
    }
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    // Upload to Supabase Storage
    final response = await _client.storage.from('images').uploadBinary(
      'notes/$filename',
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    
    if (response.isNotEmpty) {
      return 'notes/$filename';
    }
    throw Exception('Image upload failed');
  }

  @override
  Future<String> getImageUrl(String fileId) async {
    final url = _client.storage.from('images').getPublicUrl(fileId);
    return url;
  }

  void dispose() {
    _authStateController.close();
    _authSubscription?.cancel();
  }
}
