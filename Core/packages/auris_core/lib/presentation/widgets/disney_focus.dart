import 'package:flutter/material.dart';

/// Tokens de foco/hover extraídos del carrusel "Deportes" del hub ESPN de
/// Disney+ (evidencia REA: DOM + CSS reales, 2026-10-26, viewport 1920x1080).
///
/// Reglas CSS observadas sobre la tarjeta (`<a data-testid="event-card">`):
///
/// ```text
/// rounded-small                              -> border-radius: 8px
/// transition-[transform,box-shadow]          -> propiedades animadas
/// duration-300                               -> transition-duration: .3s
/// ease-out                                   -> cubic-bezier(0,0,.2,1)
/// hover:scale-[1.03]                         -> escala activa
/// after:outline after:outline-4              -> anillo de 4px
/// after:outline-offset-4                     -> separado 4px del borde
/// after:outline-transparent
/// hover:after:outline-onSurface              -> --colorsOnSurface = #FAFAFA
/// after:transition-all after:duration-300 after:ease-out
/// md:hover:shadow-[1px -20px 14px -18px rgb(0 0 0/80%),
///                  2px  12px 13px  -3px rgb(0 0 0/72%)]
/// ```
///
/// Estas constantes son la **única** fuente de verdad del tratamiento Disney+
/// en el frontend: las usan las tarjetas *wide* (16:9), las tarjetas *poster*
/// (2:3) y el carrusel de marcas deportivas.
class DisneyFocusTokens {
  DisneyFocusTokens._();

  /// `rounded-small` — radio de la tarjeta y de la esquina interior del anillo.
  static const double radius = 8.0;

  /// `outline-4` — grosor del anillo de foco.
  static const double ringWidth = 4.0;

  /// `outline-offset-4` — hueco transparente entre tarjeta y anillo.
  static const double ringOffset = 4.0;

  /// Distancia del borde de la tarjeta al borde exterior del anillo
  /// (= ringWidth + ringOffset = 8px). Se usa como inset negativo.
  static const double ringInset = ringWidth + ringOffset;

  /// `outline-onSurface` en tema oscuro: `hsl(0,0%,98%)`.
  static const Color ringColor = Color(0xFFFAFAFA);

  /// `hover:scale-[1.03]`.
  static const double scale = 1.03;

  /// `duration-300`.
  static const Duration duration = Duration(milliseconds: 300);

  /// `.ease-out` de Tailwind = `cubic-bezier(0,0,.2,1)`.
  /// No confundir con `Curves.easeOut` de Flutter (`cubic-bezier(0,0,.58,1)`).
  static const Cubic curve = Cubic(0.0, 0.0, 0.2, 1.0);

  /// `md:hover:shadow-[…]` — sombra dual, solo aplica en pantallas ≥768px.
  static const List<BoxShadow> dualShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xCC000000), // rgb(0 0 0/80%)
      offset: Offset(1, -20),
      blurRadius: 14,
      spreadRadius: -18,
    ),
    BoxShadow(
      color: Color(0xB8000000), // rgb(0 0 0/72%)
      offset: Offset(2, 12),
      blurRadius: 13,
      spreadRadius: -3,
    ),
  ];

  /// Umbral `md` de Tailwind para la sombra dual.
  static const double wideBreakpoint = 768;

  /// Sombra dual si el viewport es ≥768px (`md:`), `null` en el resto —
  /// igual que Disney+, que solo declara la sombra con prefijo `md:hover:`.
  static List<BoxShadow>? shadowFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint ? dualShadow : null;

  /// Radio exterior del anillo: `rounded-small` + offset + grosor.
  /// (En CSS el outline escalona su radio; en Flutter se declara el radio
  /// exterior y el borde de 4px deja el interior en radius + ringOffset.)
  static double ringRadius([double cardRadius = radius]) =>
      cardRadius + ringOffset + ringWidth;

  /// Holgura vertical (px por lado) que una fila debe reservar para que ni el
  /// `scale 1.03` ni el anillo a 8px se recorten ni pisen el título de sección.
  static double allowanceFor(double cardExtent) =>
      cardExtent * (scale - 1) / 2 + ringInset;
}

/// Aplica a [child] el tratamiento de foco/hover de Disney+: escala
/// `1.0 -> 1.03`, sombra dual (≥768px) y anillo `outline-4 outline-offset-4`
/// en `--colorsOnSurface`, todo con transición de **300ms** y curva
/// `cubic-bezier(0,0,.2,1)`.
///
/// * [child] debe venir **ya recortado** con `ClipRRect` a
///   [DisneyFocusTokens.radius] (8px), como hace Disney+ con `rounded-small`.
/// * El anillo se pinta **fuera** de la tarjeta, por lo que todas las filas que
///   usan este shell deben tener `clipBehavior: Clip.none` (ya lo tienen) y
///   reserva vertical ≥ [DisneyFocusTokens.allowanceFor].
/// * Al vivir dentro de `AnimatedScale`, anillo, escala y sombra se mueven como
///   una sola unidad, igual que el `::after` sobre el elemento transformado.
class DisneyFocusShell extends StatelessWidget {
  /// `true` cuando la tarjeta está enfocada u hovered.
  final bool active;

  /// Contenido de la tarjeta, recortado a `radius`.
  final Widget child;

  /// Radio de la tarjeta. Por defecto [DisneyFocusTokens.radius].
  final double radius;

  /// Sombra mientras está activa. Pasar `null` para no proyectar ninguna
  /// (p. ej. en pantallas <768px, donde Disney+ tampoco la dibuja).
  final List<BoxShadow>? activeShadow;

  /// Permite desactivar el anillo (filas que dibujan su propio marco).
  final bool showRing;

  /// Color del anillo. Por defecto [DisneyFocusTokens.ringColor] (#FAFAFA);
  /// se expone para que plataformas que ya declaren su color (TV) lo pasen.
  final Color ringColor;

  const DisneyFocusShell({
    super.key,
    required this.active,
    required this.child,
    this.radius = DisneyFocusTokens.radius,
    this.activeShadow,
    this.showRing = true,
    this.ringColor = DisneyFocusTokens.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? DisneyFocusTokens.scale : 1.0,
      duration: DisneyFocusTokens.duration,
      curve: DisneyFocusTokens.curve,
      alignment: Alignment.center,
      child: Stack(
        // El anillo sobresale 8px: sin Clip.none quedaría cortado.
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: DisneyFocusTokens.duration,
            curve: DisneyFocusTokens.curve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: active ? (activeShadow ?? const <BoxShadow>[]) : null,
            ),
            child: child,
          ),
          if (showRing)
            Positioned(
              left: -DisneyFocusTokens.ringInset,
              top: -DisneyFocusTokens.ringInset,
              right: -DisneyFocusTokens.ringInset,
              bottom: -DisneyFocusTokens.ringInset,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: active ? 1.0 : 0.0,
                  duration: DisneyFocusTokens.duration,
                  curve: DisneyFocusTokens.curve,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ringColor,
                        width: DisneyFocusTokens.ringWidth,
                      ),
                      borderRadius:
                          BorderRadius.circular(DisneyFocusTokens.ringRadius(radius)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
