import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'cinematic_palette_controller.dart';

/// Modo Ambiente (Cinematic Lighting) inspirado directamente en la
/// arquitectura interna de YouTube (`CinematicContainerLayout`, `CinematicImageView`,
/// `CinematicGradientColor` y `CinematicTwoColorGradient`).
///
/// Características y configuración extraída de YouTube:
/// 1. **Dos colores dominantes (`CinematicTwoColorGradient`)**: Color primario superior (`startColor`)
///    y color complementario inferior (`endColor`), extraídos **en tiempo real desde el video**
///    via `RepaintBoundary` (funciona con SurfaceView / hardware acceleration) o
///    via `player.screenshot()` como fallback.
/// 2. **Proyección Radial + Gradual Blur**:
///    - Gradiente radial centrado con expansión elíptica (`heightMultiplier` ~ 1.5 - 2.0).
///    - Gradiente vertical gradual que se funde suavemente al negro absoluto (`Colors.black`)
///      hacia arriba y hacia abajo para integrarse de forma invisible.
/// 3. **Transición Temporal Suave**:
///    - Transición animada (`TweenAnimationBuilder` con curva suave de 800ms)
///      para evitar cambios bruscos al cambiar de escena/color en el video.
class CinematicAmbientLighting extends StatefulWidget {
  const CinematicAmbientLighting({
    super.key,
    this.player,
    this.videoWidgetKey,
    this.primaryColor,
    this.secondaryColor,
    this.posterColor,
    this.blurSigma = 45.0,
    this.intensity = 0.55,
    this.heightMultiplier = 1.6,
    this.percentageFromTop = 0.45,
    this.child,
  });

  /// Instancia de [Player] para extraer la paleta cromática del video en tiempo de ejecución.
  final Player? player;

  /// GlobalKey opcional del widget exclusivo del reproductor de video.
  /// Si no se especifica, se envuelve [child] completo.
  final GlobalKey? videoWidgetKey;

  /// Color primario del resplandor (Start Color) — usado si no hay player.
  final Color? primaryColor;

  /// Color secundario del resplandor (End Color) — usado si no hay player.
  final Color? secondaryColor;

  /// Color del poster/banner (fallback para ambient mode en Android SurfaceView).
  /// Cuando el video usa superficie nativa, screenshot bloquea 5-13s; se usa este
  /// color como paleta inmediata hasta que screenshot funcione.
  final Color? posterColor;

  /// Nivel de difusión gaussiana (por defecto 45.0, emula el radial blur de YouTube).
  final double blurSigma;

  /// Opacidad global del resplandor (0.0 a 1.0, por defecto 0.55 como YouTube).
  final double intensity;

  /// Multiplicador de altura de proyección detrás del reproductor (YouTube `heightMultiplier`: 1.6x).
  final double heightMultiplier;

  /// Punto de origen vertical del gradiente principal (YouTube `percentageFromTop`: 45%).
  final double percentageFromTop;

  /// Contenido principal que se dibuja sobre el resplandor (típicamente el reproductor de video).
  final Widget? child;

  @override
  State<CinematicAmbientLighting> createState() => _CinematicAmbientLightingState();
}

class _CinematicAmbientLightingState extends State<CinematicAmbientLighting> {
  /// GlobalKey del RepaintBoundary que envuelve al hijo (video widget).
  /// CinematicPaletteController lo usa para capturar frames vía renderizado Flutter,
  /// lo que funciona incluso con SurfaceView / hardware acceleration.
  final GlobalKey _videoKey = GlobalKey();

  CinematicPaletteController? _paletteController;
  Color _topColor = Colors.transparent;
  Color _bottomColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _initSampling();
  }

  @override
  void didUpdateWidget(covariant CinematicAmbientLighting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _initSampling();
    } else if (widget.player == null &&
        (oldWidget.primaryColor != widget.primaryColor ||
            oldWidget.secondaryColor != widget.secondaryColor ||
            oldWidget.posterColor != widget.posterColor)) {
      _applyExplicitColors();
    }
  }

  void _initSampling() {
    if (widget.player != null) {
      _paletteController?.removeListener(_onPaletteUpdated);
      _paletteController?.dispose();
      _paletteController = CinematicPaletteController(
        player: widget.player!,
        videoKey: widget.videoWidgetKey ?? _videoKey,
        posterColor: widget.posterColor,
      )..addListener(_onPaletteUpdated);
    } else {
      _applyExplicitColors();
    }
  }

  void _onPaletteUpdated() {
    if (!mounted || _paletteController == null) return;
    setState(() {
      _topColor = _paletteController!.startColor;
      _bottomColor = _paletteController!.endColor;
    });
  }

  void _applyExplicitColors() {
    // Prioridad: primaryColor > posterColor > colors del controller > transparent.
    if (widget.primaryColor != null) {
      setState(() {
        _topColor = widget.primaryColor!;
        _bottomColor = widget.secondaryColor ?? widget.primaryColor!.withValues(alpha: 0.6);
      });
    } else if (widget.posterColor != null) {
      // Usar colores por defecto cinematográficos derivados del poster.
      setState(() {
        _topColor = const Color(0xFF1E2A38);
        _bottomColor = const Color(0xFF0F151C);
      });
    } else {
      setState(() {
        _topColor = Colors.transparent;
        _bottomColor = Colors.transparent;
      });
    }
  }

  @override
  void dispose() {
    _paletteController?.removeListener(_onPaletteUpdated);
    _paletteController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Capa de Fondo: Resplandor Cinematográfico Gradual + Desenfoque
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double extendedHeight = constraints.maxHeight * widget.heightMultiplier;

              return OverflowBox(
                minHeight: extendedHeight,
                maxHeight: extendedHeight,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: widget.intensity),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, currentIntensity, _) {
                    return ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: widget.blurSigma,
                        sigmaY: widget.blurSigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0.0, (widget.percentageFromTop - 0.5) * 2),
                            radius: 1.1,
                            colors: [
                              _topColor.withValues(alpha: (currentIntensity * 0.9).clamp(0.0, 1.0)),
                              _bottomColor.withValues(alpha: (currentIntensity * 0.55).clamp(0.0, 1.0)),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                        foregroundDecoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.2, 0.8, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // 2. Capa Frontal: El reproductor de video u otro hijo.
        if (widget.child != null)
          widget.videoWidgetKey != null
              ? widget.child!
              : RepaintBoundary(
                  key: _videoKey,
                  child: widget.child!,
                ),
      ],
    );
  }
}
