import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'todo_service.dart';

/// Service for scheduling and managing local notifications.
/// Handles sync reminders and due-date alerts.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  /// Show a notification for a todo item due soon.
  Future<void> showDueSoonNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'jot_due_dates',
      'Due Date Reminders',
      channelDescription: 'Reminders for upcoming todo due dates',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Show a sync status notification.
  Future<void> showSyncNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'jot_sync',
      'Sync Status',
      channelDescription: 'Background sync notifications',
      importance: Importance.low,
      priority: Priority.low,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Check all todo lists for overdue or due-today items and send notifications.
  Future<void> checkTodoDueDates(TodoService todoService) async {
    if (!_initialized) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final list in todoService.lists) {
      for (final item in list.items) {
        if (item.isDone || item.dueDate == null) continue;

        final dueDay = DateTime(item.dueDate!.year, item.dueDate!.month, item.dueDate!.day);
        final daysUntilDue = dueDay.difference(today).inDays;

        if (daysUntilDue < 0) {
          // Overdue
          final id = item.id.hashCode.abs() % 2147483647;
          await showDueSoonNotification(
            id: id,
            title: 'Overdue: ${item.text}',
            body: '"${list.title}" was due ${-daysUntilDue} day${-daysUntilDue == 1 ? '' : 's'} ago',
          );
        } else if (daysUntilDue == 0) {
          // Due today
          final id = item.id.hashCode.abs() % 2147483647;
          await showDueSoonNotification(
            id: id,
            title: 'Due today: ${item.text}',
            body: 'In "${list.title}"',
          );
        } else if (daysUntilDue == 1) {
          // Due tomorrow
          final id = item.id.hashCode.abs() % 2147483647;
          await showDueSoonNotification(
            id: id,
            title: 'Due tomorrow: ${item.text}',
            body: 'In "${list.title}"',
          );
        }
      }
    }
  }

  /// Schedule a periodic reminder to check sync status.
  Future<void> scheduleSyncReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync_time');
    if (lastSync != null) {
      final lastSyncTime = DateTime.parse(lastSync);
      final hoursSinceSync = DateTime.now().difference(lastSyncTime).inHours;
      if (hoursSinceSync >= 24) {
        await showSyncNotification(
          id: 9999,
          title: 'Sync Reminder',
          body: 'Your notes haven\'t synced in $hoursSinceSync hours. Open Jot? to sync.',
        );
      }
    }
  }

  /// Update last sync time in preferences.
  Future<void> recordSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
