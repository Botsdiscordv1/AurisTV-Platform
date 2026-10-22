import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cast_state.dart';
import '../../data/services/native_cast_service.dart';

/// Estado global de la sesión Chromecast (compartido entre player screens,
/// mini player y el sheet de selección). Singleton vía Riverpod.
///
/// Nota: se llama `chromecastProvider` porque `auris_core` ya exporta un
/// `castProvider` (provider del reparto/actores del contenido).
final chromecastProvider = StateNotifierProvider<CastNotifier, CastState>((ref) {
  return CastNotifier();
});

class CastNotifier extends StateNotifier<CastState> {
  final NativeCastService _service = NativeCastService();
  StreamSubscription? _eventsSub;

  CastNotifier() : super(const CastState()) {
    _init();
  }

  Future<void> _init() async {
    if (!_service.isSupported) {
      state = state.copyWith(available: false);
      return;
    }
    final available = await _service.init();
    if (!available) {
      state = state.copyWith(available: false);
      return;
    }
    // Restaurar estado si ya había una sesión activa (p. ej. reabrir el player).
    final status = await _service.getMediaStatus();
    if (status != null && status['loaded'] == true && mounted) {
      state = state.copyWith(
        phase: CastPhase.casting,
        device: state.device ?? const CastDeviceInfo(id: '', name: 'Chromecast'),
        media: CastMediaStatus.fromMap(status),
      );
    }
    _eventsSub = _service.events().listen(_onEvent, onError: (e) {
      debugPrint('[AurisCast] event error: $e');
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['event'] as String?) {
      case 'availability':
        state = state.copyWith(available: event['available'] == true);
        break;
      case 'sessionStarted':
        state = state.copyWith(
          phase: CastPhase.casting,
          device: CastDeviceInfo(
            id: (event['deviceId'] ?? '') as String? ?? '',
            name: (event['deviceName'] ?? 'Chromecast') as String? ?? 'Chromecast',
          ),
          error: null,
        );
        break;
      case 'mediaStatus':
        state = state.copyWith(
          // mediaStatus implica sesión viva (restauración incluida).
          phase: CastPhase.casting,
          media: CastMediaStatus.fromMap(event),
        );
        break;
      case 'sessionEnded':
        state = state.copyWith(
          phase: CastPhase.idle,
          device: null,
          media: const CastMediaStatus(),
          finalPositionMs: (event['positionMs'] as num?)?.toInt() ?? 0,
          finalDurationMs: (event['durationMs'] as num?)?.toInt() ?? 0,
        );
        break;
      case 'error':
        // Error técnico transitorio: se reporta sin romper la sesión
        // (el receptor también puede emitir errores recuperables).
        debugPrint('[AurisCast] native error: ${event['message']}');
        break;
    }
  }

  // ------------------------------------------------------------------
  // Acciones expuestas a la UI
  // ------------------------------------------------------------------

  /// Abre el diálogo nativo de Google (elección de Chromecast).
  Future<void> showDeviceChooser() => _service.showDeviceChooser();

  /// Carga el media local actual en el receptor (posición incluida).
  Future<void> loadMedia({
    required String url,
    required int startMs,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    await _service.loadMedia(
      url: url,
      startMs: startMs,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  Future<void> play() => _service.play();
  Future<void> pause() => _service.pause();
  Future<void> seekTo(int ms) => _service.seekTo(ms);
  Future<void> setVolume(double v) => _service.setVolume(v);

  /// Toggle play/pause del receptor.
  Future<void> togglePlay() {
    if (state.media.isPlaying) return _service.pause();
    return _service.play();
  }

  /// Detiene la transmisión y desconecta (la sesión emite SessionEnded).
  Future<void> stopCasting() async {
    final ok = await _service.stopCasting();
    if (!ok && mounted && state.isCasting) {
      // Fallback: si el nativo no pudo cerrar (p. ej. receptor desconectado
      // de la red), restauramos el estado local igualmente.
      state = state.copyWith(
        phase: CastPhase.idle,
        device: null,
        media: const CastMediaStatus(),
      );
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}
