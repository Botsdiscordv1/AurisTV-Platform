import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:auris_core/auris_core.dart';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

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
/// En una fase avanzada, esto vendría de un endpoint /api/home/layout.
final homeLayoutProvider = FutureProvider<List<HomeLayoutSection>>((ref) async {
  final List<HomeLayoutSection> layout = [];

  // 1. Siempre intentamos poner Historial/Continuar Viendo primero si hay datos.
  layout.add(const HomeLayoutSection(type: HomeSectionType.continueWatching));

  // 2. NUEVO: Top 10 Global (Mezcla de todo lo top)
  layout.add(const HomeLayoutSection(type: HomeSectionType.top10Global, title: 'Top 10 de hoy'));

  // 3. NUEVO: Novedades Unificadas
  layout.add(const HomeLayoutSection(type: HomeSectionType.recentlyAdded, title: 'Recién añadido a AurisTV'));

  // 4. Cargamos las secciones editoriales unificadas.
  try {
    final editorials = await ref.watch(editorialRowsProvider.future);
    // Agregamos las secciones editoriales al inicio
    for (final row in editorials) {
      layout.add(HomeLayoutSection(type: HomeSectionType.editorial, data: row));
    }
  } catch (e) {
    debugPrint('[HomeLayout] Error cargando editoriales: $e');
  }

  // 3. Agregamos las secciones dinámicas (Tendencias y Estrenos)
  // Senior Logic: Podríamos barajar estas secciones o basarlas en la hora del día.
  layout.add(const HomeLayoutSection(type: HomeSectionType.recentEpisodes, title: 'Estrenos (Hoy)'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingAnime, title: 'Animes en tendencia'));
  layout.add(const HomeLayoutSection(type: HomeSectionType.trendingMovies, title: 'Películas destacadas'));

  return layout;
});

