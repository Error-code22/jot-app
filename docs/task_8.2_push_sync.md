# Task 8.2: Push Sync (Local to Cloud) Implementation

## Overview

This document describes the implementation of push sync functionality in the SyncEngine, which uploads local note modifications to Firebase Firestore. The implementation supports incremental sync, offline queue management, and proper handling of deleted notes.

## Requirements Addressed

- **Requirement 3.1**: Upload created notes to cloud
- **Requirement 3.2**: Upload edited notes to cloud
- **Requirement 3.3**: Remove deleted notes from cloud
- **Requirement 4.6**: Sync offline changes when connectivity restored

## Implementation Details

### Core Functionality

The `pushLocalChanges()` method in `SyncEngine` implements the following features:

#### 1. Incremental Sync

The sync engine tracks the last successful sync time (`_lastSyncTime`) and queries only notes modified after that timestamp:

```dart
if (_lastSyncTime != null) {
  notesToSync = await _local.getNotesModifiedAfter(_lastSyncTime!, userId);
} else {
  // First sync - upload all notes
  notesToSync = await _local.getAllNotesForSync(userId);
}
```

This approach:
- Reduces bandwidth usage by uploading only changed notes
- Improves sync performance for users with many notes
- Supports efficient incremental synchronization

#### 2. Deleted Notes Handling

The implementation separates deleted notes from active notes and handles them differently:

```dart
final deletedNotes = notesToSync.where((note) => note.isDeleted).toList();
final activeNotes = notesToSync.where((note) => !note.isDeleted).toList();

// Upload active notes using batch operation
if (activeNotes.isNotEmpty) {
  await _firestore.batchUploadNotes(activeNotes);
}

// Delete notes marked as deleted from cloud
for (var note in deletedNotes) {
  await _firestore.deleteNote(userId, note.id);
  await _local.hardDeleteNote(note.id);
}
```

This ensures:
- Soft-deleted notes are removed from Firestore
- Successfully deleted notes are permanently removed from local storage
- Failed deletions are retried on next sync

#### 3. Offline Queue

The sync engine maintains an implicit offline queue through:
- Tracking `_lastSyncTime` to identify pending changes
- Using `getNotesModifiedAfter()` to query pending notes
- Updating `pendingChanges` count in `SyncState`

When connectivity is restored:
- The connectivity monitor triggers `syncNow()`
- `pushLocalChanges()` uploads all notes modified since last sync
- The pending changes count is reset to 0 on successful sync

#### 4. Batch Upload

The implementation uses `FirestoreService.batchUploadNotes()` for efficient uploads:
- Handles up to 500 notes per Firestore batch
- Automatically splits larger batches
- Validates note size before upload (1MB limit)

### State Management

The sync engine updates `SyncState` throughout the sync process:

```dart
// Before sync
_updateState(_currentState.copyWith(status: SyncStatus.syncing));

// After successful sync
_updateState(_currentState.copyWith(
  status: SyncStatus.success,
  lastSyncTime: _lastSyncTime,
  pendingChanges: 0,
  errorMessage: null,
));

// On error
_updateState(_currentState.copyWith(
  status: SyncStatus.error,
  errorMessage: e.toString(),
));
```

This provides real-time feedback to the UI through the `syncStatus` stream.

### Error Handling

The implementation handles errors gracefully:

1. **Network Errors**: Caught by `syncNow()` and reported in `SyncState`
2. **Firestore Errors**: Converted to user-friendly messages by `FirestoreService`
3. **Deletion Failures**: Notes remain in local storage for retry
4. **Partial Failures**: Active notes upload succeeds even if deletions fail

## Testing

### Test Coverage

The implementation includes comprehensive unit tests in `sync_engine_push_test.dart`:

1. **Incremental Sync Tests**
   - Uploads all notes on first sync
   - Queries only modified notes after initial sync
   - Correctly filters notes by timestamp

2. **Deleted Notes Tests**
   - Soft delete marks notes as deleted
   - `getAllNotes()` excludes deleted notes
   - `getAllNotesForSync()` includes deleted notes
   - Deleted notes are removed from cloud

3. **Offline Queue Tests**
   - Tracks pending changes count
   - Identifies notes modified after sync time
   - Queues changes for next sync

4. **Batch Upload Tests**
   - Handles empty lists
   - Uploads multiple notes efficiently
   - Splits large batches (>500 notes)

5. **Integration Tests**
   - Full sync flow including push
   - Connectivity restoration triggers sync

### Running Tests

```bash
cd flutter-projects/jot_app
flutter test test/unit/services/sync_engine_push_test.dart
```

## Usage Example

```dart
// Initialize sync engine
final syncEngine = SyncEngine(localStorage, firestoreService);

// Start monitoring connectivity
await syncEngine.start(userId);

// Manual sync (includes push)
await syncEngine.syncNow(userId);

// Push only local changes
await syncEngine.pushLocalChanges(userId);

// Listen to sync status
syncEngine.syncStatus.listen((state) {
  print('Sync status: ${state.status}');
  print('Pending changes: ${state.pendingChanges}');
});
```

## Performance Considerations

1. **Incremental Sync**: Only modified notes are uploaded, reducing bandwidth
2. **Batch Operations**: Multiple notes uploaded in single Firestore batch
3. **Indexed Queries**: `modifiedAt` index enables fast timestamp queries
4. **Lazy Sync**: Sync triggered only on connectivity changes or manual request

## Future Enhancements

Potential improvements for future iterations:

1. **Retry Logic**: Exponential backoff for failed uploads
2. **Conflict Detection**: Check for conflicts before pushing
3. **Progress Tracking**: Report upload progress for large batches
4. **Selective Sync**: Allow users to choose which notes to sync
5. **Compression**: Compress large notes before upload

## Related Files

- `lib/services/sync_engine.dart` - Main implementation
- `lib/services/local_storage_service.dart` - Local storage queries
- `lib/services/firestore_service.dart` - Cloud upload operations
- `lib/models/sync_state.dart` - Sync state model
- `test/unit/services/sync_engine_push_test.dart` - Unit tests

## Conclusion

The push sync implementation provides efficient, reliable synchronization of local changes to the cloud. It supports incremental sync, handles deleted notes properly, and maintains an offline queue for pending changes. The implementation is well-tested and ready for integration with the rest of the application.
