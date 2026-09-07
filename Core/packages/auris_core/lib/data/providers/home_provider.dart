import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../auris_core.dart';

/// Senior: Global state for the Hero Banner mute status to allow control across platforms.
final heroBannerMutedProvider = StateProvider<bool>((ref) => true);

/// Senior: Current category state (Inicio, Animes, Películas, etc.)
final homeCategoryProvider = StateProvider<String>((ref) => 'inicio');

/// Senior: Exclusivity for card expansions in carousels.
final hoveredCardIdProvider = StateProvider<String?>((ref) => null);

/// Senior: Director Editorial del Banner.
/// Selecciona y filtra el contenido más impactante para el HeroBanner de cada categoría.
final heroBannerItemsProvider = FutureProvider.family<List<MediaItem>, String>((ref, category) async {
  final repo = ref.watch(aurisRepositoryProvider);
  
  // --- LÓGICA ESPECIAL PARA INICIO (FUSIÓN DE CATEGORÍAS) ---
  if (category == 'inicio') {
    try {
      // Senior Strategy: Pedimos los 3 pilares en paralelo
      // Optimizamos a 1080 (FHD) para el Home, reservando 'original' para detalles.
      final results = await Future.wait([
        repo.getHomeHero(category: 'anime', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
        repo.getHomeHero(category: 'peliculas', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
        repo.getHomeHero(category: 'series', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
      ]);

      final animes = results[0];
      final movies = results[1];
      final series = results[2];

      // Senior Adaptive Mixing: Barajamos el orden de las categorías para que el inicio sea dinámico
      final categories = [animes, movies, series]..shuffle();

      final List<MediaItem> mixedHero = [];
      int maxLen = categories.map((l) => l.length).fold(0, (prev, curr) => curr > prev ? curr : prev);

      // Algoritmo de Intercalado Dinámico (Interleaving)
      for (int i = 0; i < maxLen; i++) {
        for (final list in categories) {
          if (i < list.length) {
            mixedHero.add(list[i]);
            if (mixedHero.length >= 25) break;
          }
        }
        if (mixedHero.length >= 25) break;
      }

      if (mixedHero.isNotEmpty) return mixedHero;
    } catch (e) {
      debugPrint('[heroBannerItemsProvider] Inicio fusion error: $e');
    }
  }

  // --- LÓGICA PARA CATEGORÍAS ESPECÍFICAS ---
  final String heroCategory = (category == 'animes') ? 'anime' : category;
  
  try {
    if (category == 'animes' || category == 'películas' || category == 'series' || category == 'kdrama') {
      final heroItems = await repo.getHomeHero(category: heroCategory, imgSize: '1080')
          .timeout(const Duration(seconds: 10));
      
      if (heroItems.isNotEmpty) return heroItems;
    }
  } catch (e) {
    debugPrint('[heroBannerItemsProvider] Hero endpoint error: $e');
  }

  // 3. FALLBACK: Búsqueda tradicional si el Hero falla o no existe para la categoría
  try {
    final apiCategory = _mapUiCategoryToApi(category);
    final response = await repo.search(apiCategory, '', imgSize: '1080')
        .timeout(const Duration(seconds: 12));
    
    final Map<String, MediaItem> uniqueItems = {};
    for (var r in response.results) {
      final item = _mapSearchResultToMediaItem(r, apiCategory);
      final key = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (!uniqueItems.containsKey(key)) uniqueItems[key] = item;
    }

    final trendingItems = uniqueItems.values.toList();
    if (trendingItems.isNotEmpty) {
      // Aplicamos orden por rating para que el banner siempre sea de calidad
      trendingItems.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return trendingItems;
    }
  } catch (e) {
    debugPrint('[heroBannerItemsProvider] Search fallback error: $e');
  }

  return MockData.featuredItems;
});

final scheduleProvider = FutureProvider<ScheduleResponse>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getSchedule();
});

/// Senior: Provider for "Recently Added".
/// Uses real scraped sources. Resilient fallback to trending if sources fail.
final recentlyAddedProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(aurisRepositoryProvider);
  try {
    final items = await repo.getHomeRecent(15).timeout(const Duration(seconds: 8));
    if (items.isNotEmpty) return items;
  } catch (_) {}

  Future<List<MediaItem>> fetchRecent(String uiCat) async {
    try {
      return await ref.read(trendingListProvider(uiCat).future).timeout(const Duration(seconds: 4));
    } catch (_) {
      return [];
    }
  }

  final results = await Future.wait([
    fetchRecent('animes'),
    fetchRecent('películas'),
    fetchRecent('kdrama'),
  ]);

  final List<MediaItem> merged = [];
  final animes = results[0];
  final movies = results[1];
  final kdramas = results[2];

  int index = 0;
  while (merged.length < 15) {
    bool added = false;
    if (index < animes.length) { merged.add(animes[index]); added = true; }
    if (merged.length < 15 && index < movies.length) { merged.add(movies[index]); added = true; }
    if (merged.length < 15 && index < kdramas.length) { merged.add(kdramas[index]); added = true; }
    index++;
    if (!added) break;
  }
  return merged;
});

