import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:jot_app/services/note_service.dart';
import 'package:jot_app/services/i_local_storage_service.dart';
import 'package:jot_app/services/i_sync_engine.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/models/sync_result.dart';
import 'note_service_test.mocks.dart';

@GenerateMocks([ILocalStorageService, ISyncEngine])
void main() {
  late NoteService noteService;
  late MockILocalStorageService mockLocal;
  late MockISyncEngine mockSync;

  setUp(() {
    mockLocal = MockILocalStorageService();
    mockSync = MockISyncEngine();
    noteService = NoteService(mockLocal, mockSync);
  });

  group('NoteService', () {
    const userId = 'user123';
    final dummySyncResult = SyncResult.empty();

    test('createNote saves locally and triggers sync', () async {
      when(mockLocal.insertNote(any)).thenAnswer((_) async => {});
      when(mockLocal.getAllNotes(userId)).thenAnswer((_) async => []);
      when(mockSync.syncNow(userId)).thenAnswer((_) async => dummySyncResult);

      final note = await noteService.createNote(
        userId: userId,
        title: 'New Note',
        content: 'Content',
      );

      expect(note.title, 'New Note');
      expect(note.userId, userId);
      verify(mockLocal.insertNote(argThat(predicate((Note n) => n.id == note.id)))).called(1);
      verify(mockSync.syncNow(userId)).called(1);
    });

    test('updateNote updates local and triggers sync', () async {
      final note = Note(
        id: '1',
        userId: userId,
        title: 'Old',
        content: 'Old',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      when(mockLocal.updateNote(any)).thenAnswer((_) async => {});
      when(mockLocal.getAllNotes(userId)).thenAnswer((_) async => []);
      when(mockSync.syncNow(userId)).thenAnswer((_) async => dummySyncResult);

      final updated = await noteService.updateNote(note, title: 'New');

      expect(updated.title, 'New');
      verify(mockLocal.updateNote(argThat(predicate((Note n) => n.title == 'New')))).called(1);
      verify(mockSync.syncNow(userId)).called(1);
    });

    test('deleteNote soft deletes and triggers sync', () async {
      final note = Note(
        id: '1',
        userId: userId,
        title: 'To Delete',
        content: 'Content',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      when(mockLocal.softDeleteNote(any)).thenAnswer((_) async => {});
      when(mockLocal.getAllNotes(userId)).thenAnswer((_) async => []);
      when(mockSync.syncNow(userId)).thenAnswer((_) async => dummySyncResult);

      await noteService.deleteNote(note);

      verify(mockLocal.softDeleteNote(note.id)).called(1);
      verify(mockSync.syncNow(userId)).called(1);
    });
  });
}
