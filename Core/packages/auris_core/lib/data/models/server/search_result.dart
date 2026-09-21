import 'package:collection/collection.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/image_policy.dart';

class SearchResult {
  final String title;
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
  final int? season;
  final int? totalSeasons;
  final List<String>? genres;
  final double? progress;
  final String? sectionId;

  final List<SourceItem> sources;

  const SearchResult({
    required this.title,
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
    int? season,
    int? totalSeasons,
    List<String>? genres,
    double? progress,
    String? sectionId,
    List<SourceItem>? sources,
  }) {
    return SearchResult(
      title: title ?? this.title,
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
        json['banner']?.toString() ?? json['backdrop']?.toString(), 
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
      score: _parseDouble(json['score']),
      fullDate: json['fullDate']?.toString(),
      trailerKey: json['trailerKey']?.toString() ?? json['trailer_key']?.toString(),
      synopsis: json['synopsis']?.toString(),
      status: json['status']?.toString(),
      kind: json['kind']?.toString(),
      type: json['type']?.toString(),
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

  const SearchResponse({
    required this.query,
    required this.category,
    required this.count,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<dynamic, dynamic> json) {
    return SearchResponse(
      query: json['query']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      count: switch (json['count']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map))
              .toList() ??
          [],
    );
  }
}
