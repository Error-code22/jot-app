import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_engine.dart';

/// Handles scheduled sync operations and keepalive pings.
class SyncScheduler {
  final SyncEngine _syncEngine;
  Timer? _dailySyncTimer;
  Timer? _keepaliveTimer;
  String? _currentUserId;
  
  static const String _lastSyncKey = 'last_scheduled_sync';
  static const String _lastKeepaliveKey = 'last_keepalive_ping';

  SyncScheduler(this._syncEngine);

  /// Start scheduled sync operations
  Future<void> start(String userId) async {
    _currentUserId = userId;
    
    // Check if daily sync is due
    await _checkDailySync();
    
    // Check if keepalive ping is due
    await _checkKeepalive();
    
    // Set up periodic checks (every hour)
    _dailySyncTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkDailySync(),
    );
    
    // Keepalive check (every 6 hours)
    _keepaliveTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _checkKeepalive(),
    );
  }

  /// Stop scheduled operations
  void stop() {
    _dailySyncTimer?.cancel();
    _keepaliveTimer?.cancel();
    _currentUserId = null;
  }

  /// Check if daily sync is due and perform it
  Future<void> _checkDailySync() async {
    if (_currentUserId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    
    if (lastSyncStr != null) {
      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();
      final diff = now.difference(lastSync);
      
      // Sync if more than 24 hours have passed
      if (diff.inHours < 24) return;
    }
    
    // Check connectivity before syncing
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      debugPrint('SyncScheduler: No connectivity, skipping daily sync');
      return;
    }
    
    try {
      debugPrint('SyncScheduler: Performing daily sync');
      await _syncEngine.syncNow(_currentUserId!);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('SyncScheduler: Daily sync error: $e');
    }
  }

  /// Check if keepalive ping is due
  Future<void> _checkKeepalive() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPingStr = prefs.getString(_lastKeepaliveKey);
    
    if (lastPingStr != null) {
      final lastPing = DateTime.parse(lastPingStr);
      final now = DateTime.now();
      final diff = now.difference(lastPing);
      
      // Ping if more than 5 days have passed
      if (diff.inDays < 5) return;
    }
    
    // Check connectivity
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      debugPrint('SyncScheduler: No connectivity, skipping keepalive');
      return;
    }
    
    try {
      debugPrint('SyncScheduler: Sending keepalive ping');
      // The ping is done by attempting a sync, which keeps the Supabase project alive
      if (_currentUserId != null) {
        await _syncEngine.syncNow(_currentUserId!);
      }
      await prefs.setString(_lastKeepaliveKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('SyncScheduler: Keepalive error: $e');
    }
  }

  /// Force an immediate sync
  Future<void> forceSyncNow() async {
    if (_currentUserId == null) return;
    
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      debugPrint('SyncScheduler: No connectivity for forced sync');
      return;
    }
    
    try {
      await _syncEngine.syncNow(_currentUserId!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('SyncScheduler: Forced sync error: $e');
    }
  }

  /// Get time until next scheduled sync
  Future<Duration?> getTimeUntilNextSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    
    if (lastSyncStr == null) return null;
    
    final lastSync = DateTime.parse(lastSyncStr);
    final nextSync = lastSync.add(const Duration(hours: 24));
    final now = DateTime.now();
    
    if (nextSync.isBefore(now)) return Duration.zero;
    return nextSync.difference(now);
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    return lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
  }
}
