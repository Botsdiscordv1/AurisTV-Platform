import 'package:auris_core/data/models/media_item.dart';
import 'package:auris_core/data/models/server/search_result.dart';

/// Entidad unificada que representa cualquier contenido (Anime, Película o Serie)
/// en cualquier estado del ciclo de vida (Búsqueda, Home, Detalle).
///
/// Actúa como el modelo de dominio único para reducir la fragmentación entre
/// [MediaItem] y [SearchResult].
class ContentEntity {
  final String id;
  final String title;
  final String? romaji;
  final String? english;
  final String posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final MediaType type;
  final String source;
  final int? year;
  final int? season;
  final int? episode;
  final double? rating;
  final String? synopsis;
  final List<String> genres;
  
  /// El objeto original del servidor si está disponible.
  final SearchResult? rawResult;

  const ContentEntity({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.type,
    required this.source,
    this.romaji,
    this.english,
    this.bannerUrl,
    this.logoUrl,
    this.year,
    this.season,
    this.episode,
    this.rating,
    this.synopsis,
    this.genres = const [],
    this.rawResult,
  });

  /// Crea una entidad desde un [SearchResult] (Búsqueda).
  factory ContentEntity.fromSearchResult(SearchResult result, {MediaType? fallbackType}) {
    return ContentEntity(
      id: result.url,
      title: result.title,
      romaji: result.romaji,
      english: result.english,
      posterUrl: result.thumbnail,
      bannerUrl: result.banner,
      logoUrl: result.logo,
      type: fallbackType ?? _inferType(result),
      source: result.source,
      year: result.year,
      season: result.season,
      rating: result.score,
      synopsis: result.synopsis,
      genres: result.genres ?? [],
      rawResult: result,
    );
  }

  /// Crea una entidad desde un [MediaItem] (Home/Legacy).
  factory ContentEntity.fromMediaItem(MediaItem item) {
    return ContentEntity(
      id: item.id,
      title: item.title,
      romaji: item.romaji,
      english: item.english,
      posterUrl: item.posterUrl,
      bannerUrl: item.bannerUrl,
      logoUrl: item.logoUrl,
      type: item.type,
      source: item.source,
      year: item.year,
      episode: item.episode,
      airingAt: item.airingAt,
      rating: item.rating,
      synopsis: item.synopsis,
      genres: item.genres,
      rawResult: item.card,
    );
  }
  
  final int? airingAt;

  static MediaType _inferType(SearchResult r) {
    final k = r.kind?.toLowerCase() ?? '';
    if (k.contains('anime')) return MediaType.anime;
    if (k.contains('movie')) return MediaType.movie;
    if (k.contains('series') || k.contains('tv')) return MediaType.series;
    return MediaType.anime;
  }
}
