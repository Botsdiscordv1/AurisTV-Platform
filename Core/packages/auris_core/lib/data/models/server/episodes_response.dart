import '../../../core/api/api_endpoints.dart';
import 'package:flutter/foundation.dart';
import 'search_result.dart';
import 'detail_params.dart';

class EpisodesResponse {
  final String source;
  final String url;
  final String slug;
  final int total;
  final List<EpisodeInfo> episodes;

  final List<EpisodeInfo> specials;

  final int? tmdbId;
  final String? fullTitle;
  final int? season;
  final List<RelatedInfo> relations;
  final List<CastInfo> cast;

  final String? seasonAirDate;

  /// Indica que la temporada pedida no existe en esta fuente (p.ej. AnimeD23
  /// solo tiene S3 y se pidió S1/S2). Lo usa el core para no listar la fuente
  /// en temporadas que no tiene.
  final bool? seasonNotAvailable;
  final String? error;

  const EpisodesResponse({
    required this.source,
    required this.url,
    required this.slug,
    required this.total,
    this.episodes = const [],
    this.specials = const [],
    this.relations = const [],
    this.cast = const [],
    this.tmdbId,
    this.fullTitle,
    this.season,
    this.seasonAirDate,
    this.seasonNotAvailable,
    this.error,
  });

