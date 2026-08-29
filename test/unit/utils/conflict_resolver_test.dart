import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/models/note_model.dart';
import 'package:jot_app/utils/conflict_resolver.dart';

void main() {
  late ConflictResolver resolver;

  setUp(() {
    resolver = ConflictResolver();
  });

  group('ConflictResolver', () {
    group('resolveConflict', () {
      test('returns local note when local is more recent', () {
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(hours: 1));
        
        final localNote = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Local Title',
          content: 'Local content',
          createdAt: earlier,
          modifiedAt: now,
        );
        
        final cloudNote = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Cloud Title',
          content: 'Cloud content',
          createdAt: earlier,
          modifiedAt: earlier,
        );
        
        final result = resolver.resolveConflict(localNote, cloudNote);
        
        expect(result, equals(localNote));
        expect(result.title, equals('Local Title'));
      });

      test('returns cloud note when cloud is more recent', () {
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(hours: 1));
        
        final localNote = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Local Title',
          content: 'Local content',
          createdAt: earlier,
          modifiedAt: earlier,
        );
        
        final cloudNote = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Cloud Title',
          content: 'Cloud content',
          createdAt: earlier,
          modifiedAt: now,
        );
        
        final result = resolver.resolveConflict(localNote, cloudNote);
        
        expect(result, equals(cloudNote));
        expect(result.title, equals('Cloud Title'));
      });

      test('uses note ID lexicographic comparison as tiebreaker when timestamps are identical', () {
        final now = DateTime.now();
        
        // Note with ID 'b' should win over 'a' (lexicographically greater)
        final localNote = Note(
          id: 'b',
          userId: 'user1',
          title: 'Local Title',
          content: 'Local content',
          createdAt: now,
          modifiedAt: now,
        );
        
        final cloudNote = Note(
          id: 'b',
          userId: 'user1',
          title: 'Cloud Title',
          content: 'Cloud content',
          createdAt: now,
          modifiedAt: now,
        );
        
        final result = resolver.resolveConflict(localNote, cloudNote);
        
        // When IDs are the same and timestamps identical, local should win (>= 0)
        expect(result, equals(localNote));
      });

      test('tiebreaker is deterministic across different devices', () {
        final now = DateTime.now();
        
        final noteA = Note(
          id: 'aaa',
          userId: 'user1',
          title: 'Title A',
          content: 'Content A',
          createdAt: now,
          modifiedAt: now,
        );
        
        final noteB = Note(
          id: 'bbb',
          userId: 'user1',
          title: 'Title B',
          content: 'Content B',
          createdAt: now,
          modifiedAt: now,
        );
        
        // Resolve from both perspectives
        final resultAB = resolver.resolveConflict(noteA, noteB);
        final resultBA = resolver.resolveConflict(noteB, noteA);
        
        // Both should resolve to the same note (the one with lexicographically greater ID)
        expect(resultAB.id, equals('bbb'));
        expect(resultBA.id, equals('bbb'));
      });
    });

    group('hasConflict', () {
      test('returns false when notes are identical', () {
        final now = DateTime.now();
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
        );
        
        final note2 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
        );
        
        expect(resolver.hasConflict(note1, note2), isFalse);
      });

      test('returns true when timestamps differ', () {
        final now = DateTime.now();
        final earlier = now.subtract(const Duration(hours: 1));
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: earlier,
          modifiedAt: now,
        );
        
        final note2 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: earlier,
          modifiedAt: earlier,
        );
        
        expect(resolver.hasConflict(note1, note2), isTrue);
      });

      test('returns true when titles differ', () {
        final now = DateTime.now();
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Title 1',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
        );
        
        final note2 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Title 2',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
        );
        
        expect(resolver.hasConflict(note1, note2), isTrue);
      });

      test('returns true when content differs', () {
        final now = DateTime.now();
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Content 1',
          createdAt: now,
          modifiedAt: now,
        );
        
        final note2 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Content 2',
          createdAt: now,
          modifiedAt: now,
        );
        
        expect(resolver.hasConflict(note1, note2), isTrue);
      });

      test('returns true when isDeleted differs', () {
        final now = DateTime.now();
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
          isDeleted: false,
        );
        
        final note2 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Same Title',
          content: 'Same content',
          createdAt: now,
          modifiedAt: now,
          isDeleted: true,
        );
        
        expect(resolver.hasConflict(note1, note2), isTrue);
      });

      test('returns false when note IDs differ', () {
        final now = DateTime.now();
        
        final note1 = Note(
          id: 'note1',
          userId: 'user1',
          title: 'Title',
          content: 'Content',
          createdAt: now,
          modifiedAt: now,
        );
        
        final note2 = Note(
          id: 'note2',
          userId: 'user1',
          title: 'Title',
          content: 'Content',
          createdAt: now,
          modifiedAt: now,
        );
        
        expect(resolver.hasConflict(note1, note2), isFalse);
      });
    });
  });
}
