import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Platform-specific theme configuration for Jot? app
class PlatformTheme {
  /// Whether to wrap text themes with Google Fonts.
  ///
  /// Disable this in unit tests (and offline environments) to avoid
  /// triggering font asset loading when themes are constructed.
  static bool useGoogleFonts = true;

  static TextTheme _interTextTheme(TextTheme base) =>
      useGoogleFonts ? GoogleFonts.interTextTheme(base) : base;

  static TextTheme _outfitTextTheme(TextTheme base) =>
      useGoogleFonts ? GoogleFonts.outfitTextTheme(base) : base;

  /// Get the appropriate theme data based on the current platform
  static ThemeData getTheme(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return _getAndroidTheme();
      case TargetPlatform.windows:
        return _getWindowsTheme();
      case TargetPlatform.linux:
        return _getLinuxTheme();
      case TargetPlatform.macOS:
        return _getMacOSTheme();
      default:
        return _getDefaultTheme();
    }
  }

  /// Get dark theme for the platform
  static ThemeData getDarkTheme(TargetPlatform platform) {
    return _getDarkTheme();
  }

  static ThemeData _getDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF),
        brightness: Brightness.dark,
        primary: const Color(0xFF9E7BFF),
        surface: const Color(0xFF1E1E2E),
        surfaceContainerHighest: const Color(0xFF181825),
        surfaceContainerHigh: const Color(0xFF313244),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF181825),
      textTheme: _interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1E1E2E),
        foregroundColor: Colors.white,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF313244), width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF9E7BFF),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9E7BFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: Color(0xFF9E7BFF),
        selectedTileColor: Color(0xFF313244),
        textColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF313244),
        hintStyle: const TextStyle(color: Colors.grey),
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }

  /// Material Design theme for Android - Premium & Vibrant
  static ThemeData _getAndroidTheme() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF673AB7), // Deep Purple
        primary: const Color(0xFF673AB7),
        secondary: const Color(0xFF03DAC6),
        surface: const Color(0xFFFBFBFE),
        surfaceContainerHighest: const Color(0xFFFBFBFE),
        error: const Color(0xFFB00020),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: const Color(0xFF1C1B1F),
        onError: Colors.white,
        brightness: Brightness.light,
      ),
    );

    return baseTheme.copyWith(
      textTheme: _outfitTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -1.5),
        displayMedium: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(fontSize: 16),
      ),
      
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1C1B1F),
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        labelStyle: const TextStyle(color: Color(0xFF1C1B1F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF673AB7), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF673AB7),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF673AB7).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }

  /// Desktop theme for Windows - Modern & Clean
  static ThemeData _getWindowsTheme() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // Blue
        primary: const Color(0xFF2196F3),
        surface: const Color(0xFFF3F3F3),
        brightness: Brightness.light,
      ),
    );

    return baseTheme.copyWith(
      textTheme: _interTextTheme(baseTheme.textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }

  /// Desktop theme for Linux
  static ThemeData _getLinuxTheme() => _getWindowsTheme().copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
  );

  /// Desktop theme for macOS
  static ThemeData _getMacOSTheme() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
    );

    return baseTheme.copyWith(
      textTheme: _interTextTheme(baseTheme.textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black12),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }

  /// Default theme fallback
  static ThemeData _getDefaultTheme() => _getAndroidTheme();
}
