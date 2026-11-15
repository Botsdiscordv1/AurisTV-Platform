/// Configuración de reproducción dirigida por servidor (estilo Netflix
/// AseConfig): los apps leen `GET /api/client-config` en arranque y aplican
/// estos knobs en vez de tenerlos hardcodeados.
///
/// Los defaults replican EXACTAMENTE los valores que estaban fijos en las
/// apps; si el server no responde, el comportamiento es idéntico al anterior.
class PlaybackConfig {
  const PlaybackConfig({
    this.version = 2,
    this.bufferSizeBytes = 96 * 1024 * 1024,
    this.streamBufferSize = '32MiB',
    this.streamBufferSizeWeb = '16MiB',
    this.demuxerReadaheadSecs = 60,
    this.demuxerMaxBytes = '128MiB',
    this.demuxerMaxBackBytes = '32MiB',
    this.networkTimeoutSecs = 6,
    this.audioBufferSec = 5,
    this.audioBufferSecWeb = 3,
    this.bufferingDebounceMs = 2500,
    this.telemetryEnabled = true,
    this.telemetrySampleRate = 1.0,
    this.telemetryFlushIntervalMs = 60000,
  });

  final int version;
  final int bufferSizeBytes;
  final String streamBufferSize;
  final String streamBufferSizeWeb;
  final int demuxerReadaheadSecs;
  final String demuxerMaxBytes;
  final String demuxerMaxBackBytes;
  final int networkTimeoutSecs;
  final int audioBufferSec;
  final int audioBufferSecWeb;
  final int bufferingDebounceMs;
  final bool telemetryEnabled;
  final double telemetrySampleRate;
  final int telemetryFlushIntervalMs;

  static const PlaybackConfig defaults = PlaybackConfig();

  factory PlaybackConfig.fromJson(Map<String, dynamic> json, {bool isMovie = false}) {
    // Selección de perfil: profiles.movie o profiles.episode tienen prioridad
    // sobre el bloque legacy player (que actúa como fallback).
    final profiles = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : const <String, dynamic>{};
    final profileKey = isMovie ? 'movie' : 'episode';
    final profileBlock = profiles[profileKey] is Map
        ? Map<String, dynamic>.from(profiles[profileKey] as Map)
        : null;

    // Bloque legacy player: fallback cuando no hay profiles en la respuesta.
    final player = profileBlock ??
        (json['player'] is Map
            ? Map<String, dynamic>.from(json['player'] as Map)
            : const <String, dynamic>{});

    final telemetry = json['telemetry'] is Map
        ? Map<String, dynamic>.from(json['telemetry'] as Map)
        : const <String, dynamic>{};

    int asInt(dynamic v, int fallback) =>
        v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

    return PlaybackConfig(
      version: asInt(json['version'], 2),
      bufferSizeBytes: asInt(player['bufferSizeBytes'], defaults.bufferSizeBytes),
      streamBufferSize: player['streamBufferSize'] is String
          ? player['streamBufferSize'] as String
          : defaults.streamBufferSize,
      streamBufferSizeWeb: player['streamBufferSizeWeb'] is String
          ? player['streamBufferSizeWeb'] as String
          : defaults.streamBufferSizeWeb,
      demuxerReadaheadSecs: asInt(player['demuxerReadaheadSecs'], defaults.demuxerReadaheadSecs),
      demuxerMaxBytes: player['demuxerMaxBytes'] is String
          ? player['demuxerMaxBytes'] as String
          : defaults.demuxerMaxBytes,
      demuxerMaxBackBytes: player['demuxerMaxBackBytes'] is String
          ? player['demuxerMaxBackBytes'] as String
          : defaults.demuxerMaxBackBytes,
      networkTimeoutSecs: asInt(player['networkTimeoutSecs'], defaults.networkTimeoutSecs),
      audioBufferSec: asInt(player['audioBufferSec'], defaults.audioBufferSec),
      audioBufferSecWeb: asInt(player['audioBufferSecWeb'], defaults.audioBufferSecWeb),
      bufferingDebounceMs: asInt(player['bufferingDebounceMs'], defaults.bufferingDebounceMs),
      telemetryEnabled: telemetry['enabled'] is bool
          ? telemetry['enabled'] as bool
          : defaults.telemetryEnabled,
      telemetrySampleRate: telemetry['sampleRate'] is num
          ? (telemetry['sampleRate'] as num).toDouble().clamp(0.0, 1.0)
          : defaults.telemetrySampleRate,
      telemetryFlushIntervalMs:
          asInt(telemetry['flushIntervalMs'], defaults.telemetryFlushIntervalMs),
    );
  }

  /// Knob de mpv `stream-buffer-size` según plataforma.
  String streamBufferSizeFor(bool isWebDesktop) =>
      isWebDesktop ? streamBufferSizeWeb : streamBufferSize;

  /// Knob de mpv `audio-buffer` según plataforma.
  int audioBufferSecFor(bool isWebDesktop) =>
      isWebDesktop ? audioBufferSecWeb : audioBufferSec;
}
