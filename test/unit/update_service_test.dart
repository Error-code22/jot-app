import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jot_app/services/update_service.dart';

void main() {
  group('AppRelease.fromJson (Supabase manifest)', () {
    test('parses version, notes, size and digest', () {
      final release = AppRelease.fromJson({
        'version': '2.5.0',
        'platform': 'android',
        'notes': 'Fixed things',
        'download_url': 'https://example.com/jot-2.5.0.apk',
        'published_at': '2026-10-01T10:00:00Z',
        'size_bytes': 12345678,
        'sha256': 'SHA256:ABCDEF',
      });

      expect(release.version, '2.5.0');
      expect(release.platform, 'android');
      expect(release.notes, 'Fixed things');
      expect(release.sizeBytes, 12345678);
      expect(release.sha256, 'abcdef');
      expect(release.source, ReleaseSource.supabase);
    });
  });

  group('AppRelease.latestForPlatform', () {
    final rows = <Map<String, dynamic>>[
      {'version': '2.4.1', 'platform': 'android'},
      {'version': '2.5.0', 'platform': 'android'},
      {'version': '9.9.9', 'platform': 'ios'},
      {'version': '2.4.5', 'platform': 'all'},
    ];

    test('picks the newest release for the platform', () {
      final latest = AppRelease.latestForPlatform(rows, 'android');
      expect(latest!.version, '2.5.0');
    });

    test('includes platform-agnostic releases', () {
      final latest = AppRelease.latestForPlatform(
        [
          {'version': '2.4.1', 'platform': 'all'},
        ],
        'windows',
      );
      expect(latest!.version, '2.4.1');
    });

    test('ignores other platforms', () {
      final latest = AppRelease.latestForPlatform(
        [
          {'version': '9.9.9', 'platform': 'ios'},
        ],
        'android',
      );
      expect(latest, isNull);
    });
  });

  group('AppRelease.pickAssetForPlatform', () {
    final assets = <dynamic>[
      {'name': 'jot-2.5.0.apk', 'size': 10, 'browser_download_url': 'apk'},
      {'name': 'jot-2.5.0.exe', 'size': 20, 'browser_download_url': 'exe'},
      {'name': 'jot-2.5.0.dmg', 'size': 30, 'browser_download_url': 'dmg'},
      {'name': 'jot-2.5.0.deb', 'size': 40, 'browser_download_url': 'deb'},
    ];

    test('selects the right asset per platform', () {
      expect(AppRelease.pickAssetForPlatform(assets, 'android')!['name'],
          'jot-2.5.0.apk');
      expect(AppRelease.pickAssetForPlatform(assets, 'windows')!['name'],
          'jot-2.5.0.exe');
      expect(AppRelease.pickAssetForPlatform(assets, 'macos')!['name'],
          'jot-2.5.0.dmg');
      expect(AppRelease.pickAssetForPlatform(assets, 'linux')!['name'],
          'jot-2.5.0.deb');
    });

    test('returns null when no build matches', () {
      expect(AppRelease.pickAssetForPlatform(assets, 'ios'), isNull);
    });
  });

  group('AppRelease.fromGitHub', () {
    test('parses tag, notes, page and source', () {
      final release = AppRelease.fromGitHub({
        'tag_name': 'v2.6.0',
        'body': '## Highlights\n- Faster sync',
        'html_url': 'https://github.com/owner/repo/releases/tag/v2.6.0',
        'published_at': '2026-10-02T09:00:00Z',
        'assets': [
          {
            'name': 'jot-2.6.0.apk',
            'size': 4096,
            'digest': 'sha256:DEADBEEF',
            'browser_download_url': 'https://example.com/jot-2.6.0.apk',
          },
        ],
      });

      expect(release!.version, '2.6.0');
      expect(release.notes, contains('Faster sync'));
      expect(release.source, ReleaseSource.github);
      expect(release.pageUrl, contains('releases/tag'));
    });

    test('returns null without a tag', () {
      expect(AppRelease.fromGitHub({'body': 'notes'}), isNull);
    });
  });

  group('UpdateService', () {
    test('uses GitHub Releases when a public release exists', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, contains('/repos/owner/repo/releases/latest'));
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.5.0',
            'body': 'New stuff',
            'html_url': 'https://github.com/owner/repo/releases/tag/v2.5.0',
            'published_at': '2026-10-02T09:00:00Z',
            'assets': const [],
          }),
          200,
        );
      });

      final service =
          UpdateService(httpClient: client, githubRepo: 'owner/repo');
      final result = await service.checkForUpdates();

      expect(result.supported, isTrue);
      expect(result.updateAvailable, isTrue);
      expect(result.release!.version, '2.5.0');
      expect(result.release!.source, ReleaseSource.github);
    });

    test('reports up to date when the GitHub tag matches the app', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'tag_name': 'v2.4.0', 'assets': const []}),
            200,
          ));

      final service =
          UpdateService(httpClient: client, githubRepo: 'owner/repo');
      final result = await service.checkForUpdates();

      expect(result.updateAvailable, isFalse);
      expect(result.message, contains('latest'));
    });

    test('falls back when GitHub returns 404', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      final service =
          UpdateService(httpClient: client, githubRepo: 'owner/repo');

      // Supabase is not initialised in unit tests, so the fallback path reports
      // an unsupported check rather than throwing.
      final result = await service.checkForUpdates();
      expect(result.supported, isFalse);
    });

    test('skips GitHub entirely when no repo is configured', () async {
      final client = MockClient((_) async {
        fail('GitHub should not be called when no repo is configured');
      });

      final service = UpdateService(httpClient: client, githubRepo: '');
      final result = await service.checkForUpdates();
      expect(result.supported, isFalse);
    });
  });

  group('UpdateDownloadHandle', () {
    test('reports cancellation', () {
      final handle = UpdateDownloadHandle();
      expect(handle.isCancelled, isFalse);
      handle.cancel();
      expect(handle.isCancelled, isTrue);
    });
  });
}
