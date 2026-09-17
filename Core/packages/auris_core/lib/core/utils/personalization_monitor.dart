import 'package:flutter/foundation.dart';
import '../../data/models/server/personalized_home.dart';
import '../../data/models/media_item.dart';

/// Monitor de calidad y observabilidad para el sistema de personalización de AurisTV.
/// Se encarga de auditar la integridad de los datos recibidos y registrar métricas de salud del Home.
class PersonalizationMonitor {
  PersonalizationMonitor._();

  static final PersonalizationMonitor instance = PersonalizationMonitor._();

  /// Audita una respuesta completa del Home y reporta discrepancias de calidad.
  void auditHomeResponse(HomeResponse response) {
    if (response.sections.isEmpty) {
      _reportIssue('EMPTY_HOME', 'El servidor devolvió un Home sin secciones.');
      return;
    }

    for (final section in response.sections) {
      if (section.items.isEmpty) {
        _reportIssue('EMPTY_SECTION', 'Sección vacía detectada: ${section.id} (${section.type})');
      }

      for (final item in section.items) {
        _auditItem(item, section);
      }
    }
  }

  void _auditItem(HomeItem item, HomeSection section) {
    // 1. Detección de identidades faltantes - solo para anime (películas/series no usan animeId)
    final k = item.kind?.toLowerCase() ?? '';
    final isAnime = k.contains('anime');
    if (isAnime && item.animeId == null) {
      _reportIssue('MISSING_ANIME_ID', 'Recomendación sin animeId canónico: ${item.title} en sección ${section.id}');
    }

    // 2. Calidad visual
    if (item.posterUrl == null || item.posterUrl!.isEmpty) {
      _reportIssue('MISSING_POSTER', 'Item sin posterUrl: ${item.title} (ID: ${item.id})');
    }

    // 3. Integridad de razones
    if (item.reasonKeys.isEmpty && section.type == 'recommendation') {
      _reportIssue('MISSING_REASONS', 'Recomendación sin reasonKeys: ${item.title} en sección ${section.id}');
    }

    // 4. Detección de duplicados inter-sección (si aplica a futuro, el backend ya lo hace)
  }

  /// Registro de métricas de rendimiento del Home (Latencia, Cache Hits, etc.)
  void logMetric(String name, dynamic value, {Map<String, String>? tags}) {
    if (kDebugMode) {
      print('[PersonalizationMonitor] METRIC: $name = $value ${tags != null ? tags.toString() : ''}');
    }
    // En una fase futura, esto podría enviarse a un colector de métricas real.
  }

  void _reportIssue(String code, String message) {
    if (kDebugMode) {
      print('[PersonalizationMonitor] QUALITY_ISSUE [$code]: $message');
    }
    // Reportar a un logger centralizado si existiera.
  }
}
