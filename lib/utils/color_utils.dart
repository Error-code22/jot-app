import 'package:flutter/material.dart';

class ColorUtils {
  /// Parse hex color string to Color
  static Color? fromHex(String? hex) {
    if (hex == null) return null;
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  }

  /// Get the appropriate note background color based on theme
  /// In dark mode, colored notes use a darker, desaturated version
  static Color noteBackground(String? hex, bool isDark, BuildContext context) {
    if (hex == null) {
      return isDark ? const Color(0xFF1E1E2E) : Colors.white;
    }
    final base = fromHex(hex)!;
    if (!isDark) return base;

    // In dark mode: slightly darken the color while keeping its hue visible
    final hsl = HSLColor.fromColor(base);
    final darkened = hsl.withLightness((hsl.lightness * 0.45).clamp(0.15, 0.45))
                        .withSaturation((hsl.saturation * 0.85).clamp(0.3, 1.0));
    return darkened.toColor();
  }

  /// Get text color that contrasts well with the background
  static Color textColor(Color background) {
    // Calculate relative luminance
    final luminance = background.computeLuminance();
    return luminance > 0.35 ? Colors.black87 : Colors.white;
  }

  /// Get secondary text color (for subtitles, dates)
  static Color secondaryTextColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.35
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.6);
  }
}
