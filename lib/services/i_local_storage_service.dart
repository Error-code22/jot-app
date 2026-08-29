import '../models/note_model.dart';
import '../models/todo_model.dart';

/// Interface for local storage service
/// Provides SQLite-based local persistence for notes
abstract class ILocalStorageService {
  /// Initialize database
  Future<void> initialize();
  
  /// Insert a new note
  Future<void> insertNote(Note note);
  
  /// Get a note by ID
  Future<Note?> getNoteById(String id);
  
  /// Get all non-deleted notes for a user
  Future<List<Note>> getAllNotes(String userId);

  /// Get all notes for a user including deleted notes (for sync)
  Future<List<Note>> getAllNotesForSync(String userId);
  
  /// Update an existing note
  Future<void> updateNote(Note note);
  
  /// Soft delete a note (mark as deleted)
  Future<void> softDeleteNote(String id);

  /// Hard delete a note (remove from DB)
  Future<void> hardDeleteNote(String id);
  
  /// Get notes modified after a timestamp for a user
  Future<List<Note>> getNotesModifiedAfter(DateTime timestamp, String userId);
  
  /// Clear all notes (used on logout), optionally scoped by userId
  Future<void> clearAllNotes([String? userId]);

  // --- TodoList CRUD ---

  /// Insert a new todo list
  Future<void> insertTodoList(TodoList todoList);

  /// Update an existing todo list
  Future<void> updateTodoList(TodoList todoList);

  /// Delete a todo list by ID
  Future<void> deleteTodoList(String id);

  /// Get all todo lists for a user
  Future<List<TodoList>> getTodoListsForUser(String userId);
}
