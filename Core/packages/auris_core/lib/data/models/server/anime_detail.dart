import '../../../core/utils/synopsis_cleaner.dart';
import '../../../core/api/api_endpoints.dart';

class AnimeDetail {
  final String id;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String> synonyms;
  final String? overview;
  final String? poster;
  final String? backdrop;
  final String? banner;
  final String? logo;
  final double? rating;
  final int? episodes;
  final List<String> genres;
  final String? format;
  final String? status;
  final String? season;
  final int? totalSeasons;
  final int? year;
  final int? duration;
  final List<String> tags;
  final List<String> studios;
  final TrailerInfo? trailer;
  final List<RelationInfo> relations;
  final List<RecommendationInfo> recommendations;
  final List<AnimeThemeInfo> openings;
  final List<AnimeThemeInfo> endings;
  final String? certification;
  final List<CharacterInfo> characters;
  final String? kind;
  final Map<int, String> backdropsBySeason;

  const AnimeDetail({
    required this.id,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.synonyms = const [],
    this.overview,
    this.poster,
    this.backdrop,
    this.banner,
    this.logo,
    this.rating,
    this.episodes,
    this.genres = const [],
    this.format,
    this.status,
    this.season,
    this.totalSeasons,
    this.year,
    this.duration,
    this.tags = const [],
    this.studios = const [],
    this.trailer,
    this.relations = const [],
    this.recommendations = const [],
    this.openings = const [],
    this.endings = const [],
    this.certification,
    this.characters = const [],
    this.kind,
    this.backdropsBySeason = const {},
  });

  String? get trailerKey => trailer?.videoId;
  String? get firstAirDate => year?.toString();

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    final root = (json.containsKey('data') && json['data'] is Map)
        ? json['data'] as Map<String, dynamic>
        : json;

    final anime = (root['anime'] as Map<String, dynamic>?) ?? root;
    final visuals = (root['visuals'] as Map<String, dynamic>?) ?? root;
    final themes = (root['themes'] as List<dynamic>?) ?? [];

    final trailerData =
        anime['trailer'] is Map<String, dynamic>
            ? TrailerInfo.fromJson(anime['trailer'] as Map<String, dynamic>)
            : null;

    final openings = <AnimeThemeInfo>[];
    final endings = <AnimeThemeInfo>[];
    for (final t in themes) {
      final theme = AnimeThemeInfo.fromJson(t as Map<String, dynamic>);
      if (theme.type == 'OPENING') {
        openings.add(theme);
      } else if (theme.type == 'ENDING') {
        endings.add(theme);
      }
    }

    final backdropsBySeason = <int, String>{};
    final backdropsData = visuals?['backdrops_by_season'] ?? anime['backdrops_by_season'] ?? root['backdrops_by_season'];
    if (backdropsData is Map) {
      backdropsData.forEach((key, value) {
        final seasonNum = int.tryParse(key.toString());
        if (seasonNum != null && value != null) {
          backdropsBySeason[seasonNum] = ApiEndpoints.proxyImage(value.toString(), highQuality: true);
        }
      });
    }

