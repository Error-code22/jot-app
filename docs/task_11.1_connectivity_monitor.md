# Task 11.1: Connectivity Monitoring Utility

## Overview

Created a connectivity monitoring utility that provides a clean abstraction over the `connectivity_plus` package. This utility is used by the sync engine to detect offline mode and trigger automatic synchronization when connectivity is restored.

## Implementation

### Interface: `IConnectivityMonitor`

Located in `lib/utils/i_connectivity_monitor.dart`

Defines the contract for connectivity monitoring:

```dart
abstract class IConnectivityMonitor {
  /// Stream of connectivity state changes (true = online, false = offline)
  Stream<bool> get connectivityStream;
  
  /// Check current connectivity state (one-time check)
  Future<bool> isOnline();
  
  /// Dispose resources and close streams
  void dispose();
}
```

**Key Features:**
- Simplified boolean stream (online/offline) instead of complex connectivity types
- Reactive updates via stream for UI and sync engine
- One-time checks for immediate status queries
- Proper resource cleanup

### Implementation: `ConnectivityMonitor`

Located in `lib/utils/connectivity_monitor.dart`

Wraps the `connectivity_plus` package and provides:

1. **Simplified API**: Converts complex `ConnectivityResult` types into simple boolean states
2. **Lazy Initialization**: Starts monitoring only when first listener subscribes
3. **Error Handling**: Gracefully handles connectivity check failures (assumes offline)
4. **Multiple Listeners**: Supports broadcast stream for multiple subscribers
5. **Resource Management**: Proper cleanup of subscriptions and streams

**Connectivity Detection Logic:**
- Online: Any of wifi, mobile, ethernet, bluetooth, vpn, etc.
- Offline: Only when all results are `ConnectivityResult.none`

## Usage

### Basic Usage

```dart
// Create monitor
final monitor = ConnectivityMonitor();

// One-time check
final isOnline = await monitor.isOnline();
if (isOnline) {
  print('Device is online');
}

// Reactive monitoring
monitor.connectivityStream.listen((isOnline) {
  if (isOnline) {
    print('Connectivity restored');
  } else {
    print('Connectivity lost');
  }
});

// Clean up
monitor.dispose();
```

### Integration with Sync Engine

The sync engine will use this utility to:
1. Monitor connectivity changes
2. Update sync status to offline when connectivity is lost
3. Trigger automatic sync when connectivity is restored
4. Show offline indicator in UI

```dart
class SyncEngine {
  final IConnectivityMonitor _connectivityMonitor;
  
  void start() {
    _connectivityMonitor.connectivityStream.listen((isOnline) {
      if (isOnline) {
        // Trigger sync
        syncNow();
      } else {
        // Update status to offline
        _updateState(SyncState(status: SyncStatus.offline));
      }
    });
  }
}
```

## Testing

### Unit Tests

Located in `test/unit/utils/connectivity_monitor_test.dart`

**Test Coverage:**
- ✅ Online detection for wifi, mobile, ethernet
- ✅ Offline detection when no connectivity
- ✅ Multiple connectivity types
- ✅ Stream emits initial state
- ✅ Stream emits on connectivity changes
- ✅ Multiple state transitions
- ✅ Multiple listeners support
- ✅ Error handling (connectivity check failures)
- ✅ Error handling (stream errors)
- ✅ Resource cleanup on dispose

**Mock Strategy:**
Uses `MockConnectivity` that extends `Connectivity` and provides:
- Controllable connectivity state
- Stream controller for testing state changes
- Synchronous state updates for deterministic tests

## Requirements Validation

### Requirement 4.1: App detects when device is offline
✅ **Validated** - `isOnline()` method and `connectivityStream` detect offline state

### Requirement 4.7: App shows sync status indicator
✅ **Validated** - `connectivityStream` provides reactive updates for UI sync indicator

## Design Decisions

### Why a separate utility instead of using connectivity_plus directly?

1. **Abstraction**: Hides complexity of `ConnectivityResult` types
2. **Testability**: Easy to mock for testing sync engine
3. **Simplification**: Boolean online/offline is clearer than multiple connectivity types
4. **Consistency**: Single source of truth for connectivity state
5. **Flexibility**: Can swap implementation (e.g., add custom connectivity checks)

### Why lazy initialization of monitoring?

- Avoids unnecessary resource usage if stream is never used
- Allows creating monitor instance without immediately starting subscription
- Reduces battery drain by only monitoring when needed

### Why assume offline on errors?

- Fail-safe approach: better to assume offline than incorrectly assume online
- Prevents sync attempts when connectivity state is unknown
- User can manually retry if needed

## Future Enhancements

Potential improvements for future iterations:

1. **Connection Quality**: Detect slow/poor connections
2. **Connectivity Type**: Expose wifi vs mobile for data-saving features
3. **Reachability Check**: Ping actual server to verify internet access
4. **Offline Duration**: Track how long device has been offline
5. **Connectivity History**: Log connectivity changes for debugging

## Files Created

- `lib/utils/i_connectivity_monitor.dart` - Interface definition
- `lib/utils/connectivity_monitor.dart` - Implementation
- `test/unit/utils/connectivity_monitor_test.dart` - Unit tests
- `docs/task_11.1_connectivity_monitor.md` - This documentation

## Next Steps

Task 11.2 will integrate this utility into the sync engine to replace direct usage of `connectivity_plus` and provide better offline mode detection.
