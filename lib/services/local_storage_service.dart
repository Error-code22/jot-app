import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/todo_model.dart';
import 'i_local_storage_service.dart';

/// Service for handling local SQLite storage of notes and todos.
class LocalStorageService implements ILocalStorageService {
  static const String _dbName = 'jot_app.db';
  static const String _tableName = 'notes';
  static const String _todosTable = 'todos';

  Database? _database;

  Future<Database> get database => _getDb();

  @override
  Future<void> initialize() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _database = await openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            modifiedAt INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            remoteId TEXT,
            telegramMessageId TEXT,
            type TEXT NOT NULL DEFAULT 'text',
            tags TEXT,
            color TEXT,
            isPinned INTEGER NOT NULL DEFAULT 0,
            isLocked INTEGER NOT NULL DEFAULT 0,
            pinHash TEXT,
            imageIds TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_notes_userId ON $_tableName (userId)');
        await db.execute('''
          CREATE TABLE $_todosTable (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            data TEXT NOT NULL,
            modifiedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_todos_userId ON $_todosTable (userId)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN remoteId TEXT');
          await db.execute('ALTER TABLE $_tableName ADD COLUMN telegramMessageId TEXT');
        } else if (oldVersion == 2) {
          // Version 2 had remoteId, but might have missed telegramMessageId in some iterations
          try {
            await db.execute('ALTER TABLE $_tableName ADD COLUMN telegramMessageId TEXT');
          } catch (e) {
            // Column already exists — safe to ignore.
          }
        }

        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN type TEXT NOT NULL DEFAULT "text"');
        }
        if (oldVersion < 4) {
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN tags TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN color TEXT'); } catch (_) {}
        }
        if (oldVersion < 5) {
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN isPinned INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN isLocked INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
        }
        if (oldVersion < 6) {
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN pinHash TEXT'); } catch (_) {}
        }
        if (oldVersion < 7) {
          try { await db.execute('ALTER TABLE $_tableName ADD COLUMN imageIds TEXT'); } catch (_) {}
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_todosTable (
              id TEXT PRIMARY KEY,
              userId TEXT NOT NULL,
              data TEXT NOT NULL,
              modifiedAt INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_todos_userId ON $_todosTable (userId)');
        }
      },
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  @override
  Future<void> insertNote(Note note) async {
    final db = await _getDb();
    await db.insert(
      _tableName,
      note.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final db = await _getDb();
    final maps = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Note.fromSqlite(maps.first);
  }

  @override
  Future<List<Note>> getAllNotes(String userId) async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isDeleted = 0 AND userId = ?',
      whereArgs: [userId],
      orderBy: 'isPinned DESC, modifiedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromSqlite(maps[i]));
  }

  @override
  Future<List<Note>> getAllNotesForSync(String userId) async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'modifiedAt ASC',
    );
    return List.generate(maps.length, (i) => Note.fromSqlite(maps[i]));
  }

  @override
  Future<List<Note>> getNotesModifiedAfter(DateTime timestamp, String userId) async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'userId = ? AND modifiedAt > ?',
      whereArgs: [userId, timestamp.millisecondsSinceEpoch],
      orderBy: 'modifiedAt ASC',
    );
    return List.generate(maps.length, (i) => Note.fromSqlite(maps[i]));
  }

  @override
  Future<void> updateNote(Note note) async {
    final db = await _getDb();
    await db.update(
      _tableName,
      note.toSqlite(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<void> softDeleteNote(String id) async {
    final db = await _getDb();
    await db.update(
      _tableName,
      {
        'isDeleted': 1, 
        'modifiedAt': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> hardDeleteNote(String id) async {
    final db = await _getDb();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAllNotes([String? userId]) async {
    final db = await _getDb();
    if (userId != null) {
      await db.delete(_tableName, where: 'userId = ?', whereArgs: [userId]);
    } else {
      await db.delete(_tableName);
    }
  }

  // --- TodoList CRUD ---

  @override
  Future<void> insertTodoList(TodoList todoList) async {
    final db = await _getDb();
    await db.insert(
      _todosTable,
      _todoListToRow(todoList),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTodoList(TodoList todoList) async {
    final db = await _getDb();
    await db.update(
      _todosTable,
      _todoListToRow(todoList),
      where: 'id = ?',
      whereArgs: [todoList.id],
    );
  }

  @override
  Future<void> deleteTodoList(String id) async {
    final db = await _getDb();
    await db.delete(_todosTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<TodoList>> getTodoListsForUser(String userId) async {
    final db = await _getDb();
    final maps = await db.query(
      _todosTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'modifiedAt DESC',
    );
    return maps.map(_todoListFromRow).toList();
  }

  Map<String, dynamic> _todoListToRow(TodoList todoList) {
    final data = jsonEncode({
      'title': todoList.title,
      'items': todoList.items.map((i) => i.toJson()).toList(),
      'createdAt': todoList.createdAt.toIso8601String(),
      'color': todoList.color,
      'icon': todoList.icon,
    });
    return {
      'id': todoList.id,
      'userId': todoList.userId,
      'data': data,
      'modifiedAt': todoList.modifiedAt.millisecondsSinceEpoch,
    };
  }

  TodoList _todoListFromRow(Map<String, dynamic> row) {
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    final itemsJson = (data['items'] as List<dynamic>?) ?? [];
    return TodoList(
      id: row['id'] as String,
      userId: row['userId'] as String,
      title: data['title'] as String,
      items: itemsJson.map((j) => TodoItem.fromJson(j as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse(data['createdAt'] as String),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(row['modifiedAt'] as int),
      color: data['color'] as String?,
      icon: data['icon'] as String?,
    );
  }

  Future<Database> _getDb() async {
    if (_database == null) await initialize();
    return _database!;
  }
}
