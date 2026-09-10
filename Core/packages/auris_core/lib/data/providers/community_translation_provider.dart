import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server/episodes_response.dart';
import '../../core/api/providers.dart';
import 'auth_provider.dart';

final communityTranslationManagerProvider = Provider<CommunityTranslationManager>((ref) {
  return CommunityTranslationManager(ref);
});

class CommunityTranslationManager {
  final Ref ref;

  CommunityTranslationManager(this.ref);

  bool _isGenericTitle(String? title) {
    if (title == null || title.isEmpty) return true;
    final lower = title.toLowerCase().trim();
    final regex = RegExp(r'^(episode|episodio|ep|capitulo|capítulo|chapter)\s*\d+$');
    return regex.hasMatch(lower);
  }

  bool _containsCjk(String text) {
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\uAC00-\uD7A3]').hasMatch(text);
  }

  String _detectSourceLanguage(String text) {
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text)) {
      return 'ja';
    }
    return 'en';
  }

  /// Procesa la traducción silenciosa de un episodio en segundo plano si cumple con los triggers.
  Future<void> processEpisodeTranslation({
    required int? tmdbId,
    required int? season,
    required EpisodeInfo episode,
  }) async {
    if (tmdbId == null || season == null) return;
    if (!episode.needsTranslation) return;

    final srcTitle = episode.title;
    final srcOverview = episode.description;

    // 1. Validar que exista texto fuente real
    if ((srcTitle == null || srcTitle.trim().isEmpty) && (srcOverview == null || srcOverview.trim().isEmpty)) {
      return;
    }

    // Si el título es plantilla genérica y la sinopsis está vacía -> saltar
    if (_isGenericTitle(srcTitle) && (srcOverview == null || srcOverview.trim().isEmpty)) {
      return;
    }

    try {
      // 2. Dedup local: Ver si ya se envió antes para ahorrar red
      final box = await Hive.openBox('community_translations_cache');
      final cacheKey = 'sent_${tmdbId}_${season}_${episode.number}';
      if (box.get(cacheKey) == true) {
        return;
      }

      // 3. Protección anti-spam local: Límite de 100 por día por usuario
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final dayCountKey = 'count_$todayStr';
      final currentDayCount = box.get(dayCountKey, defaultValue: 0) as int;
      if (currentDayCount >= 100) {
        debugPrint('[CommunityTranslation] Límite local diario de 100 traducciones alcanzado.');
        return;
      }

      // 4. Determinar idioma fuente (JA o EN)
      final textForDetection = (srcOverview != null && srcOverview.isNotEmpty) ? srcOverview : (srcTitle ?? '');
      final sourceLang = _detectSourceLanguage(textForDetection);

      // Aviso de descarga de modelo ML Kit offline bajo demanda una sola vez en móvil con WiFi
      if (!kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          final noticeKey = 'mlkit_notice_shown';
          if (box.get(noticeKey) != true) {
            debugPrint('*** [Aviso ML Kit] Descarga de modelo de traducción offline iniciada bajo demanda (Solo WiFi recomendado). ***');
            await box.put(noticeKey, true);
          }
        }
      }

      // 5. Ejecutar traducción silenciosa en background
      String? translatedTitle;
      String? translatedOverview;

      if (srcTitle != null && srcTitle.trim().isNotEmpty && !_isGenericTitle(srcTitle)) {
        translatedTitle = await _translateText(srcTitle, sourceLang);
      } else {
        translatedTitle = srcTitle;
      }

      if (srcOverview != null && srcOverview.trim().isNotEmpty) {
        translatedOverview = await _translateText(srcOverview, sourceLang);
      }

      // 6. Validaciones post-traducción (Constraints)
      if (translatedTitle == null && translatedOverview == null) return;
      if (translatedTitle == srcTitle && translatedOverview == srcOverview) return;

      // Validar longitud máxima y ausencia de caracteres CJK en texto traducido
      if (translatedTitle != null) {
        if (translatedTitle.length > 200 || _containsCjk(translatedTitle)) {
          translatedTitle = null;
        }
      }
      if (translatedOverview != null) {
        if (translatedOverview.length > 2000 || _containsCjk(translatedOverview)) {
          translatedOverview = null;
        }
      }

      if (translatedTitle == null && translatedOverview == null) return;

      // 7. Obtener userId actual de la cuenta o guest por defecto
      final userAccount = ref.read(authProvider);
      final userId = userAccount?.id ?? 'guest_user';

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
      final response = await apiClient.post('/api/translations/community', data: payload);

      final data = response.data;
      bool saved = false;
      if (data is Map) {
        saved = data['saved'] == true;
      }

      if (saved) {
        await box.put(cacheKey, true);
        await box.put(dayCountKey, currentDayCount + 1);
        debugPrint('[CommunityTranslation] Traducción enviada exitosamente para S${season}E${episode.number}');
      } else {
        final reason = (data is Map) ? data['reason'] : 'Motivo desconocido';
        debugPrint('[CommunityTranslation] Servidor rechazó traducción: $reason');
      }
    } catch (e) {
      debugPrint('[CommunityTranslation] Error procesando traducción: $e');
      // No reintentar agresivamente, se intentará en la próxima oportunidad de apertura
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
