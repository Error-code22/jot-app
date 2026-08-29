import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../models/todo_model.dart';
import 'i_local_storage_service.dart';

/// Service for handling local storage on the WEB using SharedPreferences.
class WebStorageService implements ILocalStorageService {
  static const String _storageKey = 'jot_app_notes';
  late SharedPreferences _prefs;

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<Note> _getAll() {
    final List<String>? notesJson = _prefs.getStringList(_storageKey);
    if (notesJson == null) return [];
    return notesJson.map((json) => Note.fromJson(jsonDecode(json))).toList();
  }

  Future<void> _saveAll(List<Note> notes) async {
    final List<String> notesJson = notes.map((note) => jsonEncode(note.toJson())).toList();
    await _prefs.setStringList(_storageKey, notesJson);
  }

  @override
  Future<void> insertNote(Note note) async {
    final notes = _getAll();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
    await _saveAll(notes);
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final notes = _getAll();
    try {
      return notes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Note>> getAllNotes(String userId) async {
    return _getAll()
        .where((n) => n.userId == userId && !n.isDeleted)
        .toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  @override
  Future<List<Note>> getAllNotesForSync(String userId) async {
    return _getAll()
        .where((n) => n.userId == userId)
        .toList()
      ..sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
  }

  @override
  Future<void> updateNote(Note note) async => insertNote(note);

  @override
  Future<void> softDeleteNote(String id) async {
    final notes = _getAll();
    final index = notes.indexWhere((n) => n.id == id);
    if (index >= 0) {
      notes[index] = notes[index].copyWith(
        isDeleted: true,
        modifiedAt: DateTime.now(),
      );
      await _saveAll(notes);
    }
  }

  @override
  Future<void> hardDeleteNote(String id) async {
    final notes = _getAll();
    notes.removeWhere((n) => n.id == id);
    await _saveAll(notes);
  }

  @override
  Future<List<Note>> getNotesModifiedAfter(DateTime timestamp, String userId) async {
    return _getAll()
        .where((n) => n.userId == userId && n.modifiedAt.isAfter(timestamp))
        .toList()
      ..sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
  }

  @override
  Future<void> clearAllNotes([String? userId]) async {
    if (userId == null) {
      await _prefs.remove(_storageKey);
    } else {
      final notes = _getAll();
      notes.removeWhere((n) => n.userId == userId);
      await _saveAll(notes);
    }
  }

  // --- TodoList CRUD (web: stored in SharedPreferences as JSON) ---

  static const String _todoKey = 'jot_app_todos';

  List<TodoList> _getAllTodos() {
    final raw = _prefs.getStringList(_todoKey);
    if (raw == null) return [];
    return raw.map((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return TodoList(
        id: m['id'],
        userId: m['userId'],
        title: m['title'],
        items: (m['items'] as List<dynamic>? ?? [])
            .map((i) => TodoItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(m['createdAt']),
        modifiedAt: DateTime.parse(m['modifiedAt']),
        color: m['color'] as String?,
        icon: m['icon'] as String?,
      );
    }).toList();
  }

  Future<void> _saveAllTodos(List<TodoList> todos) async {
    final raw = todos.map((t) => jsonEncode({
      'id': t.id,
      'userId': t.userId,
      'title': t.title,
      'items': t.items.map((i) => i.toJson()).toList(),
      'createdAt': t.createdAt.toIso8601String(),
      'modifiedAt': t.modifiedAt.toIso8601String(),
      'color': t.color,
      'icon': t.icon,
    })).toList();
    await _prefs.setStringList(_todoKey, raw);
  }

  @override
  Future<void> insertTodoList(TodoList todoList) async {
    final todos = _getAllTodos();
    final idx = todos.indexWhere((t) => t.id == todoList.id);
    if (idx >= 0) {
      todos[idx] = todoList;
    } else {
      todos.add(todoList);
    }
    await _saveAllTodos(todos);
  }

  @override
  Future<void> updateTodoList(TodoList todoList) => insertTodoList(todoList);

  @override
  Future<void> deleteTodoList(String id) async {
    final todos = _getAllTodos();
    todos.removeWhere((t) => t.id == id);
    await _saveAllTodos(todos);
  }

  @override
  Future<List<TodoList>> getTodoListsForUser(String userId) async {
    return _getAllTodos().where((t) => t.userId == userId).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }
}
