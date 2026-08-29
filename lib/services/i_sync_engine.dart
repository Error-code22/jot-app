import 'dart:async';
import '../models/sync_state.dart';
import '../models/sync_result.dart';

/// Interface for the synchronization engine
/// 
/// Defines the contract for synchronizing notes between local storage
/// and Firebase Firestore, with connectivity monitoring and conflict resolution.
abstract class ISyncEngine {
  /// Start sync engine (begins listening for connectivity changes)
  Future<void> start(String userId);
  
  /// Stop sync engine and clean up resources
  Future<void> stop();
  
  /// Manually trigger a full synchronization
  /// Returns SyncResult with statistics about the sync operation
  Future<SyncResult> syncNow(String userId);
  
  /// Upload local changes to cloud
  Future<void> pushLocalChanges(String userId);
  
  /// Download cloud changes to local storage
  Future<void> pullCloudChanges(String userId);
  
  /// Get current sync status as a stream
  Stream<SyncState> get syncStatus;
  
  /// Check if currently syncing
  bool get isSyncing;
  
  /// Dispose resources
  void dispose();
}
