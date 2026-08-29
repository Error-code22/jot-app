/// Interface for monitoring network connectivity state.
/// 
/// Provides both reactive (stream-based) and one-time connectivity checks.
/// Used by the sync engine to detect offline mode and trigger automatic sync
/// when connectivity is restored.
/// 
/// Validates: Requirements 4.1, 4.7
/// - Detects when device is offline (4.1)
/// - Provides sync status indicator data (4.7)
abstract class IConnectivityMonitor {
  /// Stream of connectivity state changes.
  /// 
  /// Emits `true` when device has network connectivity (wifi, mobile, ethernet),
  /// emits `false` when device is offline (no connectivity).
  /// 
  /// This stream enables reactive UI updates and automatic sync triggering.
  Stream<bool> get connectivityStream;
  
  /// Check current connectivity state.
  /// 
  /// Returns `true` if device has network connectivity, `false` if offline.
  /// This is a one-time check, use [connectivityStream] for continuous monitoring.
  Future<bool> isOnline();
  
  /// Dispose resources and close streams.
  void dispose();
}
