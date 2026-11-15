import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_endpoints.dart';
import '../../core/config/playback_config.dart';

/// Parámetro del family: (serverBaseUrl, isMovie).
/// - serverBaseUrl: URL base del VPS correcto (ApiEndpoints.animeBaseUrl, etc.)
/// - isMovie: true para películas, false para episodios de serie.
typedef PlaybackConfigParam = ({String serverUrl, bool isMovie});

/// Config remota de reproducción por VPS y tipo de contenido.
///
/// Llama `GET /api/client-config` al servidor correspondiente y parsea el
/// perfil correcto (movie vs episode). Si el server no responde devuelve
/// [PlaybackConfig.defaults] — idéntico al comportamiento previo hardcodeado.
///
/// Uso:
/// ```dart
/// final param = (serverUrl: ApiEndpoints.animeBaseUrl, isMovie: false);
/// final cfg = ref.watch(playbackConfigFamily(param)).valueOrNull
///             ?? PlaybackConfig.defaults;
/// ```
final playbackConfigFamily =
    FutureProvider.family<PlaybackConfig, PlaybackConfigParam>((ref, param) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 4),
  ));
  try {
    final resp = await dio.get<dynamic>(
      '${param.serverUrl}/api/client-config',
      options: Options(headers: {'Accept': 'application/json'}),
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      return PlaybackConfig.fromJson(payload, isMovie: param.isMovie);
    }
  } catch (_) {
    // Offline o server sin el endpoint: defaults locales.
  }
  return PlaybackConfig.defaults;
});

/// Shortcut de retrocompatibilidad: config del servidor anime para episodios.
/// Usado donde aún no se conoce source/category (p. ej. timers de buffering).
final playbackConfigProvider = FutureProvider<PlaybackConfig>((ref) {
  final param = (serverUrl: ApiEndpoints.animeBaseUrl, isMovie: false);
  return ref.watch(playbackConfigFamily(param).future);
});

/// Helper síncrono: lee la config ya cargada (o defaults si aún no responde).
/// Acepta un param opcional para leer un perfil específico del family.
PlaybackConfig playbackConfigSync(Ref ref, [PlaybackConfigParam? param]) {
  if (param != null) {
    return ref.read(playbackConfigFamily(param)).valueOrNull ??
        PlaybackConfig.defaults;
  }
  return ref.read(playbackConfigProvider).valueOrNull ?? PlaybackConfig.defaults;
}

/// Resuelve el [PlaybackConfigParam] correcto a partir de source y category.
/// Centraliza el mapeo source → VPS + isMovie en un único lugar.
PlaybackConfigParam resolvePlaybackParam({
  required String? source,
  required String? category,
}) {
  final serverUrl = (source != null && source.isNotEmpty)
      ? ApiEndpoints.baseUrlForSource(source, category)
      : (category != null && category.isNotEmpty)
          ? ApiEndpoints.baseUrlForCategory(category)
          : ApiEndpoints.animeBaseUrl;

  final cat = (category ?? '').toLowerCase();
  final isMovie = cat.contains('movie') ||
      cat == 'pelicula' ||
      cat == 'film';

  return (serverUrl: serverUrl, isMovie: isMovie);
}
