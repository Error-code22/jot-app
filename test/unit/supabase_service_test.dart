import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:jot_app/models/auth_state.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/services/supabase_service.dart';

import 'supabase_service_test.mocks.dart';

@GenerateMocks([supa.SupabaseClient, supa.GoTrueClient])
void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockGoTrue;

  /// Creates a fake gotrue User with sensible defaults.
  supa.User fakeUser({
    String id = 'user-1',
    String email = 'test@example.com',
    Map<String, dynamic>? userMetadata,
  }) {
    return supa.User(
      id: id,
      appMetadata: const {},
      userMetadata: userMetadata,
      aud: 'authenticated',
      email: email,
      createdAt: '2026-01-01T00:00:00Z',
    );
  }

  SupabaseService createService() {
    when(mockClient.auth).thenReturn(mockGoTrue);
    when(mockGoTrue.onAuthStateChange)
        .thenAnswer((_) => const Stream<supa.AuthState>.empty());
    return SupabaseService(client: mockClient);
  }

  setUp(() {
    mockClient = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
  });

  group('SupabaseService auth', () {
    test('signInWithEmail returns mapped user on success', () async {
      when(mockGoTrue.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => supa.AuthResponse(user: fakeUser(
        userMetadata: {'display_name': 'Test User'},
      )));

      final service = createService();
      final result = await service.signInWithEmail('test@example.com', 'secret');

      expect(result.success, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.uid, 'user-1');
      expect(result.user!.email, 'test@example.com');
      expect(result.user!.displayName, 'Test User');
    });

    test('signInWithEmail returns error message on AuthException', () async {
      when(mockGoTrue.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(const supa.AuthException('Invalid login credentials'));

      final service = createService();
      final result = await service.signInWithEmail('test@example.com', 'wrong');

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid login credentials');
    });

    test('signUpWithEmail returns mapped user on success', () async {
      when(mockGoTrue.signUp(
        email: anyNamed('email'),
        password: anyNamed('password'),
        data: anyNamed('data'),
      )).thenAnswer((_) async => supa.AuthResponse(user: fakeUser(
        email: 'new@example.com',
      )));

      final service = createService();
      final result = await service.signUpWithEmail(
        'new@example.com',
        'secret123',
        displayName: 'New User',
      );

      expect(result.success, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.email, 'new@example.com');
      expect(result.user!.displayName, 'New User');
    });

    test('signInWithGmail reports not configured', () async {
      final service = createService();
      final result = await service.signInWithGmail();

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('restoreSession returns false when no session exists', () async {
      when(mockGoTrue.currentSession).thenReturn(null);

      final service = createService();
      final restored = await service.restoreSession();

      expect(restored, isFalse);
      expect(service.isAuthenticated(), isFalse);
    });

    test('getCurrentUser returns null when signed out', () {
      when(mockGoTrue.currentUser).thenReturn(null);

      final service = createService();

      expect(service.getCurrentUser(), isNull);
    });

    test('getCurrentUser maps Supabase user to Jot User', () {
      when(mockGoTrue.currentUser).thenReturn(fakeUser(
        userMetadata: {'display_name': 'Mapped User'},
      ));

      final service = createService();
      final user = service.getCurrentUser();

      expect(user, isNotNull);
      expect(user!.uid, 'user-1');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Mapped User');
    });

    test('signOut emits unauthenticated state', () async {
      when(mockGoTrue.signOut()).thenAnswer((_) async {});

      final service = createService();
      final states = <AuthState>[];
      final sub = service.authStateChanges.listen(states.add);
      addTearDown(sub.cancel);

      await service.signOut();
      await pumpEventQueue();

      expect(states.last.status, AuthStatus.unauthenticated);
    });
  });

  group('SupabaseService remote storage', () {
    Note makeNote() => Note(
          id: 'note-1',
          userId: 'user-1',
          title: 'Title',
          content: 'Body',
          createdAt: DateTime(2026, 1, 1),
          modifiedAt: DateTime(2026, 1, 2),
        );

    test('uploadNote rethrows on network failure', () async {
      when(mockClient.from('notes')).thenThrow(Exception('network down'));

      final service = createService();

      await expectLater(service.uploadNote(makeNote()), throwsException);
    });

    test('downloadNote returns null on network failure', () async {
      when(mockClient.from('notes')).thenThrow(Exception('network down'));

      final service = createService();

      expect(await service.downloadNote('user-1', 'note-1'), isNull);
    });

    test('downloadAllNotes returns empty list on network failure', () async {
      when(mockClient.from('notes')).thenThrow(Exception('network down'));

      final service = createService();

      expect(await service.downloadAllNotes('user-1'), isEmpty);
    });

    test('deleteNote swallows network failures', () async {
      when(mockClient.from('notes')).thenThrow(Exception('network down'));

      final service = createService();

      await service.deleteNote('user-1', 'note-1');
    });
  });
}
