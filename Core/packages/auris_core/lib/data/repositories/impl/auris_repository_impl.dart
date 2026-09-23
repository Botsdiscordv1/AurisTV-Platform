import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/image_policy.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/utils/content_logic.dart';
import '../../../core/utils/source_utils.dart';
import '../../models/server/anilist_media.dart';
import '../../models/server/anime_detail.dart';
import '../../models/server/episodes_response.dart';
import '../../models/server/editorial_section.dart';
import '../../models/server/personalized_home.dart';
import '../../models/server/extract_result.dart';
import '../../models/server/movie_detail.dart';
import '../../models/server/omdb_episode.dart';
import '../../models/server/schedule.dart';
import '../../models/server/search_result.dart';
import '../../models/server/source_info.dart';
import '../../models/server/title_info.dart';
import '../../models/server/gallery.dart';
import '../../models/media_item.dart';
import '../auris_repository.dart';

class AurisRepositoryImpl implements AurisRepository {
  final ApiClient _client;
  
  // Senior LRU Cache Layer: Guardamos hasta 50 detalles en memoria con desalojo LRU
  // para evitar fugas de memoria en sesiones largas de navegación.
  static const int _maxCacheEntries = 50;
  final Map<String, AnimeDetail> _animeCache = {};
  final Map<String, MovieDetail> _movieCache = {};

  AnimeDetail? _getAnimeFromCache(String key) {
    final cached = _animeCache.remove(key);
    if (cached != null) {
      _animeCache[key] = cached; // Reinsertar para mover al final (más reciente)
    }
    return cached;
  }

  void _putInAnimeCache(String key, AnimeDetail detail) {
    if (_animeCache.length >= _maxCacheEntries) {
      _animeCache.remove(_animeCache.keys.first); // Eliminar el ítem menos usado (LRU)
    }
    _animeCache[key] = detail;
  }

  MovieDetail? _getMovieFromCache(String key) {
    final cached = _movieCache.remove(key);
    if (cached != null) {
      _movieCache[key] = cached; // Reinsertar para mover al final
    }
    return cached;
  }

  void _putInMovieCache(String key, MovieDetail detail) {
    if (_movieCache.length >= _maxCacheEntries) {
      _movieCache.remove(_movieCache.keys.first); // Eliminar el ítem menos usado (LRU)
    }
    _movieCache[key] = detail;
  }

  AurisRepositoryImpl(this._client);

