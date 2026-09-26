import 'editorial_badge.dart';
import 'playback_history.dart';
import 'server/search_result.dart';
import 'server/schedule.dart';
import 'server/detail_params.dart';

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
  // Extras del hero del servidor (opcionales, defaults seguros).
  final List<String> genres;
  final String? certification;
  final bool available;
  final String? detailUrl;
  final int? tmdbId;
  final String? animeId;
  final double? score;
  final List<String> reasonKeys;
  final PlaybackHistory? playbackHistory;
  final String? sectionId;

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
    this.genres = const [],
    this.certification,
    this.available = true,
    this.detailUrl,
    this.tmdbId,
    this.animeId,
    this.score,
    this.reasonKeys = const [],
    this.playbackHistory,
    this.sectionId,
    this.card,
  });

  MediaItem copyWith({
    String? bannerUrl,
    PlaybackHistory? playbackHistory,
    String? sectionId,
    bool? available,
  }) {
    return MediaItem(
      id: id,
      title: title,
      romaji: romaji,
      english: english,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl,
      trailerKey: trailerKey,
      type: type,
      synopsis: synopsis,
      rating: rating,
      subtitle: subtitle,
      episodes: episodes,
      source: source,
      year: year,
      episode: episode,
      airingAt: airingAt,
      aired: aired,
      editorialBadge: editorialBadge,
      genres: genres,
      certification: certification,
      available: available ?? this.available,
      detailUrl: detailUrl,
      tmdbId: tmdbId,
      animeId: animeId,
      score: score,
      reasonKeys: reasonKeys,
      playbackHistory: playbackHistory ?? this.playbackHistory,
      sectionId: sectionId ?? this.sectionId,
      card: card,
    );
  }
}

extension MediaItemToSeed on MediaItem {
  SearchResult toContentSeed() => card ??
      SearchResult(
        title: title,
        url: detailUrl ?? id,
        quality: 'TV',
        thumbnail: posterUrl,
        banner: bannerUrl,
        source: source,
        romaji: romaji,
        english: english,
        year: year,
        trailerKey: trailerKey,
        slug: null,
        kind: switch (type) {
          MediaType.movie => 'movie',
          MediaType.series => 'series',
          MediaType.kdrama => 'kdrama',
          MediaType.anime => 'anime',
        },
        type: switch (type) {
          MediaType.movie => 'movie',
          MediaType.series => 'series',
          MediaType.kdrama => 'kdrama',
          MediaType.anime => 'anime',
        },
      );
}

extension MediaItemToDetailParams on MediaItem {
  UnifiedDetailParams toUnifiedDetailParams({String? sectionId}) {
    final String cat = switch (type) {
      MediaType.anime => 'anime',
      MediaType.movie => 'movie',
      MediaType.series => 'series',
      MediaType.kdrama => 'kdrama',
    };
    return UnifiedDetailParams(
      title: title,
      metadataTitle: english ?? romaji,
      category: cat,
      kind: card?.kind ?? type.name,
      year: year,
      source: source,
      url: detailUrl ?? id,
      type: card?.type ?? type.name,
      sectionId: sectionId ?? this.sectionId,
      initialSources: card != null ? [card!] : null,
    );
  }
}

extension ScheduleItemToMediaItem on ScheduleItem {
  MediaItem toMediaItem() {
    final String rawKind = kind?.toLowerCase() ?? 'anime';
    MediaType mediaType = MediaType.anime;
    if (rawKind == 'movie') {
      mediaType = MediaType.movie;
    } else if (rawKind == 'series') {
      mediaType = MediaType.series;
    } else if (rawKind == 'kdrama') {
      mediaType = MediaType.kdrama;
    }

    final cardItem = SearchResult(
      title: title,
      url: url ?? id.toString(),
      source: source ?? (mediaType == MediaType.anime ? 'AniList' : 'TMDB'),
      quality: quality ?? type ?? 'TV',
      thumbnail: coverImage ?? '',
      banner: banner,
      romaji: romaji,
      english: english,
      year: year,
      slug: slug,
      score: averageScore,
      synopsis: description,
      status: status,
      kind: kind,
      type: type,
      genres: genres,
      sources: sources.map((s) => SourceItem(
        source: s.source,
        url: s.url,
        quality: s.quality,
        slug: s.slug,
        type: s.type,
      )).toList(),
    );

    return MediaItem(
      id: id.toString(),
      title: title,
      romaji: romaji,
      english: english,
      posterUrl: coverImage ?? '',
      bannerUrl: banner,
      type: mediaType,
      synopsis: description,
      rating: averageScore,
      year: year,
      episode: episode,
      airingAt: airingAt,
      genres: genres,
      detailUrl: url ?? id.toString(),
      source: source ?? (mediaType == MediaType.anime ? 'AniList' : 'TMDB'),
      card: cardItem,
    );
  }
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
