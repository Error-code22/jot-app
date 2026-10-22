import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'todo_service.dart';

/// Service for scheduling and managing local notifications.
/// Handles due-date reminders for to-do items and sync reminders.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'jot_due_dates',
        'Due Date Reminders',
        description: 'Reminders for upcoming to-do due dates',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'jot_sync',
        'Sync Status',
        description: 'Background sync notifications',
        importance: Importance.low,
      ));
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) return false;
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

  /// Schedule one reminder for each pending to-do item with a due date.
  Future<void> rescheduleAll(TodoService todoService) async {
    if (!_initialized) return;
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    for (final list in todoService.lists) {
      for (final item in list.items) {
        if (item.isDone || !item.reminderEnabled || item.dueDate == null) {
          continue;
        }

        final due = item.dueDate!;
        // Date-only todos remind at 09:00 local time.
        final localDue = (due.hour == 0 && due.minute == 0)
            ? DateTime(due.year, due.month, due.day, 9)
            : due;
        var scheduled = tz.TZDateTime.from(localDue, tz.local);
        if (scheduled.isBefore(now)) {
          scheduled = now.add(const Duration(seconds: 5));
        }

        try {
          await _plugin.zonedSchedule(
            _notificationId(item.id),
            'To-do reminder',
            item.text,
            scheduled,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'jot_due_dates',
                'Due Date Reminders',
                channelDescription: 'Reminders for upcoming todo due dates',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'todo:${list.id}:${item.id}',
          );
        } catch (e) {
          debugPrint('Could not schedule reminder for ${item.id}: $e');
        }
      }
    }
  }

  /// Check all todo lists for overdue or due-today items and send notifications.
  /// Runs at most once per calendar day.
  Future<void> checkTodoDueDates(TodoService todoService) async {
    if (!_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        'due_check_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
    if (prefs.getBool(todayKey) == true) return;
    await prefs.setBool(todayKey, true);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final list in todoService.lists) {
      for (final item in list.items) {
        if (item.isDone || item.dueDate == null) continue;

        final dueDay = DateTime(
            item.dueDate!.year, item.dueDate!.month, item.dueDate!.day);
        final daysUntilDue = dueDay.difference(today).inDays;

        if (daysUntilDue < 0) {
          await showDueSoonNotification(
            id: _notificationId(item.id),
            title: 'Overdue: ${item.text}',
            body:
                '"${list.title}" was due ${-daysUntilDue} day${-daysUntilDue == 1 ? '' : 's'} ago',
          );
        } else if (daysUntilDue == 0) {
          await showDueSoonNotification(
            id: _notificationId(item.id),
            title: 'Due today: ${item.text}',
            body: 'In "${list.title}"',
          );
        } else if (daysUntilDue == 1) {
          await showDueSoonNotification(
            id: _notificationId(item.id),
            title: 'Due tomorrow: ${item.text}',
            body: 'In "${list.title}"',
          );
        }
      }
    }
  }

  Future<void> showTestNotification() async {
    await initialize();
    await showDueSoonNotification(
      id: 424242,
      title: 'Jot? notifications are working',
      body: 'This is a test reminder from your settings.',
    );
  }

  int _notificationId(String itemId) => itemId.hashCode & 0x7fffffff;

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
          body:
              'Your notes haven\'t synced in $hoursSinceSync hours. Open Jot? to sync.',
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
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
