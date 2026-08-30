import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:auris_core/auris_core.dart';

final homeRepositoryProvider = Provider<AurisRepository>((ref) {
  return ref.watch(aurisRepositoryProvider);
});

final scheduleProvider = FutureProvider<ScheduleResponse>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getSchedule();
});

/// Senior: Provider para "Recién añadido a AurisTV".
/// Usa las fuentes reales scrapeadas (AnimeJara/AnimeD23/AnimeAV1).
/// Si las fuentes fallan, cae back a las tendencias para no romper la UI.
final recentlyAddedProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  try {
    final items = await repo.getHomeRecent(15).timeout(const Duration(seconds: 8));
    if (items.isNotEmpty) return items;
  } catch (_) {
    // Ignorado: caemos al fallback de tendencias.
  }

  // Fallback resiliente a tendencias.
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

/// Senior: Provider para el "Top 10 de hoy" unificado.
/// Usa las fuentes reales scrapeadas. Si fallan, cae back a las tendencias.
final top10GlobalProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  try {
    final items = await repo.getHomeTop(10).timeout(const Duration(seconds: 8));
    if (items.isNotEmpty) return items;
  } catch (_) {
    // Ignorado: caemos al fallback de tendencias.
  }

  // Fallback resiliente a tendencias.
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
    // 1. Carga inmediata desde el disco (Hive)
    final box = Hive.box('home_cache');
    final cachedData = box.get('editorial_sections');
    
    if (cachedData != null) {
      try {
        final List<dynamic> list = cachedData as List<dynamic>;
        final sections = list.map((e) => EditorialSection.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        
        // Disparamos la actualización en segundo plano sin esperar
        _refreshFromNetwork();
        
        return sections;
      } catch (e) {
        debugPrint('[HomeCache] Error decodificando caché: $e');
      }
    }

    // 2. Si no hay caché, esperamos a la red
    return _refreshFromNetwork();
  }

  Future<List<EditorialSection>> _refreshFromNetwork() async {
    try {
      final repo = ref.read(homeRepositoryProvider);
      final response = await repo.getEditorial();
      
      // Guardamos en caché para la próxima vez
      final box = Hive.box('home_cache');
      await box.put('editorial_sections', response.sections.map((e) => e.toJson()).toList());
      
      // Actualizamos el estado si el notifier sigue montado
      state = AsyncData(response.sections);
      return response.sections;
    } catch (e, stack) {
      debugPrint('[HomeNetwork] Error actualizando inicio: $e');
      // Si ya teníamos datos del caché, no pisamos con error
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
  final dynamic data; // Puede ser EditorialRow o una categoría de búsqueda

  const HomeLayoutSection({required this.type, this.title, this.data});
}

/// Senior: Provider que orquesta el orden de la pantalla de inicio.
final homeLayoutProvider = FutureProvider<List<HomeLayoutSection>>((ref) async {
  final List<HomeLayoutSection> layout = [];

  // 1. Siempre intentamos poner Historial/Continuar Viendo primero si hay datos.
  layout.add(const HomeLayoutSection(type: HomeSectionType.continueWatching));

  // 2. NUEVO: Top 10 Global (Mezcla de todo lo top)
  layout.add(const HomeLayoutSection(type: HomeSectionType.top10Global, title: 'Top 10 de hoy'));

  // 3. NUEVO: Novedades Unificadas
  layout.add(const HomeLayoutSection(type: HomeSectionType.recentlyAdded, title: 'Recién añadido a AurisTV'));

  // 4. Secciones Editoriales (Placeholder dinámico)
  // Senior Fix: No esperamos a que las editoriales carguen para mostrar el resto del Home.
  // Esto evita el "blank state" prolongado y los picos de CPU al inicio.
  final editorialsAsync = ref.watch(editorialRowsProvider);
  if (editorialsAsync.hasValue) {
    for (final row in editorialsAsync.value!) {
      layout.add(HomeLayoutSection(type: HomeSectionType.editorial, data: row));
    }
  }

  // 5. Agregamos las secciones dinámicas (Tendencias y Estrenos)
  layout.add(const HomeLayoutSection(type: HomeSectionType.recentEpisodes, title: 'Estrenos (Hoy)'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingAnime, title: 'Animes en tendencia'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingMovies, title: 'Películas destacadas'));

  return layout;
});

final editorialRowsProvider = FutureProvider<List<EditorialRow>>((ref) async {
  final sections = await ref.watch(editorialSectionsProvider.future);
  
  // Senior Performance Fix: Limitamos el número de items procesados por fila
  // en el Home para evitar bloqueos del hilo principal al mapear JSON masivos.
  return sections.map((section) {
    final badge = _badgeFromString(section.badge);
    final isMovie = section.badge.toLowerCase().contains('movie');
    
    RowFormat format = RowFormat.vertical;
    final titleLower = section.title.toLowerCase();
    if (badge == EditorialBadge.hiddenGem || 
        badge == EditorialBadge.movieEssential || 
        titleLower.contains('película') ||
        titleLower.contains('pelicula')) {
      format = RowFormat.horizontal;
    }

    // Solo mapeamos los primeros 20 items para el carrusel del home.
    // Esto reduce drásticamente el tiempo de CPU en payloads de 2MB+.
    final displayItems = section.items.take(20).map(_mapEditorialItemToMediaItem).toList();

    return EditorialRow(
      badge: badge ?? EditorialBadge.essential,
      title: section.title,
      subtitle: section.subtitle,
      isMovie: isMovie,
      format: format,
      items: displayItems,
    );
  }).toList();
});

EditorialBadge? _badgeFromString(String? badge) => editorialBadgeFromString(badge);

MediaItem _mapEditorialItemToMediaItem(EditorialItem result) {
  MediaType type = MediaType.series; 
  
  final s = result.source.toLowerCase();
  final t = result.title.toLowerCase();
  final sub = result.subtitle?.toLowerCase() ?? '';
  
  final isAnime = result.badge.toLowerCase().contains('anime') || 
                  sub.contains('anime') || 
                  s.contains('jkanime') || s.contains('flv') || s.contains('katanime') || s.contains('animegratis');
                  
  final isKdrama = s.contains('tudorama') || s.contains('dorama') || s.contains('pandrama') || sub.contains('drama');
  
  final isMovie = result.badge.toLowerCase().contains('movie') || 
                  sub.contains('película') ||
                  t.contains('película');

  if (isAnime) {
    type = MediaType.anime;
  } else if (isKdrama) {
    type = MediaType.kdrama;
  } else if (isMovie) {
    type = MediaType.movie;
  }

  String? displaySubtitle = result.subtitle;
  if (type != MediaType.anime) {
    displaySubtitle = (result.year != null && result.year!.isNotEmpty) ? result.year : null;
  } else if (displaySubtitle != null &&
      (displaySubtitle.toLowerCase().contains('1 ep') || displaySubtitle.toLowerCase().contains('película'))) {
    displaySubtitle = (result.year != null && result.year!.isNotEmpty) ? result.year : null;
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
    source: result.source,
    year: int.tryParse(result.year ?? ''),
    trailerKey: result.trailerKey,
    synopsis: result.synopsis,
    subtitle: displaySubtitle,
    aired: type == MediaType.movie || (result.subtitle?.toLowerCase().contains('finalizado') ?? false),
  );
}

final animeMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(homeRepositoryProvider);
  final response = await repo.search('movie_anime', '');
  return response.results.map((r) => _mapSearchResultToMediaItem(r, 'movie_anime')).toList();
});

