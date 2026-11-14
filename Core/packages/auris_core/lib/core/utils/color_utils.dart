import 'package:flutter/material.dart';

/// Utility function to create a Color from HSL values.
Color hslToColor(double hue, double saturation, double lightness) {
  // Dart/Flutter: Color.fromHSL no está disponible, crear manualmente.
  // Convert HSL to RGB.
  final h = hue.clamp(0.0, 1.0);
  final s = saturation.clamp(0.0, 1.0);
  final l = lightness.clamp(0.0, 1.0);

  if (s == 0.0) {
    // Achromatic (grey).
    final gray = (l * 255).round().clamp(0, 255);
    return Color.fromARGB(255, gray, gray, gray);
  }

  double hueToRgb(double n1, double n2, double h) {
    double hh = h;
    if (hh < 0) hh += 1;
    if (hh > 1) hh -= 1;
    if (hh < 1/6) return n1 + (n2 - n1) * 6 * hh;
    if (hh < 1/2) return n2;
    if (hh < 2/3) return n1 + (n2 - n1) * (2/3 - hh) * 6;
    return n1;
  }

  final double n2 = l <= 0.5 ? l * (1 + s) : l + s - l * s;
  final double n1 = 2 * l - n2;

  final r = (hueToRgb(n1, n2, h + 1/3) * 255).round().clamp(0, 255);
  final g = (hueToRgb(n1, n2, h) * 255).round().clamp(0, 255);
  final b = (hueToRgb(n1, n2, h - 1/3) * 255).round().clamp(0, 255);

  return Color.fromARGB(255, r, g, b);
}

/// Helper class for HSL color operations.
class HSL {
  static Color toColor(double hue, double saturation, double lightness) {
    return hslToColor(hue, saturation, lightness);
  }
}

/// Color palette from a title hash (deterministic per content for ambient mode).
Color extractAmbientColorFromTitle(String title) {
  if (title.isEmpty) return const Color(0xFF1E2A38); // Dark blue fallback.
  final hash = title.hashCode.abs();
  final hue = (hash % 360) / 360.0;
  final saturation = 0.6 + (hash % 40) / 100.0;
  final lightness = 0.25 + (hash % 20) / 100.0;
  return hslToColor(hue, saturation, lightness);
}