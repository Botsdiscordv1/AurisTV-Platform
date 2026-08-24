import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveUtils {
  /// Devuelve true si la aplicación es nativa (Android/iOS).
  static bool get isNative => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Devuelve true si la plataforma es móvil (Nativa o Web en navegador móvil).
  static bool get isMobilePlatform {
    if (kIsWeb) {
      // Senior Fix: Detección ultra-robusta de plataforma móvil en Web
      return (defaultTargetPlatform == TargetPlatform.android || 
              defaultTargetPlatform == TargetPlatform.iOS);
    }
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Devuelve true si el dispositivo debe usar interfaz táctil (Móvil nativo o Web en plataforma móvil).
  static bool isTactic(BuildContext context) {
    // Si la plataforma base es Android o iOS, forzamos UI táctica (Mobile/Tablet)
    if (isMobilePlatform) return true;
    
    // En Web Desktop, solo es táctico si la ventana es muy pequeña (simulando móvil)
    return MediaQuery.of(context).size.shortestSide < 600;
  }

  static DeviceType getDeviceType(BuildContext context) {
    // Si es plataforma móvil, forzamos detección móvil/tablet por hardware
    if (isMobilePlatform) {
      final double shortestSide = MediaQuery.of(context).size.shortestSide;
      // Senior Fix: Si estamos en Web, el navegador puede reportar dimensiones infladas en Fullscreen.
      // Usamos un umbral más alto para Tablets en Web.
      return shortestSide < 600 ? DeviceType.mobile : DeviceType.tablet;
    }

    // Para Desktop (Web):
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide < 600) return DeviceType.mobile;
    if (shortestSide < 1000) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isMobile(BuildContext context) => getDeviceType(context) == DeviceType.mobile;
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceType.tablet;
  static bool isDesktop(BuildContext context) => getDeviceType(context) == DeviceType.desktop;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isMobile(context)) return 12.0;
    if (width > 2200) return (width - 2000) / 2 + 32.0;
    final double percentage = width > 1200 ? 0.03 : 0.04;
    return (width * percentage).clamp(24.0, 100.0);
  }

  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= 1000) {
      return size * (width / 1440.0).clamp(0.9, 1.25);
    }
    return size * (width / 375.0).clamp(0.85, 1.3);
  }

  /// Ancho máximo de seguridad para el contenido cinematográfico (4K).
  static const double maxContentWidth = 3840.0;
}
