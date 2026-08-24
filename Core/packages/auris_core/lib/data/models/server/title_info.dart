class AnimeTitleInfo {
  final String? en;
  final String? romaji;
  final List<String> extra;
  final List<SeasonEntry> seasons;

  const AnimeTitleInfo({
    this.en,
    this.romaji,
    this.extra = const [],
    this.seasons = const [],
  });

  factory AnimeTitleInfo.fromJson(Map<String, dynamic> json) {
    return AnimeTitleInfo(
      en: json['en'] as String?,
      romaji: json['romaji'] as String?,
      extra: (json['extra'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      seasons: (json['seasons'] as List<dynamic>?)
              ?.map((e) => SeasonEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SeasonEntry {
  final String title;
  final String? romaji;
  final int? year;
  final int? malId;
  final String? type;

  const SeasonEntry({
    required this.title,
    this.romaji,
    this.year,
    this.malId,
    this.type,
  });

  factory SeasonEntry.fromJson(Map<String, dynamic> json) {
    return SeasonEntry(
      title: json['title'] as String? ?? '',
      romaji: json['romaji'] as String?,
      year: json['year'] as int?,
      malId: json['mal_id'] as int?,
      type: json['type'] as String?,
    );
  }
}

class MovieTitleInfo {
  final String? movie;
  final String? tv;
  final List<String> extra;
  final int? movieId;
  final int? tvId;

  const MovieTitleInfo({
    this.movie,
    this.tv,
    this.extra = const [],
    this.movieId,
    this.tvId,
  });

  factory MovieTitleInfo.fromJson(Map<String, dynamic> json) {
    return MovieTitleInfo(
      movie: json['movie'] as String?,
      tv: json['tv'] as String?,
      extra: (json['extra'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      movieId: json['movieId'] as int?,
      tvId: json['tvId'] as int?,
    );
  }
}
