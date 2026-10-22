import 'package:package_info_plus/package_info_plus.dart';

/// Central app identity so the version shown in the UI can never drift from
/// the actual build again.
class AppInfo {
  static const String appName = 'Jot?';
  static const String fallbackVersion = '2.4.0';
  static const int fallbackBuildNumber = 4;

  static String _version = fallbackVersion;
  static String _buildNumber = '$fallbackBuildNumber';
  static String _packageName = 'com.jotapp.jot_app';
  static bool _loaded = false;

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get versionLabel => '$_version ($_buildNumber)';
  static String get packageName => _packageName;
  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version.isEmpty ? fallbackVersion : info.version;
      _buildNumber =
          info.buildNumber.isEmpty ? '$fallbackBuildNumber' : info.buildNumber;
      _packageName = info.packageName.isEmpty ? _packageName : info.packageName;
      _loaded = true;
    } catch (_) {
      // Keep the compile-time fallback; tests and unsupported platforms may not
      // provide package metadata.
      _loaded = true;
    }
  }

  static int compareVersions(String a, String b) {
    final left = _numericParts(a);
    final right = _numericParts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  static List<int> _numericParts(String value) {
    // Strip a leading "v" and any build metadata.
    final clean =
        value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    return clean.split('.').map((part) {
      final match = RegExp(r'^\d+').firstMatch(part);
      return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
    }).toList();
  }
}
