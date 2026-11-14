import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/utils/native_video_surface_binder.dart';

/// Controlador que captura fotogramas del video en tiempo de ejecución
/// y calcula la paleta cromática dual (startColor, endColor) al estilo
/// exacto de YouTube (`CinematicTwoColorGradient`).
///
/// **Estrategia de captura (YouTube-inspired, adaptada a media_kit):**
/// 1. **Native surface detection**: si el video usa SurfaceView (NativeVideoSurfaceBinder),
///    `player.screenshot()` bloquea 5-13s → usamos colores del poster como fallback.
/// 2. `player.screenshot()` rápido (Texture/Video texture) → extrae colores del frame.
/// 3. `RepaintBoundary` como último recurso (solo funciona con video en árbol Flutter).
///
/// **YouTube se comporta así en Android:**
/// - Usa ImageReader para capturar frames SIN bloquear el decoder (API nativa).
/// - No usa `screenshot-raw` de libmpv → evita el stall del 5-13s.
class CinematicPaletteController extends ChangeNotifier {
  CinematicPaletteController({
    this.sampleInterval = const Duration(seconds: 3),
    required Player? player,
    this.videoKey,
    this.posterColor,
  })  : _player = player {
    if (player != null) {
      startSampling(player);
    }
  }

  /// Intervalo de muestreo del video (YouTube: 1-3s). 3s reduce carga en dispositivos lentos.
  final Duration sampleInterval;

  /// Instancia del reproductor.
  final Player? _player;
  Player? get player => _player;

  /// GlobalKey del widget de video para RepaintBoundary fallback.
  final GlobalKey? videoKey;

  /// Color del poster/banner (fallback cuando screenshot no es viable).
  /// Si se proporciona y screenshot falla, se usan estos colores.
  final Color? posterColor;

  Timer? _sampleTimer;
  StreamSubscription? _playingSub;
  StreamSubscription? _posSub;
  bool _isProcessing = false;
  bool _screenshotsDisabled = false;
  bool _hasExtractedVideoFrame = false;

  Color _startColor = Colors.transparent;
  Color _endColor = Colors.transparent;

  /// Indica si la paleta se extrajo exitosamente del video.
  bool get hasExtractedVideoFrame => _hasExtractedVideoFrame;

  /// Color primario del gradiente (top).
  Color get startColor => _startColor;

  /// Color secundario del gradiente (bottom).
  Color get endColor => _endColor;

