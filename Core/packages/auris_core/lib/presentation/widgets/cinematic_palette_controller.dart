import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';

/// Controlador que captura fotogramas del video en tiempo de ejecución
/// y calcula la paleta cromática dual (startColor, endColor) al estilo
/// exacto de YouTube (`CinematicTwoColorGradient`).
///
/// **Estrategia de captura (en orden de prioridad):**
/// 1. `RepaintBoundary` via [videoKey] — funciona con SurfaceView / hardware acceleration.
/// 2. `player.screenshot()` — solo funciona cuando el video renderiza en textura CPU-accesible.
class CinematicPaletteController extends ChangeNotifier {
  CinematicPaletteController({
    this.sampleInterval = const Duration(seconds: 2),
    this.player,
    this.videoKey,
  }) {
    if (player != null) {
      startSampling(player!);
    }
  }

  /// Intervalo periódico de muestreo del video en reproducción (YouTube muestrea entre 1s - 3s).
  final Duration sampleInterval;

  Player? player;

  /// GlobalKey del widget de video — permite capturar el frame renderizado
  /// directamente desde el árbol de Flutter (funciona con hardware acceleration).
  final GlobalKey? videoKey;

  Timer? _sampleTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _posSub;
  bool _isProcessing = false;
  bool _hasExtractedVideoFrame = false;

  Color _startColor = Colors.transparent;
  Color _endColor = Colors.transparent;

  /// Indica si ya se extrajo al menos un fotograma real del video.
  bool get hasExtractedVideoFrame => _hasExtractedVideoFrame;

  /// Color primario superior del gradiente (Start Color).
  Color get startColor => _startColor;

  /// Color complementario inferior del gradiente (End Color).
  Color get endColor => _endColor;

  /// Inicia el muestreo en vivo del reproductor.
  void startSampling(Player targetPlayer) {
    player = targetPlayer;
    _sampleTimer?.cancel();
    _playingSub?.cancel();
    _posSub?.cancel();

    // Reaccionar inmediatamente cuando empiece a reproducir o cambie de posición/frame
    _playingSub = targetPlayer.stream.playing.listen((playing) {
      if (playing) _captureAndExtract();
    });

    _posSub = targetPlayer.stream.position.listen((pos) {
      if (!_hasExtractedVideoFrame && pos.inMilliseconds > 0) {
        _captureAndExtract();
      }
    });

    _sampleTimer = Timer.periodic(sampleInterval, (_) => _captureAndExtract());
    _captureAndExtract();
  }

  /// Detiene el muestreo en vivo.
  void stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _playingSub?.cancel();
    _playingSub = null;
    _posSub?.cancel();
    _posSub = null;
  }

  @override
  void dispose() {
    stopSampling();
    super.dispose();
  }

  Future<void> _captureAndExtract() async {
    final p = player;
    // Si no está reproduciendo o no hay video aún, no intentar extraer durante el buffering/carga inicial
    if (p == null || !p.state.playing || p.state.position.inMilliseconds == 0) return;
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      Uint8List? bytes;

      // ── Estrategia 1: RepaintBoundary (funciona con SurfaceView / GPU) ──
      bytes = await _captureViaRepaintBoundary();

      // ── Estrategia 2: player.screenshot() (funciona con textura CPU) ──
      if (bytes == null || bytes.isEmpty) {
        final p = player;
        if (p != null) {
          try {
            bytes = await p.screenshot(format: 'image/jpeg');
          } catch (_) {
            try {
              bytes = await p.screenshot(format: null);
            } catch (_) {}
          }
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return;
      }

      final pair = await compute(_extractDualDominantColors, bytes);
      if (pair != null) {
        _startColor = pair.$1;
        _endColor = pair.$2;
        _hasExtractedVideoFrame = true;
        debugPrint('[CinematicPaletteController] Colores: start=$_startColor end=$_endColor');
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[CinematicPaletteController] Error en muestreo: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  /// Captura el widget referenciado por [videoKey] via RepaintBoundary.
  /// Escala a 64x36 para análisis rápido. Devuelve bytes PNG o null.
  Future<Uint8List?> _captureViaRepaintBoundary() async {
    try {
      final key = videoKey;
      if (key == null) return null;
      final context = key.currentContext;
      if (context == null) return null;

      // Buscar el RenderRepaintBoundary más cercano
      RenderRepaintBoundary? boundary;
      context.visitAncestorElements((element) {
        final ro = element.renderObject;
        if (ro is RenderRepaintBoundary) {
          boundary = ro;
          return false; // detener
        }
        return true;
      });

      // Si no encontramos antecesor, intentar desde el propio renderObject
      boundary ??= () {
        final ro = context.findRenderObject();
        if (ro is RenderRepaintBoundary) return ro;
        return null;
      }();

      if (boundary == null || boundary!.debugNeedsPaint) return null;

      // Capturar a pixelRatio bajo para ser rápido
      final ui.Image image = await boundary!.toImage(pixelRatio: 0.1);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[CinematicPaletteController] RepaintBoundary captura falló: $e');
      return null;
    }
  }

  /// Asigna colores manuales (ej: desde un poster/banner).
  void setColors(Color start, Color end) {
    _startColor = start;
    _endColor = end;
    notifyListeners();
  }
}

/// Función de nivel superior ejecutada en un Isolate secundario para no bloquear el hilo de UI.
/// Decodifica la imagen en crudo y extrae dos colores representativos:
/// 1. `startColor`: Zona media/superior del fotograma.
/// 2. `endColor`: Zona media/inferior del fotograma.
Future<(Color, Color)?> _extractDualDominantColors(Uint8List jpegBytes) async {
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      jpegBytes,
      targetWidth: 64, // Redimensionar a miniatura 64x36 para análisis instantáneo
      targetHeight: 36,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return null;

    final Uint8List pixels = byteData.buffer.asUint8List();
    final int width = image.width;
    final int height = image.height;
    final int halfHeight = height ~/ 2;

    int rTop = 0, gTop = 0, bTop = 0, countTop = 0;
    int rBottom = 0, gBottom = 0, bBottom = 0, countBottom = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = (y * width + x) * 4;
        final int r = pixels[index];
        final int g = pixels[index + 1];
        final int b = pixels[index + 2];

        // Ignorar píxeles excesivamente negros (bandas negras letterbox)
        final int brightness = (r + g + b) ~/ 3;
        if (brightness < 18) continue;

        if (y < halfHeight) {
          rTop += r;
          gTop += g;
          bTop += b;
          countTop++;
        } else {
          rBottom += r;
          gBottom += g;
          bBottom += b;
          countBottom++;
        }
      }
    }

    final Color topColor = countTop > 0
        ? Color.fromARGB(255, rTop ~/ countTop, gTop ~/ countTop, bTop ~/ countTop)
        : const Color(0xFF1E2A38);

    final Color bottomColor = countBottom > 0
        ? Color.fromARGB(255, rBottom ~/ countBottom, gBottom ~/ countBottom, bBottom ~/ countBottom)
        : const Color(0xFF0F151C);

    return (topColor, bottomColor);
  } catch (_) {
    return null;
  }
}