/// Senior: Unified Top 10 Provider.
final top10GlobalProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(aurisRepositoryProvider);
  try {
    final items = await repo.getHomeTop(10).timeout(const Duration(seconds: 8));
    if (items.isNotEmpty) return items;
  } catch (_) {}

  Future<List<MediaItem>> guardedTrending(String cat) async {
    try {
      return await ref.read(trendingListProvider(cat).future).timeout(const Duration(seconds: 4));
    } catch (_) {
      return [];
    }
  }

  final results = await Future.wait([
    guardedTrending('animes'),
    guardedTrending('películas'),
    guardedTrending('kdrama'),
  ]);

  final List<MediaItem> merged = [];
  final animes = results[0];
  final movies = results[1];
  final kdramas = results[2];

  int maxLen = [animes.length, movies.length, kdramas.length].reduce((a, b) => a > b ? a : b);
  for (int i = 0; i < maxLen; i++) {
    if (i < animes.length) merged.add(animes[i]);
    if (i < movies.length) merged.add(movies[i]);
    if (i < kdramas.length) merged.add(kdramas[i]);
    if (merged.length >= 20) break;
  }
  return merged.take(20).toList();
});

final editorialSectionsProvider = AsyncNotifierProvider<EditorialSectionsNotifier, List<EditorialSection>>(() {
  return EditorialSectionsNotifier();
});

class EditorialSectionsNotifier extends AsyncNotifier<List<EditorialSection>> {
  @override
  FutureOr<List<EditorialSection>> build() async {
    ref.keepAlive();
    final box = Hive.box('home_cache');
    final cachedData = box.get('editorial_sections');
    
    if (cachedData != null) {
      try {
        final List<dynamic> list = cachedData as List<dynamic>;
        final sections = list.map((e) => EditorialSection.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _refreshFromNetwork();
        return sections;
      } catch (e) {
        debugPrint('[HomeCache] Error: $e');
      }
    }
    return _refreshFromNetwork();
  }

  Future<List<EditorialSection>> _refreshFromNetwork() async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      // Senior Fix: Solicitamos calidad w780 para secciones editoriales para optimizar carga.
      final response = await repo.getEditorial(imgSize: 'w780');
      final box = Hive.box('home_cache');
      await box.put('editorial_sections', response.sections.map((e) => e.toJson()).toList());
      state = AsyncData(response.sections);
      return response.sections;
    } catch (e) {
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }
}

enum RowFormat { vertical, horizontal }

class EditorialRow {
  final EditorialBadge badge;
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final bool isMovie;
  final RowFormat format;
  
  const EditorialRow({
    required this.badge, 
    required this.title, 
    required this.items, 
    this.subtitle, 
    this.isMovie = false,
    this.format = RowFormat.vertical,
  });
}

enum HomeSectionType {
  editorial,
  trendingAnime,
  trendingMovies,
  recentEpisodes,
  recentlyAdded,
  continueWatching,
  top10Global
}

class HomeLayoutSection {
  final HomeSectionType type;
  final String? title;
  final dynamic data;

  const HomeLayoutSection({required this.type, this.title, this.data});
}

