import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../models/server/anilist_media.dart';
import '../../models/server/anime_detail.dart';
import '../../models/server/episodes_response.dart';
import '../../models/server/editorial_section.dart';
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
  Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase}) async {
    final normalized = _normalizeSearchCategory(category);
    if (server != null) {
      return _searchOn(server, normalized, query, year: year, phase: phase);
    }
    if (normalized.toLowerCase() == 'all') {
      return _searchAll(query, year, phase: phase);
    }
    return _searchOn(ApiEndpoints.baseUrlForCategory(normalized), normalized, query, year: year, phase: phase);
  }

  Future<SearchResponse> _searchOn(
    String baseUrl,
    String category,
    String query, {
    int? year,
    String? phase,
  }) async {
    final params = {'q': query};
    if (year != null) params['year'] = year.toString();
    if (phase != null) params['phase'] = phase;

    final response = await _client.get(
      ApiEndpoints.searchByCategory(category),
      queryParameters: params,
      baseUrl: baseUrl,
      options: Options(
        connectTimeout: const Duration(seconds: 70),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SearchResponse> _searchAll(String query, int? year, {String? phase}) async {
    Future<SearchResponse> guarded(
      Future<SearchResponse> Function() search) async {
      try {
        return await search();
      } catch (_) {
        return SearchResponse(query: query, category: 'all', count: 0, results: const []);
      }
    }

    final List<Future<SearchResponse>> futures = [
      guarded(() => _searchOn(ApiEndpoints.animeBaseUrl, 'all', query, year: year, phase: phase)),
      guarded(() => _searchOn(ApiEndpoints.moviesSeriesBaseUrl, 'all', query, year: year, phase: phase)),
      guarded(() => _searchOn(ApiEndpoints.kdramasBaseUrl, 'all', query, year: year, phase: phase)),
    ];

    final responses = await Future.wait(futures.map((f) => f.timeout(
      const Duration(seconds: 60),
      onTimeout: () => SearchResponse(query: query, category: 'all', count: 0, results: const []),
    )));

    final seen = <String>{};
    final merged = <SearchResult>[];
    for (final response in responses) {
      for (final r in response.results) {
        final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
        if (seen.add(key)) merged.add(r);
      }
    }
    return SearchResponse(query: query, category: 'all', count: merged.length, results: merged);
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
    return SearchResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AnimeDetail?> getAnimeDetail({
    required String title,
    int? malId,
    String? metadataTitle,
    int? year,
    int? season,
    String? kind,
  }) async {
    final params = <String, dynamic>{'title': title};
    if (malId != null) params['malId'] = malId;
    if (metadataTitle != null) params['metadataTitle'] = metadataTitle;
    if (year != null) params['year'] = year;
    if (season != null) params['season'] = season;
    if (kind != null) params['kind'] = kind;
    final response = await _client.get(
      ApiEndpoints.detailAnime,
      queryParameters: params,
      baseUrl: ApiEndpoints.animeBaseUrl,
    );
    if (response.statusCode == 404) return null;
    return AnimeDetail.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<MovieDetail?> getMovieDetail({
    required String title,
    int? year,
    String? metadataTitle,
    String? url,
    String? quality,
    String category = 'movie',
    String? server,
  }) async {
    final params = <String, dynamic>{'title': title};
    if (year != null) params['year'] = year;
    if (metadataTitle != null) params['metadataTitle'] = metadataTitle;
    if (url != null) params['url'] = url;
    if (quality != null) params['quality'] = quality;
    final response = await _client.get(
      ApiEndpoints.detailMovie,
      queryParameters: params,
      baseUrl: server ?? ApiEndpoints.baseUrlForCategory(category),
    );
    if (response.statusCode == 404) return null;
    return MovieDetail.fromJson(response.data as Map<String, dynamic>);
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
  Future<EditorialResponse> getEditorial() async {
    Future<EditorialResponse?> fetchEditorial(String baseUrl) async {
      try {
        final response = await _client.get(
          ApiEndpoints.homeEditorial,
          queryParameters: {'locale': 'es-MX'},
          baseUrl: baseUrl,
        );
        return EditorialResponse.fromJson(response.data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[AurisRepo] getEditorial error for $baseUrl: $e');
        return null;
      }
    }

    final futures = [
      fetchEditorial(ApiEndpoints.animeBaseUrl),
      fetchEditorial(ApiEndpoints.moviesSeriesBaseUrl),
      fetchEditorial(ApiEndpoints.kdramasBaseUrl),
    ];

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
        posterUrl: ApiEndpoints.proxyImage(m['posterUrl']),
        bannerUrl: ApiEndpoints.proxyImage(m['bannerUrl']),
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
  Future<ExtractResult> extractVideo(String url, String source, {String? category, bool direct = false}) async {
    final params = <String, dynamic>{'url': url, 'source': source};
    if (direct) params['native'] = '1';
    final response = await _client.get(
      ApiEndpoints.extract,
      queryParameters: params,
      baseUrl: ApiEndpoints.baseUrlForSource(source, category),
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
  }) async {
    final params = <String, dynamic>{'url': url, 'source': source};
    if (title != null) params['title'] = title;
    if (fullTitle != null) params['fullTitle'] = fullTitle;
    if (altTitle != null) params['altTitle'] = altTitle;
    if (tmdbId != null) params['tmdbId'] = tmdbId;
    if (season != null) params['season'] = season;
    if (year != null) params['year'] = year;
    final response = await _client.get(
      ApiEndpoints.episodes,
      queryParameters: params,
      baseUrl: ApiEndpoints.baseUrlForSource(source, category),
      options: Options(
        connectTimeout: const Duration(seconds: 35),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return EpisodesResponse.fromJson(response.data as Map<String, dynamic>);
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
}