    return AnimeDetail(
      id: (anime['id'] ?? '').toString(),
      title: anime['title'] as String? ?? '',
      titleEnglish: anime['titleEnglish'] as String?,
      titleJapanese: anime['titleJapanese'] as String?,
      synonyms: (anime['synonyms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      overview: SynopsisCleaner.clean(
        visuals?['overview'] as String? ??
            anime['description'] as String? ??
            root['overview'] as String?,
      ),
      poster: ApiEndpoints.proxyImage(visuals?['poster'] as String? ??
          root['poster'] as String? ??
          root['thumbnail'] as String?),
      backdrop: ApiEndpoints.proxyImage(visuals?['backdrop'] as String? ??
          root['backdrop'] as String? ??
          root['banner'] as String?, highQuality: true),
      banner: ApiEndpoints.proxyImage(visuals?['banner'] as String? ?? root['banner'] as String?, highQuality: true),
      logo: ApiEndpoints.proxyImage(visuals?['logo'] as String? ?? root['logo'] as String?),
      rating: (anime['score'] as num?)?.toDouble(),
      episodes: anime['episodes'] as int?,
      genres: (anime['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      format: anime['type'] as String?,
      status: anime['status'] as String?,
      season: anime['season']?.toString(),
      totalSeasons: (anime['totalSeasons'] as num?)?.toInt(),
      year: anime['year'] as int?,
      duration: anime['duration'] as int?,
      tags: (anime['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      studios: (anime['studios'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      trailer: trailerData,
      relations: (anime['relations'] as List<dynamic>?)
              ?.map((e) => RelationInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: (anime['recommendations'] as List<dynamic>?)
              ?.map(
                  (e) => RecommendationInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      openings: openings,
      endings: endings,
      certification: root['certification'] as String? ??
          visuals?['certification'] as String? ??
          anime['certification'] as String?,
      kind: root['kind'] as String?,
      characters: (root['characters'] as List<dynamic>?)
              ?.map((e) => CharacterInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      backdropsBySeason: backdropsBySeason,
    );
  }
}

class CharacterInfo {
  final String? id;
  final String name;
  final String? image;
  final String? role;
  final List<VoiceActorInfo> voiceActors;

  const CharacterInfo({
    this.id,
    required this.name,
    this.image,
    this.role,
    this.voiceActors = const [],
  });

  factory CharacterInfo.fromJson(Map<String, dynamic> json) {
    return CharacterInfo(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? 'Unknown',
      image: ApiEndpoints.proxyImage(json['image'] as String?),
      role: json['role'] as String?,
      voiceActors: (json['voiceActors'] as List<dynamic>?)
              ?.map((e) => VoiceActorInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class VoiceActorInfo {
  final String? id;
  final String name;
  final String? language;
  final String? image;

  const VoiceActorInfo({
    this.id,
    required this.name,
    this.language,
    this.image,
  });

  factory VoiceActorInfo.fromJson(Map<String, dynamic> json) {
    return VoiceActorInfo(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? 'Unknown',
      language: json['language'] as String?,
      image: ApiEndpoints.proxyImage(json['image'] as String?),
    );
  }
}

class TrailerInfo {
  final String site;
  final String? videoId;
  final String? thumbnail;
  final String? url;

  const TrailerInfo({
    required this.site,
    this.videoId,
    this.thumbnail,
    this.url,
  });

  factory TrailerInfo.fromJson(Map<String, dynamic> json) {
    return TrailerInfo(
      site: json['site'] as String? ?? 'youtube',
      videoId: json['videoId'] as String?,
      thumbnail: ApiEndpoints.proxyImage(json['thumbnail'] as String?),
      url: json['url'] as String?,
    );
  }
}

class RelationInfo {
  final String? id;
  final String title;
  final String relation;
  final String? poster;

  const RelationInfo({this.id, required this.title, required this.relation, this.poster});

  factory RelationInfo.fromJson(Map<String, dynamic> json) {
    final v = (json['visuals'] as Map<String, dynamic>?) ?? json;
    return RelationInfo(
      id: json['id']?.toString(),
      title: json['title'] as String? ?? '',
      relation: json['relation'] as String? ?? 'UNKNOWN',
      poster: ApiEndpoints.proxyImage(
        v['poster'] as String? ??
        v['posterUrl'] as String? ??
        v['poster_path'] as String? ??
        v['thumbnail'] as String? ??
        v['image'] as String? ??
        v['imageUrl'] as String? ??
        v['cover'] as String? ??
        v['coverImage'] as String? ??
        v['cover_image'] as String? ??
        v['img'] as String? ??
        json['poster'] as String? ??
        json['posterUrl'] as String? ??
        json['image'] as String?
      ),
    );
  }
}

class RecommendationInfo {
  final String? id;
  final String title;
  final String? poster;
  final double? score;

  const RecommendationInfo({this.id, required this.title, this.poster, this.score});

  factory RecommendationInfo.fromJson(Map<String, dynamic> json) {
    final v = (json['visuals'] as Map<String, dynamic>?) ?? json;
    return RecommendationInfo(
      id: json['id']?.toString(),
      title: json['title'] as String? ?? '',
      poster: ApiEndpoints.proxyImage(
        v['poster'] as String? ??
        v['posterUrl'] as String? ??
        v['poster_path'] as String? ??
        v['thumbnail'] as String? ??
        v['image'] as String? ??
        v['imageUrl'] as String? ??
        v['cover'] as String? ??
        v['coverImage'] as String? ??
        v['cover_image'] as String? ??
        v['img'] as String? ??
        json['poster'] as String? ??
        json['posterUrl'] as String? ??
        json['image'] as String?
      ),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class AnimeThemeInfo {
  final String title;
  final String artist;
  final String videoUrl;
  final String? video720;
  final String? video1080;
  final String? audioUrl;
  final String? imageUrl;
  final String type;
  final int sequence;

  const AnimeThemeInfo({
    required this.title,
    required this.artist,
    required this.videoUrl,
    this.video720,
    this.video1080,
    this.audioUrl,
    this.imageUrl,
    required this.type,
    this.sequence = 0,
  });

  factory AnimeThemeInfo.fromJson(Map<String, dynamic> json) {
    return AnimeThemeInfo(
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      videoUrl: json['video'] as String? ?? '',
      video720: json['video_720'] as String?,
      video1080: json['video_1080'] as String?,
      audioUrl: json['audio'] as String?,
      imageUrl: ApiEndpoints.proxyImage(
        json['image'] as String? ?? 
        json['imageUrl'] as String? ?? 
        json['thumbnail'] as String? ?? 
        json['cover'] as String?
      ),
      type: json['type'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 0,
    );
  }
}
