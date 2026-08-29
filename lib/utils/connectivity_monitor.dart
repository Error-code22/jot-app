import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'i_connectivity_monitor.dart';

/// Monitors network connectivity state using connectivity_plus package.
/// 
/// Provides a simplified boolean stream (online/offline) and one-time checks.
/// Wraps the connectivity_plus package to provide a cleaner interface for
/// the sync engine and UI components.
/// 
/// Validates: Requirements 4.1, 4.7
/// - Detects when device is offline (4.1)
/// - Provides sync status indicator data (4.7)
class ConnectivityMonitor implements IConnectivityMonitor {
  final Connectivity _connectivity;
  final _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<ConnectivityResult>? _subscription;
  
  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();
  
  /// Stream of connectivity state changes.
  /// 
  /// Emits `true` when device has network connectivity (wifi, mobile, ethernet),
  /// emits `false` when device is offline (no connectivity).
  /// 
  /// Automatically starts monitoring when first listener subscribes.
  @override
  Stream<bool> get connectivityStream {
    // Start monitoring on first subscription
    if (_subscription == null) {
      _startMonitoring();
    }
    return _connectivityController.stream;
  }
  
  /// Check current connectivity state.
  /// 
  /// Returns `true` if device has network connectivity, `false` if offline.
  /// 
  /// Validates: Requirements 4.1
  /// - Detects when device is offline
  @override
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _hasConnectivity(result);
    } catch (_) {
      // If the connectivity plugin fails, assume offline to be safe.
      return false;
    }
  }
  
  /// Start monitoring connectivity changes.
  /// 
  /// Subscribes to connectivity_plus stream and transforms it into
  /// a simplified boolean stream.
  void _startMonitoring() {
    // Get initial connectivity state
    try {
      _connectivity.checkConnectivity().then((result) {
        _connectivityController.add(_hasConnectivity(result));
      }).catchError((error) {
        // If initial check fails, assume offline
        _connectivityController.add(false);
      });
    } catch (_) {
      // If checkConnectivity throws synchronously, assume offline.
      _connectivityController.add(false);
    }
    
    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        _connectivityController.add(_hasConnectivity(result));
      },
      onError: (error) {
        // On error, assume offline to be safe
        _connectivityController.add(false);
      },
    );
  }
  
  /// Check if connectivity results indicate online status.
  /// 
  /// Returns `true` if any result indicates connectivity (wifi, mobile, ethernet, etc.),
  /// returns `false` if all results are none.
  bool _hasConnectivity(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }
  
  /// Dispose resources and close streams.
  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _connectivityController.close();
  }
}
