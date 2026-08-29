import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/models/sync_state.dart';

void main() {
  group('SyncState Model', () {
    late SyncState testSyncState;
    late DateTime testLastSyncTime;

    setUp(() {
      testLastSyncTime = DateTime(2024, 1, 1, 12, 0, 0);
      
      testSyncState = SyncState(
        status: SyncStatus.success,
        lastSyncTime: testLastSyncTime,
        pendingChanges: 5,
        errorMessage: null,
      );
    });

    group('SyncStatus Enum', () {
      test('has all expected values', () {
        expect(SyncStatus.values, contains(SyncStatus.idle));
        expect(SyncStatus.values, contains(SyncStatus.syncing));
        expect(SyncStatus.values, contains(SyncStatus.success));
        expect(SyncStatus.values, contains(SyncStatus.error));
        expect(SyncStatus.values, contains(SyncStatus.offline));
      });

      test('has exactly 5 values', () {
        expect(SyncStatus.values.length, equals(5));
      });
    });

    group('Constructor', () {
      test('creates sync state with all fields', () {
        final syncState = SyncState(
          status: SyncStatus.syncing,
          lastSyncTime: testLastSyncTime,
          pendingChanges: 10,
          errorMessage: 'Test error',
        );
        
        expect(syncState.status, equals(SyncStatus.syncing));
        expect(syncState.lastSyncTime, equals(testLastSyncTime));
        expect(syncState.pendingChanges, equals(10));
        expect(syncState.errorMessage, equals('Test error'));
      });

      test('creates sync state with null optional fields', () {
        final syncState = SyncState(
          status: SyncStatus.idle,
        );
        
        expect(syncState.status, equals(SyncStatus.idle));
        expect(syncState.lastSyncTime, isNull);
        expect(syncState.pendingChanges, equals(0));
        expect(syncState.errorMessage, isNull);
      });

      test('creates sync state with default pendingChanges', () {
        final syncState = SyncState(
          status: SyncStatus.success,
          lastSyncTime: testLastSyncTime,
        );
        
        expect(syncState.pendingChanges, equals(0));
      });

      test('creates sync state with only required fields', () {
        final syncState = SyncState(
          status: SyncStatus.offline,
        );
        
        expect(syncState.status, equals(SyncStatus.offline));
        expect(syncState.lastSyncTime, isNull);
        expect(syncState.pendingChanges, equals(0));
        expect(syncState.errorMessage, isNull);
      });
    });

    group('Getters', () {
      test('isOnline returns true for idle status', () {
        final syncState = SyncState(status: SyncStatus.idle);
        expect(syncState.isOnline, isTrue);
      });

      test('isOnline returns true for syncing status', () {
        final syncState = SyncState(status: SyncStatus.syncing);
        expect(syncState.isOnline, isTrue);
      });

      test('isOnline returns true for success status', () {
        final syncState = SyncState(status: SyncStatus.success);
        expect(syncState.isOnline, isTrue);
      });

      test('isOnline returns true for error status', () {
        final syncState = SyncState(status: SyncStatus.error);
        expect(syncState.isOnline, isTrue);
      });

      test('isOnline returns false for offline status', () {
        final syncState = SyncState(status: SyncStatus.offline);
        expect(syncState.isOnline, isFalse);
      });

      test('hasPendingChanges returns false when pendingChanges is 0', () {
        final syncState = SyncState(
          status: SyncStatus.idle,
          pendingChanges: 0,
        );
        expect(syncState.hasPendingChanges, isFalse);
      });

      test('hasPendingChanges returns true when pendingChanges is positive', () {
        final syncState = SyncState(
          status: SyncStatus.idle,
          pendingChanges: 1,
        );
        expect(syncState.hasPendingChanges, isTrue);
      });

      test('hasPendingChanges returns true for large pendingChanges', () {
        final syncState = SyncState(
          status: SyncStatus.idle,
          pendingChanges: 1000,
        );
        expect(syncState.hasPendingChanges, isTrue);
      });
    });

    group('copyWith', () {
      test('copyWith updates status', () {
        final updated = testSyncState.copyWith(status: SyncStatus.error);
        
        expect(updated.status, equals(SyncStatus.error));
        expect(updated.lastSyncTime, equals(testSyncState.lastSyncTime));
        expect(updated.pendingChanges, equals(testSyncState.pendingChanges));
        expect(updated.errorMessage, equals(testSyncState.errorMessage));
      });

      test('copyWith updates lastSyncTime', () {
        final newTime = DateTime(2024, 2, 1, 12, 0, 0);
        final updated = testSyncState.copyWith(lastSyncTime: newTime);
        
        expect(updated.status, equals(testSyncState.status));
        expect(updated.lastSyncTime, equals(newTime));
        expect(updated.pendingChanges, equals(testSyncState.pendingChanges));
        expect(updated.errorMessage, equals(testSyncState.errorMessage));
      });

      test('copyWith updates pendingChanges', () {
        final updated = testSyncState.copyWith(pendingChanges: 20);
        
        expect(updated.status, equals(testSyncState.status));
        expect(updated.lastSyncTime, equals(testSyncState.lastSyncTime));
        expect(updated.pendingChanges, equals(20));
        expect(updated.errorMessage, equals(testSyncState.errorMessage));
      });

      test('copyWith updates errorMessage', () {
        final updated = testSyncState.copyWith(errorMessage: 'New error');
        
        expect(updated.status, equals(testSyncState.status));
        expect(updated.lastSyncTime, equals(testSyncState.lastSyncTime));
        expect(updated.pendingChanges, equals(testSyncState.pendingChanges));
        expect(updated.errorMessage, equals('New error'));
      });

      test('copyWith updates multiple fields', () {
        final newTime = DateTime(2024, 3, 1, 12, 0, 0);
        final updated = testSyncState.copyWith(
          status: SyncStatus.offline,
          lastSyncTime: newTime,
          pendingChanges: 15,
          errorMessage: 'Offline error',
        );
        
        expect(updated.status, equals(SyncStatus.offline));
        expect(updated.lastSyncTime, equals(newTime));
        expect(updated.pendingChanges, equals(15));
        expect(updated.errorMessage, equals('Offline error'));
      });

      test('copyWith with no parameters returns equivalent state', () {
        final updated = testSyncState.copyWith();
        
        expect(updated.status, equals(testSyncState.status));
        expect(updated.lastSyncTime, equals(testSyncState.lastSyncTime));
        expect(updated.pendingChanges, equals(testSyncState.pendingChanges));
        expect(updated.errorMessage, equals(testSyncState.errorMessage));
      });
    });

    group('Equality', () {
      test('sync states with same data are equal', () {
        final state1 = SyncState(
          status: SyncStatus.success,
          lastSyncTime: testLastSyncTime,
          pendingChanges: 5,
          errorMessage: 'Error',
        );
        
        final state2 = SyncState(
          status: SyncStatus.success,
          lastSyncTime: testLastSyncTime,
          pendingChanges: 5,
          errorMessage: 'Error',
        );
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('sync states with different status are not equal', () {
        final state1 = testSyncState;
        final state2 = testSyncState.copyWith(status: SyncStatus.error);
        
        expect(state1, isNot(equals(state2)));
      });

      test('sync states with different lastSyncTime are not equal', () {
        final state1 = testSyncState;
        final state2 = testSyncState.copyWith(
          lastSyncTime: DateTime(2024, 2, 1, 12, 0, 0),
        );
        
        expect(state1, isNot(equals(state2)));
      });

      test('sync states with different pendingChanges are not equal', () {
        final state1 = testSyncState;
        final state2 = testSyncState.copyWith(pendingChanges: 10);
        
        expect(state1, isNot(equals(state2)));
      });

      test('sync states with different errorMessage are not equal', () {
        final state1 = testSyncState;
        final state2 = testSyncState.copyWith(errorMessage: 'Different error');
        
        expect(state1, isNot(equals(state2)));
      });

      test('sync states with null vs non-null optional fields are not equal', () {
        final state1 = SyncState(
          status: SyncStatus.idle,
          lastSyncTime: testLastSyncTime,
        );
        
        final state2 = SyncState(
          status: SyncStatus.idle,
          lastSyncTime: null,
        );
        
        expect(state1, isNot(equals(state2)));
      });
    });

    group('Edge Cases', () {
      test('handles zero pendingChanges', () {
        final syncState = SyncState(
          status: SyncStatus.success,
          pendingChanges: 0,
        );
        
        expect(syncState.pendingChanges, equals(0));
        expect(syncState.hasPendingChanges, isFalse);
      });

      test('handles large pendingChanges', () {
        final syncState = SyncState(
          status: SyncStatus.offline,
          pendingChanges: 999999,
        );
        
        expect(syncState.pendingChanges, equals(999999));
        expect(syncState.hasPendingChanges, isTrue);
      });

      test('handles empty errorMessage', () {
        final syncState = SyncState(
          status: SyncStatus.error,
          errorMessage: '',
        );
        
        expect(syncState.errorMessage, equals(''));
      });

      test('handles long errorMessage', () {
        final longError = 'A' * 1000;
        final syncState = SyncState(
          status: SyncStatus.error,
          errorMessage: longError,
        );
        
        expect(syncState.errorMessage, equals(longError));
      });

      test('handles special characters in errorMessage', () {
        final syncState = SyncState(
          status: SyncStatus.error,
          errorMessage: 'Error with émojis 🔥 and "quotes" & symbols',
        );
        
        expect(syncState.errorMessage, contains('émojis'));
        expect(syncState.errorMessage, contains('🔥'));
        expect(syncState.errorMessage, contains('"quotes"'));
      });

      test('handles lastSyncTime in the past', () {
        final pastTime = DateTime(2000, 1, 1);
        final syncState = SyncState(
          status: SyncStatus.success,
          lastSyncTime: pastTime,
        );
        
        expect(syncState.lastSyncTime, equals(pastTime));
        expect(syncState.lastSyncTime!.isBefore(DateTime.now()), isTrue);
      });

      test('handles lastSyncTime in the future', () {
        final futureTime = DateTime(2100, 1, 1);
        final syncState = SyncState(
          status: SyncStatus.success,
          lastSyncTime: futureTime,
        );
        
        expect(syncState.lastSyncTime, equals(futureTime));
        expect(syncState.lastSyncTime!.isAfter(DateTime.now()), isTrue);
      });

      test('handles all status values with offline check', () {
        for (final status in SyncStatus.values) {
          final syncState = SyncState(status: status);
          
          if (status == SyncStatus.offline) {
            expect(syncState.isOnline, isFalse);
          } else {
            expect(syncState.isOnline, isTrue);
          }
        }
      });
    });

    group('toString', () {
      test('toString includes all fields', () {
        final syncState = SyncState(
          status: SyncStatus.success,
          lastSyncTime: testLastSyncTime,
          pendingChanges: 5,
          errorMessage: 'Test error',
        );
        
        final str = syncState.toString();
        
        expect(str, contains('success'));
        expect(str, contains('5'));
        expect(str, contains('Test error'));
      });

      test('toString handles null optional fields', () {
        final syncState = SyncState(
          status: SyncStatus.idle,
        );
        
        final str = syncState.toString();
        
        expect(str, contains('idle'));
        expect(str, contains('null'));
        expect(str, contains('0'));
      });

      test('toString includes all status types', () {
        for (final status in SyncStatus.values) {
          final syncState = SyncState(status: status);
          final str = syncState.toString();
          
          expect(str, contains(status.toString().split('.').last));
        }
      });
    });

    group('State Transitions', () {
      test('idle to syncing transition', () {
        final idle = SyncState(status: SyncStatus.idle);
        final syncing = idle.copyWith(status: SyncStatus.syncing);
        
        expect(syncing.status, equals(SyncStatus.syncing));
        expect(syncing.isOnline, isTrue);
      });

      test('syncing to success transition', () {
        final syncing = SyncState(
          status: SyncStatus.syncing,
          pendingChanges: 5,
        );
        final success = syncing.copyWith(
          status: SyncStatus.success,
          lastSyncTime: DateTime.now(),
          pendingChanges: 0,
        );
        
        expect(success.status, equals(SyncStatus.success));
        expect(success.pendingChanges, equals(0));
        expect(success.lastSyncTime, isNotNull);
      });

      test('syncing to error transition', () {
        final syncing = SyncState(status: SyncStatus.syncing);
        final error = syncing.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Sync failed',
        );
        
        expect(error.status, equals(SyncStatus.error));
        expect(error.errorMessage, equals('Sync failed'));
      });

      test('online to offline transition', () {
        final online = SyncState(
          status: SyncStatus.success,
          pendingChanges: 0,
        );
        final offline = online.copyWith(
          status: SyncStatus.offline,
          pendingChanges: 3,
        );
        
        expect(offline.status, equals(SyncStatus.offline));
        expect(offline.isOnline, isFalse);
        expect(offline.hasPendingChanges, isTrue);
      });

      test('offline to syncing transition', () {
        final offline = SyncState(
          status: SyncStatus.offline,
          pendingChanges: 10,
        );
        final syncing = offline.copyWith(status: SyncStatus.syncing);
        
        expect(syncing.status, equals(SyncStatus.syncing));
        expect(syncing.isOnline, isTrue);
        expect(syncing.pendingChanges, equals(10));
      });
    });
  });
}
