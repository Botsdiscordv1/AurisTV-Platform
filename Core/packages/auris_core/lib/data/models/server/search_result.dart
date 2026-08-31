import '../../../core/api/api_endpoints.dart';

class SearchResult {
  final String title;
  final String url;
  final String quality;
  final String thumbnail;
  final String? banner;
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

  final List<SourceItem> sources;

  const SearchResult({
    required this.title,
    required this.url,
    required this.quality,
    required this.thumbnail,
    this.banner,
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
    this.sources = const [],
  });

  SearchResult copyWith({
    String? title,
    String? url,
    String? quality,
    String? thumbnail,
    String? banner,
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
    List<SourceItem>? sources,
  }) {
    return SearchResult(
      title: title ?? this.title,
      url: url ?? this.url,
      quality: quality ?? this.quality,
      thumbnail: thumbnail ?? this.thumbnail,
      banner: banner ?? this.banner,
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
      sources: sources ?? this.sources,
    );
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      thumbnail: ApiEndpoints.proxyImage(
        json['thumbnail'] as String? ?? 
        json['poster'] as String? ?? 
        json['posterUrl'] as String? ?? 
        json['cover'] as String? ?? 
        json['coverImage'] as String? ?? 
        json['image'] as String?
      ),
      banner: ApiEndpoints.proxyImage(json['banner'] as String? ?? json['backdrop'] as String?),
      logo: ApiEndpoints.proxyImage(json['logo'] as String?),
      source: json['source'] as String? ?? '',
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      year: _parseInt(json['year']),
      slug: json['slug'] as String?,
      scrapedTitle: json['scrapedTitle'] as String?,
      metadataTitle: json['metadataTitle'] as String?,
      forcedTitle: json['forcedTitle'] as bool?,
      fromDiscovery: json['fromDiscovery'] as bool?,
      score: _parseDouble(json['score']),
      fullDate: json['fullDate'] as String?,
      trailerKey: json['trailerKey'] as String?,
      synopsis: json['synopsis'] as String?,
      status: json['status'] as String?,
      kind: json['kind'] as String?,
      type: json['type'] as String?,
      season: _parseInt(json['season']),
      totalSeasons: _parseInt(json['totalSeasons']),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceItem.fromJson(e as Map<String, dynamic>))
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
      'banner': banner,
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
    'sources': sources.map((e) => e.toJson()).toList(),
  };
}

class SourceItem {
  final String source;
  final String url;
  final String quality;
  final String? slug;

  const SourceItem({
    required this.source,
    required this.url,
    required this.quality,
    this.slug,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      source: json['source'] as String? ?? '',
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      slug: json['slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'url': url,
    'quality': quality,
    'slug': slug,
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

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: json['query'] as String? ?? '',
      category: json['category'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
