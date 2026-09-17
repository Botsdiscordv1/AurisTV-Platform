import '../editorial_badge.dart';
import 'search_result.dart';
import '../../../core/api/api_endpoints.dart';

class EditorialSection {
  final String id;
  final String title;
  final String? subtitle;
  final String badge;
  final List<EditorialItem> items;
  final String? format; // Senior Fix: Soporte para Server-Driven UI (poster, wide, top10)

  const EditorialSection({
    required this.id,
    required this.title,
    required this.badge,
    required this.items,
    this.subtitle,
    this.format,
  });

  factory EditorialSection.fromJson(Map<String, dynamic> json) {
    return EditorialSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      badge: json['badge'] as String? ?? '',
      format: json['format'] as String? ?? 
              json['layout'] as String? ?? 
              json['layoutType'] as String? ?? 
              json['carousel'] as String? ?? 
              json['displayMode'] as String? ?? 
              json['carouselType'] as String?,
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
    'format': format,
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
  final String? url;
  final String? detailUrl;
  final String? kind;
  final String? type;
  final List<String> genres;
  final List<SourceItem> sources;
  final String? logoUrl;
  final int? tmdbId;
  final int? episode;
  final int? airingAt;
  final String? certification;
  final String? status;
  final bool available;

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
    this.url,
    this.detailUrl,
    this.kind,
    this.type,
    this.genres = const [],
    this.sources = const [],
    this.logoUrl,
    this.tmdbId,
    this.episode,
    this.airingAt,
    this.certification,
    this.status,
    this.available = true,
  });

  factory EditorialItem.fromJson(Map<String, dynamic> json) {
    final String? rawPoster = json['posterUrl'] as String? ?? json['poster'] as String? ?? json['thumbnail'] as String?;
    final String? rawBanner = json['bannerUrl'] as String? ?? json['banner'] as String? ?? json['backdropUrl'] as String? ?? json['backdrop_url'] as String?;
    final String sourceHint = json['source'] as String? ?? json['url'] as String? ?? '';

    return EditorialItem(
      id: switch (json['id']) {
        String s => s,
        num n => n.toString(),
        _ => '',
      },
      title: json['title'] as String? ?? '',
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      posterUrl: ApiEndpoints.proxyImage(rawPoster, source: sourceHint, category: json['kind'] as String?),
      bannerUrl: ApiEndpoints.proxyImage(rawBanner, highQuality: true, source: sourceHint, category: json['kind'] as String?),
      trailerKey: json['trailerKey'] as String?,
      synopsis: json['synopsis'] as String?,
      rating: switch (json['rating']) {
        num value => value.toDouble(),
        _ => null,
      },
      year: switch (json['year']) {
        String s => s,
        num n => n.toString(),
        _ => null,
      },
      subtitle: json['subtitle'] as String?,
      badge: json['badge'] as String? ?? '',
      source: json['source'] as String? ?? '',
      url: json['url'] as String? ?? json['detailUrl'] as String?,
      detailUrl: json['detailUrl'] as String? ?? json['url'] as String?,
      kind: json['kind'] as String?,
      type: json['type'] as String?,
      genres: (json['genresTranslated'] as List<dynamic>? ?? json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceItem.fromJson(e as Map))
              .toList() ??
          const [],
      logoUrl: json['logoUrl'] as String? ?? json['logo'] as String?,
      tmdbId: switch (json['tmdbId']) {
        num value => value.toInt(),
        _ => null,
      },
      episode: switch (json['episode']) {
        num value => value.toInt(),
        _ => null,
      },
      airingAt: switch (json['airingAt']) {
        num value => value.toInt(),
        _ => null,
      },
      certification: json['certification'] as String?,
      status: json['status'] as String?,
      available: json['available'] as bool? ?? true,
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
    'url': url,
    'detailUrl': detailUrl,
    'kind': kind,
    'type': type,
    'genres': genres,
    'sources': sources.map((e) => e.toJson()).toList(),
    'logoUrl': logoUrl,
    'tmdbId': tmdbId,
    'episode': episode,
    'airingAt': airingAt,
    'certification': certification,
    'status': status,
    'available': available,
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
    final Map<String, dynamic> data = (json.containsKey('data') && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    return EditorialResponse(
      generatedAt: data['generatedAt'] as String? ?? '',
      locale: data['locale'] as String? ?? '',
      sections: (data['sections'] as List<dynamic>?)
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