/// Senior: Orchestrator for the Home Screen layout.
final homeLayoutProvider = FutureProvider<List<HomeLayoutSection>>((ref) async {
  final List<HomeLayoutSection> layout = [];
  layout.add(const HomeLayoutSection(type: HomeSectionType.continueWatching));
  layout.add(const HomeLayoutSection(type: HomeSectionType.top10Global, title: 'Top 10 de hoy'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.recentlyAdded, title: 'Recién añadido a AurisTV'));

  try {
    final editorials = await ref.watch(editorialRowsProvider.future);
    for (final row in editorials) {
      layout.add(HomeLayoutSection(type: HomeSectionType.editorial, data: row));
    }
  } catch (e) {}

  layout.add(const HomeLayoutSection(type: HomeSectionType.recentEpisodes, title: 'Estrenos (Hoy)'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingAnime, title: 'Animes en tendencia'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingMovies, title: 'Películas destacadas'));

  return layout;
});

final editorialRowsProvider = FutureProvider<List<EditorialRow>>((ref) async {
  final sections = await ref.watch(editorialSectionsProvider.future);
  return sections.map((section) {
    final badge = editorialBadgeFromString(section.badge);
    final isMovie = section.badge.toLowerCase().contains('movie');
    
    RowFormat format = RowFormat.vertical;
    final titleLower = section.title.toLowerCase();
    if (badge == EditorialBadge.hiddenGem || 
        badge == EditorialBadge.movieEssential || 
        titleLower.contains('película') ||
        titleLower.contains('pelicula')) {
      format = RowFormat.horizontal;
    }

    return EditorialRow(
      badge: badge ?? EditorialBadge.essential,
      title: section.title,
      subtitle: section.subtitle,
      isMovie: isMovie,
      format: format,
      items: section.items.map(_mapEditorialItemToMediaItem).toList(),
    );
  }).toList();
});

MediaItem _mapEditorialItemToMediaItem(EditorialItem result) {
  MediaType type = MediaType.series;
  final s = result.source.toLowerCase();
  final t = result.title.toLowerCase();
  final sub = result.subtitle?.toLowerCase() ?? '';
  
  final isAnime = result.badge.toLowerCase().contains('anime') || 
                  sub.contains('anime') || 
                  s.contains('jkanime') || s.contains('animejara') || s.contains('animed23');
                  
  final isKdrama = s.contains('tudorama') || s.contains('dorama') || s.contains('pandrama') || sub.contains('drama');
  
  final isMovie = result.badge.toLowerCase().contains('movie') || 
                  sub.contains('película') ||
                  t.contains('película');

  if (isAnime) type = MediaType.anime;
  else if (isKdrama) type = MediaType.kdrama;
  else if (isMovie) type = MediaType.movie;

  String? displaySubtitle = result.subtitle;
  if (type != MediaType.anime) {
    displaySubtitle = (result.year != null && result.year!.isNotEmpty) ? result.year : null;
  } else if (displaySubtitle != null &&
      (displaySubtitle.toLowerCase().contains('1 ep') || displaySubtitle.toLowerCase().contains('película'))) {
    displaySubtitle = (result.year != null && result.year!.isNotEmpty) ? result.year : null;
  }

  // Senior Fix: Asegurar que el source sea un nombre de servidor válido para UrlUtils
  String effectiveSource = result.source;
  if (effectiveSource.isEmpty) {
    if (result.id.contains('jkanime.net')) effectiveSource = 'JKAnime';
    else if (result.id.contains('animejara.com')) effectiveSource = 'AnimeJara';
    else if (result.id.contains('tudorama.net')) effectiveSource = 'TuDorama';
  }

  return MediaItem(
    id: result.id,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.posterUrl),
    bannerUrl: ApiEndpoints.proxyImage(result.bannerUrl),
    type: type,
    rating: result.rating,
    source: effectiveSource,
    year: int.tryParse(result.year ?? ''),
    trailerKey: result.trailerKey,
    synopsis: result.synopsis,
    subtitle: displaySubtitle,
    aired: type == MediaType.movie || (result.subtitle?.toLowerCase().contains('finalizado') ?? false),
  );
}

final animeMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(aurisRepositoryProvider);
  final response = await repo.search('movie_anime', '');
  return response.results.map((r) => _mapSearchResultToMediaItem(r, 'movie_anime')).toList();
});

String _mapUiCategoryToApi(String uiCategory) {
  switch (uiCategory.toLowerCase()) {
    case 'animes': return 'anime';
    case 'películas': return 'peliculas';
    case 'series': return 'series';
    case 'kdrama': return 'kdrama';
    default: return 'anime';
  }
}

MediaItem _mapSearchResultToMediaItem(SearchResult result, String category) {
  MediaType type = MediaType.series;
  final c = category.toLowerCase();
  
  if (c.contains('anime')) type = MediaType.anime;
  else if (c.contains('movie') || c.contains('pelicula')) type = MediaType.movie;
  else if (c.contains('drama')) type = MediaType.kdrama;
  else if (c.contains('series')) type = MediaType.series;

  String? displaySubtitle = (type != MediaType.anime || result.year != null) ? result.year?.toString() : null;
  final isFinished = result.status?.toLowerCase() == 'finished';

  // Senior Fix: Asegurar que el source sea un nombre de servidor válido
  String effectiveSource = result.source;
  if (effectiveSource.isEmpty) {
    if (result.url.contains('jkanime.net')) effectiveSource = 'JKAnime';
    else if (result.url.contains('animejara.com')) effectiveSource = 'AnimeJara';
    else if (result.url.contains('tudorama.net')) effectiveSource = 'TuDorama';
  }

  return MediaItem(
    id: result.url,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.thumbnail, fallbackUrl: result.tmdbThumbnail),
    bannerUrl: ApiEndpoints.proxyImage(result.banner, highQuality: true, fallbackUrl: result.tmdbBanner),
    logoUrl: result.logo,
    type: type,
    rating: result.score,
    source: effectiveSource,
    year: result.year,
    trailerKey: result.trailerKey,
    synopsis: result.synopsis,
    subtitle: displaySubtitle,
    aired: type == MediaType.movie || isFinished,
    genres: result.genres ?? const [], // Senior Fix: Mapear géneros desde SearchResult
    card: result,
  );
}

final trendingListProvider = AsyncNotifierProvider.family<TrendingListNotifier, List<MediaItem>, String>(() {
  return TrendingListNotifier();
});

class TrendingListNotifier extends FamilyAsyncNotifier<List<MediaItem>, String> {
  @override
  FutureOr<List<MediaItem>> build(String arg) async {
    ref.keepAlive();
    final box = Hive.box('home_cache');
    final cacheKey = 'trending_$arg';
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> list = cachedData as List<dynamic>;
        final items = list.map((e) => _mapJsonToMediaItem(Map<String, dynamic>.from(e as Map))).toList();
        _refreshTrending(arg);
        return items;
      } catch (e) {}
    }
    return _refreshTrending(arg);
  }

  Future<List<MediaItem>> _refreshTrending(String uiCategory) async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final apiCategory = _mapUiCategoryToApi(uiCategory);
      final response = await repo.search(apiCategory, '');

      final Map<String, MediaItem> uniqueItems = {};
      for (var r in response.results) {
        final item = _mapSearchResultToMediaItem(r, apiCategory);
        final key = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (!uniqueItems.containsKey(key)) uniqueItems[key] = item;
      }

      final items = uniqueItems.values.toList();
      final box = Hive.box('home_cache');
      await box.put('trending_$uiCategory', items.map((e) => _mapMediaItemToJson(e)).toList());
      state = AsyncData(items);
      return items;
    } catch (e) {
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }

  Map<String, dynamic> _mapMediaItemToJson(MediaItem item) => {
    'id': item.id, 'title': item.title, 'posterUrl': item.posterUrl, 'bannerUrl': item.bannerUrl,
    'logoUrl': item.logoUrl, 'type': item.type.index, 'rating': item.rating, 'year': item.year,
    'synopsis': item.synopsis, 'romaji': item.romaji, 'english': item.english,
    'genres': item.genres, 'certification': item.certification, 'available': item.available,
    'detailUrl': item.detailUrl, 'tmdbId': item.tmdbId, 'episode': item.episode, 'airingAt': item.airingAt,
  };

  MediaType _mediaTypeFromJson(dynamic v) {
    if (v is int && v >= 0 && v < MediaType.values.length) return MediaType.values[v];
    if (v is String) {
      final s = v.toLowerCase();
      for (final t in MediaType.values) {
        if (t.name == s) return t;
      }
    }
    return MediaType.anime;
  }

  MediaItem _mapJsonToMediaItem(Map<String, dynamic> json) => MediaItem(
    id: json['id'], title: json['title'], posterUrl: json['posterUrl'], bannerUrl: json['bannerUrl'],
    logoUrl: json['logoUrl'], type: _mediaTypeFromJson(json['type']), rating: json['rating'],
    year: json['year'], synopsis: json['synopsis'], romaji: json['romaji'], english: json['english'],
    genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    certification: json['certification'] as String?,
    available: (json['available'] as bool?) ?? true,
    detailUrl: json['detailUrl'] as String?,
    tmdbId: (json['tmdbId'] as num?)?.toInt(),
    episode: (json['episode'] as num?)?.toInt(),
    airingAt: (json['airingAt'] as num?)?.toInt(),
    trailerKey: json['trailerKey'] as String?, // Senior Fix: Restaurar trailer en cache
  );
}