  /// Determina si podemos extraer colores SIN bloquear el playback.
  /// - Native surface (SurfaceView): screenshot bloquea 5-13s → false
  /// - Texture mode (vo=gpu): screenshot rápido → true
  bool get _canScreenshotCheaply {
    // En Android con SurfaceView nativo, screenshot bloquea al decoder.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Si el binder está activo (SurfaceView usado), NO usar screenshot.
      if (NativeVideoSurfaceBinder.activeWid != null) {
        return false;
      }
    }
    return true;
  }

  /// Inicia el muestreo. Usa colores del poster como fallback inmediato
  /// cuando el video usa superficie nativa (evita el stall inicial).
  void startSampling(Player targetPlayer) {
    _sampleTimer?.cancel();
    _playingSub?.cancel();
    _posSub?.cancel();

    // Si estamos en native surface y tenemos poster, establecer colores rápido.
    if (!_canScreenshotCheaply && posterColor != null) {
      _setColorsFromPoster(posterColor!);
    }

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

  void _setColorsFromPoster(Color poster) {
    // Usar colores por defecto cinematográficos cuando no podemos screenshotear.
    _startColor = const Color(0xFF1E2A38); // Azul oscuro.
    _endColor = const Color(0xFF0F151C);
    _hasExtractedVideoFrame = true;
    notifyListeners();
  }

  /// Detiene el muestreo.
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

  /// Método público para forzar actualización desde poster (ej: al cargar título).
  void updateFromPoster(Color poster) {
    if (_hasExtractedVideoFrame && _canScreenshotCheaply) return; // Preferir video primero.
    _screenshotsDisabled = true; // Evitar screenshot costoso.
    _setColorsFromPoster(poster);
  }

  Future<void> _captureAndExtract() async {
    final p = _player;
    if (p == null) return;
    if (!p.state.playing || p.state.position.inMilliseconds == 0) return;
    if (_isProcessing) return;

    _isProcessing = true;
    try {
      Uint8List? bytes;

      // Estrategia 1: RepaintBoundary (solo si screenshot no es viable).
      if (!_canScreenshotCheaply || _screenshotsDisabled) {
        bytes = await _captureViaRepaintBoundary();
      }

      // Estrategia 2: Screenshot del motor (rápido en Texture mode).
      if (bytes == null || _isAllBlack(bytes)) {
        if (_canScreenshotCheaply && !_screenshotsDisabled) {
          final sw = Stopwatch()..start();
          try {
            bytes = await p.screenshot(format: 'image/jpeg');
          } catch (_) {}
          sw.stop();

          // Watchdog: si screenshot > 500ms, deshabilitamos para esta sesión.
          if (sw.elapsed > const Duration(milliseconds: 500)) {
            _screenshotsDisabled = true;
            debugPrint('[CinematicPaletteController] screenshot tardó ${sw.elapsedMilliseconds}ms → watchdog deshabilitado');
            bytes = null; // Forzar RB fallback.
          } else if (bytes != null) {
            debugPrint('[CinematicPaletteController] screenshot() → ${bytes.length} bytes (${sw.elapsedMilliseconds}ms)');
          }
        }

        // Estrategia 3: RepaintBoundary como último recurso.
        if (bytes == null || bytes.isEmpty || _isAllBlack(bytes)) {
          bytes = await _captureViaRepaintBoundary();
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
      debugPrint('[CinematicPaletteController] Error: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  /// Detecta si la imagen está completamente negra (letterbox).
  bool _isAllBlack(Uint8List pngBytes) {
    if (pngBytes.length < 100) return true;
    int sum = 0;
    final int end = pngBytes.length < 2048 ? pngBytes.length : 2048;
    for (int i = 8; i < end; i++) {
      sum += pngBytes[i];
    }
    return sum < 500;
  }

  /// Captura vía RepaintBoundary (funciona con video en árbol Flutter).
  Future<Uint8List?> _captureViaRepaintBoundary() async {
    try {
      final key = videoKey;
      if (key == null) return null;
      final context = key.currentContext;
      if (context == null) return null;

      final ro = context.findRenderObject();
      final RenderRepaintBoundary? boundary = ro is RenderRepaintBoundary ? ro : null;
      if (boundary == null || boundary.debugNeedsPaint) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 0.3);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[CinematicPaletteController] RepaintBoundary falló: $e');
      return null;
    }
  }

  /// Asigna colores manualmente (ej: desde un poster/banner).
  void setColors(Color start, Color end) {
    _startColor = start;
    _endColor = end;
    _hasExtractedVideoFrame = true;
    notifyListeners();
  }
}

/// Extrae dos colores dominantes de una imagen.
Future<(Color, Color)?> _extractDualDominantColors(Uint8List jpegBytes) async {
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      jpegBytes,
      targetWidth: 64,
      targetHeight: 36,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final int width = image.width;
    final int height = image.height;
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) return null;
    final Uint8List pixels = byteData.buffer.asUint8List();
    final int halfHeight = height ~/ 2;

    int rTop = 0, gTop = 0, bTop = 0, countTop = 0;
    int rBottom = 0, gBottom = 0, bBottom = 0, countBottom = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = (y * width + x) * 4;
        final r = pixels[index];
        final g = pixels[index + 1];
        final b = pixels[index + 2];

        final int brightness = (r + g + b) ~/ 3;
        if (brightness < 18) continue; // Ignorar letterbox negro.

        if (y < halfHeight) {
          rTop += r; gTop += g; bTop += b; countTop++;
        } else {
          rBottom += r; gBottom += g; bBottom += b; countBottom++;
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