import 'package:flutter/foundation.dart';
import '../../auris_core.dart';

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
  final String id; // Senior Fix: Identificador estable para Diffing Engine y preservación de estado
  final HomeSectionType type;
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final List<ContentSports>? sportsItems;
  /// Items del carrusel de marcas (solo `type == brands`) → `SportsBrandCarousel`.
  final List<SportsBrandItem>? brandItems;
  final SectionPresentation presentation;
  final dynamic data;
  final EditorialBadge? badge;

  const ComposedHomeSection({
    required this.id,
    required this.type,
    required this.title,
    required this.presentation,
    required this.items,
    this.sportsItems,
    this.brandItems,
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
      if (s.data is SportsEditorialRow) {
        return (s.data as SportsEditorialRow).items.isNotEmpty;
      }
      if (s.data is SportsBrandRow) {
        return (s.data as SportsBrandRow).items.isNotEmpty;
      }
      return true;
    }).toList();

    // 2. Map to final ComposedHomeSection respecting server-driven order
    // Senior Logic: Se elimina el reordenamiento funcional y el entrelazado visual
    // para respetar estrictamente la jerarquía definida por el servidor.
    final List<ComposedHomeSection> composed = filtered.map((raw) {
      List<MediaItem> items = [];
      List<ContentSports>? sportsItems;
      List<SportsBrandItem>? brandItems;
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
      } else if (raw.data is SportsEditorialRow) {
        final row = raw.data as SportsEditorialRow;
        sportsItems = List.unmodifiable(row.items);
        items = List.unmodifiable(row.items.map((e) => e.toMediaItem()).toList());
        title = row.title;
        subtitle = row.subtitle;
      } else if (raw.data is SportsBrandRow) {
        final row = raw.data as SportsBrandRow;
        brandItems = List.unmodifiable(row.items);
        title = row.title;
      } else if (raw.data is List<MediaItem>) {
        items = List.unmodifiable(raw.data as List<MediaItem>);
      }

      // 2.1 Resolution based on Intent
      SectionPresentation presentation = raw.presentation;
      if (presentation == SectionPresentation.expandablePoster || presentation == SectionPresentation.top10Wide) {
        // Preservar la promoción realizada por el orquestador
        if (raw.serverFormat != null && raw.serverFormat!.isNotEmpty) {
          final fmt = SectionPresentationResolver.resolve(
            _getSectionIdentifier(raw),
            id: title,
            serverFormat: raw.serverFormat,
          );
          if (fmt == SectionPresentation.expandablePoster || fmt == SectionPresentation.top10 || fmt == SectionPresentation.top10Wide) {
            presentation = fmt;
          }
        }
      } else if (raw.serverFormat != null && raw.serverFormat!.isNotEmpty) {
        presentation = SectionPresentationResolver.resolve(
          _getSectionIdentifier(raw),
          id: title,
          serverFormat: raw.serverFormat,
        );
      } else {
        presentation = SectionPresentationResolver.resolve(
          _getSectionIdentifier(raw),
          id: title,
          serverFormat: raw.serverFormat,
        );
      }

      if (presentation == SectionPresentation.expandablePoster) {
        debugPrint('🌟 [SectionComposer] Section "$title" (${raw.type.name}) resolved to EXPANDABLE_POSTER!');
      } else {
        debugPrint('🎨 [SectionComposer] Section "$title" -> ${presentation.name}');
      }

      // Frontend Platform Decision for TV vs Mobile/Web
      if (ResponsiveUtils.isTV) {
        if (presentation == SectionPresentation.top10) {
          presentation = SectionPresentation.top10Wide;
          debugPrint('📺 [SectionComposer] TV Rule: Section "$title" (top10) promoted to TOP10_WIDE');
        } else if (presentation == SectionPresentation.poster || presentation == SectionPresentation.posterLarge) {
          presentation = SectionPresentation.expandablePoster;
          debugPrint('📺 [SectionComposer] TV Rule: Section "$title" promoted to EXPANDABLE_POSTER');
        }
      } else {
        if (presentation == SectionPresentation.expandablePoster) {
          presentation = SectionPresentation.posterLarge;
        }
      }

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
        id: '${raw.type.name}_$title',
        type: raw.type,
        title: title,
        subtitle: subtitle,
        items: items,
        sportsItems: sportsItems,
        brandItems: brandItems,
        presentation: presentation,
        data: data,
        badge: badge,
      );
    }).toList();

    // 3. Apply preferences/limits
    if (preferences?.maximumSections != null && composed.length > preferences!.maximumSections!) {
      return composed.take(preferences.maximumSections!).toList();
    }

    // TV Rule: Limit expandable posters (expandablePoster) to a maximum of 3 in Home
    if (ResponsiveUtils.isTV) {
      int expandableCount = 0;
      for (int i = 0; i < composed.length; i++) {
        final sec = composed[i];
        if (sec.presentation == SectionPresentation.expandablePoster) {
          expandableCount++;
          if (expandableCount > 3) {
            composed[i] = ComposedHomeSection(
              id: sec.id,
              type: sec.type,
              title: sec.title,
              subtitle: sec.subtitle,
              items: sec.items,
              sportsItems: sec.sportsItems,
              brandItems: sec.brandItems,
              presentation: SectionPresentation.wide,
              data: sec.data,
              badge: sec.badge,
            );
            debugPrint('📺 [SectionComposer] TV Rule: Excess expandablePoster (#$expandableCount) downgraded to WIDE (Max 3 allowed on TV)');
          }
        }
      }
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
