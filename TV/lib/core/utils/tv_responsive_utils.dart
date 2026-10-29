import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Senior TV Optimization: Plataforma independiente de AurisTV.
/// Este utilitario gestiona el responsive EXCLUSIVO para televisores (10ft UI).
///
/// Los valores base (los indicados como `prime*`) se extrajeron midiendo la UI
/// real de Prime Video TV v6.24.12 sobre un panel 1920x1080. Ver evidencia en
/// `TV/.artifacts/primevideo_ui/PRIMEVIDEO_UI_MEDIDAS.md`.
class TVResponsiveUtils {
  /// Rejilla de diseño de referencia: Prime Video declara explícitamente
  /// `imageResolution 1920x1080` en `assets/ignite-assets.tar/lua/appBootstrap.js`
  /// y escala por razón de resolución, así que aquí se replica ese modelo.
  static const double designWidth = 1920.0;

  // ── Constantes medidas en Prime Video TV (a 1920x1080) ────────────────────
  /// Margen izquierdo de todo el contenido. Medido 144 px; coincide con la
  /// constante estática `errorMessageMarginLeft: 144` de appBootstrap.js.
  static const double primeLeftMargin = 144.0;
  /// Pill del item de nav enfocado. Medido 88 x 48 en (144, 54).
  static const double primeNavPillHeight = 48.0;
  /// Altura total del bloque del hero (el arte termina en y ~= 610-620).
  static const double primeHeroHeight = 620.0;
  /// Póster vertical de fila. Medido 384 x 573 (2:3).
  static const double primePortraitCard = 384.0;
  /// Tarjeta horizontal de fila. Medido 384 x 216-230 (16:9).
  static const double primeLandscapeCard = 384.0;
  /// Tarjeta Top 10. Medida 335 x 189 (16:9).
  static const double primeTop10CardWidth = 335.0;
  /// Separación entre tarjetas dentro de una fila. Medida 32-33.
  static const double primeCardGap = 32.0;
  /// Fuente del título de sección. Banda de glifos medida 20-24 px.
  static const double primeSectionTitleFont = 26.0;
  /// Título de sección -> primera tarjeta. Medido 16.
  static const double primeSectionTitleGap = 16.0;
  /// Última tarjeta -> título de sección siguiente. Medido 25-32.
  static const double primeSectionBottomGap = 32.0;
  /// Tecla del teclado en pantalla del buscador. Medida 66 x 66, paso 66.
  static const double primeSearchKeySize = 66.0;
  /// Tarjeta de resultados de búsqueda. Medida 336 x 189.
  static const double primeSearchCardWidth = 336.0;
  /// Panel izquierdo (teclado) -> panel de resultados. Medido x = 612.
  static const double primeSearchResultsLeft = 612.0;

  /// Siempre es nativo en TV (Android TV)
  static bool get isNative => !kIsWeb;

  /// La navegación en TV nunca es táctil (D-pad Focus)
  static bool isTactic(BuildContext context) => false;

  /// Siempre false en el proyecto TV
  static bool isMobile(BuildContext context) => false;
  static bool isTablet(BuildContext context) => false;
  static bool isDesktop(BuildContext context) => true; // Se comporta como un desktop ultra-grande
  static bool isTV(BuildContext context) => true;

  /// Escala lineal de la rejilla de diseño (modelo Prime Video).
  /// Un valor medido a 1920 px se reproduce idéntico en 1080p y crece
  /// proporcionalmente en 720p / 4K.
  static double grid(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    final double scale = (width / designWidth).clamp(0.5, 2.5);
    return size * scale;
  }

