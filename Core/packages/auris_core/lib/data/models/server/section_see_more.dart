class SectionSeeMore {
  final String endpoint;
  final Map<String, dynamic> params;

  const SectionSeeMore({
    required this.endpoint,
    required this.params,
  });

  factory SectionSeeMore.fromJson(Map<String, dynamic> json) {
    return SectionSeeMore(
      endpoint: json['endpoint'] as String? ?? '',
      params: json['params'] is Map 
          ? Map<String, dynamic>.from(json['params'] as Map) 
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'params': params,
  };
}
class SectionFilters {
  final String? strategy;
  final String? category;
  final int? year;
  final List<int>? years;
  final List<String>? genres;
  final String? genreSlug;
  final List<String>? sources;

  const SectionFilters({
    this.strategy,
    this.category,
    this.year,
    this.years,
    this.genres,
    this.genreSlug,
    this.sources,
  });

  factory SectionFilters.fromJson(Map<String, dynamic> json) {
    return SectionFilters(
      strategy: json['strategy'] as String?,
      category: json['category'] as String?,
      year: json['year'] as int?,
      years: (json['years'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      genreSlug: json['genreSlug'] as String?,
      sources: (json['sources'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (strategy != null) 'strategy': strategy,
    if (category != null) 'category': category,
    if (year != null) 'year': year,
    if (years != null) 'years': years,
    if (genres != null) 'genres': genres,
    if (genreSlug != null) 'genreSlug': genreSlug,
    if (sources != null) 'sources': sources,
  };
}
