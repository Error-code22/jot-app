import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/models/note_model.dart';

void main() {
  group('Note Model', () {
    late Note testNote;
    late DateTime testCreatedAt;
    late DateTime testModifiedAt;

    setUp(() {
      testCreatedAt = DateTime(2024, 1, 1, 12, 0, 0);
      testModifiedAt = DateTime(2024, 1, 2, 12, 0, 0);
      
      testNote = Note(
        id: 'test-id-123',
        userId: 'user-456',
        title: 'Test Note',
        content: 'This is test content',
        createdAt: testCreatedAt,
        modifiedAt: testModifiedAt,
        isDeleted: false,
      );
    });

    group('Constructor', () {
      test('creates note with all required fields', () {
        expect(testNote.id, equals('test-id-123'));
        expect(testNote.userId, equals('user-456'));
        expect(testNote.title, equals('Test Note'));
        expect(testNote.content, equals('This is test content'));
        expect(testNote.createdAt, equals(testCreatedAt));
        expect(testNote.modifiedAt, equals(testModifiedAt));
        expect(testNote.isDeleted, equals(false));
      });

      test('defaults isDeleted to false when not provided', () {
        final note = Note(
          id: 'id',
          userId: 'user',
          title: 'Title',
          content: 'Content',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
        
        expect(note.isDeleted, equals(false));
      });
    });

    group('copyWith', () {
      test('creates copy with updated title', () {
        final updated = testNote.copyWith(title: 'Updated Title');
        
        expect(updated.title, equals('Updated Title'));
        expect(updated.id, equals(testNote.id));
        expect(updated.userId, equals(testNote.userId));
        expect(updated.content, equals(testNote.content));
        expect(updated.createdAt, equals(testNote.createdAt));
        expect(updated.modifiedAt, equals(testNote.modifiedAt));
      });

      test('creates copy with updated content', () {
        final updated = testNote.copyWith(content: 'New content');
        
        expect(updated.content, equals('New content'));
        expect(updated.title, equals(testNote.title));
      });

      test('creates copy with updated modifiedAt', () {
        final newModifiedAt = DateTime(2024, 1, 3, 12, 0, 0);
        final updated = testNote.copyWith(modifiedAt: newModifiedAt);
        
        expect(updated.modifiedAt, equals(newModifiedAt));
        expect(updated.createdAt, equals(testNote.createdAt));
      });

      test('creates copy with updated isDeleted', () {
        final updated = testNote.copyWith(isDeleted: true);
        
        expect(updated.isDeleted, equals(true));
      });

      test('creates copy with multiple updated fields', () {
        final newModifiedAt = DateTime(2024, 1, 3, 12, 0, 0);
        final updated = testNote.copyWith(
          title: 'New Title',
          content: 'New Content',
          modifiedAt: newModifiedAt,
          isDeleted: true,
        );
        
        expect(updated.title, equals('New Title'));
        expect(updated.content, equals('New Content'));
        expect(updated.modifiedAt, equals(newModifiedAt));
        expect(updated.isDeleted, equals(true));
      });

      test('preserves immutable fields (id, userId, createdAt)', () {
        final updated = testNote.copyWith(title: 'Changed');
        
        expect(updated.id, equals(testNote.id));
        expect(updated.userId, equals(testNote.userId));
        expect(updated.createdAt, equals(testNote.createdAt));
      });
    });

    group('JSON Serialization', () {
      test('toJson converts note to JSON map', () {
        final json = testNote.toJson();
        
        expect(json['id'], equals('test-id-123'));
        expect(json['userId'], equals('user-456'));
        expect(json['title'], equals('Test Note'));
        expect(json['content'], equals('This is test content'));
        expect(json['createdAt'], equals(testCreatedAt.toIso8601String()));
        expect(json['modifiedAt'], equals(testModifiedAt.toIso8601String()));
        expect(json['isDeleted'], equals(false));
      });

      test('fromJson creates note from JSON map', () {
        final json = {
          'id': 'json-id',
          'userId': 'json-user',
          'title': 'JSON Title',
          'content': 'JSON Content',
          'createdAt': '2024-01-01T12:00:00.000',
          'modifiedAt': '2024-01-02T12:00:00.000',
          'isDeleted': true,
        };
        
        final note = Note.fromJson(json);
        
        expect(note.id, equals('json-id'));
        expect(note.userId, equals('json-user'));
        expect(note.title, equals('JSON Title'));
        expect(note.content, equals('JSON Content'));
        expect(note.createdAt, equals(DateTime.parse('2024-01-01T12:00:00.000')));
        expect(note.modifiedAt, equals(DateTime.parse('2024-01-02T12:00:00.000')));
        expect(note.isDeleted, equals(true));
      });

      test('fromJson defaults isDeleted to false when missing', () {
        final json = {
          'id': 'json-id',
          'userId': 'json-user',
          'title': 'JSON Title',
          'content': 'JSON Content',
          'createdAt': '2024-01-01T12:00:00.000',
          'modifiedAt': '2024-01-02T12:00:00.000',
        };
        
        final note = Note.fromJson(json);
        
        expect(note.isDeleted, equals(false));
      });

      test('JSON round trip preserves all data', () {
        final json = testNote.toJson();
        final restored = Note.fromJson(json);
        
        expect(restored, equals(testNote));
      });
    });

    group('SQLite Serialization', () {
      test('toSqlite converts note to SQLite map', () {
        final sqlite = testNote.toSqlite();
        
        expect(sqlite['id'], equals('test-id-123'));
        expect(sqlite['userId'], equals('user-456'));
        expect(sqlite['title'], equals('Test Note'));
        expect(sqlite['content'], equals('This is test content'));
        expect(sqlite['createdAt'], equals(testCreatedAt.millisecondsSinceEpoch));
        expect(sqlite['modifiedAt'], equals(testModifiedAt.millisecondsSinceEpoch));
        expect(sqlite['isDeleted'], equals(0));
      });

      test('toSqlite converts isDeleted true to 1', () {
        final deletedNote = testNote.copyWith(isDeleted: true);
        final sqlite = deletedNote.toSqlite();
        
        expect(sqlite['isDeleted'], equals(1));
      });

      test('fromSqlite creates note from SQLite map', () {
        final sqlite = {
          'id': 'sqlite-id',
          'userId': 'sqlite-user',
          'title': 'SQLite Title',
          'content': 'SQLite Content',
          'createdAt': testCreatedAt.millisecondsSinceEpoch,
          'modifiedAt': testModifiedAt.millisecondsSinceEpoch,
          'isDeleted': 1,
        };
        
        final note = Note.fromSqlite(sqlite);
        
        expect(note.id, equals('sqlite-id'));
        expect(note.userId, equals('sqlite-user'));
        expect(note.title, equals('SQLite Title'));
        expect(note.content, equals('SQLite Content'));
        expect(note.createdAt, equals(testCreatedAt));
        expect(note.modifiedAt, equals(testModifiedAt));
        expect(note.isDeleted, equals(true));
      });

      test('fromSqlite converts isDeleted 0 to false', () {
        final sqlite = {
          'id': 'id',
          'userId': 'user',
          'title': 'Title',
          'content': 'Content',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'modifiedAt': DateTime.now().millisecondsSinceEpoch,
          'isDeleted': 0,
        };
        
        final note = Note.fromSqlite(sqlite);
        
        expect(note.isDeleted, equals(false));
      });

      test('SQLite round trip preserves all data', () {
        final sqlite = testNote.toSqlite();
        final restored = Note.fromSqlite(sqlite);
        
        expect(restored, equals(testNote));
      });
    });

    group('Equality', () {
      test('notes with same data are equal', () {
        final note1 = Note(
          id: 'id',
          userId: 'user',
          title: 'Title',
          content: 'Content',
          createdAt: testCreatedAt,
          modifiedAt: testModifiedAt,
          isDeleted: false,
        );
        
        final note2 = Note(
          id: 'id',
          userId: 'user',
          title: 'Title',
          content: 'Content',
          createdAt: testCreatedAt,
          modifiedAt: testModifiedAt,
          isDeleted: false,
        );
        
        expect(note1, equals(note2));
        expect(note1.hashCode, equals(note2.hashCode));
      });

      test('notes with different data are not equal', () {
        final note1 = testNote;
        final note2 = testNote.copyWith(title: 'Different');
        
        expect(note1, isNot(equals(note2)));
      });
    });

    group('Edge Cases', () {
      test('handles empty title and content', () {
        final note = Note(
          id: 'id',
          userId: 'user',
          title: '',
          content: '',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
        
        expect(note.title, equals(''));
        expect(note.content, equals(''));
        
        // Test serialization
        final json = note.toJson();
        final restored = Note.fromJson(json);
        expect(restored.title, equals(''));
        expect(restored.content, equals(''));
      });

      test('handles special characters in title and content', () {
        final note = Note(
          id: 'id',
          userId: 'user',
          title: 'Title with émojis 🎉 and "quotes"',
          content: 'Content with\nnewlines\tand\ttabs',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
        
        final json = note.toJson();
        final restored = Note.fromJson(json);
        
        expect(restored.title, equals(note.title));
        expect(restored.content, equals(note.content));
      });

      test('handles very long content', () {
        final longContent = 'A' * 10000;
        final note = Note(
          id: 'id',
          userId: 'user',
          title: 'Long Note',
          content: longContent,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
        
        final sqlite = note.toSqlite();
        final restored = Note.fromSqlite(sqlite);
        
        expect(restored.content, equals(longContent));
        expect(restored.content.length, equals(10000));
      });
    });
  });
}
