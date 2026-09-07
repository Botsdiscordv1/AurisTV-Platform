import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';

/// Senior Utility: Resuelve el stream adaptativo (HLS) de YouTube para máxima calidad
/// en Android TV y dispositivos móviles sin errores de embedding.
class YoutubeResolver {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Obtiene la URL del manifiesto HLS o el stream directo de mayor compatibilidad.
  /// Implementación Senior: Prioriza estabilidad sobre resolución extrema para evitar 403.
  static Future<String?> getDirectStreamUrl(String videoId) async {
    try {
      // 1. Intento de HLS (Solo para transmisiones o compatibilidad alta)
      try {
        final hlsUrl = await _yt.videos.streamsClient.getHttpLiveStreamUrl(VideoId(videoId));
        if (hlsUrl.isNotEmpty) {
          debugPrint('[YoutubeResolver] HLS Detectado para $videoId');
          return hlsUrl;
        }
      } catch (_) {}

      // 2. Prioridad a Streams MUXED (Video + Audio integrados)
      // Estos streams (normalmente 720p o 360p) son los más estables y raramente devuelven 403.
      // Para un trailer en un banner, 720p es nitidez más que suficiente.
      final manifest = await _yt.videos.streamsClient.getManifest(VideoId(videoId));
      
      final muxedInfo = manifest.muxed.withHighestBitrate();
      if (muxedInfo != null) {
        debugPrint('[YoutubeResolver] Usando Muxed Stream (${muxedInfo.videoQualityLabel}) para $videoId');
        return muxedInfo.url.toString();
      }

      // 3. Fallback Seguro: Si no hay muxed, buscamos la pista de video más ligera (360p/480p)
      // para asegurar que al menos se vea algo sin disparar los bloqueos de 1080p.
      final bestVideo = manifest.videoOnly.firstWhere(
        (s) => s.videoQualityLabel.contains('480') || s.videoQualityLabel.contains('360'),
        orElse: () => manifest.videoOnly.withHighestBitrate()!,
      );

      debugPrint('[YoutubeResolver] Fallback a Video-Only (${bestVideo.videoQualityLabel}) para $videoId');
      return bestVideo.url.toString();
    } catch (e) {
      debugPrint('[YoutubeResolver] Error crítico resolviendo YouTube ($videoId): $e');
      return null;
    }
  }

  static void dispose() {
    _yt.close();
  }
}
