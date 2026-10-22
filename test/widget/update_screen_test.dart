import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/screens/update_screen.dart';
import 'package:jot_app/services/update_service.dart';

AppRelease buildRelease({
  String? downloadUrl = 'https://example.com/jot-2.5.0.apk',
  String? pageUrl,
  String? sha256 = 'abcdef0123456789',
  int? sizeBytes = 48234496,
}) {
  return AppRelease(
    version: '2.5.0',
    platform: 'android',
    notes: '🎉 New version of Jot?:\n\n- Faster sync\n- Voice notes',
    downloadUrl: downloadUrl,
    pageUrl: pageUrl,
    sizeBytes: sizeBytes,
    sha256: sha256,
  );
}

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('UpdateScreen', () {
    testWidgets('shows the version heading and release notes', (tester) async {
      await tester.pumpWidget(wrap(UpdateScreen(
        service: UpdateService(githubRepo: ''),
        release: buildRelease(),
      )));

      expect(find.text('Discover new version v2.5.0'), findsOneWidget);
      expect(find.textContaining('You are on'), findsOneWidget);
      expect(find.textContaining('Download size'), findsOneWidget);
      expect(find.textContaining('Faster sync'), findsOneWidget);
    });

    testWidgets('offers update and not-now actions when a build exists',
        (tester) async {
      await tester.pumpWidget(wrap(UpdateScreen(
        service: UpdateService(githubRepo: ''),
        release: buildRelease(),
      )));

      expect(find.text('Update now'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.textContaining('Security verified'), findsOneWidget);
    });

    testWidgets('shows a release-page action when no build matches',
        (tester) async {
      await tester.pumpWidget(wrap(UpdateScreen(
        service: UpdateService(githubRepo: ''),
        release: buildRelease(
          downloadUrl: null,
          pageUrl: 'https://github.com/owner/repo/releases/tag/v2.5.0',
        ),
      )));

      expect(find.text('Open release page'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
    });

    testWidgets('disables the action when there is nothing to download',
        (tester) async {
      await tester.pumpWidget(wrap(UpdateScreen(
        service: UpdateService(githubRepo: ''),
        release: buildRelease(downloadUrl: null, pageUrl: null, sha256: null),
      )));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Official release channel'), findsOneWidget);
    });
  });
}