final homeCategoryProvider = StateProvider<String>((ref) => 'inicio');

final heroBannerMutedProvider = StateProvider<bool>((ref) => true);

final hoveredCardIdProvider = StateProvider<String?>((ref) => null);

String _mapUiCategoryToApi(String uiCategory) {
  final cat = uiCategory.toLowerCase();
  if (cat == 'animes') return 'anime-seasonal';
  if (cat == 'películas' || cat == 'series' || cat == 'peliculas') return 'peliculas';
  if (cat == 'kdrama') return 'anime'; 
  return 'anime';
}

MediaItem _mapSearchResultToMediaItem(SearchResult result, String category) {
  MediaType type = MediaType.series; 
  final c = category.toLowerCase();
  
  if (c.contains('anime')) type = MediaType.anime;
  else if (c.contains('movie') || c.contains('pelicula')) type = MediaType.movie;
  else if (c.contains('drama')) type = MediaType.kdrama;
  else if (c.contains('series')) type = MediaType.series;

  String? displaySubtitle;
  if (type != MediaType.anime) {
    displaySubtitle = result.year?.toString();
  } else if (result.year != null) {
    displaySubtitle = result.year.toString();
  }

  final isFinished = result.status?.toLowerCase() == 'finished';

  return MediaItem(
    id: result.url,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.thumbnail),
    bannerUrl: ApiEndpoints.proxyImage(result.banner),
    logoUrl: result.logo,
    type: type,
    rating: result.score,
    source: result.source,
    year: result.year,
    trailerKey: result.trailerKey,
    synopsis: result.synopsis,
    subtitle: displaySubtitle,
    aired: type == MediaType.movie || isFinished,
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
    
    final apiCategory = _mapUiCategoryToApi(arg);
    
    final box = Hive.box('home_cache');
    final cacheKey = 'trending_$apiCategory';
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> list = cachedData as List<dynamic>;
        final items = list.map((e) => _mapJsonToMediaItem(Map<String, dynamic>.from(e as Map))).toList();
        _refreshTrending(arg);
        return items;
      } catch (e) {
        debugPrint('[TrendingCache] Error: $e');
      }
    }

    return _refreshTrending(arg);
  }

  Future<List<MediaItem>> _refreshTrending(String uiCategory) async {
    try {
      final repo = ref.read(homeRepositoryProvider);
      final apiCategory = _mapUiCategoryToApi(uiCategory);
      final response = await repo.search(apiCategory, '');

      final Map<String, MediaItem> uniqueItems = {};
      for (var r in response.results) {
        final item = _mapSearchResultToMediaItem(r, apiCategory);
        final key = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (!uniqueItems.containsKey(key)) uniqueItems[key] = item;
      }

      final items = uniqueItems.values.toList();
      
      // Senior Performance Fix: No guardamos ni procesamos más de 30 items
      // para el carrusel de tendencias para evitar saturar el hilo de UI.
      final displayItems = items.take(30).toList();
      
      final box = Hive.box('home_cache');
      await box.put('trending_$uiCategory', displayItems.map((e) => _mapMediaItemToJson(e)).toList());

      state = AsyncData(displayItems);
      return displayItems;
    } catch (e) {
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }

  Map<String, dynamic> _mapMediaItemToJson(MediaItem item) => {
    'id': item.id,
    'title': item.title,
    'posterUrl': item.posterUrl,
    'bannerUrl': item.bannerUrl,
    'logoUrl': item.logoUrl,
    'type': item.type.index,
    'rating': item.rating,
    'year': item.year,
    'synopsis': item.synopsis,
    'romaji': item.romaji,
    'english': item.english,
  };

  MediaItem _mapJsonToMediaItem(Map<String, dynamic> json) => MediaItem(
    id: json['id'],
    title: json['title'],
    posterUrl: json['posterUrl'],
    bannerUrl: json['bannerUrl'],
    logoUrl: json['logoUrl'],
    type: MediaType.values[json['type'] as int],
    rating: json['rating'],
    year: json['year'],
    synopsis: json['synopsis'],
    romaji: json['romaji'],
    english: json['english'],
  );
}