  @override
  Future<GalleryResponse> getGallery({int? tmdbId, String kind = 'tv', String? title, int? year}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.galleryUrl(tmdbId: tmdbId, kind: kind, title: title, year: year),
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
      final raw = response.data is Map ? response.data as Map<String, dynamic> : null;
      final data = (raw != null && raw.containsKey('data'))
          ? (raw['data'] as Map<String, dynamic>?)
          : raw;
      if (data == null) return const GalleryResponse();
      return GalleryResponse.fromJson(data);
    } catch (e) {
      debugPrint('[AurisRepo] getGallery error: $e');
      return const GalleryResponse();
    }
  }

  @override
  Future<AnilistMedia?> getAnilistMedia(int id) async {
    const query = r'''
      query ($id: Int) {
        Media (id: $id, type: ANIME) {
          id
          title {
            english
            romaji
          }
          bannerImage
          coverImage {
            extraLarge
          }
          episodes
        }
      }
    ''';

    final response = await _client.post(
      'https://graphql.anilist.co',
      data: {
        'query': query,
        'variables': {'id': id},
      },
    );

    if (response.data?['data']?['Media'] == null) return null;
    return AnilistMedia.fromJson(response.data['data']['Media'] as Map<String, dynamic>);
  }

  String _normalizeSearchCategory(String category) {
    final c = category.toLowerCase();
    if (c == 'movie') return 'peliculas';
    if (c == 'anime-movies') return 'movie_anime';
    return category;
  }

  @override
  Future<SearchResponse> search(
    String category, 
    String query, {
    int? year, 
    String? server, 
    String? phase,
    String? imgSize,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    final normalized = _normalizeSearchCategory(category);
    if (server != null) {
      return _searchOn(server, normalized, query, year: year, phase: phase, imgSize: imgSize, page: page, cancelToken: cancelToken);
    }
    final targets = _searchTargetsFor(normalized);
    final filter = normalized.toLowerCase() == 'all' ? null : normalized;
    return _searchFanout(targets, query, year, phase, filterCategory: filter, imgSize: imgSize, page: page, cancelToken: cancelToken);
  }

  @override
  Future<SearchResponse> filter({
    String? genre,
    int? year,
    String? category,
    String? status,
    String? idioma,
    int page = 1,
    String? source,
  }) async {
    try {
      final params = <String, dynamic>{'page': page};
      if (genre != null) {
        params['genre'] = genre;
        params['genero'] = genre;
        params['tag'] = genre;
      }
      if (year != null) {
        params['year'] = year;
        params['anio'] = year;
        params['fecha'] = year;
      }
      if (category != null) {
        params['category'] = category;
        params['tipo'] = category;
        params['kind'] = category;
      }
      if (status != null) {
        params['status'] = status;
        params['estado'] = status;
      }
      if (idioma != null) params['idioma'] = idioma;
      if (source != null) {
        params['source'] = source;
        params['provider'] = source;
      }

      // Senior Fix: Determinar el servidor correcto basado en la categoría
      final String baseUrl = ApiEndpoints.baseUrlForCategory(category ?? 'movie');

      final response = await _client.get(
        ApiEndpoints.filter,
        queryParameters: params,
        baseUrl: baseUrl,
      );

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final List resultsRaw = (data['results'] as List?) ?? (data['data']?['results'] as List?) ?? [];
        
        return SearchResponse(
          query: 'filter',
          category: category ?? 'all',
          count: resultsRaw.length,
          results: resultsRaw.map((e) => SearchResult.fromJson(e as Map)).toList(),
        );
      }
      return SearchResponse(query: 'filter', category: category ?? 'all', count: 0, results: []);
    } catch (e) {
      debugPrint('[AurisRepo] Filter error: $e');
      return SearchResponse(query: 'filter', category: category ?? 'all', count: 0, results: []);
    }
  }

  @override
  Stream<SearchResponse> searchStream(
    String category, 
    String query, {
    int? year, 
    String? server, 
    String? phase,
    String? imgSize,
    CancelToken? cancelToken,
  }) async* {
    final normalized = _normalizeSearchCategory(category);
    
    // Si se especifica un servidor concreto, buscamos solo ahí
    if (server != null) {
      yield* _searchStreamOn(server, normalized, query, year: year, phase: phase, imgSize: imgSize, cancelToken: cancelToken);
      return;
    }

    // Senior Fanout Logic: Lanzamiento escalonado para evitar agotar el pool de conexiones del navegador (Límite 6)
    final targets = _searchTargetsFor(normalized);
    final controller = StreamController<SearchResponse>();
    int completed = 0;

    // 1. Lanzamos el primer target inmediatamente
    _searchStreamOn(targets.first, normalized, query, year: year, phase: phase, imgSize: imgSize, cancelToken: cancelToken)
      .listen(
        (data) { if (!controller.isClosed) controller.add(data); },
        onError: (e) { if (e is! DioException || e.type != DioExceptionType.cancel) debugPrint('[AurisRepo] Stream error 1: $e'); },
        onDone: () { completed++; if (completed == targets.length && !controller.isClosed) controller.close(); },
      );

    // 2. Retrasamos los demás para dar tiempo a la cancelación si el usuario sigue escribiendo
    if (targets.length > 1) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (cancelToken?.isCancelled == true || controller.isClosed) return;
        
        for (int i = 1; i < targets.length; i++) {
          _searchStreamOn(targets[i], normalized, query, year: year, phase: phase, imgSize: imgSize, cancelToken: cancelToken)
            .listen(
              (data) { if (!controller.isClosed) controller.add(data); },
              onError: (e) { if (e is! DioException || e.type != DioExceptionType.cancel) debugPrint('[AurisRepo] Stream error $i: $e'); },
              onDone: () { completed++; if (completed == targets.length && !controller.isClosed) controller.close(); },
            );
        }
      });
    }

    yield* controller.stream;
  }

  Stream<SearchResponse> _searchStreamOn(
    String server,
    String category,
    String query, {
    int? year,
    String? phase,
    String? imgSize,
    CancelToken? cancelToken,
  }) async* {
    final stream = _client.getStream(
      ApiEndpoints.searchByCategory(category),
      queryParameters: {
        'q': query,
        if (year != null) 'year': year,
        if (phase != null) 'phase': phase,
        if (imgSize != null) 'img': imgSize,
        'stream': '1',
      },
      baseUrl: server,
      cancelToken: cancelToken,
    );

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        final Map<String, dynamic> data = (decoded is Map && decoded.containsKey('data')) 
            ? decoded['data'] 
            : decoded;
        
        yield SearchResponse.fromJson(data);
      } catch (e) {
        debugPrint('[AurisRepo] NDJSON Parse Error ($server): $e');
      }
    }
  }

  List<String> _searchTargetsFor(String category) {
    final c = category.toLowerCase();
    if (c == 'anime' || c == 'movie_anime') {
      return [ApiEndpoints.animeBaseUrl, ApiEndpoints.moviesSeriesBaseUrl];
    }
    if (c == 'peliculas' || c == 'movie') {
      return [ApiEndpoints.moviesSeriesBaseUrl];
    }
    if (c == 'series') {
      return [ApiEndpoints.moviesSeriesBaseUrl, ApiEndpoints.kdramasBaseUrl];
    }
    return [
      ApiEndpoints.animeBaseUrl,
      ApiEndpoints.moviesSeriesBaseUrl,
      ApiEndpoints.kdramasBaseUrl,
    ];
  }

  bool _matchesCategory(SearchResult result, String category) {
    final c = category.toLowerCase();
    final target = (c == 'peliculas' || c == 'movie')
        ? 'movie'
        : (c == 'series' || c == 'kdrama')
            ? 'series'
            : (c == 'anime' || c == 'movie_anime' || c.contains('anime'))
                ? 'anime'
                : null;
    if (target == null) return true;
    return inferOpenCategory(result, '') == target;
  }

  Future<SearchResponse> _searchOn(
    String baseUrl,
    String category,
    String query, {
    int? year,
    String? phase,
    String? imgSize,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    final params = {'q': query, 'page': page.toString()};
    if (year != null) params['year'] = year.toString();
    if (phase != null) params['phase'] = phase;
    if (imgSize != null) params['img'] = imgSize;

    final response = await _client.get(
      ApiEndpoints.searchByCategory(category),
      queryParameters: params,
      baseUrl: baseUrl,
      cancelToken: cancelToken,
      options: Options(
        connectTimeout: const Duration(seconds: 70),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    if (response.data is Map) {
      return SearchResponse.fromJson(response.data as Map);
    }
    return SearchResponse(query: query, category: category, count: 0, results: const []);
  }

  Future<SearchResponse> _searchFanout(
    List<String> baseUrls,
    String query,
    int? year,
    String? phase, {
    String? filterCategory,
    String? imgSize,
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    Future<SearchResponse> guarded(
      Future<SearchResponse> Function() search) async {
      try {
        return await search();
      } catch (_) {
        return SearchResponse(query: query, category: filterCategory ?? 'all', count: 0, results: const []);
      }
    }

    final futures = baseUrls.map(
      (b) => guarded(() => _searchOn(b, filterCategory ?? 'all', query, year: year, phase: phase, imgSize: imgSize, page: page, cancelToken: cancelToken)),
    );

    final responses = await Future.wait(futures.map((f) => f.timeout(
      const Duration(seconds: 20),
      onTimeout: () => SearchResponse(query: query, category: filterCategory ?? 'all', count: 0, results: const []),
    )));

    final seen = <String>{};
    final merged = <SearchResult>[];
    for (final response in responses) {
      for (final r in response.results) {
        final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
        if (seen.add(key)) merged.add(r);
      }
    }

    if (filterCategory != null) {
      merged.removeWhere((r) => !_matchesCategory(r, filterCategory));
    }

    return SearchResponse(
      query: query,
      category: filterCategory ?? 'all',
      count: merged.length,
      page: page,
      hasMore: responses.any((r) => r.hasMore) || merged.isNotEmpty,
      results: merged,
    );
  }

  @override
  Future<SearchResponse> searchAnimeVariants({
    required String q,
    String? display,
    String? english,
    String? native_,
    String? collapsed,
    List<String>? synonyms,
  }) async {
    final params = <String, dynamic>{'q': q};
    if (display != null) params['display'] = display;
    if (english != null) params['english'] = english;
    if (native_ != null) params['native'] = native_;
    if (collapsed != null) params['collapsed'] = collapsed;
    if (synonyms != null && synonyms.isNotEmpty) {
      params['synonyms'] = synonyms.join(',');
    }
    final response = await _client.get(
      ApiEndpoints.searchAnimeVariants,
      queryParameters: params,
      baseUrl: ApiEndpoints.animeBaseUrl,
    );
    if (response.data is Map) {
      return SearchResponse.fromJson(response.data as Map);
    }
    return SearchResponse(query: q, category: 'anime', count: 0, results: const []);
  }

  @override
  Future<int> getHomeVersion({String? category}) async {
    try {
      final String normalizedCat = category != null ? switch (category.toLowerCase()) {
        'animes' => 'anime',
        'películas' => 'peliculas',
        'series' => 'series',
        'kdrama' => 'kdrama',
        _ => category.toLowerCase(),
      } : 'inicio';

      final response = await _client.get(
        ApiEndpoints.homeVersion,
        baseUrl: ApiEndpoints.baseUrlForCategory(normalizedCat),
      );
      
      if (response.data is Map) {
        return (response.data['version'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[AurisRepo] getHomeVersion error: $e');
      return 0;
    }
  }

  @override
  Future<AnimeDetail?> getAnimeDetail({
    required String title,
    int? malId,
    String? metadataTitle,
    int? year,
    int? season,
    String? kind,
    String? url,
    String? type,
    String? server,
    String? imgSize, // Senior Fix: Soporte para el nuevo parámetro &img del servidor
  }) async {
    final normalizedTitle = cleanTitleForDisplay(stripSeasonSuffix(title)).toLowerCase().trim();
    final normalizedUrl = url?.split('?').first.split('#').first ?? '';
    final cacheKey = '$normalizedTitle|$year|$season|$normalizedUrl';
    final cachedDetail = _getAnimeFromCache(cacheKey);
    if (cachedDetail != null) {
      debugPrint('[AurisRepo] Cache HIT for Anime: $title');
      return cachedDetail;
    }

    final params = <String, dynamic>{'title': title};
    if (malId != null) params['malId'] = malId;
    if (metadataTitle != null) params['metadataTitle'] = metadataTitle;
    if (year != null) params['year'] = year;
    if (season != null) params['season'] = season;
    if (kind != null) params['kind'] = kind;
    if (type != null) params['type'] = type;
    if (imgSize != null) params['img'] = imgSize;
    params['metadataOnly'] = '1';
    final response = await _client.get(
      ApiEndpoints.detailAnime,
      queryParameters: params,
      baseUrl: server ?? ApiEndpoints.animeBaseUrl,
      options: Options(
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    if (response.statusCode == 404) return null;
    final detail = AnimeDetail.fromJson(response.data as Map<String, dynamic>);
    _putInAnimeCache(cacheKey, detail);
    return detail;
  }

  @override
  Future<MovieDetail?> getMovieDetail({
    required String title,
    int? year,
    String? metadataTitle,
    String? url,
    String? type,
    String category = 'movie',
    String? server,
    String? kind,
    String? imgSize, // Senior Fix: Soporte para &img en películas y series
  }) async {
    final normalizedTitle = cleanTitleForDisplay(stripSeasonSuffix(title)).toLowerCase().trim();
    final normalizedUrl = url?.split('?').first.split('#').first ?? '';
    
    // Senior Fix: Normalizar categoría para asegurar cache determinista y peticiones correctas.
    String technicalCategory = category.toLowerCase().trim();
    final String? rawKind = kind?.toLowerCase();
    if (rawKind == 'movie' || rawKind == 'pelicula') {
      technicalCategory = 'movie';
    } else if (rawKind == 'series' || rawKind == 'tv') {
      technicalCategory = 'series';
    } else if (rawKind == 'kdrama' || rawKind == 'dorama') {
      technicalCategory = 'kdrama';
    } else if (rawKind == 'anime' || rawKind == 'movie_anime') {
      technicalCategory = rawKind!;
    }

    final cacheKey = '$normalizedTitle|$year|$normalizedUrl|$technicalCategory';
    final cachedMovie = _getMovieFromCache(cacheKey);
    if (cachedMovie != null) {
      debugPrint('[AurisRepo] Cache HIT for Movie: $title');
      return cachedMovie;
    }

    final params = <String, dynamic>{'title': title};
    if (year != null) params['year'] = year;
    if (metadataTitle != null) params['metadataTitle'] = metadataTitle;
    if (type != null) params['type'] = type;
    if (kind != null) params['kind'] = kind;
    if (imgSize != null) params['img'] = imgSize;
    params['category'] = technicalCategory;
    final response = await _client.get(
      ApiEndpoints.detailMovie,
      queryParameters: params,
      baseUrl: server ?? ApiEndpoints.baseUrlForCategory(technicalCategory),
      options: Options(
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    if (response.statusCode == 404) return null;
    final detail = MovieDetail.fromJson(response.data as Map<String, dynamic>);
    _putInMovieCache(cacheKey, detail);
    return detail;
  }

  @override
  Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async {
    try {
      final params = <String, dynamic>{};
      
      // Senior Fix: Si se pide 1080 (FHD), solicitamos 'original' al server 
      // para tener la fuente de alta resolución y luego redimensionamos en el proxy.
      final bool isFHD = imgSize == '1080';
      params['img'] = isFHD ? 'original' : (imgSize ?? 'w780');
      
      // Normalización de categorías...
      final String normalizedCat = switch (category.toLowerCase()) {
        'animes' => 'anime',
        'películas' => 'peliculas',
        'series' => 'series',
        'kdrama' => 'kdrama',
        _ => category,
      };

      if (normalizedCat != 'anime' && normalizedCat != 'inicio') {
        params['category'] = normalizedCat;
      }

      final response = await _client.get(
        ApiEndpoints.homeHero,
        queryParameters: params,
        baseUrl: ApiEndpoints.baseUrlForCategory(normalizedCat),
      );

      // Senior Resilience: El servidor puede devolver la lista en 'data.items' o directamente en 'items' o como Array.
      List<dynamic> list = [];
      if (response.data is List) {
        list = response.data;
      } else if (response.data is Map) {
        list = response.data['data']?['items'] ?? response.data['items'] ?? [];
      }

      return list.map((e) {
        try {
          final m = e as Map<String, dynamic>;
          // Senior Fix: Mapeo Ultra-Resiliente para el Hero
          final List<String> extractedGenres = [];
          final rawGenres = m['genresTranslated'] ?? m['genres'] ?? m['genre'] ?? m['category'];
          if (rawGenres is List) {
            extractedGenres.addAll(rawGenres.map((e) => e.toString()));
          } else if (rawGenres is String && rawGenres.isNotEmpty) {
            extractedGenres.add(rawGenres);
          }

          // Senior Fix: Extraer la lista de fuentes (sources) si existe para crear la "semilla" (card)
          final rawSources = m['sources'] as List?;
          final List<SourceItem> sources = [];
          if (rawSources != null) {
            for (var s in rawSources) {
              if (s is Map<String, dynamic>) {
                sources.add(SourceItem.fromJson(s));
              }
            }
          }

          final String? scraperUrl = m['url'] ?? m['sURL'] ?? m['detailUrl'];
          final String itemId = m['id']?.toString() ?? scraperUrl ?? '';

          // Senior Fix: Clasificación precisa del MediaType para el Hero
          final String rawKind = m['kind']?.toString().toLowerCase() ?? '';
          MediaType mediaType;
          
          if (normalizedCat == 'anime' || normalizedCat == 'inicio') {
            // En Inicio/Anime, el kind manda. Si no hay kind, por defecto es anime.
            mediaType = rawKind == 'movie' ? MediaType.movie : MediaType.anime;
          } else if (normalizedCat == 'series' || rawKind == 'series') {
            mediaType = MediaType.series;
          } else if (normalizedCat == 'kdrama' || rawKind == 'kdrama') {
            mediaType = MediaType.kdrama;
          } else {
            mediaType = MediaType.movie;
          }

          final String? bannerSource = m['bannerUrl'] ?? m['banner'] ?? m['backdrop'] ?? m['backdropUrl'];
          
          // Senior Optimization: Aplicar políticas de imagen centralizadas
          final String bannerUrl = isFHD 
              ? ApiEndpoints.proxyImage(bannerSource, policy: ImageSize.full)
              : ApiEndpoints.proxyImage(bannerSource, policy: imgSize == 'original' ? ImageSize.original : ImageSize.banner);

          final card = SearchResult(
            title: m['title'] ?? '',
            url: scraperUrl ?? itemId,
            source: m['source'] ?? (mediaType == MediaType.anime ? 'AniList' : 'TMDB'),
            quality: 'HD',
            thumbnail: m['posterUrl'] ?? m['poster'] ?? m['thumbnail'] ?? '',
            banner: bannerSource ?? '',
            romaji: m['romaji'],
            english: m['english'],
            year: (m['year'] as num?)?.toInt() ?? int.tryParse(m['year']?.toString() ?? ''),
            slug: m['slug'],
            sources: sources,
          );

          return MediaItem(
            id: itemId,
            title: m['title'] ?? '',
            romaji: m['romaji'],
            english: m['english'],
            posterUrl: ApiEndpoints.proxyImage(m['posterUrl'] ?? m['poster'] ?? m['thumbnail']),
            bannerUrl: bannerUrl,
            logoUrl: m['logoUrl'] ?? m['logo'],
            trailerKey: m['trailerKey'] ?? m['trailer_key'],
            type: mediaType,
            synopsis: m['synopsis'],
            rating: (m['rating'] as num?)?.toDouble() ?? (m['score'] as num?)?.toDouble(),
            year: (m['year'] as num?)?.toInt() ?? int.tryParse(m['year']?.toString() ?? ''),
            episode: (m['episode'] as num?)?.toInt(),
            airingAt: (m['airingAt'] as num?)?.toInt(),
            genres: extractedGenres,
            certification: m['certification'],
            available: (m['available'] as bool?) ?? true,
            detailUrl: scraperUrl,
            tmdbId: (m['tmdbId'] as num?)?.toInt() ?? (m['tmdb_id'] as num?)?.toInt(),
            source: m['source'] ?? (mediaType == MediaType.anime ? 'AniList' : 'TMDB'),
            card: card.copyWith(
              kind: rawKind,
              type: m['type']?.toString(),
            ),
          );
        } catch (e) {
          debugPrint('[AurisRepo] Error mapping hero item: $e');
          return null;
        }
      }).whereType<MediaItem>().toList();
    } catch (e) {
      debugPrint('[AurisRepo] getHomeHero critical error: $e');
      return [];
    }
  }

  @override
  @override
  Future<HomeResponse> getUserHome({required String userId, String? category}) async {
    try {
      final params = <String, dynamic>{'userId': userId};
      
      final String normalizedCat = category != null ? switch (category.toLowerCase()) {
        'animes' => 'anime',
        'películas' => 'peliculas',
        'series' => 'series',
        'kdrama' => 'kdrama',
        'kdramas' => 'kdrama',
        _ => category.toLowerCase(),
      } : 'inicio';

      if (normalizedCat != 'inicio') {
        params['category'] = normalizedCat;
      }

      final response = await _client.get(
        '/api/user/home',
        queryParameters: params,
        baseUrl: ApiEndpoints.baseUrlForCategory(normalizedCat),
      );
      if (response.data is Map) {
        return HomeResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
      } else {
        throw Exception('Invalid response format for user home');
      }
    } catch (e) {
      debugPrint('[AurisRepo] getUserHome error for category $category: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {
    try {
      final Map<String, dynamic> body = {
        'userId': userId,
        'animeId': animeId,
        'event': event,
      };
      if (sectionId != null) body['sectionId'] = sectionId;

      await _client.post(
        '/api/user/events',
        data: body,
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
    } catch (e) {
      debugPrint('[AurisRepo] sendUserEvent secondary tracking error (ignored): $e');
    }
  }

  @override
  Future<ScheduleResponse> getSchedule() async {
    final response = await _client.get(
      ApiEndpoints.schedule,
      baseUrl: ApiEndpoints.animeBaseUrl,
    );
    return ScheduleResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<SourceInfo>> getSources() async {
    final futures = [
      _fetchSources(ApiEndpoints.animeBaseUrl),
      _fetchSources(ApiEndpoints.moviesSeriesBaseUrl),
      _fetchSources(ApiEndpoints.kdramasBaseUrl),
    ];
    final lists = await Future.wait(futures);

    final seen = <String>{};
    final merged = <SourceInfo>[];
    for (final list in lists) {
      for (final s in list) {
        if (seen.add(s.name.toLowerCase())) merged.add(s);
      }
    }
    return merged;
  }

  Future<List<SourceInfo>> _fetchSources(String baseUrl) async {
    try {
      final response = await _client.get(ApiEndpoints.sources, baseUrl: baseUrl);
      final data = response.data as Map<String, dynamic>;
      return (data['sources'] as List<dynamic>)
          .map((e) => SourceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async {
    Future<EditorialResponse?> fetchEditorial(String baseUrl, [String? targetCat]) async {
      try {
        final params = <String, dynamic>{'locale': 'es-MX'};
        if (imgSize != null) params['img'] = imgSize;
        if (targetCat != null) params['category'] = targetCat;

        final response = await _client.get(
          ApiEndpoints.homeEditorial,
          queryParameters: params,
          baseUrl: baseUrl,
        );
        return EditorialResponse.fromJson(response.data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[AurisRepo] getEditorial error for $baseUrl: $e');
        return null;
      }
    }

    final String? normalizedCat = category != null ? switch (category.toLowerCase()) {
      'animes' => 'anime',
      'películas' => 'peliculas',
      'series' => 'series',
      'kdrama' => 'kdrama',
      'kdramas' => 'kdrama',
      _ => category.toLowerCase(),
    } : null;

    final List<Future<EditorialResponse?>> futures = [];
    if (normalizedCat == 'anime') {
      futures.add(fetchEditorial(ApiEndpoints.animeBaseUrl));
    } else if (normalizedCat == 'kdrama') {
      futures.add(fetchEditorial(ApiEndpoints.kdramasBaseUrl));
    } else if (normalizedCat == 'peliculas' || normalizedCat == 'series') {
      futures.add(fetchEditorial(ApiEndpoints.moviesSeriesBaseUrl, normalizedCat));
    } else {
      futures.addAll([
        fetchEditorial(ApiEndpoints.animeBaseUrl),
        fetchEditorial(ApiEndpoints.moviesSeriesBaseUrl),
        fetchEditorial(ApiEndpoints.kdramasBaseUrl),
      ]);
    }

    final results = await Future.wait(futures);
    
    final allSections = <EditorialSection>[];
    String latestGeneratedAt = '';
    
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      if (res != null) {
        allSections.addAll(res.sections);
        if (res.generatedAt.compareTo(latestGeneratedAt) > 0) {
          latestGeneratedAt = res.generatedAt;
        }
      }
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final response = await _client.get(
          '/api/home/top10/personalized',
          queryParameters: {'userId': userId},
          baseUrl: ApiEndpoints.animeBaseUrl,
        );
        if (response.data != null && response.data is Map) {
          final respMap = Map<String, dynamic>.from(response.data as Map);
          final dataMap = respMap['data'] as Map<String, dynamic>?;
          final sectionMap = dataMap?['section'] as Map<String, dynamic>?;
          if (sectionMap != null) {
            final personalizedSection = EditorialSection.fromJson(sectionMap);
            final idx = allSections.indexWhere((s) => s.id == 'top10Airing');
            if (idx != -1) {
              allSections[idx] = personalizedSection;
            }
          }
        }
      } catch (e) {
        debugPrint('[AurisRepo] Error fetching personalized top10: $e');
      }
    }

    return EditorialResponse(
      generatedAt: latestGeneratedAt.isEmpty 
          ? DateTime.now().toIso8601String() 
          : latestGeneratedAt,
      locale: 'es-MX',
      sections: allSections,
    );
  }

  Future<List<MediaItem>> _fetchHomeList(String endpoint, int limit) async {
    final response = await _client.get(
      endpoint,
      baseUrl: ApiEndpoints.animeBaseUrl,
    );
    final items = (response.data['data']?['items'] as List?) ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return MediaItem(
        id: m['url'] ?? m['id'] ?? '',
        title: m['title'] ?? '',
        posterUrl: m['posterUrl'] as String? ?? '',
        bannerUrl: m['bannerUrl'] as String?,
        type: MediaType.anime,
        source: m['source'] ?? '',
        year: m['year'],
        rating: (m['rating'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<List<MediaItem>> getHomeRecent(int limit) async {
    try {
      return await _fetchHomeList(ApiEndpoints.homeRecent(limit), limit);
    } catch (e) {
      debugPrint('[AurisRepo] getHomeRecent error: $e');
      return [];
    }
  }

  @override
  Future<List<MediaItem>> getHomeTop(int limit) async {
    try {
      return await _fetchHomeList(ApiEndpoints.homeTop(limit), limit);
    } catch (e) {
      debugPrint('[AurisRepo] getHomeTop error: $e');
      return [];
    }
  }

  @override
  Future<AnimeTitleInfo> getAnimeTitles(String query) async {
    final response = await _client.get(
      ApiEndpoints.titlesAnime,
      queryParameters: {'q': query},
      baseUrl: ApiEndpoints.animeBaseUrl,
    );
    return AnimeTitleInfo.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ExtractResult> extractVideo(String url, String source, {String? category, bool direct = false, CancelToken? cancelToken}) async {
    final params = <String, dynamic>{'url': url, 'source': source};
    if (direct) params['native'] = '1';
    final response = await _client.get(
      ApiEndpoints.extract,
      queryParameters: params,
      baseUrl: ApiEndpoints.baseUrlForSource(source, category),
      cancelToken: cancelToken,
    );
    return ExtractResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> resolveEpisodeUrl(String url, String source, int episode, {String? category}) async {
    final response = await _client.get(
      ApiEndpoints.resolveEpisode,
      queryParameters: {'url': url, 'source': source, 'episode': episode.toString()},
      baseUrl: ApiEndpoints.baseUrlForSource(source, category),
    );
    return (response.data as Map<String, dynamic>)['episodeUrl'] as String;
  }

    @override
  Future<EpisodesResponse> getEpisodes(
    String url,
    String source, {
    String? category,
    String? title,
    String? fullTitle,
    String? altTitle,
    int? tmdbId,
    int? season,
    int? year,
    bool fast = false,
  }) async {
    final params = <String, dynamic>{'url': url, 'source': source};
    
    // Senior Fix: Si el cliente no pasó season, intentamos inferirlo de la URL 
    // antes de enviar la petición al servidor para ayudar al IdentityResolver.
    final int? effectiveSeason = season ?? extractSeason(url);
    
    if (title != null) params['title'] = title;
    if (fullTitle != null) params['fullTitle'] = fullTitle;
    if (altTitle != null) params['altTitle'] = altTitle;
    if (tmdbId != null) params['tmdbId'] = tmdbId;
    if (effectiveSeason != null) params['season'] = effectiveSeason;
    if (year != null) params['year'] = year;
    if (fast) params['fast'] = '1';
    
    // Senior Fix: Timeout reducido a 15s con retry automático (1 reintento)
    const maxRetries = 1;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client.get(
          ApiEndpoints.episodes,
          queryParameters: params,
          baseUrl: ApiEndpoints.baseUrlForSource(source, category),
          options: Options(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        return EpisodesResponse.fromJson(response.data as Map<String, dynamic>);
      } on DioException catch (e) {
        if (attempt == maxRetries) rethrow;
        // Solo retry en timeout o errores de conexión
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          debugPrint('[Episodes] Retry ${attempt + 1}/$maxRetries for $url');
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Unreachable');
  }

  @override
  Future<List<CastInfo>> getCast(
    String url, {
    String? source,
    String? category,
    int? tmdbId,
    String? mediaType,
    String? title,
    int? year,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (tmdbId != null) {
        params['tmdbId'] = tmdbId;
        if (mediaType != null) params['mediaType'] = mediaType;
      } else {
        if (url.isNotEmpty) params['url'] = url;
        // Fallback anime: /api/cast resuelve por título cuando no hay tmdbId.
        // El servidor movies ignora estos params extra.
        if (title != null && title.isNotEmpty) params['title'] = title;
        if (year != null) params['year'] = year;
      }

      final response = await _client.get(
        ApiEndpoints.cast,
        queryParameters: params,
        baseUrl: ApiEndpoints.baseUrlForSource(source ?? '', category),
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      // Formatos según servidor:
      //  - movies: envelope {success:true, data:{cast:[...]}}
      //  - anime:  objeto {tmdbId, cast:[...]}
      //  - legacy: lista directa [...]
      final dynamic body = response.data;
      final dynamic root = (body is Map<String, dynamic> &&
              body['success'] == true &&
              body['data'] is Map<String, dynamic>)
          ? body['data']
          : body;
      List<dynamic> list;
      if (root is List) {
        list = root;
      } else if (root is Map<String, dynamic>) {
        list = (root['cast'] as List<dynamic>?) ?? [];
      } else {
        list = [];
      }
      return list.map((e) => CastInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[AurisRepo] getCast error: $e');
      return [];
    }
  }

  @override
  Future<List<RelatedInfo>> getRelations(String url, {String? source, String? category}) async {
    try {
      final params = <String, dynamic>{'url': url};
      if (source != null && source.isNotEmpty) {
        params['source'] = source;
      }

      final response = await _client.get(
        ApiEndpoints.relations,
        queryParameters: params,
        baseUrl: ApiEndpoints.baseUrlForSource(source ?? '', category),
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      // Formatos según servidor:
      //  - movies: envelope {success:true, data:{source, relations:[...]}}
      //  - anime:  objeto {source, relations:[...]}
      final dynamic body = response.data;
      final Map<String, dynamic> map = (body is Map<String, dynamic> &&
              body['success'] == true &&
              body['data'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(body['data'] as Map)
          : (body is Map<String, dynamic>
              ? body
              : <String, dynamic>{});
      final List<dynamic> list = (map['relations'] as List<dynamic>?) ?? [];
      return list.map((e) => RelatedInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[AurisRepo] getRelations error: $e');
      return [];
    }
  }

  @override
  Future<MovieTitleInfo> getMovieTitles(String query) async {
    final response = await _client.get(
      ApiEndpoints.titlesMovie,
      queryParameters: {'q': query},
      baseUrl: ApiEndpoints.moviesSeriesBaseUrl,
    );
    return MovieTitleInfo.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<OmdbEpisode>> getOmdbSeason({required String title, int season = 1, bool enrich = true}) async {
    try {
      final response = await _client.get(
        ApiEndpoints.omdbSeason,
        queryParameters: {
          'title': title,
          'season': season,
          'enrich': enrich ? 'true' : 'false',
        },
      );
      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final List<dynamic> list = (map['episodes'] as List<dynamic>?) ?? [];
        return list.map((e) => OmdbEpisode.fromJson(e as Map<String, dynamic>)).toList();
      } else if (response.data is List<dynamic>) {
        final List<dynamic> list = response.data as List<dynamic>;
        return list.map((e) => OmdbEpisode.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('[AurisRepo] getOmdbSeason error: $e');
      return [];
    }
  }

  @override
  Future<OmdbEpisode?> getOmdbEpisode({required String title, int season = 1, int episode = 1}) async {
    final response = await _client.get(
      ApiEndpoints.omdbEpisode,
      queryParameters: {'title': title, 'season': season, 'episode': episode},
    );
    if (response.statusCode == 404) return null;
    return OmdbEpisode.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SearchResponse> getCastCredits({
    String? url,
    String? name,
    String? profile,
    int? personId,
  }) async {
    final params = <String, dynamic>{};
    if (personId != null) {
      params['personId'] = personId;
    } else {
      if (url != null && url.isNotEmpty) params['url'] = url;
      if (name != null && name.isNotEmpty) params['name'] = name;
      if (profile != null && profile.isNotEmpty) params['profile'] = profile;
    }

    final String targetBaseUrl = personId != null
        ? ApiEndpoints.animeBaseUrl
        : ApiEndpoints.moviesSeriesBaseUrl;

    final response = await _client.get(
      ApiEndpoints.castCredits,
      queryParameters: params,
      baseUrl: targetBaseUrl,
      options: Options(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> updateCatalogSources({required String title, required List<SourceItem> sources, int? season}) async {
    if (sources.isEmpty) return;
    try {
      await _client.post(
        ApiEndpoints.catalogSources,
        data: {
          'title': title,
          if (season != null) 'season': season,
          'sources': sources.map((s) => {
            'source': s.source,
            'url': s.url,
          }).toList(),
        },
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
    } catch (e) {
      debugPrint('[AurisRepo] Error updating catalog sources: $e');
    }
  }

  // --- NOTIFICACIONES ---
  
  @override
  Future<void> registerDeviceToken(String userId, String token, String platform) async {
    try {
      await _client.post(
        ApiEndpoints.subscriptions(userId) + '/token',
        data: {'token': token, 'platform': platform},
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
    } catch (e) {
      debugPrint('[AurisRepo] Error registering token: $e');
    }
  }

  @override
  Future<void> subscribeToTopic(String userId, String topic) async {
    try {
      await _client.post(
        ApiEndpoints.subscriptions(userId) + '/subscribe',
        data: {'topic': topic},
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
    } catch (e) {
      debugPrint('[AurisRepo] Error subscribing to topic: $e');
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String userId, String topic) async {
    try {
      await _client.post(
        ApiEndpoints.subscriptions(userId) + '/unsubscribe',
        data: {'topic': topic},
        baseUrl: ApiEndpoints.animeBaseUrl,
      );
    } catch (e) {
      debugPrint('[AurisRepo] Error unsubscribing from topic: $e');
    }
  }
}
