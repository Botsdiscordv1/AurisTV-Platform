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

  /// Senior UI Strategy: Número de columnas para la pantalla de búsqueda.
  static int searchGridColumns(BuildContext context) {
    final b = getBreakpoint(context);
    if (b < Breakpoint.md) return 2;
    if (b < Breakpoint.lg) return 3;
    if (b < Breakpoint.xl) return 4;
    return 5;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final b = getBreakpoint(context);

    if (b < Breakpoint.md) return 12.0;
    if (width > 2200) return (width - 2000) / 2 + 32.0;

    final double percentage = b >= Breakpoint.xl ? 0.03 : 0.04;
    return (width * percentage).clamp(24.0, 100.0);
  }

  static double posterWidth(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final Orientation orientation = MediaQuery.of(context).orientation;
    final b = getBreakpoint(context);
    
    // Senior Fix: Densidad Dinámica Total. 
    // Evitamos valores hardcodeados para que tablets y plegables no tengan posters gigantes.
    if (b < Breakpoint.md) {
      if (width > 550 || orientation == Orientation.landscape) {
        return (width / 6.5).clamp(80.0, 110.0);
      }
      return (width / 3.5).clamp(100.0, 125.0);
    }
    
    // Para Tablets (Z Fold / iPad / Android Tablets)
    if (b == Breakpoint.md) {
      // Forzamos una densidad de ~6.5 posters para aprovechar el ancho sin gigantismo
      return (width / 6.5).clamp(110.0, 140.0);
    }
    
    // Para Desktop y Tablets Grandes
    if (b == Breakpoint.lg) return 180.0;
    return 200.0;
  }

  /// Altura proporcional al ancho (AspectRatio 2:3 perfecto).
  static double posterHeight(BuildContext context) {
    return (posterWidth(context) * 1.5).roundToDouble();
  }

  /// Altura del contenedor de la fila.
  /// [hasInfo] - Si es true (Búsqueda/Explorar), reserva espacio para el texto.
  /// Si es false (Home), colapsa el espacio al mínimo para la sombra/foco.
  static double rowHeight(BuildContext context, {bool hasInfo = false}) {
    final b = getBreakpoint(context);
    final double posterH = posterHeight(context);
    if (!hasInfo) {
      // Senior Tuning: Altura exacta del póster + margen para sombra/zoom
      return posterH + (b < Breakpoint.md ? 12.0 : 16.0);
    }
    // Espacio para póster + Gap (8) + Texto (22-28) + Margen sombra
    return posterH + (b < Breakpoint.md ? 42.0 : 55.0);
  }

  static double bannerWidth(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final Orientation orientation = MediaQuery.of(context).orientation;
    final b = getBreakpoint(context);
    
    if (b < Breakpoint.md) {
      if (width > 550 || orientation == Orientation.landscape) {
        return (width / 3.2).clamp(200.0, 260.0);
      }
      return (width / 1.35).clamp(240.0, 310.0);
    }

    // Senior Fix: Para Tablets y Plegables (Z Fold)
    if (b == Breakpoint.md) {
      // Aumentamos densidad a ~3.2 para que los banners sean elegantes y no ocupen media pantalla
      return (width / 3.2).clamp(240.0, 290.0);
    }
    
    if (b == Breakpoint.lg) return 380.0;
    return 420.0;
  }

  /// Altura de banners (Wide Cards) manteniendo AspectRatio 16:9 aprox.
  static double bannerHeight(BuildContext context) {
    return (bannerWidth(context) / 1.77).roundToDouble();
  }

  /// Altura del contenedor de la fila Wide.
  /// [hasSubtitle] - Si es true (Continuar Viendo / Categorías), reserva espacio para el texto inferior.
  static double bannerRowHeight(BuildContext context, {bool hasSubtitle = true}) {
    final b = getBreakpoint(context);
    // bannerHeight + (subtitleArea (20) if needed)
    final double extraSpace = hasSubtitle ? sp(context, 20) : 0;
    // Senior Fix: Sincronizado con rowHeight (Posters) para paridad visual absoluta (12px mobile / 16px desktop)
    return bannerHeight(context) + extraSpace + (b < Breakpoint.md ? 12.0 : 16.0);
  }

  /// Senior UI Strategy: Tamaños de fuente adaptativos para títulos de filas.
  static double rowTitleFontSize(BuildContext context) {
    final b = getBreakpoint(context);
    if (b == Breakpoint.base) return 14.0;
    if (b == Breakpoint.sm) return 15.0;
    if (b == Breakpoint.md) return 17.0;
    if (b == Breakpoint.lg) return 18.0;
    return 19.0;
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
    return 2.8; // Restaurado a 2.8 para no afectar a Desktop Web
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
    // Senior Fix: Escala suavizada para evitar deformaciones en pantallas intermedias (Fold/Tablets Portrait)
    return size * (width / 375.0).clamp(0.85, 1.2);
  }

  /// Ancho máximo de seguridad para el contenido cinematográfico (4K).
  static const double maxContentWidth = 3840.0;
}
