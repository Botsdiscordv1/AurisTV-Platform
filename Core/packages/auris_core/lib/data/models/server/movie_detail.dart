import '../../../core/utils/synopsis_cleaner.dart';

class MovieDetail {
  final String tmdbId;
  final String? mediaType;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? poster;
  final String? backdrop;
  final String? logo;
  final double? rating;
  final int? voteCount;
  final String? releaseDate;
  final int? runtime;
  final int? episodeRuntime;
  final List<String> genres;
  final List<String> productionCompanies;
  final List<String> directors;
  final List<CastMember> cast;
  final String? status;
  final List<String> languages;
  final List<SeasonInfo> seasons;
  final int? totalSeasons;
  final int? totalEpisodes;
  final String? certification;
  final List<PlatformInfo> platforms;
  final String? trailerKey;
  final String? trailerType;
  final String? homepage;
  final bool isMovie;
  final String? kind;

  const MovieDetail({
    required this.tmdbId,
    this.mediaType,
    required this.title,
    this.originalTitle,
    this.overview,
    this.poster,
    this.backdrop,
    this.logo,
    this.rating,
    this.voteCount,
    this.releaseDate,
    this.runtime,
    this.episodeRuntime,
    this.genres = const [],
    this.productionCompanies = const [],
    this.directors = const [],
    this. cast = const [],
    this.status,
    this.languages = const [],
    this.seasons = const [],
    this.totalSeasons,
    this.totalEpisodes,
    this.certification,
    this.platforms = const [],
    this.trailerKey,
    this.trailerType,
    this.homepage,
    this.isMovie = true,
    this.kind,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    return MovieDetail(
      tmdbId: (json['tmdbId'] ?? '').toString(),
      mediaType: json['mediaType'] as String?,
      title: json['title'] as String? ?? '',
      originalTitle: json['originalTitle'] as String?,
      overview: SynopsisCleaner.clean(json['overview'] as String?),
      poster: json['poster'] as String?,
      backdrop: json['backdrop'] as String?,
      logo: json['logo'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      voteCount: json['voteCount'] as int?,
      releaseDate: json['releaseDate'] as String?,
      runtime: json['runtime'] as int?,
      episodeRuntime: json['episodeRuntime'] as int?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      productionCompanies: (json['productionCompanies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      directors: (json['directors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cast: (json['cast'] as List<dynamic>?)
              ?.map((e) => CastMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      seasons: (json['seasons'] as List<dynamic>?)
              ?.map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalSeasons: json['totalSeasons'] as int?,
      totalEpisodes: json['totalEpisodes'] as int?,
      certification: json['certification'] as String?,
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => PlatformInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trailerKey: json['trailerKey'] as String?,
      trailerType: json['trailerType'] as String?,
      homepage: json['homepage'] as String?,
      isMovie: json['isMovie'] as bool? ?? true,
      kind: json['kind'] as String?,
    );
  }
}

class CastMember {
  final String name;
  final String? character;
  final String? profile;

  const CastMember({required this.name, this.character, this.profile});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] as String? ?? '',
      character: json['character'] as String?,
      profile: json['profile'] as String?,
    );
  }
}

class SeasonInfo {
  final int seasonNumber;
  final String? name;
  final int? episodeCount;
  final String? airDate;
  final String? poster;

  const SeasonInfo({
    required this.seasonNumber,
    this.name,
    this.episodeCount,
    this.airDate,
    this.poster,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      seasonNumber: json['seasonNumber'] as int? ?? 0,
      name: json['name'] as String?,
      episodeCount: json['episodeCount'] as int?,
      airDate: json['airDate'] as String?,
      poster: json['poster'] as String?,
    );
  }
}

class PlatformInfo {
  final String providerName;
  final String? logo;

  const PlatformInfo({required this.providerName, this.logo});

  factory PlatformInfo.fromJson(Map<String, dynamic> json) {
    return PlatformInfo(
      providerName: json['providerName'] as String? ?? '',
      logo: json['logo'] as String?,
    );
  }
}