final homePrefetchProvider = FutureProvider<void>((ref) async {
  try {
    ref.watch(editorialRowsProvider.future).ignore();
    ref.watch(trendingListProvider('animes').future).ignore();
    ref.watch(trendingListProvider('películas').future).ignore();
    ref.watch(trendingListProvider('series').future).ignore();
    ref.watch(recentEpisodesProvider.future).ignore();
  } catch (_) {}
});

final recentEpisodesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.keepAlive();
  final schedule = await ref.watch(scheduleProvider.future);
  final todayItems = schedule.days.firstWhere((d) => d.isToday, orElse: () => schedule.days.first).items.where((item) => item.sourceAvailable).toList();

  return todayItems.map((item) {
    final ep = item.episode ?? 0;
    final isMovie = item.format?.toUpperCase() == 'MOVIE';
    final itemYear = item.year ?? (item.airingAt != null ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year : null);
    final card = SearchResult(
      title: item.title, source: item.source ?? '', url: item.url ?? '', thumbnail: ApiEndpoints.proxyImage(item.coverImage),
      quality: item.quality ?? 'HD', kind: 'anime', type: item.type, slug: item.slug, year: itemYear, romaji: item.romaji, english: item.english,
      sources: item.sources.map((s) => SourceItem(source: s.source, url: s.url, quality: s.quality, slug: s.slug, type: s.type)).toList(),
    );
    // Senior Fix: Asegurar que el source sea un nombre de servidor válido
    String effectiveSource = item.source ?? '';
    if (effectiveSource.isEmpty && item.url != null) {
      final u = item.url!.toLowerCase();
      if (u.contains('jkanime.net')) effectiveSource = 'JKAnime';
      else if (u.contains('animejara.com')) effectiveSource = 'AnimeJara';
      else if (u.contains('animeav1.com')) effectiveSource = 'AnimeAV1';
      else if (u.contains('animed23.com')) effectiveSource = 'AnimeD23';
    }

    final String? rawBanner = (item.banner != null && item.banner!.isNotEmpty) ? item.banner : item.coverImage;
    return MediaItem(
      id: item.url ?? item.id.toString(), title: item.title, romaji: item.romaji, english: item.english,
      posterUrl: ApiEndpoints.proxyImage(item.coverImage), bannerUrl: ApiEndpoints.proxyImage(rawBanner),
      type: isMovie ? MediaType.movie : MediaType.anime, rating: item.averageScore,
      subtitle: (isMovie || ep == 0) ? item.year?.toString() : (item.year != null ? '${item.year} • Episodio $ep' : 'Episodio $ep'),
      year: item.year, source: effectiveSource, episode: ep == 0 ? null : ep, airingAt: item.airingAt,
      aired: isMovie || item.aired || item.status?.toLowerCase() == 'finished', card: card,
    );
  }).toList();
});
