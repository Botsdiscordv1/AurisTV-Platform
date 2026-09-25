import '../../../core/utils/synopsis_cleaner.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/image_policy.dart';
import 'shared_models.dart';
import 'anime_detail.dart';

bool _inferIsMovie(Map<String, dynamic> root) {
  final mediaType = root['mediaType']?.toString().toLowerCase();
  final kind = root['kind']?.toString().toLowerCase();
  final type = root['type']?.toString().toLowerCase();
  final seasons = root['seasons'] as List?;
  final totalSeasons = root['totalSeasons'] as int?;
  final totalEpisodes = root['totalEpisodes'] as int?;
  // Series inequívocas
  if (mediaType == 'tv' || kind == 'series' || type == 'tv' || type == 'series') return false;
  if (seasons != null && seasons.isNotEmpty) return false;
  if (totalSeasons != null && totalSeasons > 1) return false;
  if (totalEpisodes != null && totalEpisodes > 1 && mediaType == 'tv') return false;
  // Película inequívoca
  if (mediaType == 'movie' || kind == 'movie' || type == 'movie') return true;
  // Fallback: si tiene seasons es serie
  return true;
}

class MovieDetail {
  final String tmdbId;
  final String? mediaType;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? poster;
  final String? backdrop;
  final String? banner;
  final String? logo;
  final double? rating;
  final double? score;
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
  final List<AnimeThemeInfo> openings;
  final List<AnimeThemeInfo> endings;
  final String? releaseStatus;
  final String? releaseTimestamp;

  const MovieDetail({
    required this.tmdbId,
    this.mediaType,
    required this.title,
    this.originalTitle,
    this.overview,
    this.poster,
    this.backdrop,
    this.banner,
    this.logo,
    this.rating,
    this.score,
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
    this.openings = const [],
    this.endings = const [],
    this.releaseStatus,
    this.releaseTimestamp,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    final root = (json.containsKey('data') && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final openingsData = (root['openings'] as List<dynamic>?) ?? [];
    final endingsData = (root['endings'] as List<dynamic>?) ?? [];
    
    final openings = openingsData
        .whereType<Map>()
        .map((e) => AnimeThemeInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
        
    final endings = endingsData
        .whereType<Map>()
        .map((e) => AnimeThemeInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final seasons = (root['seasons'] as List<dynamic>?)
            ?.map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
            // TMDB fantasma: episodeCount 0 / seasonNumber 0 no se muestra.
            .where((s) => s.seasonNumber > 0 && (s.episodeCount ?? 0) > 0)
            .toList() ??
        [];

    final inferredReleaseDate = root['releaseDate'] as String? ?? 
                                root['airDate'] as String? ?? 
                                (seasons.isNotEmpty ? seasons.first.airDate : null);

    return MovieDetail(
      tmdbId: (root['tmdbId'] ?? '').toString(),
      mediaType: root['mediaType'] as String?,
      title: root['title'] as String? ?? '',
      originalTitle: root['originalTitle'] as String?,
      overview: SynopsisCleaner.clean(root['overview'] as String?),
      poster: ApiEndpoints.proxyImage(root['poster'] as String? ?? root['posterUrl'] as String?, policy: ImageSize.poster),
      backdrop: ApiEndpoints.proxyImage(root['backdrop'] as String? ?? root['backdrop_url'] as String? ?? root['backdropUrl'] as String? ?? root['banner'] as String?, policy: ImageSize.full),
      banner: ApiEndpoints.proxyImage(root['banner'] as String? ?? root['backdrop'] as String? ?? root['backdrop_url'] as String?, policy: ImageSize.banner),
      logo: ApiEndpoints.proxyImage(root['logo'] as String?, policy: ImageSize.tiny),
      rating: (root['rating'] as num? ?? root['score'] as num?)?.toDouble(),
      score: (root['score'] as num? ?? root['rating'] as num?)?.toDouble(),
      voteCount: root['voteCount'] as int?,
      releaseDate: inferredReleaseDate,
      runtime: root['runtime'] as int?,
      episodeRuntime: root['episodeRuntime'] as int?,
      genres: (root['genresTranslated'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (root['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      productionCompanies: (root['productionCompanies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      directors: (root['directors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cast: (root['cast'] as List<dynamic>?)
              ?.map((e) => CastMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: root['status'] as String?,
      languages: (root['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      seasons: (root['seasons'] as List<dynamic>?)
              ?.map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
              // TMDB fantasma: episodeCount 0 / seasonNumber 0 no se muestra.
              .where((s) => s.seasonNumber > 0 && (s.episodeCount ?? 0) > 0)
              .toList() ??
          [],
      totalSeasons: root['totalSeasons'] as int?,
      totalEpisodes: root['totalEpisodes'] as int?,
      certification: root['certification'] as String?,
      platforms: (root['platforms'] as List<dynamic>?)
              ?.map((e) => PlatformInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trailerKey: root['trailerKey'] as String? ?? root['trailer_key'] as String?,
      trailerType: root['trailerType'] as String?,
      homepage: root['homepage'] as String?,
      isMovie: root['isMovie'] as bool? ?? _inferIsMovie(root),
      kind: root['kind'] as String?,
      openings: openings,
      endings: endings,
      releaseStatus: (root['releaseStatus'] ?? root['release_status']) as String?,
      releaseTimestamp: (root['releaseTimestamp'] ?? root['release_timestamp'] ?? root['airDate']) as String?,
    );
  }
}

class CastMember {
  final int? id;
  final String name;
  final String? character;
  final String? profile;

  const CastMember({this.id, required this.name, this.character, this.profile});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: switch (json['id']) {
        final int n => n,
        final String s => int.tryParse(s),
        _ => null,
      },
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
      poster: ApiEndpoints.proxyImage(json['poster'] as String?),
    );
  }
}
