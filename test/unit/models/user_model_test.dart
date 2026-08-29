import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/models/user_model.dart';

void main() {
  group('User Model', () {
    late User testUser;
    late DateTime testCreatedAt;
    late DateTime testLastLoginAt;

    setUp(() {
      testCreatedAt = DateTime(2024, 1, 1, 12, 0, 0);
      testLastLoginAt = DateTime(2024, 1, 2, 12, 0, 0);
      
      testUser = User(
        uid: 'test-uid-123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: testCreatedAt,
        lastLoginAt: testLastLoginAt,
      );
    });

    group('Constructor', () {
      test('creates user with all fields', () {
        expect(testUser.uid, equals('test-uid-123'));
        expect(testUser.email, equals('test@example.com'));
        expect(testUser.displayName, equals('Test User'));
        expect(testUser.photoUrl, equals('https://example.com/photo.jpg'));
        expect(testUser.createdAt, equals(testCreatedAt));
        expect(testUser.lastLoginAt, equals(testLastLoginAt));
      });

      test('creates user with null optional fields', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: DateTime.now(),
        );
        
        expect(user.displayName, isNull);
        expect(user.photoUrl, isNull);
        expect(user.lastLoginAt, isNull);
      });

      test('creates user with only required fields', () {
        final user = User(
          uid: 'uid-456',
          email: 'minimal@example.com',
          createdAt: testCreatedAt,
        );
        
        expect(user.uid, equals('uid-456'));
        expect(user.email, equals('minimal@example.com'));
        expect(user.createdAt, equals(testCreatedAt));
        expect(user.displayName, isNull);
        expect(user.photoUrl, isNull);
        expect(user.lastLoginAt, isNull);
      });
    });

    group('JSON Serialization', () {
      test('toJson converts user to JSON map with all fields', () {
        final json = testUser.toJson();
        
        expect(json['uid'], equals('test-uid-123'));
        expect(json['email'], equals('test@example.com'));
        expect(json['displayName'], equals('Test User'));
        expect(json['photoUrl'], equals('https://example.com/photo.jpg'));
        expect(json['createdAt'], equals(testCreatedAt.toIso8601String()));
        expect(json['lastLoginAt'], equals(testLastLoginAt.toIso8601String()));
      });

      test('toJson handles null optional fields', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: testCreatedAt,
        );
        
        final json = user.toJson();
        
        expect(json['uid'], equals('uid'));
        expect(json['email'], equals('user@example.com'));
        expect(json['displayName'], isNull);
        expect(json['photoUrl'], isNull);
        expect(json['createdAt'], equals(testCreatedAt.toIso8601String()));
        expect(json['lastLoginAt'], isNull);
      });

      test('fromJson creates user from JSON map with all fields', () {
        final json = {
          'uid': 'json-uid',
          'email': 'json@example.com',
          'displayName': 'JSON User',
          'photoUrl': 'https://example.com/json.jpg',
          'createdAt': '2024-01-01T12:00:00.000',
          'lastLoginAt': '2024-01-02T12:00:00.000',
        };
        
        final user = User.fromJson(json);
        
        expect(user.uid, equals('json-uid'));
        expect(user.email, equals('json@example.com'));
        expect(user.displayName, equals('JSON User'));
        expect(user.photoUrl, equals('https://example.com/json.jpg'));
        expect(user.createdAt, equals(DateTime.parse('2024-01-01T12:00:00.000')));
        expect(user.lastLoginAt, equals(DateTime.parse('2024-01-02T12:00:00.000')));
      });

      test('fromJson handles null optional fields', () {
        final json = {
          'uid': 'uid',
          'email': 'user@example.com',
          'displayName': null,
          'photoUrl': null,
          'createdAt': '2024-01-01T12:00:00.000',
          'lastLoginAt': null,
        };
        
        final user = User.fromJson(json);
        
        expect(user.uid, equals('uid'));
        expect(user.email, equals('user@example.com'));
        expect(user.displayName, isNull);
        expect(user.photoUrl, isNull);
        expect(user.createdAt, equals(DateTime.parse('2024-01-01T12:00:00.000')));
        expect(user.lastLoginAt, isNull);
      });

      test('JSON round trip preserves all data', () {
        final json = testUser.toJson();
        final restored = User.fromJson(json);
        
        expect(restored, equals(testUser));
      });

      test('JSON round trip preserves data with null fields', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: testCreatedAt,
        );
        
        final json = user.toJson();
        final restored = User.fromJson(json);
        
        expect(restored, equals(user));
      });
    });

    group('Equality', () {
      test('users with same data are equal', () {
        final user1 = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: 'User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
        );
        
        final user2 = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: 'User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: testCreatedAt,
          lastLoginAt: testLastLoginAt,
        );
        
        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('users with different uid are not equal', () {
        final user1 = testUser;
        final user2 = User(
          uid: 'different-uid',
          email: testUser.email,
          displayName: testUser.displayName,
          photoUrl: testUser.photoUrl,
          createdAt: testUser.createdAt,
          lastLoginAt: testUser.lastLoginAt,
        );
        
        expect(user1, isNot(equals(user2)));
      });

      test('users with different email are not equal', () {
        final user1 = testUser;
        final user2 = User(
          uid: testUser.uid,
          email: 'different@example.com',
          displayName: testUser.displayName,
          photoUrl: testUser.photoUrl,
          createdAt: testUser.createdAt,
          lastLoginAt: testUser.lastLoginAt,
        );
        
        expect(user1, isNot(equals(user2)));
      });

      test('users with null vs non-null optional fields are not equal', () {
        final user1 = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: 'User',
          createdAt: testCreatedAt,
        );
        
        final user2 = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: null,
          createdAt: testCreatedAt,
        );
        
        expect(user1, isNot(equals(user2)));
      });
    });

    group('Edge Cases', () {
      test('handles empty displayName', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: '',
          createdAt: DateTime.now(),
        );
        
        expect(user.displayName, equals(''));
        
        // Test serialization
        final json = user.toJson();
        final restored = User.fromJson(json);
        expect(restored.displayName, equals(''));
      });

      test('handles special characters in displayName', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          displayName: 'User with émojis 🎉 and "quotes"',
          createdAt: DateTime.now(),
        );
        
        final json = user.toJson();
        final restored = User.fromJson(json);
        
        expect(restored.displayName, equals(user.displayName));
      });

      test('handles various email formats', () {
        final emails = [
          'simple@example.com',
          'user+tag@example.com',
          'user.name@example.co.uk',
          'user_name@sub.example.com',
        ];
        
        for (final email in emails) {
          final user = User(
            uid: 'uid',
            email: email,
            createdAt: DateTime.now(),
          );
          
          final json = user.toJson();
          final restored = User.fromJson(json);
          
          expect(restored.email, equals(email));
        }
      });

      test('handles various photoUrl formats', () {
        final urls = [
          'https://example.com/photo.jpg',
          'https://example.com/path/to/photo.png',
          'https://cdn.example.com/user/123/avatar.gif',
        ];
        
        for (final url in urls) {
          final user = User(
            uid: 'uid',
            email: 'user@example.com',
            photoUrl: url,
            createdAt: DateTime.now(),
          );
          
          final json = user.toJson();
          final restored = User.fromJson(json);
          
          expect(restored.photoUrl, equals(url));
        }
      });

      test('handles createdAt and lastLoginAt with same timestamp', () {
        final timestamp = DateTime.now();
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: timestamp,
          lastLoginAt: timestamp,
        );
        
        expect(user.createdAt, equals(user.lastLoginAt));
        
        final json = user.toJson();
        final restored = User.fromJson(json);
        
        expect(restored.createdAt, equals(restored.lastLoginAt));
      });

      test('handles lastLoginAt before createdAt', () {
        // This shouldn't happen in practice, but the model should handle it
        final createdAt = DateTime(2024, 1, 2);
        final lastLoginAt = DateTime(2024, 1, 1);
        
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: createdAt,
          lastLoginAt: lastLoginAt,
        );
        
        expect(user.lastLoginAt!.isBefore(user.createdAt), isTrue);
        
        final json = user.toJson();
        final restored = User.fromJson(json);
        
        expect(restored.createdAt, equals(createdAt));
        expect(restored.lastLoginAt, equals(lastLoginAt));
      });
    });

    group('toString', () {
      test('toString includes all fields', () {
        final str = testUser.toString();
        
        expect(str, contains('test-uid-123'));
        expect(str, contains('test@example.com'));
        expect(str, contains('Test User'));
        expect(str, contains('https://example.com/photo.jpg'));
      });

      test('toString handles null optional fields', () {
        final user = User(
          uid: 'uid',
          email: 'user@example.com',
          createdAt: testCreatedAt,
        );
        
        final str = user.toString();
        
        expect(str, contains('uid'));
        expect(str, contains('user@example.com'));
        expect(str, contains('null'));
      });
    });
  });
}
