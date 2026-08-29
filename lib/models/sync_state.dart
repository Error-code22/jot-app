/// Sync state model for the Jot? application
/// 
/// Represents the current synchronization status and state.
/// Used to track sync progress, pending changes, and connectivity status.
library;

/// Synchronization status enumeration
enum SyncStatus {
  /// Not currently syncing
  idle,
  
  /// Currently syncing with cloud
  syncing,
  
  /// Last sync completed successfully
  success,
  
  /// Last sync failed with error
  error,
  
  /// No network connectivity available
  offline,
}

/// Synchronization state model
class SyncState {
  /// Current synchronization status
  final SyncStatus status;
  
  /// Timestamp of last successful sync (optional)
  final DateTime? lastSyncTime;
  
  /// Number of pending changes waiting to sync
  final int pendingChanges;
  
  /// Error message from last failed sync (optional)
  final String? errorMessage;

  SyncState({
    required this.status,
    this.lastSyncTime,
    this.pendingChanges = 0,
    this.errorMessage,
  });

  /// Check if device is online (not in offline status)
  bool get isOnline => status != SyncStatus.offline;

  /// Check if there are pending changes to sync
  bool get hasPendingChanges => pendingChanges > 0;

  /// Create a copy with updated fields
  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    int? pendingChanges,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SyncState &&
        other.status == status &&
        other.lastSyncTime == lastSyncTime &&
        other.pendingChanges == pendingChanges &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      lastSyncTime,
      pendingChanges,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'SyncState(status: $status, lastSyncTime: $lastSyncTime, '
        'pendingChanges: $pendingChanges, errorMessage: $errorMessage)';
  }
}
