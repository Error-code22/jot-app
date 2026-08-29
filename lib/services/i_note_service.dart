import '../models/note_model.dart';

/// Interface for the note management service
abstract class INoteService {
  Future<Note> createNote({
    required String userId,
    required String title,
    required String content,
    NoteType type = NoteType.text,
    List<String>? imageIds,
  });
  
  Future<Note?> getNote(String noteId);
  
  Future<List<Note>> getAllNotes(String userId);
  
  Future<Note> updateNote(
    Note note, {
    String? title,
    String? content,
    NoteType? type,
    List<String>? imageIds,
  });
  
  Future<void> deleteNote(Note note);
  
  Stream<List<Note>> watchNotes(String userId);

  Future<List<Note>> searchNotes(String userId, String query, {String? tag});
}
