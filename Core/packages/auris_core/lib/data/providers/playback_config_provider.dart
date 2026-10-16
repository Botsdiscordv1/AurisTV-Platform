import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/config/playback_config.dart';

/// Config remota de reproducción (`GET /api/client-config`).
///
/// Se descarga una vez por sesión con timeout corto; mientras carga (o si el
/// server falla) el valor es [PlaybackConfig.defaults], idéntico al
/// comportamiento previo hardcodeado.
final playbackConfigProvider = FutureProvider<PlaybackConfig>((ref) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 4),
  ));
  try {
    final resp = await dio.get<dynamic>(
      '${ApiEndpoints.animeBaseUrl}/api/client-config',
      options: Options(headers: {'Accept': 'application/json'}),
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      return PlaybackConfig.fromJson(payload);
    }
  } catch (_) {
    // Offline o server sin el endpoint: defaults locales.
  }
  return PlaybackConfig.defaults;
});

/// Config ya cargada (o defaults si aún no responde) — uso síncrono en
/// puntos donde no podemos esperar (p.ej. timers de buffering).
PlaybackConfig playbackConfigSync(Ref ref) =>
    ref.read(playbackConfigProvider).valueOrNull ?? PlaybackConfig.defaults;