  factory EpisodesResponse.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print("[EpisodesResponse.fromJson] json['seasonAirDate']: ${json['seasonAirDate']}");
    }
    return EpisodesResponse(
      source: json['source'] as String? ?? '',
      url: json['url'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      fullTitle: json['fullTitle'] as String?,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => EpisodeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      specials: (json['specials'] as List<dynamic>?)
              ?.map((e) => EpisodeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      relations: (json['relations'] as List<dynamic>?)
              ?.map((e) => RelatedInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cast: (json['cast'] as List<dynamic>?)
              ?.map((e) => CastInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tmdbId: json['tmdbId'] as int?,
      season: json['season'] as int?,
      seasonAirDate: json['seasonAirDate'] as String?,
      seasonNotAvailable: json['seasonNotAvailable'] as bool?,
      error: json['error'] as String?,
    );
  }
}

class RelatedInfo {
  final String title;
  final String url;
  final String slug;
  final String cover;
  final String relation;
  final String? category; // Senior Fix: Clasificación servida por el VPS (franquicia | relacionado)
  final String? source;
  final String? kind; // movie | serie | anime | null
  final int? year;

  const RelatedInfo({
    required this.title,
    required this.url,
    required this.slug,
    required this.cover,
    required this.relation,
    this.category,
    this.source,
    this.kind,
    this.year,
  });

  RelatedInfo copyWith({String? source, String? kind, int? year}) {
    return RelatedInfo(
      title: title,
      url: url,
      slug: slug,
      cover: cover,
      relation: relation,
      category: category,
      source: source ?? this.source,
      kind: kind ?? this.kind,
      year: year ?? this.year,
    );
  }

  factory RelatedInfo.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title'] as String? ?? '';
    final rawUrl = json['url'] as String? ?? '';
    final rawSlug = json['slug'] as String? ?? '';

    // Senior Fix: Parsear año de num/String, e inferirlo del título ("(2009)") o URL/slug ("-2009") si es nulo
    int? parsedYear = int.tryParse(json['year']?.toString() ?? '');
    if (parsedYear == null) {
      final titleMatch = RegExp(r'[\(\[]?((?:19|20)\d{2})[\)\]]?').firstMatch(rawTitle);
      if (titleMatch != null) {
        parsedYear = int.tryParse(titleMatch.group(1)!);
      } else {
        final urlMatch = RegExp(r'-(19\d{2}|20\d{2})(?:/|$)').firstMatch(rawSlug.isNotEmpty ? rawSlug : rawUrl);
        if (urlMatch != null) {
          parsedYear = int.tryParse(urlMatch.group(1)!);
        }
      }
    }

    return RelatedInfo(
      title: rawTitle,
      url: rawUrl,
      slug: rawSlug,
      cover: ApiEndpoints.proxyImage(
        json['cover'] as String? ?? 
        json['coverImage'] as String? ?? 
        json['poster'] as String? ?? 
        json['posterUrl'] as String? ?? 
        json['thumbnail'] as String? ?? 
        json['image'] as String?
      ),
      relation: json['relation'] as String? ?? 'Relacionado',
      category: json['category'] as String?,
      kind: json['kind'] as String?,
      source: json['source'] as String?,
      year: parsedYear,
    );
  }

  SearchResult toSearchResult({String? fallbackSource, String? fallbackCategory}) {
    final effectiveSource = (source != null && source!.isNotEmpty) ? source! : (fallbackSource ?? '');
    final effectiveKind = kind ?? category;
    return SearchResult(
      title: title,
      url: url,
      quality: 'HD',
      thumbnail: cover,
      source: effectiveSource,
      kind: effectiveKind,
      type: effectiveKind,
      year: year,
      slug: slug,
    );
  }

  UnifiedDetailParams toUnifiedDetailParams({
    required String fallbackCategory,
    String? fallbackSource,
  }) {
    final effectiveSource = (source != null && source!.isNotEmpty) ? source! : (fallbackSource ?? '');
    final effectiveKind = kind ?? category;
    final effectiveCategory = category ?? kind ?? fallbackCategory;
    return UnifiedDetailParams(
      title: title,
      kind: effectiveKind,
      type: effectiveKind,
      year: year,
      url: url,
      category: effectiveCategory,
      source: effectiveSource,
      initialSources: [toSearchResult(fallbackSource: fallbackSource, fallbackCategory: fallbackCategory)],
    );
  }
}

class CastInfo {
  final int? id;
  final String name;
  final String? character;
  final String? profile;
  final String? rawProfile;
  final String? url;
  final String? slug;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? gender;
  final List<String> alsoKnownAs;
  final String? knownFor;
  final double? popularity;
  final List<String> roleCharacters;

  const CastInfo({
    this.id,
    required this.name,
    this.character,
    this.profile,
    this.rawProfile,
    this.url,
    this.slug,
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

  factory CastInfo.fromJson(Map<String, dynamic> json) {
    return CastInfo(
      id: (json['id'] ?? json['personId']) as int?,
      name: json['name'] as String? ?? '',
      character: json['character'] as String?,
      profile: ApiEndpoints.proxyImage(
        json['profile'] as String? ?? 
        json['image'] as String?
      ),
      rawProfile: json['profile'] as String? ?? json['image'] as String?,
      url: json['urlLI'] as String? ?? json['url'] as String?,
      slug: json['slug'] as String?,
      biography: json['biography'] as String?,
      birthday: json['birthday'] as String?,
      deathday: json['deathday'] as String?,
      placeOfBirth: json['placeOfBirth'] as String?,
      gender: json['gender'] as String?,
      alsoKnownAs: (json['alsoKnownAs'] as List?)?.map((e) => e.toString()).toList() ?? [],
      knownFor: json['knownFor'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      roleCharacters: (json['characters'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class EpisodeInfo {
  final int number;
  final int id;
  final String url;
  final String? title;
  final String? thumbnail;
  final String? description;
  final String? airDate;
  final String? duration;
  final int? runtime;

  final String? quality;

  final String? episodeType;

  final int? tmdbSpecialNumber;
  final bool needsTranslation;

  const EpisodeInfo({
    required this.number,
    required this.id,
    this.url = '',
    this.title,
    this.thumbnail,
    this.description,
    this.airDate,
    this.duration,
    this.runtime,
    this.quality,
    this.episodeType,
    this.tmdbSpecialNumber,
    this.needsTranslation = false,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
      number: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      url: json['url'] as String? ?? '',
      title: json['title'] as String?,
      thumbnail: ApiEndpoints.proxyImage(
        json['thumbnail'] as String? ?? 
        json['image'] as String? ?? 
        json['still_path'] as String?
      ),
      description: json['description'] as String?,
      airDate: json['airDate'] as String?,
      duration: json['duration'] as String?,
      runtime: json['runtime'] as int?,
      quality: json['quality'] as String?,
      episodeType: json['episodeType'] as String?,
      tmdbSpecialNumber: int.tryParse(json['tmdbSpecialNumber']?.toString() ?? ''),
      needsTranslation: json['needsTranslation'] as bool? ?? false,
    );
  }
}
