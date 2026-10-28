import 'package:flutter/foundation.dart';

enum SectionPresentation {
  wide,
  poster,
  posterLarge,
  expandablePoster,
  top10,
  top10Wide,
}

/// Resolver responsible for determining the visual presentation of a content section.
/// Follows the "Global Section Presentation System V1" rules.
class SectionPresentationResolver {
  static SectionPresentation resolve(String type, {String? id, String? serverFormat}) {
    // 0. SERVER OVERRIDE (Explicit format from backend)
    if (serverFormat != null && serverFormat.isNotEmpty) {
      final fmt = serverFormat.toLowerCase();
      if (fmt.contains('top10_wide') || fmt.contains('top10wide') || fmt.contains('top10_backdrop')) {
        return SectionPresentation.top10Wide;
      }
      if (fmt.contains('top10')) return SectionPresentation.top10;
      if (fmt.contains('wide') || fmt.contains('backdrop')) return SectionPresentation.wide;
      if (fmt.contains('expandable_poster') || fmt.contains('expandableposter')) {
        return SectionPresentation.expandablePoster;
      }
      if (fmt.contains('poster_large') || fmt.contains('posterlarge') || fmt.contains('large_poster') || fmt.contains('largeposter')) {
        return SectionPresentation.posterLarge;
      }
      if (fmt.contains('poster')) return SectionPresentation.poster;
    }

    final typeLower = type.toLowerCase();
    final idLower = id?.toLowerCase() ?? '';
    
    // 1. BASE ASSIGNMENT (Structural Intent)
    if (typeLower.contains('top10_wide') || typeLower.contains('top10wide') || idLower.contains('top10_wide') || idLower.contains('top10wide')) {
      debugPrint('📺 [SectionPresentationResolver] Resolved to TOP10_WIDE for type="$type", id="$id"');
      return SectionPresentation.top10Wide;
    } else if (typeLower == 'editorial_for_you' || 
        typeLower.contains('top10') || 
        typeLower.contains('top 10') || 
        typeLower.contains('ranking') ||
        idLower.contains('top 10') ||
        idLower.contains('ranking')) {
      debugPrint('📱 [SectionPresentationResolver] Resolved to standard TOP10 (Poster) for type="$type", id="$id"');
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
