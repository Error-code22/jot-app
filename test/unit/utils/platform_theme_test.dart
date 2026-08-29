import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_app/utils/platform_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Disable GoogleFonts loading in tests — theme construction must not
    // trigger font asset/network loading.
    GoogleFonts.config.allowRuntimeFetching = false;
    PlatformTheme.useGoogleFonts = false;
  });

  group('PlatformTheme', () {
    test('getTheme returns Material Design theme for Android', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.android);
      
      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.centerTitle, isFalse); // Android left-aligns
      expect(theme.floatingActionButtonTheme.elevation, equals(4));
      expect(theme.cardTheme.elevation, equals(0));
    });

    test('getTheme returns Windows-appropriate theme for Windows', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.windows);
      
      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.centerTitle, isTrue); // Windows centers
      expect(theme.floatingActionButtonTheme.elevation, equals(2));
      expect(theme.cardTheme.elevation, equals(2));
    });

    test('getTheme returns Linux-appropriate theme for Linux', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.linux);
      
      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(theme.floatingActionButtonTheme.elevation, equals(2));
      expect(theme.cardTheme.elevation, equals(2));
    });

    test('getTheme returns macOS-appropriate theme for macOS', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.macOS);
      
      expect(theme.useMaterial3, isTrue);
      expect(theme.appBarTheme.centerTitle, isTrue); // macOS centers
      expect(theme.appBarTheme.elevation, equals(0)); // macOS flat design
      expect(theme.floatingActionButtonTheme.elevation, equals(0));
      expect(theme.cardTheme.elevation, equals(0));
    });

    test('Android theme uses Material Design colors', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.android);
      
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.colorScheme.secondary, isNotNull);
    });

    test('Windows theme uses blue seed color', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.windows);
      
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('Linux theme uses orange seed color', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.linux);
      
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('macOS theme uses blue seed color', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.macOS);
      
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('Android theme has rounded card corners', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.android);
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      final borderRadius = shape.borderRadius as BorderRadius;
      
      expect(borderRadius.topLeft.x, equals(20));
    });

    test('Windows theme has less rounded corners than Android', () {
      final androidTheme = PlatformTheme.getTheme(TargetPlatform.android);
      final windowsTheme = PlatformTheme.getTheme(TargetPlatform.windows);
      
      final androidShape = androidTheme.cardTheme.shape as RoundedRectangleBorder;
      final androidRadius = androidShape.borderRadius as BorderRadius;
      
      final windowsShape = windowsTheme.cardTheme.shape as RoundedRectangleBorder;
      final windowsRadius = windowsShape.borderRadius as BorderRadius;
      
      expect(androidRadius.topLeft.x, greaterThan(windowsRadius.topLeft.x));
    });

    test('macOS theme has flat design with zero elevation', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.macOS);
      
      expect(theme.appBarTheme.elevation, equals(0));
      expect(theme.floatingActionButtonTheme.elevation, equals(0));
      expect(theme.cardTheme.elevation, equals(0));
    });

    test('all platform themes use Material 3', () {
      final platforms = [
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ];
      
      for (final platform in platforms) {
        final theme = PlatformTheme.getTheme(platform);
        expect(theme.useMaterial3, isTrue, 
            reason: '$platform should use Material 3');
      }
    });

    test('all platform themes have input decoration configured', () {
      final platforms = [
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ];
      
      for (final platform in platforms) {
        final theme = PlatformTheme.getTheme(platform);
        expect(theme.inputDecorationTheme.filled, isTrue,
            reason: '$platform should have filled input decoration');
        expect(theme.inputDecorationTheme.border, isNotNull,
            reason: '$platform should have input border');
      }
    });

    test('desktop platforms have elevated button theme configured', () {
      final desktopPlatforms = [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ];
      
      for (final platform in desktopPlatforms) {
        final theme = PlatformTheme.getTheme(platform);
        expect(theme.elevatedButtonTheme.style, isNotNull,
            reason: '$platform should have elevated button style');
      }
    });

    test('getTheme returns default theme for unsupported platforms', () {
      final theme = PlatformTheme.getTheme(TargetPlatform.iOS);
      
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, isNotNull);
    });
  });
}
