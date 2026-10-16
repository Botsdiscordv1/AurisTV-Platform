import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_endpoints.dart';
import '../config/playback_config.dart';

/// Telemetría de reproducción (estilo Netflix DET, mínimo viable).
///
/// Por sesión mide: arranque (primer frame), rebuffers y códigos de error.
/// Al cerrar la sesión se encola un resumen y se envía por lotes a
/// `POST /api/telemetry`. Todo best-effort: jamás rompe la reproducción ni
/// envía datos personales (sin userId, sin títulos, sin URLs).
class PlaybackTelemetry {
  PlaybackTelemetry._();

  static final PlaybackTelemetry instance = PlaybackTelemetry._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
  ));
  final List<Map<String, dynamic>> _pending = <Map<String, dynamic>>[];

  PlaybackConfig _config = PlaybackConfig.defaults;
  String? _platformOverride;
  _PlaybackSession? _session;
  Timer? _flushTimer;
  Timer? _flushDebounce;
  bool _sending = false;
  bool _sampledIn = true;

  /// Fija la etiqueta de plataforma reportada ('tv' en la app de TV).
  /// Sin esto, TV se reportaría como 'android' (mismo defaultTargetPlatform).
  void setPlatformOverride(String platform) => _platformOverride = platform;

  /// Aplica la config remota (habilita/ajusta el muestreo y el intervalo).
  void configure(PlaybackConfig config) {
    final wasEnabled = _config.telemetryEnabled;
    _config = config;
    if (!config.telemetryEnabled) {
      _flushTimer?.cancel();
      _flushDebounce?.cancel();
      _pending.clear();
      _session = null;
      return;
    }
    if (!wasEnabled || _flushTimer == null) _scheduleFlushLoop();
  }

  /// Inicia la sesión de reproducción. No-op si está deshabilitado o fuera
  /// de muestreo. Si ya había una sesión abierta (re-init del player), se
  /// cierra antes para no perder su resumen.
  void beginSession() {
    if (!_config.telemetryEnabled) return;
    if (_session != null) endSession();
    _sampledIn = Random().nextDouble() < _config.telemetrySampleRate;
    if (!_sampledIn) return;
    _session = _PlaybackSession();
  }

  /// Primer frame mostrado: de aquí sale el tiempo de arranque.
  void markFirstFrame() {
    _session?.markFirstFrame();
  }

  void markBufferingStart() => _session?.markBufferingStart();

  void markBufferingEnd() => _session?.markBufferingEnd();

  /// Registra un código del catálogo (p.ej. 'AURI1001').
  void markError(String code) => _session?.markError(code);

  /// Cierra la sesión y encola el resumen para envío por lotes.
  void endSession() {
    final s = _session;
    _session = null;
    if (s == null) return;
    final summary = s.summary();
    if (summary == null) return;
    _pending.add(summary);
    if (_pending.length > 40) _pending.removeAt(0);
    _scheduleFlushDebounce();
    if (_flushTimer == null) _scheduleFlushLoop();
  }

  void _scheduleFlushLoop() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      Duration(milliseconds: max(10000, _config.telemetryFlushIntervalMs)),
      (_) => flush(),
    );
  }

  void _scheduleFlushDebounce() {
    _flushDebounce?.cancel();
    _flushDebounce = Timer(const Duration(seconds: 5), () => flush());
  }

  /// Envía los resúmenes encolados. Best-effort: en error se reintentan luego.
  Future<void> flush() async {
    if (_sending || _pending.isEmpty || !_config.telemetryEnabled) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_pending);
    try {
      await _dio.post<dynamic>(
        '${ApiEndpoints.animeBaseUrl}/api/telemetry',
        data: <String, dynamic>{
          'platform': _platform(),
          'sessions': batch,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      _pending.removeRange(0, batch.length);
    } catch (e) {
      debugPrint('[telemetry] flush falló (se reintentará): $e');
    } finally {
      _sending = false;
    }
  }

  String _platform() {
    final override = _platformOverride;
    if (override != null) return override;
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'otro';
    }
  }
}

class _PlaybackSession {
  final Stopwatch _clock = Stopwatch()..start();
  int? _firstFrameMs;
  int? _bufferingStartMs;
  int rebufferCount = 0;
  int rebufferMs = 0;
  final Set<String> errorCodes = <String>{};

  void markFirstFrame() => _firstFrameMs ??= _clock.elapsedMilliseconds;

  void markBufferingStart() {
    if (_bufferingStartMs != null) return;
    _bufferingStartMs = _clock.elapsedMilliseconds;
    rebufferCount++;
  }

  void markBufferingEnd() {
    final start = _bufferingStartMs;
    if (start == null) return;
    rebufferMs += _clock.elapsedMilliseconds - start;
    _bufferingStartMs = null;
  }

  void markError(String code) {
    if (code.isEmpty) return;
    errorCodes.add(code);
    if (errorCodes.length > 8) errorCodes.remove(errorCodes.first);
  }

  /// Resumen de la sesión o null si nunca hubo frame (inicio fallido sin
  /// valor de salud).
  Map<String, dynamic>? summary() {
    final first = _firstFrameMs;
    if (first == null) return null;
    markBufferingEnd();
    final total = _clock.elapsedMilliseconds;
    final watchMs = max(0, total - first - rebufferMs);
    return <String, dynamic>{
      'startupMs': first,
      'watchMs': watchMs,
      'rebufferCount': rebufferCount,
      'rebufferMs': rebufferMs,
      'errorCodes': errorCodes.toList(),
    };
  }
}
