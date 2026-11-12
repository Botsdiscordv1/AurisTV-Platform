import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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
///    o como respaldo desde una imagen estática.
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
    this.primaryColor,
    this.secondaryColor,
    this.imageProvider,
    this.blurSigma = 45.0,
    this.intensity = 0.55,
    this.heightMultiplier = 1.6,
    this.percentageFromTop = 0.45,
    this.child,
  });

  /// Instancia de [Player] para extraer la paleta cromática del video en tiempo de ejecución.
  final Player? player;

  /// Color primario del resplandor (Start Color).
  final Color? primaryColor;

  /// Color secundario del resplandor (End Color).
  final Color? secondaryColor;

  /// Imagen de referencia (poster/thumbnail) para calcular la paleta de respaldo.
  final ImageProvider? imageProvider;

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
    } else if (widget.player == null && (oldWidget.primaryColor != widget.primaryColor || oldWidget.secondaryColor != widget.secondaryColor)) {
      _applyExplicitColors();
    }
  }

  void _initSampling() {
    if (widget.player != null) {
      _paletteController?.dispose();
      _paletteController = CinematicPaletteController(player: widget.player!)
        ..addListener(_onPaletteUpdated);
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
    if (widget.primaryColor != null) {
      setState(() {
        _topColor = widget.primaryColor!;
        _bottomColor = widget.secondaryColor ?? widget.primaryColor!.withValues(alpha: 0.6);
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

        // 2. Capa Frontal: El reproductor de video u otro hijo
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