final editorialRowsProvider = FutureProvider<List<EditorialRow>>((ref) async {
  final sections = await ref.watch(editorialSectionsProvider.future);
  return sections.map((section) {
    final badge = _badgeFromString(section.badge);
    final isMovie = section.badge.toLowerCase().contains('movie');
    
    // Senior UI Logic: Decidimos el formato basado en el badge o contenido.
    // Joyas ocultas y Películas imprescindibles usan formato horizontal (16:9).
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

EditorialBadge? _badgeFromString(String? badge) => editorialBadgeFromString(badge);

MediaItem _mapEditorialItemToMediaItem(EditorialItem result) {
  MediaType type = MediaType.series; // Senior: Por defecto ahora es Series (Puerto 3001)
  
  // Senior UI Logic: Detección inteligente de tipo basado en fuente y metadatos.
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
  // Si no entra en los anteriores, se queda como MediaType.series (Puerto 3001)

  // Senior UI Logic: Para películas, series y dramas limpiamos etiquetas técnicas redundantes
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

/// Senior: Global state for the Hero Banner mute status to allow control from the Navbar.
final heroBannerMutedProvider = StateProvider<bool>((ref) => true);

/// Senior: Exclusividad de expansión para evitar que varias tarjetas se expandan a la vez en un carrusel.
final hoveredCardIdProvider = StateProvider<String?>((ref) => null);

String _mapUiCategoryToApi(String uiCategory) {
  switch (uiCategory.toLowerCase()) {
    case 'animes':
      return 'anime-seasonal';
    case 'películas':
      return 'peliculas';
    case 'series':
      return 'peliculas';
    default:
      return 'anime';
  }
}

MediaItem _mapSearchResultToMediaItem(SearchResult result, String category) {
  MediaType type = MediaType.series; // Senior: Fallback a Series (Puerto 3001)
  final c = category.toLowerCase();
  
  if (c.contains('anime')) type = MediaType.anime;
  else if (c.contains('movie') || c.contains('pelicula')) type = MediaType.movie;
  else if (c.contains('drama')) type = MediaType.kdrama;
  else if (c.contains('series')) type = MediaType.series;

  // Senior UI Logic: En cine y series mostramos el año como etiqueta; en anime, el año
  // cuando existe. El rating se pinta como badge (★) en la tarjeta.
  String? displaySubtitle;
  if (type != MediaType.anime) {
    displaySubtitle = result.year?.toString();
  } else if (result.year != null) {
    displaySubtitle = result.year.toString();
  }

  // Estado de emisión desde el status del servidor (RELEASING/FINISHED/NOT_YET_RELEASED).
  final isFinished = result.status?.toLowerCase() == 'finished';

  return MediaItem(
    id: result.url,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.thumbnail, fallbackUrl: result.tmdbThumbnail),
    bannerUrl: ApiEndpoints.proxyImage(result.banner, fallbackUrl: result.tmdbBanner),
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

/// Senior: Provider para las tendencias con caché agresiva para el HeroBanner.
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
      
      // Guardar en caché
      final box = Hive.box('home_cache');
      await box.put('trending_$uiCategory', items.map((e) => _mapMediaItemToJson(e)).toList());

      state = AsyncData(items);
      return items;
    } catch (e) {
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }

  // Helpers para serialización rápida de MediaItem (Senior Tip: Solo campos necesarios para Home)
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
  // Senior Performance Optimization: Lanzamos todo en paralelo y olvidamos.
  // El ApiClient ahora fallará a los 30s-60s según los nuevos límites de scraping.
  try {
    ref.watch(editorialRowsProvider.future).ignore();
    ref.watch(trendingListProvider('animes').future).ignore();
    ref.watch(trendingListProvider('películas').future).ignore();
    ref.watch(trendingListProvider('series').future).ignore();
    ref.watch(recentEpisodesProvider.future).ignore();
  } catch (e) {
    debugPrint('[Senior Prefetch] Error en el disparo de precarga: $e');
  }
});

final recentEpisodesProvider = FutureProvider<List<MediaItem>>((ref) async {
  ref.keepAlive();
  final schedule = await ref.watch(scheduleProvider.future);

  final todayItems = schedule.days
      .firstWhere(
        (d) => d.isToday,
        orElse: () => schedule.days.first,
      )
      .items
      .where((item) => item.sourceAvailable)
      .toList();

  return todayItems.map((item) {
    final ep = item.episode ?? 0;
    final isMovie = item.format?.toUpperCase() == 'MOVIE';
    final metaTitle = item.romaji ?? item.english ?? item.title;
    final itemYear = item.year ??
        (item.airingAt != null
            ? DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000).year
            : null);

    // Senior Optimization: Construimos la semilla SearchResult directamente
    // para que la navegación desde Home sea igual de rápida que desde Schedule.
    final card = SearchResult(
      title: item.title,
      source: item.source ?? '',
      url: item.url ?? '',
      thumbnail: ApiEndpoints.proxyImage(item.coverImage),
      quality: item.quality ?? 'HD',
      kind: 'anime',
      type: item.type,
      slug: item.slug,
      year: itemYear,
      romaji: item.romaji,
      english: item.english,
      sources: item.sources
          .map((s) => SourceItem(
                source: s.source,
                url: s.url,
                quality: s.quality,
                slug: s.slug,
                type: s.type,
              ))
          .toList(),
    );

    return MediaItem(
      id: item.url ?? item.id.toString(),
      title: item.title,
      romaji: item.romaji,
      english: item.english,
      posterUrl: ApiEndpoints.proxyImage(item.coverImage),
      bannerUrl:
          item.banner != null ? ApiEndpoints.proxyImage(item.banner!) : null,
      type: isMovie ? MediaType.movie : MediaType.anime,
      rating: item.averageScore,
      subtitle: (isMovie || ep == 0)
          ? item.year?.toString()
          : (item.year != null ? '${item.year} • Episodio $ep' : 'Episodio $ep'),
      year: item.year,
      source: item.source ?? '',
      episode: ep == 0 ? null : ep,
      airingAt: item.airingAt,
      aired: isMovie || item.aired || item.status?.toLowerCase() == 'finished',
      card: card,
    );
  }).toList();
});
