import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jot_app/services/sync_engine.dart';
import 'package:jot_app/services/i_local_storage_service.dart';
import 'package:jot_app/services/i_remote_storage_service.dart';
import 'package:jot_app/models/note_model.dart';
import 'sync_engine_test.mocks.dart';

@GenerateMocks([ILocalStorageService, IRemoteStorageService, Connectivity])
void main() {
  late SyncEngine syncEngine;
  late MockILocalStorageService mockLocal;
  late MockIRemoteStorageService mockRemote;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockLocal = MockILocalStorageService();
    mockRemote = MockIRemoteStorageService();
    mockConnectivity = MockConnectivity();

    when(mockConnectivity.onConnectivityChanged).thenAnswer((_) => Stream.value(ConnectivityResult.wifi));
    when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => ConnectivityResult.wifi);

    syncEngine = SyncEngine(
      mockLocal,
      mockRemote,
      connectivity: mockConnectivity,
    );
  });

  group('SyncEngine Conflict Resolution', () {
    const userId = 'user1';

    test('syncNow pulls cloud changes and resolves conflict (cloud wins)', () async {
      final now = DateTime.now();
      final localNote = Note(
        id: '1',
        userId: userId,
        title: 'Local version',
        content: '...',
        createdAt: now.subtract(const Duration(hours: 2)),
        modifiedAt: now.subtract(const Duration(hours: 1)),
      );
      final cloudNote = Note(
        id: '1',
        userId: userId,
        title: 'Cloud version',
        content: '...',
        createdAt: now.subtract(const Duration(hours: 2)),
        modifiedAt: now,
      );

      when(mockRemote.downloadAllNotes(userId)).thenAnswer((_) async => [cloudNote]);
      when(mockLocal.getNoteById('1')).thenAnswer((_) async => localNote);
      when(mockLocal.getNotesModifiedAfter(any, userId)).thenAnswer((_) async => []);

      await syncEngine.syncNow(userId);

      verify(mockLocal.insertNote(argThat(predicate((Note n) => n.title == 'Cloud version')))).called(1);
    });

    test('syncNow pushes local changes to cloud', () async {
      final note = Note(
        id: '2',
        userId: userId,
        title: 'New local',
        content: '...',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      when(mockRemote.downloadAllNotes(userId)).thenAnswer((_) async => []);
      when(mockLocal.getAllNotesForSync(userId)).thenAnswer((_) async => [note]);

      await syncEngine.syncNow(userId);

      verify(mockRemote.uploadNote(note)).called(1);
    });
  });
}
