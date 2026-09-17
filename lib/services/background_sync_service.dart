import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';

const _taskName = 'jot_background_sync';

/// Service that schedules background sync tasks using Workmanager.
class BackgroundSyncService {
  final Workmanager _workmanager;
  bool _initialized = false;

  BackgroundSyncService({
    Workmanager? workmanager,
    required NotificationService notificationService,
  })  : _workmanager = workmanager ?? Workmanager();

  Future<void> initialize() async {
    if (_initialized) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true;
      return;
    }

    await _workmanager.initialize(
      _callbackDispatcher,
    );
    _initialized = true;
  }

  /// Schedule periodic background sync (every 15 minutes on Android).
  Future<void> schedulePeriodicSync() async {
    if (!_initialized) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _workmanager.registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Cancel all scheduled background tasks.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _workmanager.cancelAll();
  }

  /// Called by background task dispatcher — performs sync and notification.
  @pragma('vm:entry-point')
  static Future<void> _doBackgroundWork() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Record that sync happened
    await notificationService.recordSyncTime();

    // Check for due-soon items (stub — real check needs todo service DB access)
    await notificationService.scheduleSyncReminder();
  }
}

/// Top-level callback dispatcher for Workmanager.
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackgroundSyncService._doBackgroundWork();
      return true;
    } catch (e) {
      debugPrint('Background sync failed: $e');
      return false;
    }
  });
}
