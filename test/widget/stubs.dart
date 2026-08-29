import 'dart:async';
import 'dart:typed_data';
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/models/sync_result.dart';
import 'package:jot_app/models/sync_state.dart';
import 'package:jot_app/models/todo_model.dart';
import 'package:jot_app/models/user_model.dart' as jot;
import 'package:jot_app/services/i_auth_service.dart';
import 'package:jot_app/services/i_local_storage_service.dart';
import 'package:jot_app/services/i_remote_storage_service.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/services/sync_engine.dart';

// ---------------------------------------------------------------------------
// _NullLocalStorage — minimal ILocalStorageService for test wiring
// ---------------------------------------------------------------------------

class _NullLocalStorage implements ILocalStorageService {
  @override Future<void> initialize() async {}
  @override Future<void> insertNote(Note note) async {}
  @override Future<Note?> getNoteById(String id) async => null;
  @override Future<List<Note>> getAllNotes(String userId) async => [];
  @override Future<List<Note>> getAllNotesForSync(String userId) async => [];
  @override Future<void> updateNote(Note note) async {}
  @override Future<void> softDeleteNote(String id) async {}
  @override Future<void> hardDeleteNote(String id) async {}
  @override Future<List<Note>> getNotesModifiedAfter(DateTime timestamp, String userId) async => [];
  @override Future<void> clearAllNotes([String? userId]) async {}
  @override Future<void> insertTodoList(TodoList todoList) async {}
  @override Future<void> updateTodoList(TodoList todoList) async {}
  @override Future<void> deleteTodoList(String id) async {}
  @override Future<List<TodoList>> getTodoListsForUser(String userId) async => [];
}

// ---------------------------------------------------------------------------
// _NullRemoteStorage — minimal IRemoteStorageService for test wiring
// ---------------------------------------------------------------------------

class _NullRemoteStorage implements IRemoteStorageService {
  @override Future<Note> uploadNote(Note note) async => note;
  @override Future<Note?> downloadNote(String userId, String noteId) async => null;
  @override Future<List<Note>> downloadAllNotes(String userId) async => [];
  @override Future<void> deleteNote(String userId, String noteId, {String? remoteId}) async {}
  @override Stream<List<Note>> watchNotes(String userId) => const Stream.empty();
  @override Future<void> batchUploadNotes(List<Note> notes) async {}
  @override Future<String> uploadImage(Uint8List bytes, String filename) async => 'stub-file-id';
  @override Future<String> getImageUrl(String fileId) async => 'https://example.com/stub.jpg';
}

// ---------------------------------------------------------------------------
// StubAuthService — implements IAuthService for test wiring
// ---------------------------------------------------------------------------

class StubAuthService implements IAuthService {
  final AuthResult _stubSignInResult;
  final jot.User? _stubUser;
  final _stubAuthController = StreamController<AuthState>.broadcast();

  StubAuthService({
    AuthResult? signInResult,
    jot.User? user,
  })  : _stubSignInResult = signInResult ?? AuthResult(success: true),
        _stubUser = user ??
            jot.User(
              uid: 'test-user',
              email: 'test@test.com',
              displayName: 'Test User',
              createdAt: DateTime.now(),
            );

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    if (_stubSignInResult.success) {
      _stubAuthController.add(AuthState(status: AuthStatus.authenticated, user: _stubUser));
    }
    return _stubSignInResult;
  }

  @override
  Future<AuthResult> signUpWithEmail(String email, String password, {String? displayName}) async {
    if (_stubSignInResult.success) {
      _stubAuthController.add(AuthState(status: AuthStatus.authenticated, user: _stubUser));
    }
    return _stubSignInResult;
  }

  @override
  Future<AuthResult> signInWithGmail() async => _stubSignInResult;

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<void> signOut() async {
    _stubAuthController.add(AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  jot.User? getCurrentUser() => _stubUser;

  @override
  bool isAuthenticated() => _stubUser != null;

  @override
  Stream<AuthState> get authStateChanges => _stubAuthController.stream.asBroadcastStream();
}

// ---------------------------------------------------------------------------
// StubNoteService — extends NoteService for Provider compatibility
// ---------------------------------------------------------------------------

class StubNoteService extends NoteService {
  final List<Note> _stubNotes;
  final _stubStreamController = StreamController<List<Note>>.broadcast();

  StubNoteService({List<Note>? notes})
      : _stubNotes = notes ?? [],
        super(
          _NullLocalStorage(),
          _buildStubSyncEngine(),
        );

  static SyncEngine _buildStubSyncEngine() {
    return SyncEngine(_NullLocalStorage(), _NullRemoteStorage());
  }

  @override
  Future<List<Note>> getAllNotes(String userId) async =>
      _stubNotes.where((n) => !n.isDeleted).toList();

  @override
  Stream<List<Note>> watchNotes(String userId) {
    // Emit current notes immediately
    Future.microtask(() {
      if (!_stubStreamController.isClosed) {
        _stubStreamController.add(_stubNotes.where((n) => !n.isDeleted).toList());
      }
    });
    return _stubStreamController.stream;
  }

  @override
  Future<Note> createNote({
    required String userId,
    required String title,
    required String content,
    NoteType type = NoteType.text,
    List<String> tags = const [],
    String? color,
    List<String>? imageIds,
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: 'stub-note-${_stubNotes.length + 1}',
      userId: userId,
      title: title,
      content: content,
      createdAt: now,
      modifiedAt: now,
      type: type,
      tags: tags,
      color: color,
      imageIds: imageIds ?? const [],
    );
    _stubNotes.add(note);
    _stubStreamController.add(_stubNotes.where((n) => !n.isDeleted).toList());
    return note;
  }

  @override
  Future<Note> updateNote(Note note, {String? title, String? content, NoteType? type, List<String>? tags, String? color, List<String>? imageIds}) async => note;

  @override
  Future<void> deleteNote(Note note) async {
    _stubNotes.removeWhere((n) => n.id == note.id);
    _stubStreamController.add(_stubNotes.where((n) => !n.isDeleted).toList());
  }

  @override
  Future<List<Note>> searchNotes(String userId, String query, {String? tag}) async {
    final lowerQuery = query.toLowerCase();
    return _stubNotes.where((note) {
      if (note.isDeleted) return false;
      if (tag != null && !note.tags.contains(tag)) return false;
      if (query.isNotEmpty) {
        final matchesTitle = note.title.toLowerCase().contains(lowerQuery);
        final matchesContent = note.content.toLowerCase().contains(lowerQuery);
        final matchesTag = note.tags.any((t) => t.toLowerCase().contains(lowerQuery));
        if (!matchesTitle && !matchesContent && !matchesTag) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Note?> getNote(String id) async {
    try {
      return _stubNotes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// StubSyncEngine — extends SyncEngine for Provider compatibility
// ---------------------------------------------------------------------------

class StubSyncEngine extends SyncEngine {
  StubSyncEngine()
      : super(_NullLocalStorage(), _NullRemoteStorage());

  @override
  Future<void> start(String userId) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<SyncResult> syncNow(String userId) async => SyncResult.empty();

  @override
  Future<void> pushLocalChanges(String userId) async {}

  @override
  Future<void> pullCloudChanges(String userId) async {}

  @override
  Stream<SyncState> get syncStatus =>
      Stream.value(SyncState(status: SyncStatus.idle, pendingChanges: 0));

  @override
  bool get isSyncing => false;
}
