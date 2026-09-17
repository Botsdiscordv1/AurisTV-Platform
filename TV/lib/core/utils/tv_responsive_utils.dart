import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Senior TV Optimization: Plataforma independiente de AurisTV.
/// Este utilitario gestiona el responsive EXCLUSIVO para televisores (10ft UI).
class TVResponsiveUtils {
  /// Siempre es nativo en TV (Android TV)
  static bool get isNative => !kIsWeb;

  /// La navegación en TV nunca es táctil (D-pad Focus)
  static bool isTactic(BuildContext context) => false;

  /// Siempre false en el proyecto TV
  static bool isMobile(BuildContext context) => false;
  static bool isTablet(BuildContext context) => false;
  static bool isDesktop(BuildContext context) => true; // Se comporta como un desktop ultra-grande
  static bool isTV(BuildContext context) => true;

  /// Margen horizontal estándar para televisores (Safe Area optimizado)
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Reducido al 2.2% (aprox la mitad del estándar previo) para aprovechar mejor los bordes
    return (width * 0.022).clamp(20.0, 50.0);
  }

  /// Escalado de fuentes y componentes para TV (10ft UI)
  /// Optimizado para legibilidad a 3 metros de distancia.
  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    // Base de cálculo para TV: 960dp (estándar Android TV 1080p)
    final double tvScale = (width / 960.0).clamp(0.9, 1.2);
    return size * 1.25 * tvScale;
  }

  /// Ancho de póster optimizado para la densidad de TV
  static double posterWidth(BuildContext context) {
    // Reducido de 165 a 140 para que entren casi 6 posters en 960dp (Standard TV)
    return 140.0;
  }

  /// Altura proporcional (2:3)
  static double posterHeight(BuildContext context) {
    return (posterWidth(context) * 1.5).roundToDouble();
  }

  /// Altura de la fila de posters incluyendo títulos
  static double rowHeight(BuildContext context, {bool hasInfo = false}) {
    final double posterH = posterHeight(context);
    if (!hasInfo) return posterH + 12.0;
    return posterH + 55.0;
  }

  /// Ancho de banners (16:9) optimizado para TV
  static double bannerWidth(BuildContext context) {
    return 310.0;
  }

  /// Altura de banner
  static double bannerHeight(BuildContext context) {
    return (bannerWidth(context) / 1.77).roundToDouble();
  }

  /// Altura de la fila de banners
  static double bannerRowHeight(BuildContext context) {
    return bannerHeight(context) + sp(context, 42) + 28.0;
  }

  /// Títulos de secciones
  static double rowTitleFontSize(BuildContext context) {
    return 22.0;
  }

  /// Títulos dentro de tarjetas
  static double bannerTitleFontSize(BuildContext context) {
    return 16.0;
  }

  /// AspectRatio cinematográfico para el Hero en TV
  static double heroAspectRatio(BuildContext context) {
    return 2.4; // Ajustado de 2.6 a 2.4 para aumentar la altura vertical del banner
  }

  /// Logo en el Hero
  static double heroLogoHeight(BuildContext context) {
    return 120.0;
  }

  /// Sinopsis en el Hero
  static double heroSynopsisFontSize(BuildContext context) {
    return 13.0; // Reducido de 15.0 para una estética más limpia
  }

  /// Título en el Hero (cuando no hay logo)
  static double heroTitleFontSize(BuildContext context) {
    return 42.0;
  }

  /// Ancho máximo de seguridad (4K)
  static const double maxContentWidth = 3840.0;
}

/// Extensiones de conveniencia para BuildContext en TV
extension TVResponsiveExtension on BuildContext {
  /// Siempre true en este proyecto de TV
  bool get isTV => true;

  /// Siempre false en TV
  bool get isMobile => false;
  bool get isTablet => false;
  bool get isDesktop => true;

  /// Helper para escalar valores rápidamente
  double tvSp(double size) => TVResponsiveUtils.sp(this, size);
}
