import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum DeviceType { mobile, tablet, desktop }

/// Senior TV Optimization: Esta versión del utilitario fuerza el modo Desktop/TV
/// eliminando toda la lógica de layouts móviles o táctiles.
class ResponsiveUtils {
  static bool get isNative => !kIsWeb;
  static bool get isMobilePlatform => false;

  /// Siempre devolvemos false para táctil en la versión TV/Web Grande.
  static bool isTactic(BuildContext context) => false;

  /// Forzamos que el tipo de dispositivo sea siempre Desktop (optimizado para TV).
  static DeviceType getDeviceType(BuildContext context) => DeviceType.desktop;

  static bool isMobile(BuildContext context) => false;
  static bool isTablet(BuildContext context) => false;
  static bool isDesktop(BuildContext context) => true;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 2200) return (width - 2000) / 2 + 32.0;
    final double percentage = width > 1200 ? 0.03 : 0.04;
    return (width * percentage).clamp(24.0, 100.0);
  }

  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    // Senior TV Fix: En TV el ancho lógico suele ser bajo (ej. 960px).
    // Usamos 1280 como base de escalado más equilibrada para "Desktop Lite" (TV).
    // Permitimos que baje hasta 0.7 para que la UI se encoja en TVs con poco ancho lógico.
    return size * (width / 1600.0).clamp(0.7, 1.3); 
  }

  static const double maxContentWidth = 3840.0;
}
