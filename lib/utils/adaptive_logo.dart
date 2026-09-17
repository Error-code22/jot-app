import 'package:flutter/material.dart';

/// Returns the correct logo path based on current theme brightness.
String adaptiveLogoPath(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark
      ? 'public/logo.png'
      : 'public/logo_light.png';
}
