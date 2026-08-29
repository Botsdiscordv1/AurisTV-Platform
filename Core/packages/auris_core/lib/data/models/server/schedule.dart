import '../../../core/api/api_endpoints.dart';

class ScheduleResponse {
  final String season;
  final int year;
  final int total;
  final List<ScheduleDay> days;

  const ScheduleResponse({
    required this.season,
    required this.year,
    required this.total,
    required this.days,
  });

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    return ScheduleResponse(
      season: json['season'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => ScheduleDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScheduleDay {
  final String day;
  final int dayIndex;
  final bool isToday;
  final List<ScheduleItem> items;

  const ScheduleDay({
    required this.day,
    required this.dayIndex,
    this.isToday = false,
    required this.items,
  });

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    return ScheduleDay(
      day: json['day'] as String? ?? '',
      dayIndex: json['dayIndex'] as int? ?? 0,
      isToday: json['isToday'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScheduleItem {
  final int id;
  final String title;
  final String? romaji;
  final String? english;
  final String? native_;
  final List<String> synonyms;
  final String? description;
  final String? coverImage;
  final String? banner;
  final List<String> genres;
  final String? studio;
  final int? episodes;
  final String? format;
  final String? status;
  final double? averageScore;
  final int? nextEpisode;
  final int? airingAt;
  final int? episode;
  final bool aired;
  final bool sourceAvailable;
  final int? year;

  const ScheduleItem({
    required this.id,
    required this.title,
    this.romaji,
    this.english,
    this.native_,
    this.synonyms = const [],
    this.description,
    this.coverImage,
    this.banner,
    this.genres = const [],
    this.studio,
    this.episodes,
    this.format,
    this.status,
    this.averageScore,
    this.nextEpisode,
    this.airingAt,
    this.episode,
    this.aired = false,
    this.sourceAvailable = true,
    this.year,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      native_: json['native'] as String?,
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      coverImage: ApiEndpoints.proxyImage(json['coverImage'] as String?),
      banner: ApiEndpoints.proxyImage(json['banner'] as String?),
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      studio: json['studio'] as String?,
      episodes: json['episodes'] as int?,
      format: json['format'] as String?,
      status: json['status'] as String?,
      averageScore: (json['averageScore'] as num?)?.toDouble(),
      nextEpisode: json['nextEpisode'] as int?,
      airingAt: json['airingAt'] as int?,
      episode: json['episode'] as int?,
      aired: json['aired'] as bool? ?? false,
      sourceAvailable: json['sourceAvailable'] as bool? ?? true,
      year: json['year'] as int?,
    );
  }
}
