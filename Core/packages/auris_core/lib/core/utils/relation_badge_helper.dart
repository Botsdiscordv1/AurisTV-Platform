import 'package:flutter/material.dart';

class RelationBadgeHelper {
  /// Extrae el badge contextual ideal para una relación.
  /// Prioridad:
  /// 1. Secuela / Precuela directa (información cronológica de mayor valor)
  /// 2. Lo que venga especificado entre paréntesis: (OVA), (ONA), (Especial), (Pelicula)
  /// 3. El `type` canónico si es OVA, ONA, Película, Especial
  /// 4. Categoría general: Crossover, Spin-off, etc.
  static String? getBadgeText({
    required String? rawTitle,
    required String? relation,
    String? type,
  }) {
    final rel = (relation ?? '').trim();
    final relUpper = rel.toUpperCase();
    final title = (rawTitle ?? '').trim();

    // 1. Secuela / Precuela directa
    if (relUpper.contains('SECUELA')) return 'SECUELA';
    if (relUpper.contains('PRECUELA')) return 'PRECUELA';

    // 2. Extraer tipo de los paréntesis del título (ej: "(OVA)", "(ONA)", "(Pelicula)")
    final parenMatch = RegExp(r'\((OVA|ONA|Especial|Pel[íi]cula|Movie|Serie|ONA)\)', caseSensitive: false).firstMatch(title);
    if (parenMatch != null) {
      final inside = parenMatch.group(1)!.toUpperCase();
      if (inside.contains('PEL') || inside.contains('MOV')) return 'PELÍCULA';
      if (inside == 'OVA') return 'OVA';
      if (inside == 'ONA') return 'ONA';
      if (inside.contains('ESPECIAL')) return 'ESPECIAL';
    }

    // 3. Fallback al type canónico
    final tUpper = (type ?? '').toUpperCase();
    if (tUpper.contains('PEL') || tUpper.contains('MOV')) return 'PELÍCULA';
    if (tUpper == 'OVA') return 'OVA';
    if (tUpper == 'ONA') return 'ONA';
    if (tUpper.contains('ESPECIAL')) return 'ESPECIAL';

    // 4. Semántica de relación
    if (relUpper.contains('PERSONAJE INCLUIDO') || relUpper.contains('CROSSOVER')) return 'CROSSOVER';
    if (relUpper.contains('SPIN-OFF') || relUpper.contains('SPINOFF')) return 'SPIN-OFF';
    if (relUpper.contains('HISTORIA PARALELA') || relUpper.contains('PARALELA')) return 'PARALELA';
    if (relUpper.contains('RESUMEN') || relUpper.contains('RECAP')) return 'RESUMEN';
    if (relUpper.contains('ADICIONAL') || relUpper.contains('OTRO')) return 'EXTRA';

    // Si es solo "Recomendado" o "Similar", no mostramos badge intrusivo
    if (relUpper.contains('RECOMEND') || relUpper.contains('SIMILAR')) return null;

    return rel.isNotEmpty ? relUpper : null;
  }

  /// Color semántico distintivo para el badge
  static Color getBadgeColor(String? badgeText) {
    if (badgeText == null) return const Color(0xFF1E1E26).withOpacity(0.9);
    final b = badgeText.toUpperCase();

    if (b.contains('SECUELA')) {
      return const Color(0xFF10B981); // Esmeralda vivo
    }
    if (b.contains('PRECUELA')) {
      return const Color(0xFF2563EB); // Azul real
    }
    if (b.contains('PEL')) {
      return const Color(0xFFEF7A1E); // Naranja AurisTV
    }
    if (b == 'OVA' || b == 'ONA') {
      return const Color(0xFF8B5CF6); // Púrpura elegante
    }
    if (b.contains('ESPECIAL') || b.contains('EXTRA')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    if (b.contains('CROSSOVER')) {
      return const Color(0xFFF59E0B); // Ámbar / Dorado
    }
    if (b.contains('RESUMEN')) {
      return const Color(0xFF475569); // Slate Grey
    }
    return const Color(0xFF1E1E26).withOpacity(0.9);
  }
}

