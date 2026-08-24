import 'editorial_badge.dart';
import 'server/search_result.dart';

enum MediaType { anime, series, kdrama, movie }

class MediaItem {
  final String id;
  final String title;
  final String? romaji;
  final String? english;
  final String posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final String? trailerKey;
  final MediaType type;
  final String? synopsis;
  final double? rating;
  final String? subtitle;
  final List<Episode> episodes;
  final String source;
  final int? year;
  final int? episode;
  final int? airingAt;
  final bool aired;
  final EditorialBadge? editorialBadge;

  final SearchResult? card;

  const MediaItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.type,
    this.romaji,
    this.english,
    this.bannerUrl,
    this.logoUrl,
    this.trailerKey,
    this.synopsis,
    this.rating,
    this.subtitle,
    this.episodes = const [],
    this.source = '',
    this.year,
    this.episode,
    this.airingAt,
    this.aired = false,
    this.editorialBadge,
    this.card,
  });
}

extension MediaItemToSeed on MediaItem {
  SearchResult toContentSeed() => card ??
      SearchResult(
        title: title,
        url: id,
        quality: 'TV',
        thumbnail: posterUrl,
        banner: bannerUrl,
        source: source,
        romaji: romaji,
        english: english,
        year: year,
        slug: null,
      );
}

class Episode {
  final String id;
  final int number;
  final String title;
  final String sourceUrl;
  final Duration? progress;
  final Duration? totalDuration;

  const Episode({
    required this.id,
    required this.number,
    required this.title,
    required this.sourceUrl,
    this.progress,
    this.totalDuration,
  });
}
