import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/todo_model.dart';
import 'i_local_storage_service.dart';

class TodoService extends ChangeNotifier {
  final _uuid = const Uuid();
  List<TodoList> _lists = [];
  List<TodoList> get lists => List.unmodifiable(_lists);
  String? _userId;
  ILocalStorageService? _storage;

  Future<void> initialize(String userId, ILocalStorageService storage) async {
    _userId = userId;
    _storage = storage;
    await _migrateFromSharedPreferences();
    await _load();
  }

  /// One-time migration: reads todos from SharedPreferences and writes them to SQLite,
  /// then removes the SharedPreferences key. Individual item failures are caught and
  /// logged without aborting the migration.
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'todos_$_userId';
      final raw = prefs.getString(key);
      if (raw == null) return; // nothing to migrate

      final data = jsonDecode(raw) as List;
      for (final d in data) {
        try {
          final todoList = _listFromJson(d as Map<String, dynamic>);
          await _storage!.insertTodoList(todoList);
        } catch (e) {
          debugPrint('TodoService migration: failed to migrate item, skipping: $e');
        }
      }
      await prefs.remove(key);
    } catch (e) {
      debugPrint('TodoService migration error: $e');
    }
  }

  Future<void> _load() async {
    try {
      _lists = await _storage!.getTodoListsForUser(_userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService load error: $e');
      _lists = [];
      notifyListeners();
    }
  }

  Future<TodoList> createList(String title, {String? color, String? icon}) async {
    final list = TodoList(
      id: _uuid.v4(),
      userId: _userId!,
      title: title,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      color: color,
      icon: icon,
    );
    final snapshot = List<TodoList>.from(_lists);
    _lists.insert(0, list);
    try {
      await _storage!.insertTodoList(list);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService createList error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return list;
  }

  Future<void> updateList(String id, {String? title, String? color, String? icon}) async {
    final idx = _lists.indexWhere((l) => l.id == id);
    if (idx == -1) return;
    final snapshot = List<TodoList>.from(_lists);
    _lists[idx] = _lists[idx].copyWith(title: title, color: color, icon: icon);
    try {
      await _storage!.updateTodoList(_lists[idx]);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService updateList error: $e');
      _lists = snapshot;
      notifyListeners();
    }
  }

  Future<void> deleteList(String id) async {
    final snapshot = List<TodoList>.from(_lists);
    _lists.removeWhere((l) => l.id == id);
    try {
      await _storage!.deleteTodoList(id);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService deleteList error: $e');
      _lists = snapshot;
      notifyListeners();
    }
  }

  Future<TodoList> addItem(String listId, String text, {
    DateTime? dueDate,
    TodoPriority priority = TodoPriority.none,
    String? note,
    Recurrence recurrence = Recurrence.none,
  }) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final item = TodoItem(
      id: _uuid.v4(),
      text: text,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      priority: priority,
      note: note,
      recurrence: recurrence,
    );
    final updated = _lists[idx].copyWith(items: [..._lists[idx].items, item]);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService addItem error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  Future<TodoList> updateItem(String listId, String itemId, {
    String? text,
    DateTime? dueDate,
    bool clearDueDate = false,
    TodoPriority? priority,
    String? note,
    Recurrence? recurrence,
  }) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final items = _lists[idx].items.map((i) => i.id == itemId
        ? i.copyWith(
            text: text,
            dueDate: dueDate,
            clearDueDate: clearDueDate,
            priority: priority,
            note: note,
            recurrence: recurrence,
          )
        : i).toList();
    final updated = _lists[idx].copyWith(items: items);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService updateItem error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  Future<TodoList> toggleItem(String listId, String itemId) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final items = _lists[idx].items.map((i) {
      if (i.id != itemId) return i;
      final toggled = i.copyWith(isDone: !i.isDone);
      // If marking done and has recurrence, schedule next occurrence
      if (toggled.isDone && toggled.recurrence != Recurrence.none && toggled.nextRecurrenceDate != null) {
        final nextItem = TodoItem(
          id: _uuid.v4(),
          text: toggled.text,
          createdAt: DateTime.now(),
          dueDate: toggled.nextRecurrenceDate,
          priority: toggled.priority,
          note: toggled.note,
          recurrence: toggled.recurrence,
        );
        // We'll add it after toggling
        Future.microtask(() async {
          await addItem(listId, nextItem.text,
            dueDate: nextItem.dueDate,
            priority: nextItem.priority,
            note: nextItem.note,
          );
          // Set recurrence on the new item
          final newList = _lists.firstWhere((l) => l.id == listId);
          final newItem = newList.items.last;
          await updateItem(listId, newItem.id, recurrence: nextItem.recurrence);
        });
      }
      return toggled;
    }).toList();
    final updated = _lists[idx].copyWith(items: items);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService toggleItem error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  Future<TodoList> deleteItem(String listId, String itemId) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final items = _lists[idx].items.where((i) => i.id != itemId).toList();
    final updated = _lists[idx].copyWith(items: items);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService deleteItem error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  Future<TodoList> clearCompleted(String listId) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final items = _lists[idx].items.where((i) => !i.isDone).toList();
    final updated = _lists[idx].copyWith(items: items);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService clearCompleted error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  Future<TodoList> reorderItems(String listId, int oldIndex, int newIndex) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx == -1) throw Exception('List not found');
    final snapshot = List<TodoList>.from(_lists);
    final items = List<TodoItem>.from(_lists[idx].items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    final updated = _lists[idx].copyWith(items: items);
    _lists[idx] = updated;
    try {
      await _storage!.updateTodoList(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('TodoService reorderItems error: $e');
      _lists = snapshot;
      notifyListeners();
      rethrow;
    }
    return updated;
  }

  TodoList _listFromJson(Map<String, dynamic> j) => TodoList(
    id: j['id'],
    userId: j['userId'],
    title: j['title'],
    items: (j['items'] as List).map((i) => TodoItem.fromJson(i as Map<String, dynamic>)).toList(),
    createdAt: DateTime.parse(j['createdAt']),
    modifiedAt: DateTime.parse(j['modifiedAt']),
    color: j['color'] as String?,
    icon: j['icon'] as String?,
  );
}
