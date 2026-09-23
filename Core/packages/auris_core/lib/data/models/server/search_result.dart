import 'package:collection/collection.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/image_policy.dart';

class SearchResult {
  final String title;
  final String? originalTitle;
  final String url;
  final String quality;
  final String thumbnail;
  final String? tmdbThumbnail;
  final String? banner;
  final String? tmdbBanner;
  final String? logo;
  final String source;
  final String? romaji;
  final String? english;
  final int? year;
  final String? slug;
  final String? scrapedTitle;
  final String? metadataTitle;
  final bool? forcedTitle;
  final bool? fromDiscovery;
  final double? score;
  final String? fullDate;
  final String? trailerKey;
  final String? synopsis;
  final String? status;
  final String? kind;
  final String? type;
  final String? layout;
  final int? season;
  final int? totalSeasons;
  final List<String>? genres;
  final double? progress;
  final String? sectionId;

  final List<SourceItem> sources;

  const SearchResult({
    required this.title,
    this.originalTitle,
    required this.url,
    required this.quality,
    required this.thumbnail,
    this.tmdbThumbnail,
    this.banner,
    this.tmdbBanner,
    this.logo,
    required this.source,
    this.romaji,
    this.english,
    this.year,
    this.slug,
    this.scrapedTitle,
    this.metadataTitle,
    this.forcedTitle,
    this.fromDiscovery,
    this.score,
    this.fullDate,
    this.trailerKey,
    this.synopsis,
    this.status,
    this.kind,
    this.type,
    this.layout,
    this.season,
    this.totalSeasons,
    this.genres,
    this.progress,
    this.sectionId,
    this.sources = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          url == other.url &&
          source == other.source &&
          const ListEquality<SourceItem>().equals(sources, other.sources);

  @override
  int get hashCode => Object.hash(
        url,
        source,
        const ListEquality<SourceItem>().hash(sources),
      );

  SearchResult copyWith({
    String? title,
    String? originalTitle,
    String? url,
    String? quality,
    String? thumbnail,
    String? tmdbThumbnail,
    String? banner,
    String? tmdbBanner,
    String? logo,
    String? source,
    String? romaji,
    String? english,
    int? year,
    String? slug,
    String? scrapedTitle,
    String? metadataTitle,
    bool? forcedTitle,
    bool? fromDiscovery,
    double? score,
    String? fullDate,
    String? trailerKey,
    String? synopsis,
    String? status,
    String? kind,
    String? type,
    String? layout,
    int? season,
    int? totalSeasons,
    List<String>? genres,
    double? progress,
    String? sectionId,
    List<SourceItem>? sources,
  }) {
    return SearchResult(
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      url: url ?? this.url,
      quality: quality ?? this.quality,
      thumbnail: thumbnail ?? this.thumbnail,
      tmdbThumbnail: tmdbThumbnail ?? this.tmdbThumbnail,
      banner: banner ?? this.banner,
      tmdbBanner: tmdbBanner ?? this.tmdbBanner,
      logo: logo ?? this.logo,
      source: source ?? this.source,
      romaji: romaji ?? this.romaji,
      english: english ?? this.english,
      year: year ?? this.year,
      slug: slug ?? this.slug,
      scrapedTitle: scrapedTitle ?? this.scrapedTitle,
      metadataTitle: metadataTitle ?? this.metadataTitle,
      forcedTitle: forcedTitle ?? this.forcedTitle,
      fromDiscovery: fromDiscovery ?? this.fromDiscovery,
      score: score ?? this.score,
      fullDate: fullDate ?? this.fullDate,
      trailerKey: trailerKey ?? this.trailerKey,
      synopsis: synopsis ?? this.synopsis,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      type: type ?? this.type,
      layout: layout ?? this.layout,
      season: season ?? this.season,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      genres: genres ?? this.genres,
      progress: progress ?? this.progress,
      sectionId: sectionId ?? this.sectionId,
      sources: sources ?? this.sources,
    );
  }

  factory SearchResult.fromJson(Map<dynamic, dynamic> json) {
    return SearchResult(
      title: json['title']?.toString() ?? '',
      originalTitle: json['originalTitle']?.toString(),
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? '',
      thumbnail: ApiEndpoints.proxyImage(
        json['thumbnail']?.toString() ?? 
        json['poster']?.toString() ?? 
        json['posterUrl']?.toString() ?? 
        json['cover']?.toString() ?? 
        json['coverImage']?.toString() ?? 
        json['image']?.toString(),
        policy: ImageSize.poster,
        fallbackUrl: json['tmdbThumbnail']?.toString(),
      ),
      tmdbThumbnail: json['tmdbThumbnail']?.toString(),
      banner: ApiEndpoints.proxyImage(
        json['banner']?.toString() ?? 
        json['backdrop']?.toString() ??
        json['backdropUrl']?.toString(), 
        policy: ImageSize.banner,
        fallbackUrl: json['tmdbBanner']?.toString() ?? json['tmdbBackdrop']?.toString(),
      ),
      tmdbBanner: json['tmdbBanner']?.toString() ?? json['tmdbBackdrop']?.toString(),
      logo: ApiEndpoints.proxyImage(json['logo']?.toString()),
      source: json['source']?.toString() ?? '',
      romaji: json['romaji']?.toString(),
      english: json['english']?.toString(),
      year: _parseInt(json['year']),
      slug: json['slug']?.toString(),
      scrapedTitle: json['scrapedTitle']?.toString(),
      metadataTitle: json['metadataTitle']?.toString(),
      forcedTitle: json['forcedTitle'] as bool?,
      fromDiscovery: json['fromDiscovery'] as bool?,
      score: _parseDouble(json['score'] ?? json['rating']), // Senior Fix: Soporte para 'rating' (Filmografía)
      fullDate: json['fullDate']?.toString(),
      trailerKey: json['trailerKey']?.toString() ?? json['trailer_key']?.toString(),
      synopsis: json['synopsis']?.toString(),
      status: json['status']?.toString(),
      kind: json['kind']?.toString(),
      type: json['type']?.toString(),
      layout: json['layout']?.toString(),
      season: _parseInt(json['season']),
      totalSeasons: _parseInt(json['totalSeasons']),
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList(),
      progress: _parseDouble(json['progress']),
      sectionId: json['sectionId']?.toString(),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceItem.fromJson(e as Map))
              .toList() ??
          [],
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'originalTitle': originalTitle,
    'url': url,
    'quality': quality,
    'thumbnail': thumbnail,
    'tmdbThumbnail': tmdbThumbnail,
      'banner': banner,
    'tmdbBanner': tmdbBanner,
      'logo': logo,
    'source': source,
    'romaji': romaji,
    'english': english,
    'year': year,
    'slug': slug,
    'scrapedTitle': scrapedTitle,
    'metadataTitle': metadataTitle,
    'forcedTitle': forcedTitle,
    'fromDiscovery': fromDiscovery,
    'score': score,
    'fullDate': fullDate,
    'trailerKey': trailerKey,
    'synopsis': synopsis,
    'status': status,
    'kind': kind,
    'type': type,
    'layout': layout,
    'season': season,
    'totalSeasons': totalSeasons,
    'genres': genres,
    'progress': progress,
    'sectionId': sectionId,
    'sources': sources.map((e) => e.toJson()).toList(),
  };
}

class SourceItem {
  final String source;
  final String url;
  final String quality;
  final String? slug;
  final String? type;

  const SourceItem({
    required this.source,
    required this.url,
    required this.quality,
    this.slug,
    this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceItem &&
          url == other.url &&
          source == other.source &&
          quality == other.quality;

  @override
  int get hashCode => Object.hash(url, source, quality);

  factory SourceItem.fromJson(Map<dynamic, dynamic> json) {
    return SourceItem(
      source: json['source']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      quality: json['quality']?.toString() ?? '',
      slug: json['slug']?.toString(),
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'url': url,
        'quality': quality,
        'slug': slug,
        'type': type,
      };
}

class SearchResponse {
  final String query;
  final String category;
  final int count;
  final List<SearchResult> results;
  final int page;
  final bool hasMore;

  // Metadata para filmografía (Actor Detail)
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? gender;
  final List<String> alsoKnownAs;
  final String? knownFor;
  final double? popularity;
  final List<String> roleCharacters;

  const SearchResponse({
    required this.query,
    required this.category,
    required this.count,
    required this.results,
    this.page = 1,
    this.hasMore = false,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.gender,
    this.alsoKnownAs = const [],
    this.knownFor,
    this.popularity,
    this.roleCharacters = const [],
  });

  factory SearchResponse.fromJson(Map<dynamic, dynamic> json) {
    // Senior Fix: Soporte para unwrapping de la llave 'data' del servidor
    final Map<String, dynamic> root = (json.containsKey('data') && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : Map<String, dynamic>.from(json);

    // Senior Fix: El servidor puede enviar la info del actor en la raíz o en un objeto 'actor'/'person'
    final Map<String, dynamic> actorData = (root['actor'] is Map) 
        ? Map<String, dynamic>.from(root['actor'] as Map)
        : (root['person'] is Map ? Map<String, dynamic>.from(root['person'] as Map) : root);

    return SearchResponse(
      query: root['query']?.toString() ?? '',
      category: root['category']?.toString() ?? '',
      count: switch (root['count']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      page: switch (root['page']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 1,
        _ => 1,
      },
      hasMore: root['hasMore'] == true,
      results: (root['results'] as List<dynamic>? ?? root['items'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map))
              .toList() ??
          [],
      biography: actorData['biography']?.toString() ?? actorData['bio']?.toString(),
      birthday: actorData['birthday']?.toString() ?? actorData['birth_date']?.toString(),
      deathday: actorData['deathday']?.toString() ?? actorData['death_date']?.toString(),
      placeOfBirth: actorData['placeOfBirth']?.toString() ?? actorData['place_of_birth']?.toString(),
      gender: actorData['gender']?.toString(),
      alsoKnownAs: (actorData['alsoKnownAs'] as List? ?? actorData['also_known_as'] as List?)?.map((e) => e.toString()).toList() ?? [],
      knownFor: actorData['knownFor']?.toString() ?? actorData['known_for']?.toString(),
      popularity: (actorData['popularity'] as num?)?.toDouble(),
      roleCharacters: (actorData['characters'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
