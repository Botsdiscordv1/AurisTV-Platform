import '../editorial_badge.dart';
import '../../../core/api/api_endpoints.dart';

class EditorialSection {
  final String id;
  final String title;
  final String? subtitle;
  final String badge;
  final List<EditorialItem> items;

  const EditorialSection({
    required this.id,
    required this.title,
    required this.badge,
    required this.items,
    this.subtitle,
  });

  factory EditorialSection.fromJson(Map<String, dynamic> json) {
    return EditorialSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      badge: json['badge'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => EditorialItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'badge': badge,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class EditorialItem {
  final String id;
  final String title;
  final String? romaji;
  final String? english;
  final String posterUrl;
  final String? bannerUrl;
  final String? trailerKey;
  final String? synopsis;
  final double? rating;
  final String? year;
  final String? subtitle;
  final String badge;
  final String source;

  const EditorialItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.badge,
    this.romaji,
    this.english,
    this.bannerUrl,
    this.trailerKey,
    this.synopsis,
    this.rating,
    this.year,
    this.subtitle,
    this.source = '',
  });

  factory EditorialItem.fromJson(Map<String, dynamic> json) {
    return EditorialItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      posterUrl: ApiEndpoints.proxyImage(json['posterUrl'] as String?),
      bannerUrl: ApiEndpoints.proxyImage(json['bannerUrl'] as String?, highQuality: true),
      trailerKey: json['trailerKey'] as String?,
      synopsis: json['synopsis'] as String?,
      rating: switch (json['rating']) {
        num value => value.toDouble(),
        _ => null,
      },
      year: json['year'] as String?,
      subtitle: json['subtitle'] as String?,
      badge: json['badge'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'romaji': romaji,
    'english': english,
    'posterUrl': posterUrl,
    'bannerUrl': bannerUrl,
    'trailerKey': trailerKey,
    'synopsis': synopsis,
    'rating': rating,
    'year': year,
    'subtitle': subtitle,
    'badge': badge,
    'source': source,
  };
}

class EditorialResponse {
  final String generatedAt;
  final String locale;
  final List<EditorialSection> sections;

  const EditorialResponse({
    required this.generatedAt,
    required this.locale,
    required this.sections,
  });

  factory EditorialResponse.fromJson(Map<String, dynamic> json) {
    return EditorialResponse(
      generatedAt: json['generatedAt'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => EditorialSection.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt,
    'locale': locale,
    'sections': sections.map((e) => e.toJson()).toList(),
  };
}

EditorialBadge? editorialBadgeFromString(String? badge) {
  switch (badge) {
    case 'mythical':
      return EditorialBadge.mythical;
    case 'masterpiece':
      return EditorialBadge.masterpiece;
    case 'hiddenGem':
      return EditorialBadge.hiddenGem;
    case 'essential':
      return EditorialBadge.essential;
    case 'favorite':
      return EditorialBadge.favorite;
    case 'awardWinner':
      return EditorialBadge.awardWinner;
    case 'classic':
      return EditorialBadge.classic;
    case 'starter':
      return EditorialBadge.starter;
    case 'movieEssential':
      return EditorialBadge.movieEssential;
    default:
      return null;
  }
}