/// Senior: Provider para precargar las categorías principales en segundo plano.
final homePrefetchProvider = FutureProvider<void>((ref) async {
  // Senior Performance Optimization: Carga ESCALONADA (Staggered).
  // Se eliminan los 'await' de los .ignore() porque devuelven void.
  try {
    // 1. Prioridad: Editoriales (Carga inmediata para llenar el layout)
    ref.read(editorialRowsProvider.future).ignore();
    
    // 2. Respiro para procesar el JSON de editoriales (que suele ser el más grande)
    await Future.delayed(const Duration(milliseconds: 1500));
    ref.read(trendingListProvider('animes').future).ignore();
    
    // 3. Carga de Películas y Series con delay mayor
    await Future.delayed(const Duration(milliseconds: 2500));
    ref.read(trendingListProvider('películas').future).ignore();
    
    // 4. Estrenos al final (Suele ser la petición más lenta de scraping)
    await Future.delayed(const Duration(milliseconds: 3500));
    ref.read(recentEpisodesProvider.future).ignore();
  } catch (e) {
    debugPrint('[Senior Prefetch] Error en el disparo de precarga: $e');
  }
});

final recentEpisodesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.keepAlive();
  final repo = ref.watch(homeRepositoryProvider);
  final schedule = await ref.watch(scheduleProvider.future);
  
  final todayItems = schedule.days.firstWhere(
    (d) => d.isToday,
    orElse: () => schedule.days.first,
  ).items.where((item) => item.sourceAvailable).toList();

  return todayItems.map((item) {
    final ep = item.episode ?? 0;
    final isMovie = item.format?.toUpperCase() == 'MOVIE';
    
    return MediaItem(
      id: item.id.toString(),
      title: item.title,
      english: item.english,
      posterUrl: ApiEndpoints.proxyImage(item.coverImage),
      bannerUrl: item.banner != null ? ApiEndpoints.proxyImage(item.banner!) : null,
      type: isMovie ? MediaType.movie : MediaType.anime,
      rating: item.averageScore,
      subtitle: (isMovie || ep == 0)
          ? item.year?.toString()
          : (item.year != null ? '${item.year} • Episodio $ep' : 'Episodio $ep'),
      year: item.year,
      source: '',
      episode: ep == 0 ? null : ep,
      airingAt: item.airingAt,
      aired: isMovie || item.aired || item.status?.toLowerCase() == 'finished',
    );
  }).toList();
});
