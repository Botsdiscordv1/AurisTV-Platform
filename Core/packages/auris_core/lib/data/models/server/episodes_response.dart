import '../../../core/api/api_endpoints.dart';
import 'package:flutter/foundation.dart';

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

  const RelatedInfo({
    required this.title,
    required this.url,
    required this.slug,
    required this.cover,
    required this.relation,
    this.category,
    this.source,
  });

  RelatedInfo copyWith({String? source}) {
    return RelatedInfo(
      title: title,
      url: url,
      slug: slug,
      cover: cover,
      relation: relation,
      category: category,
      source: source ?? this.source,
    );
  }

  factory RelatedInfo.fromJson(Map<String, dynamic> json) {
    return RelatedInfo(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
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
      source: json['source'] as String?,
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
