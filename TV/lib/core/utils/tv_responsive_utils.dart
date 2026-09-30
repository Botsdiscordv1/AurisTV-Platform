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
    // Margen adaptativo según la resolución para aprovechar mejor los bordes sin desbordar
    if (width <= 1280) return 24.0;
    if (width <= 1920) return 36.0;
    return (width * 0.022).clamp(40.0, 64.0);
  }

  /// Altura del topbar fijo (misma fórmula que usa el home para su navbar):
  /// es la referencia para anclar las secciones justo debajo al navegar.
  static double topBarHeight(BuildContext context) => sp(context, 72);

  /// Escalado de fuentes y componentes para TV (10ft UI)
  /// Optimizado con resolución por buckets (720p, 1080p, 4K) para evitar elementos gigantes.
  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    double tvScale;
    if (width <= 1280) {
      tvScale = 0.85; // 720p
    } else if (width <= 1920) {
      tvScale = 1.0;  // 1080p estándar
    } else {
      tvScale = 1.15; // 4K / UHD (controlado)
    }
    return size * tvScale;
  }

  /// Ancho de póster optimizado y adaptativo según la densidad y resolución de TV
  static double posterWidth(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width <= 1280) return 120.0; // Compacto en 720p
    if (width <= 1920) return 140.0; // Estándar en 1080p (~6 posters por fila)
    return 165.0;                   // Ampliado en 4K
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

  /// Ancho de banners (16:9) optimizado y adaptativo para TV
  static double bannerWidth(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width <= 1280) return 280.0;
    if (width <= 1920) return 330.0;
    return 380.0;
  }

  /// Altura de banner
  static double bannerHeight(BuildContext context) {
    return (bannerWidth(context) / (16 / 9)).roundToDouble();
  }

  /// Altura de la fila de banners
  /// [hasSubtitle] - Si es true, reserva espacio para texto inferior.
  /// [subtitleLines] - 2 cuando hay segunda línea ("Quedan X" bajo "T1:E7 . Título").
  static double bannerRowHeight(BuildContext context,
      {bool hasSubtitle = true, int subtitleLines = 1}) {
    final double extraSpace = hasSubtitle
        ? sp(context, 20) + (subtitleLines > 1 ? (4 + sp(context, 20)) : 0)
        : 0;
    return bannerHeight(context) + extraSpace + 32.0; // Búfer amplio para dar aire y eliminar overflow por completo
  }

  /// Títulos de secciones
  static double rowTitleFontSize(BuildContext context) {
    return sp(context, 17.0);
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
