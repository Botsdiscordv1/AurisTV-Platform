import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../auris_core.dart';

final animeDetailProvider =
    FutureProvider.family<AnimeDetail?, AnimeDetailParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getAnimeDetail(
    title: params.title,
    malId: params.malId,
    metadataTitle: params.metadataTitle,
    year: params.year,
    season: params.season,
    kind: params.kind,
    url: params.url,
    type: params.type,
    imgSize: 'original', // Senior Fix: Calidad máxima para detalles
  );
});

final movieDetailProvider =
    FutureProvider.family<MovieDetail?, MovieDetailParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getMovieDetail(
    title: params.title,
    year: params.year,
    metadataTitle: params.metadataTitle,
    url: params.url,
    type: params.type,
    category: params.category,
    server: params.server,
    kind: params.kind,
    imgSize: 'original', // Senior Fix: Calidad máxima para detalles
  );
});

/// Orquestador unificado de detalles. Decide si consultar el servidor de Anime
/// o el de Películas/Series basándose en metadatos y categorías.
final unifiedContentDetailProvider =
    FutureProvider.family<ContentDetailResponse?, UnifiedDetailParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);

  // 1. Identificar el servidor de origen real basándose en la fuente (source)
  const metadataSourceHints = {'anilist', 'tmdb', 'trakt', 'mal', 'jikan'};
  final isMetadataSource = params.source.isNotEmpty &&
      metadataSourceHints.contains(params.source.toLowerCase());

  final String? sourceServer = (params.source.isNotEmpty && !isMetadataSource)
      ? ApiEndpoints.baseUrlForSource(params.source)
      : null;

  final bool isFromAnimeServer = sourceServer == ApiEndpoints.animeBaseUrl;
  final bool isFromMovieServer = sourceServer == ApiEndpoints.moviesSeriesBaseUrl || 
                                sourceServer == ApiEndpoints.kdramasBaseUrl;

  final rawKind = params.kind?.toLowerCase();

  AnimeDetail? anime;
  MovieDetail? movie;

  // Senior Priority Logic: Si el contenido se identifica como Anime (por categoría, kind o tipo),
  // forzamos la consulta al servidor de Anime para obtener la mejor metadata (AniList/MAL).
  final bool isStrictAnime = params.category.toLowerCase() == 'anime' || 
                             rawKind == 'anime' || 
                             params.type?.toLowerCase() == 'anime';

  if (isStrictAnime || isFromAnimeServer) {
    // Consulta al servidor de anime
    anime = await repo.getAnimeDetail(
      title: cleanTitleForDisplay(stripSeasonSuffix(params.title)),
      metadataTitle: params.metadataTitle != null ? cleanTitleForDisplay(stripSeasonSuffix(params.metadataTitle!)) : null,
      year: params.year,
      season: rawKind == 'movie' ? null : params.season,
      kind: params.kind,
      url: params.url,
      type: params.type,
      imgSize: 'original',
    );
  } else if (isFromMovieServer) {
    // Si viene del servidor movie y no es anime, pedimos a ese servidor.
    movie = await repo.getMovieDetail(
      title: cleanTitleForDisplay(stripSeasonSuffix(params.title)),
      year: params.year,
      metadataTitle: params.metadataTitle != null ? cleanTitleForDisplay(stripSeasonSuffix(params.metadataTitle!)) : null,
      url: params.url,
      type: params.type,
      category: params.category,
      server: sourceServer,
      kind: params.kind,
      imgSize: 'original',
    );
  } else {
    // Fallback para búsquedas globales sin origen claro
    movie = await repo.getMovieDetail(
      title: cleanTitleForDisplay(stripSeasonSuffix(params.title)),
      year: params.year,
      metadataTitle: params.metadataTitle != null ? cleanTitleForDisplay(stripSeasonSuffix(params.metadataTitle!)) : null,
      url: params.url,
      type: params.type,
      category: params.category,
      kind: params.kind,
      imgSize: 'original',
    );
  }

  // Definición clara de la categoría efectiva
  final String trueCategory = anime != null
      ? 'anime'
      : (movie != null
          ? (movie.isMovie ? 'movie' : 'series')
          : params.category);

  return ContentDetailResponse(
    anime: anime,
    movie: movie,
    isMovieish: rawKind == 'movie' || rawKind == 'pelicula' || (movie?.isMovie ?? false),
    effectiveCategory: trueCategory,
  );
});

class ContentDetailResponse {
  final AnimeDetail? anime;
  final MovieDetail? movie;
  final bool isMovieish;
  final String effectiveCategory;

  ContentDetailResponse({
    this.anime,
    this.movie,
    required this.isMovieish,
    required this.effectiveCategory,
  });

  /// Devuelve el detalle "principal" basándose en la clasificación.
  dynamic get main => isMovieish ? (movie ?? anime) : (anime ?? movie);
}

final activeContentSourcesProvider = StateProvider<List<SearchResult>>((ref) => []);

class ExtractParams {
  final String url;
  final String source;
  final String? category;
  const ExtractParams({required this.url, required this.source, this.category});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractParams && url == other.url && source == other.source && category == other.category;

  @override
  int get hashCode => Object.hash(url, source, category);
}

final extractProvider =
    FutureProvider.family<ExtractResult, ExtractParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.extractVideo(params.url, params.source, category: params.category, direct: !kIsWeb);
});

/// Senior Cache: Almacena la extracción del siguiente episodio para carga instantánea.
final nextEpisodePreloadProvider = StateProvider<ExtractResult?>((ref) => null);

/// Senior Prefetch Logic: Gestiona la extracción proactiva del siguiente contenido.
final playerPreloadControllerProvider = Provider((ref) => PlayerPreloadController(ref));

class PlayerPreloadController {
  final Ref ref;
  PlayerPreloadController(this.ref);

  bool _isPreloading = false;
  String? _lastPreloadedUrl;

  /// Dispara la extracción del siguiente episodio si aún no se ha hecho.
  Future<void> triggerNextPreload({
    required String currentSource,
    required String? currentEpisode,
    required int? totalEpisodes,
    required String currentSourceUrl,
    String? category,
  }) async {
    if (_isPreloading || currentEpisode == null) return;
    
    final int? currentNum = int.tryParse(currentEpisode);
    if (currentNum == null) return;
    
    final int nextNum = currentNum + 1;
    if (totalEpisodes != null && nextNum > totalEpisodes) return;

    final sources = ref.read(activeContentSourcesProvider);
    final baseSource = sources.firstWhereOrNull((s) => s.source == currentSource);
    
    if (baseSource != null) {
      final nextUrl = buildEpisodeUrl(baseSource.url, baseSource.source, nextNum);
      if (nextUrl == _lastPreloadedUrl) return;

      _isPreloading = true;
      try {
        final repo = ref.read(aurisRepositoryProvider);
        final extract = await repo.extractVideo(
          nextUrl, 
          baseSource.source, 
          category: category, 
          direct: !kIsWeb
        );
        
        ref.read(nextEpisodePreloadProvider.notifier).state = extract;
        _lastPreloadedUrl = nextUrl;
      } catch (e) {
        debugPrint('[PlayerPreload] Error pre-fetching next episode: $e');
      } finally {
        _isPreloading = false;
      }
    }
  }

  void clearPreload() {
    ref.read(nextEpisodePreloadProvider.notifier).state = null;
    _lastPreloadedUrl = null;
    _isPreloading = false;
  }
}
