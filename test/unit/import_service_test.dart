import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/services/import_service.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/models/todo_model.dart';
import 'package:jot_app/services/i_local_storage_service.dart';

// ---------------------------------------------------------------------------
// In-memory storage for tests
// ---------------------------------------------------------------------------

class _MemoryStorage implements ILocalStorageService {
  final List<Note> notes = [];

  @override Future<void> initialize() async {}
  @override Future<void> insertNote(Note note) async { notes.add(note); }
  @override Future<Note?> getNoteById(String id) async => notes.firstWhere((n) => n.id == id, orElse: () => throw Exception('not found'));
  @override Future<List<Note>> getAllNotes(String userId) async => notes.where((n) => n.userId == userId && !n.isDeleted).toList();
  @override Future<List<Note>> getAllNotesForSync(String userId) async => notes.where((n) => n.userId == userId).toList();
  @override Future<void> updateNote(Note note) async { final i = notes.indexWhere((n) => n.id == note.id); if (i >= 0) notes[i] = note; }
  @override Future<void> softDeleteNote(String id) async {}
  @override Future<void> hardDeleteNote(String id) async {}
  @override Future<List<Note>> getNotesModifiedAfter(DateTime timestamp, String userId) async => [];
  @override Future<void> clearAllNotes([String? userId]) async { notes.clear(); }
  @override Future<void> insertTodoList(TodoList todoList) async {}
  @override Future<void> updateTodoList(TodoList todoList) async {}
  @override Future<void> deleteTodoList(String id) async {}
  @override Future<List<TodoList>> getTodoListsForUser(String userId) async => [];
}

// ---------------------------------------------------------------------------
// Helper: write a temp file and return its path
// ---------------------------------------------------------------------------

Future<String> _writeTempFile(Directory dir, String name, String content) async {
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsString(content);
  return file.path;
}

void main() {
  late Directory tempDir;
  late _MemoryStorage storage;
  late ImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jot_import_test_');
    storage = _MemoryStorage();
    service = ImportService(storage);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // -------------------------------------------------------------------------
  // Task 14.1 — empty file produces a note with empty body (not skipped)
  // -------------------------------------------------------------------------
  test('empty file produces a note with empty content (req 10.11)', () async {
    await _writeTempFile(tempDir, 'empty.txt', '');
    final result = await service.importTxtFolder(tempDir.path, 'user1');
    expect(result.imported, 1);
    expect(result.skipped, 0);
    expect(storage.notes.first.content, '');
  });

  // -------------------------------------------------------------------------
  // Task 14.2 — root-folder file gets only "imported" tag (req 10.5)
  // -------------------------------------------------------------------------
  test('root-folder file gets only "imported" tag (req 10.5)', () async {
    await _writeTempFile(tempDir, 'note.txt', 'Hello');
    final result = await service.importTxtFolder(tempDir.path, 'user1');
    expect(result.imported, 1);
    expect(storage.notes.first.tags, equals(['imported']));
  });

  // -------------------------------------------------------------------------
  // Property 11 — title transformation is deterministic and non-empty
  // -------------------------------------------------------------------------
  group('title transformation (Property 11)', () {
    final testCases = [
      // [filename, expectedTitle]
      ['My Note.txt', 'My Note'],
      ['My Note_260101_120000.txt', 'My Note'],
      ['My Note (2).txt', 'My Note'],
      ['My Note_260101_120000 (3).txt', 'My Note'],
      ['.txt', 'Untitled'],
      ['note.md', 'note'],
      ['note.text', 'note'],
      ['note.markdown', 'note'],
    ];

    for (final tc in testCases) {
      test('transforms "${tc[0]}" → "${tc[1]}"', () async {
        await _writeTempFile(tempDir, tc[0], 'content');
        storage.notes.clear();
        final result = await service.importTxtFolder(tempDir.path, 'user1');
        expect(result.imported, greaterThanOrEqualTo(1));
        final note = storage.notes.last;
        expect(note.title, isNotEmpty);
        expect(note.title, tc[1]);
      });
    }
  });

  // -------------------------------------------------------------------------
  // Property 12 — imported + skipped = total files
  // -------------------------------------------------------------------------
  test('imported + skipped = total files (Property 12)', () async {
    // Write 3 readable files
    await _writeTempFile(tempDir, 'a.txt', 'aaa');
    await _writeTempFile(tempDir, 'b.txt', 'bbb');
    await _writeTempFile(tempDir, 'c.md', 'ccc');

    final result = await service.importTxtFolder(tempDir.path, 'user1');
    expect(result.imported + result.skipped, 3);
    expect(result.imported, 3);
    expect(result.skipped, 0);
  });

  // -------------------------------------------------------------------------
  // Property 13 — subfolder file gets "imported" + subfolder name tags
  // -------------------------------------------------------------------------
  test('subfolder file gets "imported" + subfolder name tags (Property 13)', () async {
    final subDir = Directory('${tempDir.path}${Platform.pathSeparator}work');
    await subDir.create();
    final file = File('${subDir.path}${Platform.pathSeparator}meeting.txt');
    await file.writeAsString('Meeting notes');

    final result = await service.importTxtFolder(tempDir.path, 'user1');
    expect(result.imported, 1);
    final note = storage.notes.first;
    expect(note.tags, contains('imported'));
    expect(note.tags, contains('work'));
  });

  // -------------------------------------------------------------------------
  // Round-trip content preservation (req 10.9)
  // -------------------------------------------------------------------------
  test('content is preserved after import (req 10.9)', () async {
    const content = 'Hello, world!\nSecond line.';
    await _writeTempFile(tempDir, 'note.txt', content);
    await service.importTxtFolder(tempDir.path, 'user1');
    expect(storage.notes.first.content, content.trim());
  });
}
