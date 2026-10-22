/// Estado del Chromecast nativo (Google Cast SDK de Android).
/// Feature confined a Movil: el servicio nativo solo existe en Android.

library cast;

enum CastPhase { unavailable, idle, connecting, casting }

class CastDeviceInfo {
  final String id;
  final String name;

  const CastDeviceInfo({required this.id, required this.name});
}

/// Estado de la media en el receptor (position/duración/play).
class CastMediaStatus {
  final bool loaded;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final bool buffering;
  final bool idle;

  const CastMediaStatus({
    this.loaded = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    this.buffering = false,
    this.idle = true,
  });

  factory CastMediaStatus.fromMap(Map<String, dynamic> map) {
    return CastMediaStatus(
      loaded: map['loaded'] == true,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      isPlaying: map['isPlaying'] == true,
      buffering: map['buffering'] == true,
      idle: map['idle'] == true,
    );
  }
}

class CastState {
  /// El dispositivo soporta Cast nativo (Android + Google Cast SDK listo).
  final bool available;

  final CastPhase phase;

  /// Dispositivo Chromecast / Google TV conectado.
  final CastDeviceInfo? device;

  /// Estado de la media en el receptor.
  final CastMediaStatus media;

  /// Última posición reportada al terminar la sesión (handback local).
  final int finalPositionMs;
  final int finalDurationMs;

  /// Último error técnico (informativo).
  final String? error;

  const CastState({
    this.available = false,
    this.phase = CastPhase.idle,
    this.device,
    this.media = const CastMediaStatus(),
    this.finalPositionMs = 0,
    this.finalDurationMs = 0,
    this.error,
  });

  bool get isCasting => phase == CastPhase.casting;

  CastState copyWith({
    bool? available,
    CastPhase? phase,
    CastDeviceInfo? device,
    CastMediaStatus? media,
    int? finalPositionMs,
    int? finalDurationMs,
    String? error,
  }) {
    return CastState(
      available: available ?? this.available,
      phase: phase ?? this.phase,
      device: device ?? this.device,
      media: media ?? this.media,
      finalPositionMs: finalPositionMs ?? this.finalPositionMs,
      finalDurationMs: finalDurationMs ?? this.finalDurationMs,
      error: error ?? this.error,
    );
  }
}