  /// Margen horizontal estándar para televisores (Safe Area optimizado).
  /// Medido en Prime: 144 px (7,5 %) frente a los 57,6 px (3 %) anteriores.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 2200) return (width - 2000) / 2 + 32.0;
    return grid(context, primeLeftMargin).clamp(24.0, 480.0);
  }

  /// Altura del topbar fijo (misma fórmula que usa el home para su navbar):
  /// es la referencia para anclar las secciones justo debajo al navegar.
  /// Prime coloca el pill en y=54 con 48 px de alto (base y ~= 102).
  ///
  /// **Usa `grid()`, no `sp()`**: en el dispositivo de prueba (320 dpi =>
  /// ancho lógico 960) `sp()` cae en el bucket 0.85 y un valor 108 medido se
  /// pintaba a 184 px físicos. `grid()` reproduce el px medido exacto.
  static double topBarHeight(BuildContext context) => grid(context, 108);

  /// Altura del pill de un item de nav (medida 48 en Prime).
  static double navPillHeight(BuildContext context) => grid(context, primeNavPillHeight);

  /// Separación entre tarjetas dentro de una fila (medida 32 en Prime).
  static double cardGap(BuildContext context) => grid(context, primeCardGap);

  /// Título de sección -> primera tarjeta (medida 16 en Prime).
  static double sectionTitleGap(BuildContext context) => grid(context, primeSectionTitleGap);

  /// Última tarjeta -> título de sección siguiente (medida 32 en Prime).
  static double sectionBottomGap(BuildContext context) => grid(context, primeSectionBottomGap);

  /// ── Buscador (medidas del overlay de Prime Video) ──────────────────────────
  /// Ancho del panel izquierdo que aloja el teclado: exactamente 6 teclas de
  /// 66 px (medido x 144..540 => 396 px).
  static double searchKeyboardPanelWidth(BuildContext context) =>
      6 * searchKeySize(context);

  /// Paso/size de una tecla del teclado en pantalla (medido 66 x 66).
  static double searchKeySize(BuildContext context) => grid(context, primeSearchKeySize);

  /// X donde arranca el panel de resultados (medido 612).
  static double searchResultsLeft(BuildContext context) => grid(context, primeSearchResultsLeft);

  /// Ancho de tarjeta de resultado (medido 336 x 189, 16:9).
  static double searchResultCardWidth(BuildContext context) =>
      grid(context, primeSearchCardWidth);

  /// Alto de tarjeta de resultado (medido 189).
  static double searchResultCardHeight(BuildContext context) =>
      (searchResultCardWidth(context) / (16 / 9)).roundToDouble();

  /// Escalado de fuentes y componentes para TV (10ft UI)
  /// Optimizado con resolución por buckets (720p, 1080p, 4K) para evitar elementos gigantes.
  static double sp(BuildContext context, double size) {
    final double width = MediaQuery.of(context).size.width;
    double tvScale;
    if (width <= 1280) {
      tvScale = 0.85; // 720p
    } else if (width <= 1920) {
      tvScale = 1.0;  // 1080p estándar
    } else if (width <= 3840) {
      tvScale = 1.15; // 4K / UHD (controlado)
    } else {
      tvScale = 1.3;  // 8K
    }
    return size * tvScale;
  }

  /// Ancho de póster vertical de fila. Prime Video usa 384 px (2:3) a 1080p,
  /// unas 4,3 tarjetas visibles por fila; el valor anterior era 140 px.
  static double posterWidth(BuildContext context) {
    return grid(context, primePortraitCard);
  }

  /// Altura proporcional (2:3) -> 576 px a 1080p (medido 573).
  static double posterHeight(BuildContext context) {
    return (posterWidth(context) * 1.5).roundToDouble();
  }

  /// Ancho de póster grande (Large Poster Card) para TV.
  /// No existe un equivalente estático en Prime: allí la tarjeta enfocada se
  /// reencuadra a hero (medido 1037 x 590). Auris conserva un formato
  /// editorial propio, escalado como póster x1.25 sobre la rejilla medida.
  static double largePosterWidth(BuildContext context) {
    return grid(context, primePortraitCard * 0.95);
  }

  /// Altura proporcional de póster grande (2:3) para TV
  static double largePosterHeight(BuildContext context) {
    return (largePosterWidth(context) * 1.5).roundToDouble();
  }

  /// Altura de fila de póster grande para TV
  static double largePosterRowHeight(BuildContext context, {bool hasInfo = false}) {
    final double posterH = largePosterHeight(context);
    if (!hasInfo) return posterH + 32.0; // Generous buffer for focus zoom and glow
    return posterH + 70.0;
  }

  /// Altura de la fila de posters incluyendo títulos
  static double rowHeight(BuildContext context, {bool hasInfo = false}) {
    final double posterH = posterHeight(context);
    if (!hasInfo) return posterH + 32.0; // buffer para el anillo/zoom de foco
    return posterH + 70.0;
  }

  /// Ancho de banners (16:9) de fila. Medido 384 px (216 de alto) a 1080p.
  static double bannerWidth(BuildContext context) {
    return grid(context, primeLandscapeCard);
  }

  /// Altura de banner
  static double bannerHeight(BuildContext context) {
    return (bannerWidth(context) / (16 / 9)).roundToDouble();
  }

  /// Ancho de tarjeta de la fila Top 10 (medido 335 px a 1080p).
  /// Prime reserva ~110 px para la cifra gigante antes de cada tarjeta.
  static double top10CardWidth(BuildContext context) {
    return grid(context, primeTop10CardWidth);
  }

  /// Altura de tarjeta de la fila Top 10 (medida 189 px a 1080p).
  static double top10CardHeight(BuildContext context) {
    return (top10CardWidth(context) / (16 / 9)).roundToDouble();
  }

  /// Altura de la fila de banners
  /// [hasSubtitle] - Si es true, reserva espacio para texto inferior.
  /// [subtitleLines] - 2 cuando hay segunda línea ("Quedan X" bajo "T1:E7 . Título").
  static double bannerRowHeight(BuildContext context,
      {bool hasSubtitle = true, int subtitleLines = 1}) {
    final double extraSpace = hasSubtitle
        ? grid(context, 24) + (subtitleLines > 1 ? (grid(context, 4) + grid(context, 24)) : 0)
        : 0;
    return bannerHeight(context) + extraSpace + grid(context, 12);
  }

  /// Títulos de sección. Medido en Prime: banda de glifos 20-24 px => 26-28 px.
  static double rowTitleFontSize(BuildContext context) {
    return grid(context, primeSectionTitleFont);
  }

  /// Etiquetas del nav superior (medido ≈ 26-28 en Prime, mismo cuerpo que
  /// los títulos de sección).
  static double navLabelFontSize(BuildContext context) {
    return grid(context, primeSectionTitleFont);
  }

  /// Títulos dentro de tarjetas (banda de glifos ≈ 20-24 en Prime =>
  /// cuerpo ≈ 24).
  static double bannerTitleFontSize(BuildContext context) {
    return grid(context, 24.0);
  }

  /// Escala vertical del bloque del hero: Prime mide ≈620 px donde Auris
  /// pintaba 800 px (aspecto 2.4). Todos los elementos interiores se
  /// reducen con la misma razón para conservar la composición.
  static const double heroHeightRatio = primeHeroHeight / 800.0; // ≈ 0.775

  /// AspectRatio cinematográfico para el Hero en TV.
  /// Medido en Prime: 1920 / 620 ≈ 3.10 (antes 2.4 => 800 px).
  static double heroAspectRatio(BuildContext context) {
    return designWidth / primeHeroHeight;
  }

  /// Logo en el Hero (120 px originales escalados con el hero)
  static double heroLogoHeight(BuildContext context) {
    return grid(context, 120.0 * heroHeightRatio); // ≈ 93
  }

  /// Sinopsis en el Hero. El 14 sp original era ilegible a 10 ft; se sube al
  /// cuerpo que usa Prime para su texto (26) medido a 1080p.
  static double heroSynopsisFontSize(BuildContext context) {
    return grid(context, 26.0);
  }

  /// Título en el Hero cuando no hay logo (42 escalados con el hero ≈ 33)
  static double heroTitleFontSize(BuildContext context) {
    return grid(context, 42.0 * heroHeightRatio); // ≈ 33
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
