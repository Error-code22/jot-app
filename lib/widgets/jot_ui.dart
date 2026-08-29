import 'dart:ui';
import 'package:flutter/material.dart';

/// A collection of premium UI components for the Jot app.
class JotUI {
  /// A glassmorphism container effect
  static Widget glassContainer({
    required Widget child,
    double blur = 10.0,
    double opacity = 0.1,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    Color? color,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withValues(alpha: opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// A modern shadow style for premium cards
  static List<BoxShadow> premiumShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: const Color(0xFF673AB7).withValues(alpha: 0.03),
        blurRadius: 40,
        offset: const Offset(0, 20),
      ),
    ];
  }

  /// Standard spacing constants
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
}

/// A stylized gradient background for screens
class JotGradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const JotGradientBackground({
    super.key,
    required this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? (isDark
            ? [const Color(0xFF181825), const Color(0xFF1E1E2E), const Color(0xFF181825)]
            : [const Color(0xFFFBFBFE), const Color(0xFFEDDFFC), const Color(0xFFE0F2F1)]),
        ),
      ),
      child: child,
    );
  }
}
