import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum DeviceType { mobile, tablet, desktop }

/// Breakpoints estándar para la plataforma AurisTV.
enum Breakpoint {
  /// Base (Móvil Portrait): < 480
  base(0),
  /// Small (Móvil Landscape / Tablet pequeña): ≥ 480
  sm(480),
  /// Medium (Tablets): ≥ 768
  md(768),
  /// Large (Desktop / Tablet grande): ≥ 1024
  lg(1024),
  /// Extra Large (Desktop HD): ≥ 1280
  xl(1280),
  /// Extra Extra Large (Desktop 4K/Ultrawide): ≥ 1536
  xxl(1536);

  final double minWidth;
  const Breakpoint(this.minWidth);

  bool operator >=(Breakpoint other) => index >= other.index;
  bool operator <=(Breakpoint other) => index <= other.index;
  bool operator >(Breakpoint other) => index > other.index;
  bool operator <(Breakpoint other) => index < other.index;
}

extension BreakpointExtension on BuildContext {
  Breakpoint get breakpoint => ResponsiveUtils.getBreakpoint(this);

  /// Móvil estricto (Smartphones): < 768
  bool get isMobile => breakpoint < Breakpoint.md;

  /// Tablet estricta: 768 a 1024
  bool get isTablet => breakpoint >= Breakpoint.md && breakpoint < Breakpoint.lg;

  /// Escritorio: ≥ 1024
  bool get isDesktop => breakpoint >= Breakpoint.lg;

  /// Senior Strategy: Define si debemos usar la UI de "Móvil/Táctil" (incluye tablets).
  /// Útil para Navbars, Paddings y comportamiento de gestos.
  /// Incluye hasta el breakpoint LG (1024dp) para soportar iPad Pro/Mini.
  bool get useMobileLayout => breakpoint <= Breakpoint.lg;

  /// Helpers de conveniencia para rangos
  bool atLeast(Breakpoint b) => breakpoint >= b;
  bool atMost(Breakpoint b) => breakpoint <= b;
}

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

    // En Web Desktop, es táctico si estamos en modo Mobile/Tablet Layout (hasta 1024dp)
    return context.useMobileLayout;
  }

  static Breakpoint getBreakpoint(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= Breakpoint.xxl.minWidth) return Breakpoint.xxl;
    if (width >= Breakpoint.xl.minWidth) return Breakpoint.xl;
    if (width >= Breakpoint.lg.minWidth) return Breakpoint.lg;
    if (width >= Breakpoint.md.minWidth) return Breakpoint.md;
    if (width >= Breakpoint.sm.minWidth) return Breakpoint.sm;
    return Breakpoint.base;
  }

  static DeviceType getDeviceType(BuildContext context) {
    final b = getBreakpoint(context);
    if (b < Breakpoint.md) return DeviceType.mobile;
    if (b < Breakpoint.lg) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isMobile(BuildContext context) => getDeviceType(context) == DeviceType.mobile;
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceType.tablet;
  static bool isDesktop(BuildContext context) => getDeviceType(context) == DeviceType.desktop;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final b = getBreakpoint(context);

    if (b < Breakpoint.md) return 12.0;
    if (width > 2200) return (width - 2000) / 2 + 32.0;

    final double percentage = b >= Breakpoint.xl ? 0.03 : 0.04;
    return (width * percentage).clamp(24.0, 100.0);
  }

  /// Senior UI Strategy: Devuelve el ancho ideal del póster según el dispositivo.
  /// Evita tarjetas gigantes en tablets y asegura densidad en desktop.
  static double posterWidth(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 125.0;
    if (b == Breakpoint.sm) return 140.0;
    if (b == Breakpoint.md) return 160.0;
    if (b == Breakpoint.lg) return 180.0;
    return 200.0;
  }

  /// Altura proporcional al ancho (AspectRatio ~0.65 para posters).
  static double posterHeight(BuildContext context) {
    return (posterWidth(context) / 0.65).roundToDouble();
  }

  /// Altura del contenedor de la fila (incluyendo texto y paddings).
  static double rowHeight(BuildContext context) {
    final b = getBreakpoint(context);
    final double baseHeight = posterHeight(context) + (b < Breakpoint.md ? 45.0 : 65.0);
    return baseHeight;
  }

  /// Senior UI Strategy: Ancho de banners (Wide Cards) adaptativo.
  static double bannerWidth(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 260.0;
    if (b == Breakpoint.sm) return 300.0;
    if (b == Breakpoint.md) return 340.0;
    if (b == Breakpoint.lg) return 380.0;
    return 420.0;
  }

  /// Altura de banners (Wide Cards) manteniendo AspectRatio 16:9 aprox.
  static double bannerHeight(BuildContext context) {
    return (bannerWidth(context) / 1.77).roundToDouble();
  }

  /// Altura del contenedor de la fila Wide.
  static double bannerRowHeight(BuildContext context) {
    final b = getBreakpoint(context);
    return bannerHeight(context) + (b < Breakpoint.md ? 60.0 : 85.0);
  }

  /// Senior UI Strategy: Tamaños de fuente adaptativos para títulos de filas.
  static double rowTitleFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 18.0;
    if (b == Breakpoint.sm) return 20.0;
    if (b == Breakpoint.md) return 22.0;
    if (b == Breakpoint.lg) return 24.0;
    return 26.0;
  }

  /// Senior UI Strategy: Tamaños de fuente adaptativos para títulos de tarjetas (Banners).
  static double bannerTitleFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 13.0;
    if (b == Breakpoint.sm) return 14.0;
    if (b == Breakpoint.md) return 15.0;
    if (b == Breakpoint.lg) return 16.0;
    return 17.0;
  }

  /// Senior UI Strategy: Tamaños de fuente adaptativos para títulos de tarjetas (Posters).
  static double posterTitleFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 12.0;
    if (b == Breakpoint.sm) return 13.0;
    if (b == Breakpoint.md) return 14.0;
    if (b == Breakpoint.lg) return 15.0;
    return 16.0;
  }

  /// Senior UI Strategy: AspectRatio dinámico para el HeroBanner.
  /// Evita que el banner sea demasiado "fino" en tablets y demasiado "alto" en monitores ultrawide.
  static double heroAspectRatio(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 16 / 11;
    if (b == Breakpoint.sm) return 16 / 10;
    if (b == Breakpoint.md) return 2.0; // Tablets: Más inmersivo pero menos ancho que desktop
    if (b == Breakpoint.lg) return 2.4;
    return 2.8; // Desktop standard
  }

  /// Senior UI Strategy: Tamaños de fuente para el HeroBanner (Cinematic).
  static double heroTitleFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.lg) return 42.0;
    if (b >= Breakpoint.xl) return 58.0;
    return 32.0; // Mobile/Tablet fallback
  }

  static double heroSynopsisFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b >= Breakpoint.xl) return 16.0;
    return 14.0;
  }

  /// Altura del logo en el HeroBanner.
  static double heroLogoHeight(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 80.0;
    if (b == Breakpoint.sm) return 95.0;
    if (b == Breakpoint.md) return 110.0;
    return 135.0;
  }

  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    final b = getBreakpoint(context);

    if (b >= Breakpoint.lg) {
      return size * (width / 1440.0).clamp(0.9, 1.25);
    }
    return size * (width / 375.0).clamp(0.85, 1.3);
  }

  /// Ancho máximo de seguridad para el contenido cinematográfico (4K).
  static const double maxContentWidth = 3840.0;
}
