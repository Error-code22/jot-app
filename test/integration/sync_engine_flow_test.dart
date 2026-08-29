import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:jot_app/services/sync_engine.dart';
import 'package:jot_app/services/i_local_storage_service.dart';
import 'package:jot_app/services/i_remote_storage_service.dart';
import 'package:jot_app/models/note_model.dart';
import 'sync_engine_flow_test.mocks.dart';

@GenerateMocks([ILocalStorageService, IRemoteStorageService])
void main() {
  group('SyncEngine flow integration', () {
    late MockILocalStorageService mockStorage;
    late MockIRemoteStorageService mockRemote;
    late SyncEngine syncEngine;

    setUp(() {
      mockStorage = MockILocalStorageService();
      mockRemote = MockIRemoteStorageService();
      syncEngine = SyncEngine(mockStorage, mockRemote);

      // Default stubs
      when(mockStorage.initialize()).thenAnswer((_) async {});
      when(mockStorage.getAllNotesForSync(any)).thenAnswer((_) async => []);
      when(mockStorage.getNotesModifiedAfter(any, any)).thenAnswer((_) async => []);
      when(mockStorage.getAllNotes(any)).thenAnswer((_) async => []);
      when(mockRemote.downloadAllNotes(any)).thenAnswer((_) async => []);
      when(mockRemote.watchNotes(any)).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      syncEngine.dispose();
    });

    test('first sync uses full local query, subsequent syncs use incremental query', () async {
      // First sync: no last-sync timestamp yet, so it uses getAllNotesForSync.
      await syncEngine.syncNow('test-user');
      verify(mockStorage.getAllNotesForSync('test-user')).called(1);

      // After a successful sync the engine tracks _lastSyncTime, so the
      // next sync pushes incrementally via getNotesModifiedAfter.
      await syncEngine.syncNow('test-user');
      verify(mockStorage.getNotesModifiedAfter(any, 'test-user')).called(greaterThanOrEqualTo(1));
    });

    test('syncNow uploads pending notes to remote', () async {
      final now = DateTime.now();
      final pendingNote = Note(
        id: 'pending-1',
        userId: 'test-user',
        title: 'Pending Note',
        content: 'Content',
        createdAt: now,
        modifiedAt: now,
      );

      when(mockStorage.getAllNotesForSync(any))
          .thenAnswer((_) async => [pendingNote]);
      when(mockStorage.getNotesModifiedAfter(any, any))
          .thenAnswer((_) async => [pendingNote]);
      when(mockRemote.uploadNote(any)).thenAnswer((_) async => pendingNote);
      when(mockStorage.updateNote(any)).thenAnswer((_) async {});

      await syncEngine.syncNow('test-user');

      verify(mockRemote.uploadNote(any)).called(greaterThanOrEqualTo(1));
    });
  });
}
