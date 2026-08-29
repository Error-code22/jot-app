import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/sync_state.dart';
import '../models/sync_result.dart';
import '../models/note_model.dart';
import 'i_sync_engine.dart';
import 'i_local_storage_service.dart';
import 'i_remote_storage_service.dart';
import '../utils/conflict_resolver.dart';

/// Engine that orchestrates synchronization between local storage and Supabase.
/// Supports conflict detection with user notification.
class SyncEngine implements ISyncEngine {
  final ILocalStorageService _local;
  final IRemoteStorageService _remote;
  final Connectivity _connectivity;
  final ConflictResolver _conflictResolver;
  
  final _syncStatusController = StreamController<SyncState>.broadcast();
  final _conflictController = StreamController<List<SyncConflict>>.broadcast();
  SyncState _currentState = SyncState(status: SyncStatus.idle);
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<List<Note>>? _remoteSubscription;
  String? _currentUserId;
  bool _isStarted = false;
  DateTime? _lastSyncTime;
  
  final Map<String, List<DateTime>> _syncAttempts = {};
  final List<Note> _failedOperationsQueue = [];
  final List<SyncConflict> _pendingConflicts = [];
  final int _maxQueueSize = 500;

  SyncEngine(
    this._local,
    this._remote, {
    Connectivity? connectivity,
    ConflictResolver? conflictResolver,
  }) : _connectivity = connectivity ?? Connectivity(),
       _conflictResolver = conflictResolver ?? ConflictResolver();

  @override
  Stream<SyncState> get syncStatus => _syncStatusController.stream;
  
  /// Stream of conflicts that need user resolution
  Stream<List<SyncConflict>> get conflicts => _conflictController.stream;
  
  @override
  bool get isSyncing => _currentState.status == SyncStatus.syncing;

