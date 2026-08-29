import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import 'i_note_service.dart';
import 'i_local_storage_service.dart';
import 'i_sync_engine.dart';

/// Service that provides a clean API for the UI to interact with notes.
class NoteService implements INoteService {
  final ILocalStorageService _local;
  final ISyncEngine _sync;
  final _uuid = const Uuid();
  
  final Map<String, StreamController<List<Note>>> _noteStreamControllers = {};

  NoteService(this._local, this._sync);

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
      id: _uuid.v4(),
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

    await _local.insertNote(note);
    await _emitNotesUpdate(userId);
    unawaited(_sync.syncNow(userId));
    
    return note;
  }

  @override
  Future<List<Note>> getAllNotes(String userId) async {
    return _local.getAllNotes(userId);
  }

  @override
  Future<Note?> getNote(String id) async {
    return _local.getNoteById(id);
  }

  @override
  Future<Note> updateNote(Note note, {String? title, String? content, NoteType? type, List<String>? tags, String? color, List<String>? imageIds}) async {
    final updatedNote = note.copyWith(
      title: title,
      content: content,
      type: type,
      tags: tags,
      color: color,
      imageIds: imageIds,
      modifiedAt: DateTime.now(),
    );

    await _local.updateNote(updatedNote);
    await _emitNotesUpdate(note.userId);
    unawaited(_sync.syncNow(note.userId));
    
    return updatedNote;
  }

  @override
  Future<void> deleteNote(Note note) async {
    await _local.softDeleteNote(note.id);
    await _emitNotesUpdate(note.userId);
    unawaited(_sync.syncNow(note.userId));
  }
  
  @override
  Stream<List<Note>> watchNotes(String userId) {
    if (!_noteStreamControllers.containsKey(userId)) {
      _noteStreamControllers[userId] = StreamController<List<Note>>.broadcast();
    }
    // Always emit current notes immediately when someone subscribes
    _emitNotesUpdate(userId);
    return _noteStreamControllers[userId]!.stream;
  }
  
  @override
  Future<List<Note>> searchNotes(String userId, String query, {String? tag}) async {
    final allNotes = await _local.getAllNotes(userId);
    final lowerQuery = query.toLowerCase();

    return allNotes.where((note) {
      // Tag filter: exact match (applied independently of query)
      if (tag != null && !note.tags.contains(tag)) {
        return false;
      }

      // Query filter: case-insensitive substring match on title, content, or any tag
      if (query.isNotEmpty) {
        final matchesTitle = note.title.toLowerCase().contains(lowerQuery);
        final matchesContent = note.content.toLowerCase().contains(lowerQuery);
        final matchesTag = note.tags.any((t) => t.toLowerCase().contains(lowerQuery));
        if (!matchesTitle && !matchesContent && !matchesTag) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> refreshNotes(String userId) async {
    await _emitNotesUpdate(userId);
  }

  Future<Note> togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned, modifiedAt: DateTime.now());
    await _local.updateNote(updated);
    await _emitNotesUpdate(note.userId);
    return updated;
  }

  Future<Note> toggleLock(Note note, {String? pin}) async {
    Note updated;
    if (note.isLocked) {
      // Unlocking — clear the pin hash
      updated = note.copyWith(isLocked: false, modifiedAt: DateTime.now(), clearPinHash: true);
    } else {
      // Locking — store the pin hash
      final hash = pin != null ? Note.hashPin(pin) : null;
      updated = note.copyWith(isLocked: true, modifiedAt: DateTime.now(), pinHash: hash);
    }
    await _local.updateNote(updated);
    await _emitNotesUpdate(note.userId);
    return updated;
  }

  Future<void> _emitNotesUpdate(String userId) async {
    if (_noteStreamControllers.containsKey(userId) && 
        !_noteStreamControllers[userId]!.isClosed) {
      final notes = await _local.getAllNotes(userId);
      _noteStreamControllers[userId]!.add(notes);
    }
  }
  
  void dispose() {
    for (final controller in _noteStreamControllers.values) {
      controller.close();
    }
    _noteStreamControllers.clear();
  }
}
