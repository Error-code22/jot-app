import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/app_info.dart';

/// Where a release was discovered. GitHub Releases is preferred; the Supabase
/// `app_releases` manifest is the fallback.
enum ReleaseSource { github, supabase }

class AppRelease {
  final String version;
  final String? notes;
  final String? downloadUrl;

  /// Human-readable release page (GitHub only). Used when no build exists for
  /// the current platform.
  final String? pageUrl;
  final String platform;
  final DateTime? publishedAt;
  final int? sizeBytes;
  final String? sha256;
  final ReleaseSource source;

  AppRelease({
    required this.version,
    required this.platform,
    this.notes,
    this.downloadUrl,
    this.pageUrl,
    this.publishedAt,
    this.sizeBytes,
    this.sha256,
    this.source = ReleaseSource.supabase,
  });

  /// Parses a row from the Supabase `app_releases` manifest.
  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        version: json['version'] as String? ?? '',
        notes: json['notes'] as String?,
        downloadUrl: json['download_url'] as String?,
        platform: json['platform'] as String? ?? 'all',
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        sha256: _normalizeDigest(json['sha256'] as String?),
        source: ReleaseSource.supabase,
      );

  /// Parses the payload of `GET /repos/{owner}/{repo}/releases/latest`.
  static AppRelease? fromGitHub(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) return null;

    final assets = json['assets'] is List ? json['assets'] as List : const [];
    final asset = pickAssetForPlatform(assets, platformKey());
    final digest = asset?['digest'] as String?;

    return AppRelease(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      notes: json['body'] as String?,
      downloadUrl: asset?['browser_download_url'] as String?,
      pageUrl: json['html_url'] as String?,
      platform: platformKey(),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      sizeBytes: (asset?['size'] as num?)?.toInt(),
      sha256: _normalizeDigest(digest),
      source: ReleaseSource.github,
    );
  }

  /// Picks the best asset for [platform] from a GitHub release asset list.
  ///
  /// Returns null when the release has no build for this platform.
  static Map<String, dynamic>? pickAssetForPlatform(
    List<dynamic> assets,
    String platform,
  ) {
    final extensions = switch (platform) {
      'android' => const ['.apk'],
      'windows' => const ['.exe', '.msix', '.zip'],
      'macos' => const ['.dmg', '.pkg', '.zip'],
      'linux' => const ['.appimage', '.deb', '.tar.gz'],
      _ => const <String>[],
    };
    for (final extension in extensions) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith(extension)) return Map<String, dynamic>.from(asset);
      }
    }
    return null;
  }

  /// Picks the newest manifest row that applies to [platform].
  static AppRelease? latestForPlatform(
    Iterable<Map<String, dynamic>> rows,
    String platform,
  ) {
    final releases = rows
        .map(AppRelease.fromJson)
        .where((release) => release.version.isNotEmpty)
        .where((release) =>
            release.platform == 'all' || release.platform == platform)
        .toList();
    if (releases.isEmpty) return null;
    releases.sort((a, b) => AppInfo.compareVersions(b.version, a.version));
    return releases.first;
  }

  /// Platform key used for release matching and asset selection.
  static String platformKey() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'all';
  }

  /// Accepts "sha256:abc…", "abc…", or null and returns a bare lowercase hash.
  static String? _normalizeDigest(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    final hash = lower.startsWith('sha256:') ? lower.substring(7) : lower;
    return hash.isEmpty ? null : hash;
  }
}

class UpdateCheckResult {
  final bool supported;
  final bool updateAvailable;
  final AppRelease? release;
  final String? message;

  const UpdateCheckResult({
    required this.supported,
    required this.updateAvailable,
    this.release,
    this.message,
  });
}

/// Lets the update page abort an in-progress download.
class UpdateDownloadHandle {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Checks for a newer build, preferring public GitHub Releases and falling
/// back to the Supabase `app_releases` manifest.
///
/// GitHub is tried first because it also hosts the APK/EXE and gives the
/// release notes, asset size, and (when present) a SHA-256 digest for free.
class UpdateService {
  final SupabaseClient? _clientOverride;
  final http.Client _http;
  final String _githubRepo;