  @override
  Future<void> start(String userId) async {
    if (_isStarted) return;
    
    _currentUserId = userId;
    _isStarted = true;
    
    final initialResult = await _connectivity.checkConnectivity();
    _handleConnectivityChange(initialResult);
    
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (result) => _handleConnectivityChange(result),
        onError: (error) {
          _updateState(_currentState.copyWith(
            status: SyncStatus.error,
            errorMessage: 'Connectivity monitoring error: $error',
          ));
        },
      );
    } catch (e) {
      // Non-fatal: connectivity subscription setup failed.
    }
    
    _remoteSubscription = _remote.watchNotes(userId).listen(
      (remoteNotes) => _handleRemoteUpdate(remoteNotes),
      onError: (error) {},
    );
  }
  
  @override
  Future<void> stop() async {
    _isStarted = false;
    _currentUserId = null;
    _lastSyncTime = null;
    _syncAttempts.clear();
    _failedOperationsQueue.clear();
    _pendingConflicts.clear();
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;
  }
  
  void _handleConnectivityChange(ConnectivityResult result) {
    _updateSyncStatusFromConnectivity(result);
    if (result != ConnectivityResult.none && _isStarted && _currentUserId != null) {
      unawaited(syncNow(_currentUserId!));
    }
  }

  void _updateSyncStatusFromConnectivity(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      _updateState(_currentState.copyWith(status: SyncStatus.offline));
    } else if (_currentState.status == SyncStatus.offline) {
      _updateState(_currentState.copyWith(status: SyncStatus.idle));
    }
  }

  @override
  Future<SyncResult> syncNow(String userId) async {
    if (_currentState.status == SyncStatus.syncing) {
      return SyncResult.empty();
    }
    
    // Check queue depth
    if (_failedOperationsQueue.length >= _maxQueueSize) {
      _updateState(_currentState.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Sync queue full (${_failedOperationsQueue.length}/$_maxQueueSize). Please free up space.',
      ));
      return SyncResult.empty();
    }
    
    _updateState(_currentState.copyWith(status: SyncStatus.syncing));

    int notesDownloaded = 0;
    int notesUploaded = 0;
    int conflictsResolved = 0;
    final errors = <String>[];

    try {
      await _processFailedOperationsQueue(userId);
      
      final pullSuccess = await _retryOperation(
        () async {
          final pullResult = await _pullRemoteChangesWithStats(userId);
          notesDownloaded = pullResult['downloaded'] as int;
          conflictsResolved = pullResult['conflicts'] as int;
        },
        'pull sync',
      );
      
      final pushSuccess = await _retryOperation(
        () async {
          final pushResult = await _pushLocalChangesWithStats(userId);
          notesUploaded = pushResult['uploaded'] as int;
        },
        'push sync',
      );
      
      if (!pushSuccess) {
        errors.add('Failed to push local changes');
      }
      
      if (pullSuccess || pushSuccess) {
        _lastSyncTime = DateTime.now();
      }
      
      final finalStatus = errors.isEmpty ? SyncStatus.success : SyncStatus.error;
      
      _updateState(_currentState.copyWith(
        status: finalStatus,
        lastSyncTime: _lastSyncTime,
        pendingChanges: _failedOperationsQueue.length,
      ));
      
      // Notify about pending conflicts
      if (_pendingConflicts.isNotEmpty) {
        _conflictController.add(List.from(_pendingConflicts));
      }
      
      return SyncResult(
        notesUploaded: notesUploaded,
        notesDownloaded: notesDownloaded,
        conflictsResolved: conflictsResolved,
        errors: errors,
      );
    } catch (e) {
      _updateState(_currentState.copyWith(status: SyncStatus.error));
      return SyncResult.empty();
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentState.status != SyncStatus.syncing) {
          _updateState(_currentState.copyWith(status: SyncStatus.idle));
        }
      });
    }
  }

  @override
  Future<void> pushLocalChanges(String userId) async {
    List<Note> notesToSync;
    
    if (_lastSyncTime != null) {
      notesToSync = await _local.getNotesModifiedAfter(_lastSyncTime!, userId);
    } else {
      notesToSync = await _local.getAllNotesForSync(userId);
    }
    
    if (notesToSync.isEmpty) return;
    
    for (var note in notesToSync) {
      if (note.isDeleted) {
        await _remote.deleteNote(userId, note.id);
        await _local.hardDeleteNote(note.id);
      } else {
        await _remote.uploadNote(note);
      }
    }
  }

  @override
  Future<void> pullCloudChanges(String userId) async {
    final remoteNotes = await _remote.downloadAllNotes(userId);
    
    for (var remoteNote in remoteNotes) {
      final localNote = await _local.getNoteById(remoteNote.id);
      
      if (localNote == null) {
        await _local.insertNote(remoteNote);
      } else {
        if (remoteNote.modifiedAt.isAfter(localNote.modifiedAt)) {
          await _local.insertNote(remoteNote);
        }
      }
    }
  }
  
  Future<Map<String, int>> _pullRemoteChangesWithStats(String userId) async {
    int downloaded = 0;
    int conflicts = 0;
    
    final remoteNotes = await _remote.downloadAllNotes(userId);
    
    for (var remoteNote in remoteNotes) {
      final localNote = await _local.getNoteById(remoteNote.id);
      
      if (localNote == null) {
        await _local.insertNote(remoteNote);
        downloaded++;
      } else {
        if (_conflictResolver.hasConflict(localNote, remoteNote)) {
          // Check if both have significant changes
          if (_hasMajorChanges(localNote, remoteNote)) {
            // Both devices made significant changes - notify user
            _pendingConflicts.add(SyncConflict(
              noteId: remoteNote.id,
              localVersion: localNote,
              remoteVersion: remoteNote,
              detectedAt: DateTime.now(),
            ));
            conflicts++;
          } else {
            // Minor changes - auto-resolve with last-write-wins
            final resolvedNote = _conflictResolver.resolveConflict(localNote, remoteNote);
            await _local.insertNote(resolvedNote);
            conflicts++;
          }
        }
      }
    }
    
    return {'downloaded': downloaded, 'conflicts': conflicts};
  }

  bool _hasMajorChanges(Note local, Note remote) {
    // Consider it a major change if both title and content differ significantly
    final titleChanged = local.title != remote.title;
    final contentChanged = local.content != remote.content;
    
    // Check if content differs by more than 20%
    if (titleChanged && contentChanged) {
      final lengthDiff = (local.content.length - remote.content.length).abs();
      final maxLength = local.content.length > remote.content.length
          ? local.content.length
          : remote.content.length;
      if (maxLength > 0 && lengthDiff / maxLength > 0.2) {
        return true;
      }
    }
    
    return false;
  }

  Future<Map<String, int>> _pushLocalChangesWithStats(String userId) async {
    int uploaded = 0;
    List<Note> notesToSync;
    
    if (_lastSyncTime != null) {
      notesToSync = await _local.getNotesModifiedAfter(_lastSyncTime!, userId);
    } else {
      notesToSync = await _local.getAllNotesForSync(userId);
    }
    
    if (notesToSync.isEmpty) {
      return {'uploaded': 0};
    }
    
    for (var note in notesToSync) {
      if (_isInSyncLoop(note.id)) continue;
      _recordSyncAttempt(note.id);
      
      try {
        if (note.isDeleted) {
          await _remote.deleteNote(userId, note.id);
          await _local.hardDeleteNote(note.id);
          uploaded++;
        } else {
          await _remote.uploadNote(note);
          uploaded++;
        }
      } catch (e) {
        _queueFailedOperation(note);
      }
    }
    
    return {'uploaded': uploaded};
  }

  Future<void> _handleRemoteUpdate(List<Note> remoteNotes) async {
    if (_currentUserId == null || !_isStarted) return;
    if (_currentState.status == SyncStatus.syncing) return;
    
    try {
      for (var remoteNote in remoteNotes) {
        final localNote = await _local.getNoteById(remoteNote.id);
        
        if (localNote == null) {
          await _local.insertNote(remoteNote);
        } else {
          if (_conflictResolver.hasConflict(localNote, remoteNote)) {
            if (_hasMajorChanges(localNote, remoteNote)) {
              _pendingConflicts.add(SyncConflict(
                noteId: remoteNote.id,
                localVersion: localNote,
                remoteVersion: remoteNote,
                detectedAt: DateTime.now(),
              ));
              _conflictController.add(List.from(_pendingConflicts));
            } else {
              final resolvedNote = _conflictResolver.resolveConflict(localNote, remoteNote);
              await _local.insertNote(resolvedNote);
            }
          }
        }
      }
    } catch (e) {
      // Non-fatal: merge of a remote update failed; next sync will retry.
    }
  }

  /// Resolve a conflict by choosing local or remote version
  Future<void> resolveConflict(String noteId, {required bool keepLocal}) async {
    final conflict = _pendingConflicts.firstWhere((c) => c.noteId == noteId);
    final chosenVersion = keepLocal ? conflict.localVersion : conflict.remoteVersion;
    
    await _local.updateNote(chosenVersion);
    await _remote.uploadNote(chosenVersion);
    
    _pendingConflicts.removeWhere((c) => c.noteId == noteId);
    _conflictController.add(List.from(_pendingConflicts));
  }

  /// Merge both versions (concatenate content)
  Future<void> mergeConflict(String noteId) async {
    final conflict = _pendingConflicts.firstWhere((c) => c.noteId == noteId);
    
    final mergedNote = conflict.localVersion.copyWith(
      title: '${conflict.localVersion.title} (merged)',
      content: '${conflict.localVersion.content}\n\n---\n\n${conflict.remoteVersion.content}',
      modifiedAt: DateTime.now(),
    );
    
    await _local.updateNote(mergedNote);
    await _remote.uploadNote(mergedNote);
    
    _pendingConflicts.removeWhere((c) => c.noteId == noteId);
    _conflictController.add(List.from(_pendingConflicts));
  }

  void _updateState(SyncState newState) {
    _currentState = newState;
    _syncStatusController.add(newState);
  }
  
  bool _isInSyncLoop(String noteId) {
    final attempts = _syncAttempts[noteId];
    if (attempts == null || attempts.isEmpty) return false;
    
    final now = DateTime.now();
    final recentAttempts = attempts.where((time) => 
      now.difference(time).inSeconds <= 10
    ).toList();
    
    _syncAttempts[noteId] = recentAttempts;
    return recentAttempts.length > 3;
  }
  
  void _recordSyncAttempt(String noteId) {
    _syncAttempts.putIfAbsent(noteId, () => []);
    _syncAttempts[noteId]!.add(DateTime.now());
  }
  
  Duration _calculateBackoffDelay(int attemptNumber) {
    final seconds = (1 << attemptNumber).clamp(1, 16);
    return Duration(seconds: seconds);
  }
  
  Future<bool> _retryOperation(
    Future<void> Function() operation,
    String operationName,
  ) async {
    const maxAttempts = 3;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await operation();
        return true;
      } catch (e) {
        if (attempt < maxAttempts - 1) {
          final delay = _calculateBackoffDelay(attempt);
          await Future.delayed(delay);
        } else {
          return false;
        }
      }
    }
    return false;
  }
  
  void _queueFailedOperation(Note note) {
    if (!_failedOperationsQueue.any((n) => n.id == note.id)) {
      _failedOperationsQueue.add(note);
      _updateState(_currentState.copyWith(
        pendingChanges: _failedOperationsQueue.length,
      ));
    }
  }
  
  Future<void> _processFailedOperationsQueue(String userId) async {
    if (_failedOperationsQueue.isEmpty) return;
    
    final notesToRetry = List<Note>.from(_failedOperationsQueue);
    _failedOperationsQueue.clear();
    
    for (var note in notesToRetry) {
      try {
        if (note.isDeleted) {
          await _remote.deleteNote(userId, note.id);
          await _local.hardDeleteNote(note.id);
        } else {
          await _remote.uploadNote(note);
        }
      } catch (e) {
        _queueFailedOperation(note);
      }
    }
    
    _updateState(_currentState.copyWith(
      pendingChanges: _failedOperationsQueue.length,
    ));
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _remoteSubscription?.cancel();
    _syncStatusController.close();
    _conflictController.close();
  }
}

/// Represents a sync conflict that needs user resolution
class SyncConflict {
  final String noteId;
  final Note localVersion;
  final Note remoteVersion;
  final DateTime detectedAt;

  SyncConflict({
    required this.noteId,
    required this.localVersion,
    required this.remoteVersion,
    required this.detectedAt,
  });
}
