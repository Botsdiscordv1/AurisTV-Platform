

/// Helper de presentación visual centralizado para Personalized Home de AurisTv.
/// Traduce reasonKeys y gestiona fallbacks de títulos/subtítulos según lineamientos de UX.
class PersonalizedHomeHelper {
  /// Resuelve un reasonKey conocido y devuelve su cadena de presentación localizada.
  /// Si la clave es desconocida o técnica pura sin mapeo, devuelve null para ser silenciada.
  static String? resolveReasonKey(String reasonKey) {
    switch (reasonKey.toUpperCase()) {
      case 'MATCH_GENRE':
        return "Porque te gusta este género";
      case 'STRONG_TASTE_MATCH':
        return "Muy recomendado para ti";
      case 'TASTE_MATCH':
        return "Basado en tus gustos";
      case 'SIMILAR_TO_HISTORY':
        return "Porque viste algo parecido";
      case 'EDITORIAL_FILTERED':
        return "Seleccionado para ti";
      case 'CONTINUE_WATCHING':
        return "Continúa viendo";
      default:
        return null;
    }
  }

  /// Retorna un subtítulo apropiado basado en las claves de justificación contextuales del item o sección.
  static String? getContextSubtitle(List<String> reasonKeys) {
    if (reasonKeys.isEmpty) return null;
    for (final rKey in reasonKeys) {
      final resolved = resolveReasonKey(rKey);
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }
}
