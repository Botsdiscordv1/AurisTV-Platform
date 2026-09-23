import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/server/episodes_response.dart';
import '../../core/api/providers.dart';
import '../../core/api/api_endpoints.dart';
import 'auth_provider.dart';

final communityTranslationManagerProvider = Provider<CommunityTranslationManager>((ref) {
  return CommunityTranslationManager(ref);
});

class CommunityTranslationManager {
  final Ref ref;

  CommunityTranslationManager(this.ref);

  static bool isGenericTitle(String? title) {
    if (title == null || title.isEmpty) return true;
    final lower = title.toLowerCase().trim();
    final regex = RegExp(r'^(episode|episodio|ep|capitulo|capítulo|chapter)\s*\d+$');
    return regex.hasMatch(lower);
  }

  static bool containsCjk(String text) {
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uAC00-\uD7A3]').hasMatch(text);
  }

  static String detectSourceLanguage(String text) {
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text)) {
      return 'ja';
    }
    return 'en';
  }

  /// UUID de instalación estable para cuota per-dispositivo (se genera una
  /// vez y persiste en Hive). Evita el bucket compartido de 'guest_user'.
  static Future<String> deviceUserId(Box box) async {
    var id = box.get('device_user_id') as String?;
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await box.put('device_user_id', id);
    }
    return id;
  }

  /// Decide si hay algo que traducir. Falso cuando no hay texto fuente
  /// (título genérico + sinopsis vacía): el server lo rechazaría igual.
  static bool shouldAttempt({String? title, String? overview}) {
    final hasTitle = title != null && title.trim().isNotEmpty;
    final hasOverview = overview != null && overview.trim().isNotEmpty;
    if (!hasTitle && !hasOverview) return false;
    if (isGenericTitle(title) && !hasOverview) return false;
    return true;
  }

  /// Procesa la traducción silenciosa de un episodio en segundo plano si cumple con los triggers.
  /// Devuelve los textos traducidos si el server los guardó (para pintar la UI local sin refresh).
  Future<({String? title, String? overview})?> processEpisodeTranslation({
    required int? tmdbId,
    required int? season,
    required EpisodeInfo episode,
    String? baseUrl,
  }) async {
    if (tmdbId == null || season == null) return null;
    if (!episode.needsTranslation) return null;

    final srcTitle = episode.title;
    final srcOverview = episode.description;

    // 1. Validar que exista texto fuente real
    if (!shouldAttempt(title: srcTitle, overview: srcOverview)) {
      return null;
    }

    try {
      // 2. Dedup local: Ver si ya se envió antes para ahorrar red
      final box = await Hive.openBox('community_translations_cache');
      final cacheKey = 'sent_${tmdbId}_${season}_${episode.number}';
      if (box.get(cacheKey) == true) {
        return null;
      }

      // 3. Protección anti-spam local: Límite de 100 por día por usuario
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final dayCountKey = 'count_$todayStr';
      final currentDayCount = box.get(dayCountKey, defaultValue: 0) as int;
      if (currentDayCount >= 100) {
        debugPrint('[CommunityTranslation] Límite local diario de 100 traducciones alcanzado.');
        return null;
      }

      // 4. Determinar idioma fuente (JA o EN)
      final textForDetection = (srcOverview != null && srcOverview.isNotEmpty) ? srcOverview : (srcTitle ?? '');
      final sourceLang = detectSourceLanguage(textForDetection);

      // Traducción vía endpoint Google con la IP del dispositivo (cuota fresca
      // por teléfono; ML Kit offline queda como optimización futura).
      if (!kIsWeb) {
        final p = defaultTargetPlatform;
        if (p == TargetPlatform.android || p == TargetPlatform.iOS) {
          final noticeKey = 'perdevice_notice_shown';
          if (box.get(noticeKey) != true) {
            debugPrint('[CommunityTranslation] Traduciendo con la IP del dispositivo (cuota propia).');
            await box.put(noticeKey, true);
          }
        }
      }

      // 5. Ejecutar traducción silenciosa en background
      String? translatedTitle;
      String? translatedOverview;

      if (srcTitle != null && srcTitle.trim().isNotEmpty && !isGenericTitle(srcTitle)) {
        translatedTitle = await _translateText(srcTitle, sourceLang);
      } else {
        translatedTitle = srcTitle;
      }

      if (srcOverview != null && srcOverview.trim().isNotEmpty) {
        translatedOverview = await _translateText(srcOverview, sourceLang);
      }

      // 6. Validaciones post-traducción (Constraints)
      if (translatedTitle == null && translatedOverview == null) return null;
      if (translatedTitle == srcTitle && translatedOverview == srcOverview) return null;

      // Validar longitud máxima y ausencia de caracteres CJK en texto traducido
      if (translatedTitle != null) {
        if (translatedTitle.length > 200 || containsCjk(translatedTitle)) {
          translatedTitle = null;
        }
      }
      if (translatedOverview != null) {
        if (translatedOverview.length > 2000 || containsCjk(translatedOverview)) {
          translatedOverview = null;
        }
      }

      if (translatedTitle == null && translatedOverview == null) return null;

      // 7. userId: cuenta logueada o UUID de instalación estable (persistido).
      // Nunca 'guest_user' literal: el server lo trata como ausente y cae a
      // IP, pero en CGNAT/móviles la IP rota y la cuota se comparte.
      final userAccount = ref.read(authProvider);
      final userId = userAccount?.id ?? await deviceUserId(box);

      // 8. Enviar al VPS
      final payload = {
        'tmdbId': tmdbId,
        'season': season,
        'episode': episode.number,
        'lang': 'es-MX',
        if (translatedTitle != null) 'title': translatedTitle,
        if (translatedOverview != null) 'overview': translatedOverview,
        'userId': userId,
      };

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/api/translations/community',
        data: payload,
        baseUrl: baseUrl ?? ApiEndpoints.animeBaseUrl,
      );

      final data = response.data;
      // El server envuelve en {success, data:{saved}}; aceptar ambas formas.
      bool saved = false;
      if (data is Map) {
        saved = data['saved'] == true || (data['data'] is Map && data['data']['saved'] == true);
      }

      if (saved) {
        await box.put(cacheKey, true);
        await box.put(dayCountKey, currentDayCount + 1);
        debugPrint('[CommunityTranslation] Traducción enviada exitosamente para S${season}E${episode.number}');
        return (
          title: translatedTitle,
          overview: translatedOverview,
        );
      } else {
        final reason = (data is Map) ? (data['reason'] ?? (data['data'] is Map ? data['data']['reason'] : null) ?? 'Motivo desconocido') : 'Motivo desconocido';
        debugPrint('[CommunityTranslation] Servidor rechazó traducción: $reason');
        return null;
      }
    } catch (e) {
      debugPrint('[CommunityTranslation] Error procesando traducción: $e');
      // No reintentar agresivamente, se intentará en la próxima oportunidad de apertura
      return null;
    }
  }

  Future<String?> _translateText(String text, String sourceLang) async {
    if (sourceLang == 'es') return text;

    try {
      final url = 'https://translate.googleapis.com/translate_a/single';
      final dio = Dio();
      final response = await dio.get(
        url,
        queryParameters: {
          'client': 'gtx',
          'sl': sourceLang,
          'tl': 'es',
          'dt': 't',
          'q': text,
        },
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final List parts = response.data[0];
        final sb = StringBuffer();
        for (var part in parts) {
          if (part is List && part.isNotEmpty) {
            sb.write(part[0]);
          }
        }
        return sb.toString().trim();
      }
    } catch (e) {
      debugPrint('[CommunityTranslation] Error en motor de traducción: $e');
    }
    return null;
  }
}
