import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences that are not tied to a single note or screen.
class AppSettings extends ChangeNotifier {
  static const _kHidePreviews = 'settings.hide_note_previews';
  static const _kBiometricUnlock = 'settings.biometric_unlock';
  static const _kTodoReminders = 'settings.todo_reminders';
  static const _kDueDateNotifications = 'settings.due_date_notifications';
  static const _kAutoCheckUpdates = 'settings.auto_check_updates';
  static const _kLastUpdateCheck = 'settings.last_update_check';

  bool _hideNotePreviews = false;
  bool _biometricUnlock = true;
  bool _todoReminders = true;
  bool _dueDateNotifications = true;
  bool _autoCheckUpdates = true;
  DateTime? _lastUpdateCheck;
  bool _loaded = false;

  bool get hideNotePreviews => _hideNotePreviews;
  bool get biometricUnlock => _biometricUnlock;
  bool get todoReminders => _todoReminders;
  bool get dueDateNotifications => _dueDateNotifications;
  bool get autoCheckUpdates => _autoCheckUpdates;
  DateTime? get lastUpdateCheck => _lastUpdateCheck;
  bool get isLoaded => _loaded;

  /// Whether the daily update check is due.
  bool get shouldCheckForUpdates {
    if (!_autoCheckUpdates) return false;
    final last = _lastUpdateCheck;
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= 24;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hideNotePreviews = prefs.getBool(_kHidePreviews) ?? false;
    _biometricUnlock = prefs.getBool(_kBiometricUnlock) ?? true;
    _todoReminders = prefs.getBool(_kTodoReminders) ?? true;
    _dueDateNotifications = prefs.getBool(_kDueDateNotifications) ?? true;
    _autoCheckUpdates = prefs.getBool(_kAutoCheckUpdates) ?? true;
    final rawLastCheck = prefs.getString(_kLastUpdateCheck);
    _lastUpdateCheck =
        rawLastCheck == null ? null : DateTime.tryParse(rawLastCheck);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setHideNotePreviews(bool value) async {
    _hideNotePreviews = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHidePreviews, value);
  }

  Future<void> setBiometricUnlock(bool value) async {
    _biometricUnlock = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricUnlock, value);
  }

  Future<void> setTodoReminders(bool value) async {
    _todoReminders = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTodoReminders, value);
  }

  Future<void> setDueDateNotifications(bool value) async {
    _dueDateNotifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDueDateNotifications, value);
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    _autoCheckUpdates = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoCheckUpdates, value);
  }

  Future<void> markUpdateChecked() async {
    _lastUpdateCheck = DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLastUpdateCheck, _lastUpdateCheck!.toIso8601String());
  }
}
