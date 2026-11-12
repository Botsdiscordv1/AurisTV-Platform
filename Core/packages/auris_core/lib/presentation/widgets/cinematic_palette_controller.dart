import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Controlador que captura fotogramas del video en tiempo de ejecución
/// y calcula la paleta cromática dual (startColor, endColor) al estilo
/// exacto de YouTube (`CinematicTwoColorGradient`).
class CinematicPaletteController extends ChangeNotifier {
  CinematicPaletteController({
    this.sampleInterval = const Duration(seconds: 2),
    this.player,
  }) {
    if (player != null) {
      startSampling(player!);
    }
  }

  /// Intervalo periódico de muestreo del video en reproducción (YouTube muestrea entre 1s - 3s).
  final Duration sampleInterval;

  Player? player;
  Timer? _sampleTimer;
  bool _isProcessing = false;

  Color _startColor = const Color(0xFF1E2A38);
  Color _endColor = const Color(0xFF0F151C);

  /// Color primario superior del gradiente (Start Color).
  Color get startColor => _startColor;

  /// Color complementario inferior del gradiente (End Color).
  Color get endColor => _endColor;

  /// Inicia el muestreo en vivo del reproductor.
  void startSampling(Player targetPlayer) {
    player = targetPlayer;
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(sampleInterval, (_) => _captureAndExtract());
    // Muestreo inicial inmediato
    _captureAndExtract();
  }

  /// Detiene el muestreo en vivo.
  void stopSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }

  @override
  void dispose() {
    stopSampling();
    super.dispose();
  }

  Future<void> _captureAndExtract() async {
    final p = player;
    if (p == null || !p.state.playing || _isProcessing) return;

    _isProcessing = true;
    try {
      // Capturar screenshot a baja resolución en JPEG (ultra rápido y bajo consumo de CPU)
      final Uint8List? bytes = await p.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) return;

      final pair = await compute(_extractDualDominantColors, bytes);
      if (pair != null) {
        _startColor = pair.$1;
        _endColor = pair.$2;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CinematicPaletteController] Error en muestreo: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Asigna colores manuales o de fallback (ej: desde un poster/banner).
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
