import '../../auris_core.dart';
import '../../data/models/section_presentation.dart';

/// Configuration preferences for the SectionComposer.
class CompositionPreferences {
  final List<SectionPresentation> preferredPresentations;
  final List<HomeSectionType> preferredSectionTypes;
  final int? maximumSections;

  const CompositionPreferences({
    this.preferredPresentations = const [],
    this.preferredSectionTypes = const [],
    this.maximumSections,
  });
}

/// A section that has been composed with a specific presentation and order.
class ComposedHomeSection {
  final HomeSectionType type;
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final SectionPresentation presentation;
  final dynamic data;
  final EditorialBadge? badge;

  const ComposedHomeSection({
    required this.type,
    required this.title,
    required this.presentation,
    required this.items,
    this.subtitle,
    this.data,
    this.badge,
  });
}

/// The SectionComposer is responsible for orchestrating the visual layout of content sections.
/// It decides what to show, in what order, and using which widget (presentation).
class SectionComposer {
  /// Composes a final list of sections based on raw input and preferences.
  static List<ComposedHomeSection> compose(
    List<HomeLayoutSection> rawSections, {
    CompositionPreferences? preferences,
  }) {
    // 1. Filter out empty sections (Keep data integrity)
    final List<HomeLayoutSection> filtered = rawSections.where((s) {
      if (s.type == HomeSectionType.continueWatching) return true;
      if (s.data is EditorialRow) {
        return (s.data as EditorialRow).items.isNotEmpty;
      }
      return true;
    }).toList();

    // 2. Map to final ComposedHomeSection respecting server-driven order
    // Senior Logic: Se elimina el reordenamiento funcional y el entrelazado visual
    // para respetar estrictamente la jerarquía definida por el servidor.
    final List<ComposedHomeSection> composed = filtered.map((raw) {
      List<MediaItem> items = [];
      String title = raw.title ?? '';
      String? subtitle;
      EditorialBadge? badge;
      dynamic data = raw.data;

      if (raw.data is EditorialRow) {
        final row = raw.data as EditorialRow;
        items = List.unmodifiable(row.items);
        title = row.title;
        subtitle = row.subtitle;
        badge = row.badge;
      } else if (raw.data is List<MediaItem>) {
        items = List.unmodifiable(raw.data as List<MediaItem>);
      }

      // 2.1 Resolution based on Intent
      SectionPresentation presentation = SectionPresentationResolver.resolve(
        _getSectionIdentifier(raw),
        id: title,
        serverFormat: raw.serverFormat,
      );

      // 2.2 CONTENT INTEGRITY CHECK (Senior Logic)
      // If we intended WIDE but items don't have banners, we must use POSTER.
      // Senior Fix: Si el servidor envió un formato explícito, lo respetamos siempre (SDUI)
      // evitando que la heurística local lo degrade a poster.
      if (raw.serverFormat == null && presentation == SectionPresentation.wide && items.isNotEmpty) {
        final hasBanners = items.take(3).every((m) => m.bannerUrl != null && m.bannerUrl!.isNotEmpty);
        if (!hasBanners) {
          presentation = SectionPresentation.poster;
        }
      }

      return ComposedHomeSection(
        type: raw.type,
        title: title,
        subtitle: subtitle,
        items: items,
        presentation: presentation,
        data: data,
        badge: badge,
      );
    }).toList();

    // 3. Apply preferences/limits
    if (preferences?.maximumSections != null && composed.length > preferences!.maximumSections!) {
      return composed.take(preferences.maximumSections!).toList();
    }

    return composed;
  }

  static String _getSectionIdentifier(HomeLayoutSection section) {
    if (section.data is EditorialRow) {
      final row = section.data as EditorialRow;
      // We use the badge or title as hints for the resolver
      return '${row.badge.name}_${row.title}';
    }
    return section.type.name;
  }
}
