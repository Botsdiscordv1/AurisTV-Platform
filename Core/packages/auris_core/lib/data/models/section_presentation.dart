enum SectionPresentation {
  wide,
  poster,
  top10,
}

/// Resolver responsible for determining the visual presentation of a content section.
/// Follows the "Global Section Presentation System V1" rules.
class SectionPresentationResolver {
  static SectionPresentation resolve(String type, {String? id, String? serverFormat}) {
    // 0. SERVER OVERRIDE (Explicit format from backend)
    if (serverFormat != null && serverFormat.isNotEmpty) {
      final fmt = serverFormat.toLowerCase();
      if (fmt.contains('top10')) return SectionPresentation.top10;
      if (fmt.contains('wide') || fmt.contains('backdrop')) return SectionPresentation.wide;
      if (fmt.contains('poster')) return SectionPresentation.poster;
    }

    final typeLower = type.toLowerCase();
    final idLower = id?.toLowerCase() ?? '';
    
    // 1. BASE ASSIGNMENT (Structural Intent)
    if (typeLower == 'editorial_for_you' || 
        typeLower.contains('top10') || 
        typeLower.contains('top 10') || 
        typeLower.contains('ranking') ||
        idLower.contains('top 10') ||
        idLower.contains('ranking')) {
      return SectionPresentation.top10;
    } else if (typeLower.contains('watching') || 
               typeLower.contains('continue') ||
               typeLower.contains('trending') ||
               typeLower.contains('destacado') ||
               typeLower.contains('estrenos') ||
               typeLower.contains('recent') || 
               typeLower.contains('episode') ||
               typeLower.contains('because_you_watched') ||
               idLower.contains('estrenos') ||
               idLower.contains('tendencias') ||
               idLower.contains('reciente') ||
               idLower.contains('novedad')) {
      return SectionPresentation.wide;
    } else {
      // Default fallback for catalog and general categories
      return SectionPresentation.poster;
    }
  }
}