  UpdateService({
    SupabaseClient? client,
    http.Client? httpClient,
    String? githubRepo,
  })  : _clientOverride = client,
        _http = httpClient ?? http.Client(),
        _githubRepo = githubRepo ?? AppConfig.githubReleasesRepo;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<UpdateCheckResult> checkForUpdates() async {
    final fromGitHub = await _checkGitHub();
    if (fromGitHub != null) return fromGitHub;
    return _checkSupabase();
  }

  Future<UpdateCheckResult?> _checkGitHub() async {
    final repo = _githubRepo.trim();
    if (repo.isEmpty) return null;

    try {
      final response = await _http.get(
        Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Jot-App',
        },
      );

      // 404 means private/missing repo or no releases yet; fall back quietly.
      if (response.statusCode != 200) {
        debugPrint('GitHub update check returned ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final release = AppRelease.fromGitHub(json);
      if (release == null || release.version.isEmpty) return null;
      return _evaluate(release);
    } catch (e) {
      debugPrint('GitHub update check failed: $e');
      return null;
    }
  }

  Future<UpdateCheckResult> _checkSupabase() async {
    try {
      final rows = await _client
          .from('app_releases')
          .select()
          .order('published_at', ascending: false)
          .limit(20);

      final latest = AppRelease.latestForPlatform(
        (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
        AppRelease.platformKey(),
      );

      if (latest == null) {
        return const UpdateCheckResult(
          supported: true,
          updateAvailable: false,
          message: 'No releases have been published yet.',
        );
      }
      return _evaluate(latest);
    } catch (e) {
      debugPrint('Update check failed: $e');
      return const UpdateCheckResult(
        supported: false,
        updateAvailable: false,
        message: 'Could not check for updates. Please try again later.',
      );
    }
  }

  UpdateCheckResult _evaluate(AppRelease latest) {
    final available =
        AppInfo.compareVersions(latest.version, AppInfo.version) > 0;
    return UpdateCheckResult(
      supported: true,
      updateAvailable: available,
      release: latest,
      message: available ? null : 'You are on the latest version.',
    );
  }

  /// Downloads an Android APK (verifying its SHA-256 when provided) and opens
  /// the system installer, or opens the download page in the browser on
  /// desktop. Returns a human-readable result message.
  Future<String> downloadAndInstall(
    AppRelease release, {
    void Function(double progress)? onProgress,
    UpdateDownloadHandle? handle,
  }) async {
    final url = release.downloadUrl;
    if (url == null || url.isEmpty) {
      return 'No build is available for this platform yet.';
    }

    if (!Platform.isAndroid) {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      return opened
          ? 'Opened the download page in your browser.'
          : 'Could not open the download page.';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/jot-${release.version}.apk');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        return 'Download failed (HTTP ${response.statusCode}).';
      }

      final total = response.contentLength ?? release.sizeBytes ?? 0;
      var received = 0;
      final out = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          if (handle?.isCancelled ?? false) {
            await out.close();
            if (await file.exists()) await file.delete();
            return 'Update cancelled.';
          }
          out.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await out.close();
      } catch (_) {
        try {
          await out.close();
        } catch (_) {}
        rethrow;
      }

      onProgress?.call(1);

      final expected = release.sha256;
      if (expected != null && expected.isNotEmpty) {
        final actual =
            (await sha256.bind(file.openRead()).first).toString().toLowerCase();
        if (actual != expected.toLowerCase()) {
          if (await file.exists()) await file.delete();
          return 'The download did not match its published checksum. '
              'Please try again.';
        }
      }

      final result = await OpenFilex.open(file.path);
      return result.type == ResultType.done
          ? 'Security verified. Installer opened.'
          : 'Downloaded to ${file.path}. Open it to install.';
    } catch (e) {
      debugPrint('Update download failed: $e');
      return 'Download failed: $e';
    } finally {
      client.close();
    }
  }
}
