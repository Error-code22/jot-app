import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jot_app/services/local_storage_service.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  late LocalStorageService storage;
  final uuid = const Uuid();

  setUpAll(() {
    // Initialize FFI for Windows tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = LocalStorageService();
    // Ensure we start with a clean state
    await storage.initialize();
    await storage.clearAllNotes();
  });
  
  tearDown(() async {
    // Clean up
    await storage.clearAllNotes();
  });

  Note createTestNote(String userId, {String title = 'Test', bool isDeleted = false, DateTime? modifiedAt}) {
    final now = DateTime.now();
    return Note(
      id: uuid.v4(),
      userId: userId,
      title: title,
      content: 'Content',
      createdAt: now,
      modifiedAt: modifiedAt ?? now,
      isDeleted: isDeleted,
    );
  }

  group('LocalStorageService CRUD', () {
    test('inserts and retrieves a note by ID', () async {
      final note = createTestNote('user1');
      await storage.insertNote(note);

      final retrieved = await storage.getNoteById(note.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, note.id);
      expect(retrieved.title, 'Test');
    });

    test('getAllNotes returns only non-deleted notes ordered by modifiedAt DESC', () async {
      final oldNote = createTestNote('user1', title: 'Old Note', modifiedAt: DateTime.now().subtract(const Duration(days: 1)));
      final newNote = createTestNote('user1', title: 'New Note', modifiedAt: DateTime.now());
      final deletedNote = createTestNote('user1', title: 'Deleted', isDeleted: true);

      await storage.insertNote(oldNote);
      await storage.insertNote(newNote);
      await storage.insertNote(deletedNote);

      final notes = await storage.getAllNotes('user1');
      expect(notes.length, 2);
      expect(notes.first.id, newNote.id); // Newest first
      expect(notes.last.id, oldNote.id);
      expect(notes.any((n) => n.id == deletedNote.id), isFalse);
    });

    test('getAllNotesForSync returns all notes ordered by modifiedAt ASC', () async {
      final oldNote = createTestNote('user1', title: 'Old Note', modifiedAt: DateTime.now().subtract(const Duration(days: 1)));
      final newNote = createTestNote('user1', title: 'New Note', modifiedAt: DateTime.now());
      final deletedNote = createTestNote('user1', title: 'Deleted', isDeleted: true, modifiedAt: DateTime.now().subtract(const Duration(hours: 12)));

      await storage.insertNote(newNote); // insert new note first
      await storage.insertNote(oldNote);
      await storage.insertNote(deletedNote);

      final notes = await storage.getAllNotesForSync('user1');
      expect(notes.length, 3);
      expect(notes[0].id, oldNote.id); // Oldest first
      expect(notes[1].id, deletedNote.id);
      expect(notes[2].id, newNote.id);
    });

    test('softDeleteNote sets isDeleted to 1', () async {
      final note = createTestNote('user1');
      await storage.insertNote(note);

      await storage.softDeleteNote(note.id);

      final retrieved = await storage.getNoteById(note.id);
      expect(retrieved!.isDeleted, isTrue);
      expect(retrieved.modifiedAt.isAfter(note.modifiedAt), isTrue); // Timestamp bumped
    });

    test('hardDeleteNote removes the row completely', () async {
      final note = createTestNote('user1');
      await storage.insertNote(note);

      await storage.hardDeleteNote(note.id);

      final retrieved = await storage.getNoteById(note.id);
      expect(retrieved, isNull);
    });

    test('getNotesModifiedAfter filters correctly', () async {
      final baseTime = DateTime.parse('2024-01-01T12:00:00Z');
      
      final note1 = createTestNote('user1', modifiedAt: baseTime.subtract(const Duration(hours: 1)));
      final note2 = createTestNote('user1', modifiedAt: baseTime.add(const Duration(hours: 1)));
      final note3 = createTestNote('user2', modifiedAt: baseTime.add(const Duration(hours: 2))); // wrong user

      await storage.insertNote(note1);
      await storage.insertNote(note2);
      await storage.insertNote(note3);

      final notes = await storage.getNotesModifiedAfter(baseTime, 'user1');
      expect(notes.length, 1);
      expect(notes.first.id, note2.id);
    });
  });
}
