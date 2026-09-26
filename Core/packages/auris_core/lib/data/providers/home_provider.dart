import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../auris_core.dart' hide SectionComposer, ComposedHomeSection, CompositionPreferences;
import '../../core/utils/section_composer.dart';

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
  
  // --- LÓGICA ESPECIAL PARA INICIO (FUSIÓN DE CATEGORÍAS: ANIME, PELÍCULAS, SERIES, KDRAMAS) ---
  if (category == 'inicio') {
    try {
      // Senior Strategy: Pedimos los 4 pilares en paralelo
      // Optimizamos a 1080 (FHD) para el Home, reservando 'original' para detalles.
      final results = await Future.wait([
        repo.getHomeHero(category: 'anime', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
        repo.getHomeHero(category: 'peliculas', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
        repo.getHomeHero(category: 'series', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
        repo.getHomeHero(category: 'kdrama', imgSize: '1080').timeout(const Duration(seconds: 8)).catchError((_) => <MediaItem>[]),
      ]);

      final animes = results[0];
      final movies = results[1];
      final series = results[2];
      final kdramas = results[3];

      // Senior Strategy: Intercalado para ritmo + shuffle con semilla horaria (cada 8h hero distinto, tolera 1-2 repetidos)
      final categories = [animes, movies, series, kdramas];

      final List<MediaItem> mixedHero = [];
      int maxLen = categories.map((l) => l.length).fold(0, (prev, curr) => curr > prev ? curr : prev);

      // Algoritmo de Intercalado Dinámico (Interleaving) - preserva variedad por categoría
      // Barajamos el orden de categorías con seed horario para que cada 8h el interleaving sea distinto
      final bucket = DateTime.now().millisecondsSinceEpoch ~/ const Duration(hours: 8).inMilliseconds;
      final rndCategory = Random(bucket);
      categories.shuffle(rndCategory);
      for (int i = 0; i < maxLen; i++) {
        for (final list in categories) {
          if (i < list.length) {
            mixedHero.add(list[i]);
            if (mixedHero.length >= 30) break;
          }
        }
        if (mixedHero.length >= 30) break;
      }

      if (mixedHero.isNotEmpty) {
        // Shuffle final con la misma semilla horaria y limitar a 10 para hero rotativo diario
        final rndHero = Random(bucket);
        mixedHero.shuffle(rndHero);
        // Senior: Que los primeros 2 no sean anime (anime luego en 3º+)
        if (mixedHero.isNotEmpty && mixedHero[0].type == MediaType.anime) {
          final idx = mixedHero.indexWhere((m) => m.type != MediaType.anime, 1);
          if (idx != -1) {
            final first = mixedHero.removeAt(0);
            mixedHero.insert(idx.clamp(2, mixedHero.length), first);
          }
        }
        if (mixedHero.length > 1 && mixedHero[1].type == MediaType.anime) {
          final idx = mixedHero.indexWhere((m) => m.type != MediaType.anime, 2);
          if (idx != -1) {
            final second = mixedHero.removeAt(1);
            mixedHero.insert(idx.clamp(2, mixedHero.length), second);
          }
        }
        final limited = mixedHero.take(10).toList();
        debugPrint('[heroBannerItemsProvider] Inicio hero ${limited.length}/${mixedHero.length} bucket:$bucket first:${limited.first.type}');
        return limited;
      }
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
    fetchRecent('series'),
    fetchRecent('kdrama'),
  ]);

  final List<MediaItem> merged = [];
  final animes = results[0];
  final movies = results[1];
  final series = results[2];
  final kdramas = results[3];

  int index = 0;
  while (merged.length < 15) {
    bool added = false;
    if (index < animes.length) { merged.add(animes[index]); added = true; }
    if (merged.length < 15 && index < movies.length) { merged.add(movies[index]); added = true; }
    if (merged.length < 15 && index < series.length) { merged.add(series[index]); added = true; }
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
    guardedTrending('series'),
    guardedTrending('kdrama'),
  ]);

  final List<MediaItem> merged = [];
  final animes = results[0];
  final movies = results[1];
  final series = results[2];
  final kdramas = results[3];

  int maxLen = [animes.length, movies.length, series.length, kdramas.length].reduce((a, b) => a > b ? a : b);
  for (int i = 0; i < maxLen; i++) {
    if (i < animes.length) merged.add(animes[i]);
    if (i < movies.length) merged.add(movies[i]);
    if (i < series.length) merged.add(series[i]);
    if (i < kdramas.length) merged.add(kdramas[i]);
    if (merged.length >= 20) break;
  }
  return merged.take(20).toList();
});

final editorialSectionsProvider = AsyncNotifierProvider.family<EditorialSectionsNotifier, List<EditorialSection>, String>(() {
  return EditorialSectionsNotifier();
});

class EditorialSectionsNotifier extends FamilyAsyncNotifier<List<EditorialSection>, String> {
  @override
  FutureOr<List<EditorialSection>> build(String arg) async {
    ref.keepAlive();
    final box = Hive.box('home_cache');
    final cachedData = box.get('editorial_sections_$arg');
    
    if (cachedData != null) {
      try {
        final List<dynamic> list = cachedData as List<dynamic>;
        final sections = list.map((e) => EditorialSection.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _refreshFromNetwork(arg);
        return sections;
      } catch (e) {
        debugPrint('[HomeCache] Error: $e');
      }
    }
    return _refreshFromNetwork(arg);
  }

  Future<List<EditorialSection>> _refreshFromNetwork(String category) async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final authState = ref.read(authProvider);
      final String userId = authState?.activeProfileId ?? authState?.id ?? 'guest_profile';
      // Senior Fix: Solicitamos calidad w780 para secciones editoriales para optimizar carga con soporte de categoría.
      final response = await repo.getEditorial(imgSize: 'w780', category: category, userId: userId);
      final box = Hive.box('home_cache');
      await box.put('editorial_sections_$category', response.sections.map((e) => e.toJson()).toList());
      state = AsyncData(response.sections);
      return response.sections;
    } catch (e) {
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }
}

class EditorialRow {
  final EditorialBadge badge;
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final bool isMovie;
  final SectionPresentation format;
  final SectionSeeMore? verMas;
  
  const EditorialRow({
    required this.badge, 
    required this.title, 
    required this.items, 
    this.subtitle, 
    this.isMovie = false,
    this.format = SectionPresentation.poster,
    this.verMas,
  });
}

enum HomeSectionType {
  editorial,
  trendingAnime,
  trendingMovies,
  recentEpisodes,
  recentlyAdded,
  continueWatching,
  top10Global,
  recommendation,
  discovery // Senior Fix: Soporte para charts y exploraciones dinámicas vía /api/filter
}

class HomeLayoutSection {
  final HomeSectionType type;
  final String? title;
  final dynamic data;
  final SectionPresentation presentation;
  final String? serverFormat; // Cache del formato original del server

  const HomeLayoutSection({
    required this.type, 
    this.title, 
    this.data, 
    this.presentation = SectionPresentation.poster,
    this.serverFormat,
  });
}

/// Senior: Orchestrator for the Home Screen layout.
/// Totalmente reactivo y asíncrono en múltiples etapas para máxima velocidad (UX Instantánea).
final homeLayoutProvider = StreamProvider<List<ComposedHomeSection>>((ref) async* {
  final currentCategory = ref.watch(homeCategoryProvider);
  final repo = ref.watch(aurisRepositoryProvider);
  final authState = ref.watch(authProvider);
  final String userId = authState?.activeProfileId ?? authState?.id ?? 'guest_profile';
  final box = Hive.box('home_cache');
  final cacheKey = 'personalized_home_${userId}_$currentCategory';

  // Senior Fix: Smart Polling. Consultamos una versión ligera del Home cada 15 min.
  // Solo invalidamos y descargamos megas de datos si el servidor indica cambios.
  final refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final remoteVersion = await repo.getHomeVersion(category: currentCategory);
      final localVersion = box.get('home_ver_${userId}_$currentCategory') ?? 0;

      if (remoteVersion > localVersion) {
        debugPrint('[HomeProvider] ¡Nueva versión de Home detectada ($remoteVersion)! Actualizando...');
        await box.put('home_ver_${userId}_$currentCategory', remoteVersion);
        ref.invalidateSelf();
      }
    } catch (_) {}
  });

  ref.onDispose(() => refreshTimer.cancel());

  final List<HomeLayoutSection> rawSections = [];
  final Set<String> sectionTitles = {};

  void addUniqueSections(List<HomeLayoutSection> newSections) {
    for (final s in newSections) {
      if (s.title != null && sectionTitles.add(s.title!)) {
        rawSections.add(s);
      } else if (s.type == HomeSectionType.continueWatching) {
        if (!rawSections.any((x) => x.type == HomeSectionType.continueWatching)) {
          rawSections.add(s);
        }
      }
    }
  }

  // --- ETAPA 1: CACHÉ (Instantánea) ---
  final cachedData = box.get(cacheKey);
  if (cachedData != null) {
    try {
      final homeResponse = HomeResponse.fromJson(Map<String, dynamic>.from(cachedData as Map));
      addUniqueSections(_mapResponseToLayout(homeResponse, currentCategory));
      yield SectionComposer.compose(rawSections);
    } catch (_) {}
  }

  // --- ETAPA 2: EDITORIAL (Rápida ~400ms) ---
  final editorialFutures = <Future<EditorialResponse>>[
    if (currentCategory == 'inicio') ...[
      repo.getEditorial(imgSize: 'w780', category: 'películas', userId: userId).timeout(const Duration(seconds: 5)).catchError((_) => const EditorialResponse(generatedAt: '', locale: '', sections: [])),
      repo.getEditorial(imgSize: 'w780', category: 'series', userId: userId).timeout(const Duration(seconds: 5)).catchError((_) => const EditorialResponse(generatedAt: '', locale: '', sections: [])),
      repo.getEditorial(imgSize: 'w780', category: 'animes', userId: userId).timeout(const Duration(seconds: 5)).catchError((_) => const EditorialResponse(generatedAt: '', locale: '', sections: [])),
      repo.getEditorial(imgSize: 'w780', category: 'kdrama', userId: userId).timeout(const Duration(seconds: 5)).catchError((_) => const EditorialResponse(generatedAt: '', locale: '', sections: [])),
    ] else
      repo.getEditorial(imgSize: 'w780', category: currentCategory, userId: userId).timeout(const Duration(seconds: 5)).catchError((_) => const EditorialResponse(generatedAt: '', locale: '', sections: []))
  ];

  final userHomeFuture = repo.getUserHome(userId: userId, category: currentCategory).timeout(const Duration(seconds: 15)).catchError((e) {
    debugPrint('[homeLayoutProvider] user/home error: $e');
    return const HomeResponse(userId: '', maturityLevel: '', sections: [], generatedAt: '');
  });

  final editorialResponses = await Future.wait(editorialFutures);
  if (currentCategory == 'inicio') {
    final List<List<HomeLayoutSection>> catSections = [];
    final catNames = ['películas', 'series', 'animes', 'kdrama'];
    for (int i = 0; i < editorialResponses.length; i++) {
      final ed = editorialResponses[i];
      if (ed.sections.isNotEmpty) {
        final cat = i < catNames.length ? catNames[i] : 'inicio';
        catSections.add(_mapEditorialResponseToLayout(ed, cat));
      }
    }
    final interleaved = _interleaveInicioSections(catSections);
    addUniqueSections(interleaved);
  } else {
    for (final ed in editorialResponses) {
      if (ed.sections.isNotEmpty) {
        final mapped = _mapEditorialResponseToLayout(ed, currentCategory);
        addUniqueSections(mapped);
      }
    }
  }
  
  yield SectionComposer.compose(rawSections);

  // --- ETAPA 3: PERSONALIZACIÓN (Lenta ~4-10s) ---
  final homeResponse = await userHomeFuture;
  if (homeResponse.sections.isNotEmpty) {
    final personalizedSections = _mapResponseToLayout(homeResponse, currentCategory);
    await box.put(cacheKey, homeResponse.toJson());
    
    if (currentCategory == 'inicio') {
      final combinedInterleaved = _interleaveInicioSections([
        personalizedSections,
        rawSections,
      ]);
      yield SectionComposer.compose(combinedInterleaved);
    } else {
      final List<HomeLayoutSection> finalSections = [];
      final Set<String> finalTitles = {};
      for (final s in personalizedSections) {
        if (s.title != null && finalTitles.add(s.title!)) finalSections.add(s);
        else if (s.type == HomeSectionType.continueWatching) finalSections.add(s);
      }
      for (final s in rawSections) {
        if (s.title != null && !finalTitles.contains(s.title)) finalSections.add(s);
      }
      yield SectionComposer.compose(finalSections);
    }
  }
});

List<HomeLayoutSection> _mapEditorialResponseToLayout(EditorialResponse response, String category) {
  final List<HomeLayoutSection> layout = [];
  for (final section in response.sections) {
    if (section.items.isEmpty) continue;

    final presentation = SectionPresentationResolver.resolve(
      section.badge,
      id: section.title,
      serverFormat: section.format,
    );
    debugPrint('[HomeProvider] editorial "${section.title}" badge="${section.badge}" serverFormat="${section.format}" -> $presentation');
    final isMovie = section.badge.toLowerCase().contains('movie') || category == 'películas';

    final row = EditorialRow(
      badge: editorialBadgeFromString(section.badge) ?? EditorialBadge.essential,
      title: section.title,
      subtitle: section.subtitle,
      items: section.items.map((e) => _mapEditorialItemToMediaItem(e, sectionId: section.id)).toList(),
      isMovie: isMovie,
      format: presentation,
      verMas: section.verMas,
    );

    layout.add(HomeLayoutSection(
      type: HomeSectionType.editorial,
      title: section.title,
      data: row,
      presentation: presentation,
      serverFormat: section.format,
    ));
  }
  return layout;
}

// El método _getCategoryLayout ha sido deprecated en favor de la personalización completa por categoría desde el servidor.
// Se mantiene como referencia interna o fallback si fuera necesario.

List<HomeLayoutSection> _mapResponseToLayout(HomeResponse response, String category) {
  final List<HomeLayoutSection> layout = [];

  // [Senior UX Fix] Forzar "Continuar Viendo" siempre al inicio de la pestaña
  // El widget de UI se encargará de ocultarse si el historial está vacío (SizedBox.shrink).
  layout.add(HomeLayoutSection(
    type: HomeSectionType.continueWatching,
    presentation: SectionPresentation.wide,
    data: category == 'animes' ? 'anime' : null,
  ));

  SectionPresentation? lastPresentation;

  for (final section in response.sections) {
    try {
      if (section.items.isEmpty) continue; // Omitir secciones vacías de forma segura
      
      // Evitar duplicar la sección de continuar viendo si el backend la envía
      if (section.type.toLowerCase().contains('watching') || section.type.toLowerCase().contains('continue')) {
        continue;
      }

      final sectionType = _mapApiSectionType(section.type);
      final List<MediaItem> mediaItems = section.items.map((item) => _mapHomeItemToMediaItem(item, section.id)).toList();

      final String? contextualSubtitle = section.subtitle ?? PersonalizedHomeHelper.getContextSubtitle(section.reasonKeys);

      final apiType = section.type.toLowerCase();
      EditorialBadge badge = EditorialBadge.essential;

      // 1. [Senior UX Rhythm] Asignación de formato ideal según el tipo de sección
      if (apiType == 'editorial_for_you') {
        badge = EditorialBadge.mythical;
      }

      // 2. [Senior UX Resolver] Determinar presentación visual mediante el Resolver Global
      final presentation = SectionPresentationResolver.resolve(
        section.type,
        id: section.title,
        serverFormat: section.format,
      );
      debugPrint('[HomeProvider] section "${section.title}" type="${section.type}" serverFormat="${section.format}" -> $presentation');

      final row = EditorialRow(
        badge: badge,
        title: section.title,
        subtitle: contextualSubtitle,
        items: mediaItems,
        isMovie: mediaItems.any((item) => item.type == MediaType.movie),
        format: presentation,
        verMas: section.verMas,
      );

      layout.add(HomeLayoutSection(
        type: sectionType,
        title: section.title,
        data: row,
        presentation: presentation,
        serverFormat: section.format,
      ));
    } catch (e) {
      debugPrint('[HomeProvider] Error mapping section ${section.title}: $e');
    }
  }
  return layout;
}

Future<void> _processPersonalizedHome(HomeResponse response, Ref ref) async {
  // Aquí se podrían disparar tareas de segundo plano o prefetch si fuera necesario.
}

/// Senior Helper: Intercala y aleatoriza secciones de las 4 categorías (anime, películas, series, kdramas)
/// para la pestaña 'Inicio', respetando estrictamente la jerarquía visual de la pantalla
/// y la armonía de formatos (evita wide-wide o top10-top10 contiguos, y rompe la monotonía de posters).
List<HomeLayoutSection> _interleaveInicioSections(
  List<List<HomeLayoutSection>> categoryLists, {
  int? seed,
}) {
  final int timeSeed = seed ?? (DateTime.now().millisecondsSinceEpoch ~/ const Duration(hours: 4).inMilliseconds);
  final rnd = Random(timeSeed);

  // 1. Clasificar jerárquicamente secciones estructurales fijas
  HomeLayoutSection? continueWatchingSec;
  HomeLayoutSection? primaryTop10Sec;

  final Set<String> seenTitles = {};
  final List<List<HomeLayoutSection>> availablePools = [];

  for (final list in categoryLists) {
    final List<HomeLayoutSection> pool = [];
    for (final sec in list) {
      if (sec.type == HomeSectionType.continueWatching) {
        continueWatchingSec ??= sec;
      } else if (sec.presentation == SectionPresentation.top10 && primaryTop10Sec == null) {
        primaryTop10Sec = sec;
      } else {
        pool.add(sec);
      }
    }
    pool.shuffle(rnd);
    availablePools.add(pool);
  }

  final List<HomeLayoutSection> result = [];

  // Jerarquía posición 0: Continuar Viendo (WIDE)
  if (continueWatchingSec != null) {
    result.add(continueWatchingSec);
    if (continueWatchingSec.title != null) seenTitles.add(continueWatchingSec.title!);
  }

  // Jerarquía posición 1: Ranking / Top 10 Principal (TOP10)
  if (primaryTop10Sec != null) {
    if (primaryTop10Sec.title != null && seenTitles.add(primaryTop10Sec.title!)) {
      result.add(primaryTop10Sec);
    }
  }

  // Orden inicial de categorías para intercalado
  final List<int> categoryOrder = List.generate(availablePools.length, (i) => i);
  categoryOrder.shuffle(rnd);

  int categoryPointer = 0;

  // 2. Loop de armonía visual para intercalar las secciones restantes
  while (availablePools.any((pool) => pool.isNotEmpty)) {
    SectionPresentation? forbiddenFormat;
    SectionPresentation? preferredFormat;

    if (result.isNotEmpty) {
      final lastFormat = result.last.presentation;
      if (lastFormat == SectionPresentation.wide) {
        forbiddenFormat = SectionPresentation.wide; // Evita wide contiguo
      } else if (lastFormat == SectionPresentation.top10) {
        forbiddenFormat = SectionPresentation.top10; // Evita top10 contiguo
      } else if (result.length >= 2 &&
          result[result.length - 1].presentation == SectionPresentation.poster &&
          result[result.length - 2].presentation == SectionPresentation.poster) {
        preferredFormat = SectionPresentation.wide; // Rompe monotonía de 2 posters
      }
    }

    HomeLayoutSection? bestCandidate;
    int? chosenCategoryIndex;
    int? chosenItemIndex;

    // Intento 1: Buscar candidato con formato adecuado de una categoría distinta a la anterior
    for (int step = 0; step < availablePools.length; step++) {
      final catIdx = categoryOrder[(categoryPointer + step) % availablePools.length];
      final pool = availablePools[catIdx];

      for (int i = 0; i < pool.length; i++) {
        final candidate = pool[i];
        final title = candidate.title;

        if (title != null && seenTitles.contains(title)) {
          pool.removeAt(i);
          i--;
          continue;
        }

        final fmt = candidate.presentation;

        if (forbiddenFormat != null && fmt == forbiddenFormat) {
          continue; // Evita repetir el mismo formato especial consecutivamente
        }

        if (preferredFormat != null && fmt != preferredFormat) {
          if (bestCandidate == null) {
            bestCandidate = candidate;
            chosenCategoryIndex = catIdx;
            chosenItemIndex = i;
          }
          continue;
        }

        bestCandidate = candidate;
        chosenCategoryIndex = catIdx;
        chosenItemIndex = i;
        break;
      }

      if (bestCandidate != null && (preferredFormat == null || bestCandidate.presentation == preferredFormat)) {
        break;
      }
    }

    // Intento 2: Fallback si no hubo candidato ideal en la rotación
    if (bestCandidate == null) {
      for (int pass = 0; pass < 2 && bestCandidate == null; pass++) {
        final bool strictHarmony = pass == 0;
        for (int step = 0; step < availablePools.length && bestCandidate == null; step++) {
          final catIdx = categoryOrder[(categoryPointer + step) % availablePools.length];
          final pool = availablePools[catIdx];

          for (int i = 0; i < pool.length; i++) {
            final candidate = pool[i];
            final title = candidate.title;

            if (title != null && seenTitles.contains(title)) {
              pool.removeAt(i);
              i--;
              continue;
            }

            if (strictHarmony && forbiddenFormat != null && candidate.presentation == forbiddenFormat) {
              continue;
            }

            bestCandidate = candidate;
            chosenCategoryIndex = catIdx;
            chosenItemIndex = i;
            break;
          }
        }
      }
    }

    if (bestCandidate != null && chosenCategoryIndex != null && chosenItemIndex != null) {
      result.add(bestCandidate);
      if (bestCandidate.title != null) seenTitles.add(bestCandidate.title!);
      availablePools[chosenCategoryIndex].removeAt(chosenItemIndex);
      categoryPointer = (chosenCategoryIndex + 1) % availablePools.length;
    } else {
      break;
    }
  }

  return result;
}

Future<List<HomeLayoutSection>> _getEditorialFallback(Ref ref, String category) async {
  final List<HomeLayoutSection> layout = [];
  layout.add(HomeLayoutSection(
    type: HomeSectionType.continueWatching,
    presentation: SectionPresentation.wide,
    data: category == 'animes' ? 'anime' : null,
  ));
  layout.add(const HomeLayoutSection(
    type: HomeSectionType.top10Global, 
    title: 'Top 10 de hoy',
    presentation: SectionPresentation.top10,
  ));
  layout.add(const HomeLayoutSection(
    type: HomeSectionType.recentlyAdded, 
    title: 'Recién añadido a AurisTV',
    presentation: SectionPresentation.poster,
  ));

  try {
    if (category == 'inicio') {
      final results = await Future.wait([
        ref.watch(editorialRowsProvider('animes').future).catchError((_) => <EditorialRow>[]),
        ref.watch(editorialRowsProvider('películas').future).catchError((_) => <EditorialRow>[]),
        ref.watch(editorialRowsProvider('series').future).catchError((_) => <EditorialRow>[]),
        ref.watch(editorialRowsProvider('kdrama').future).catchError((_) => <EditorialRow>[]),
      ]);

      final List<List<HomeLayoutSection>> categorySectionLists = [];
      for (final rows in results) {
        final List<HomeLayoutSection> secList = rows.map((row) => HomeLayoutSection(
          type: HomeSectionType.editorial,
          title: row.title,
          data: row,
          presentation: row.format,
        )).toList();
        categorySectionLists.add(secList);
      }

      final interleaved = _interleaveInicioSections(categorySectionLists);
      for (final s in interleaved) {
        if (!layout.any((existing) => existing.title == s.title)) {
          layout.add(s);
        }
      }
    } else {
      final editorials = await ref.watch(editorialRowsProvider(category).future);
      for (final row in editorials) {
        layout.add(HomeLayoutSection(
          type: HomeSectionType.editorial, 
          data: row,
          presentation: row.format,
        ));
      }
    }
  } catch (e) {}

  layout.add(const HomeLayoutSection(
    type: HomeSectionType.recentEpisodes, 
    title: 'Estrenos (Hoy)',
    presentation: SectionPresentation.wide,
  ));
  layout.add(const HomeLayoutSection(
    type: HomeSectionType.trendingAnime, 
    title: 'Animes en tendencia',
    presentation: SectionPresentation.poster,
  ));
  layout.add(const HomeLayoutSection(
    type: HomeSectionType.trendingMovies, 
    title: 'Películas destacadas',
    presentation: SectionPresentation.wide,
  ));

  return layout;
}

HomeSectionType _mapApiSectionType(String apiType) {
  switch (apiType.toLowerCase()) {
    case 'editorial':
    case 'editorial_for_you':
      return HomeSectionType.editorial;
    case 'recommendation':
    case 'for_you':
    case 'more_of_genre':
    case 'because_you_watched':
      return HomeSectionType.recommendation;
    case 'continue_watching':
      return HomeSectionType.continueWatching;
    default:
      return HomeSectionType.editorial;
  }
}

MediaItem _mapHomeItemToMediaItem(HomeItem item, String sectionId) {
  final String rawKind = item.kind?.toLowerCase() ?? '';
  MediaType mediaType = MediaType.series;
  if (rawKind == 'anime' || rawKind == 'tv_anime' || rawKind == 'movie_anime') mediaType = MediaType.anime;
  else if (rawKind == 'movie' || rawKind == 'pelicula') mediaType = MediaType.movie;
  else if (rawKind == 'kdrama') mediaType = MediaType.kdrama;
  else if (rawKind == 'series') mediaType = MediaType.series;

  final String? resolvedSubtitle = PersonalizedHomeHelper.getContextSubtitle(item.reasonKeys);

  // Senior Fix: Fallback de imagen horizontal si no viene del servidor
  final String effectiveBanner = (item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
      ? item.backdropUrl!
      : (item.posterUrl ?? '');

  // Senior Fix: Preservar source/sources reales del servidor (OnlyPelis/GnulaHD) si vienen
  final String effectiveSource = (item.source != null && item.source!.isNotEmpty)
      ? item.source!
      : (item.sources.isNotEmpty ? item.sources.first.source : '');
  final String effectiveUrl = item.url ?? item.detailUrl ?? item.id;
  final List<SourceItem> effectiveSources = item.sources.isNotEmpty
      ? item.sources
      : (effectiveSource.isNotEmpty ? [SourceItem(source: effectiveSource, url: effectiveUrl, quality: 'HD')] : const []);
  final card = SearchResult(
    title: item.title,
    url: effectiveUrl,
    source: effectiveSource,
    quality: 'HD',
    thumbnail: item.posterUrl ?? '',
    banner: effectiveBanner,
    logo: item.logoUrl,
    score: item.score ?? item.rating,
    year: item.year,
    kind: item.kind,
    type: item.type,
    sources: effectiveSources,
  );

  PlaybackHistory? progressHistory;
  if (item.progress != null && item.progress is Map) {
    try {
      final map = Map<String, dynamic>.from(item.progress as Map);
      // Casting ultra-resiliente
      final pos = map['positionInMilliseconds'] ?? map['position'] ?? 0;
      final dur = map['durationInMilliseconds'] ?? map['duration'] ?? 0;
      
      progressHistory = PlaybackHistory(
        contentId: item.id,
        positionInMilliseconds: pos is num ? pos.toInt() : 0,
        durationInMilliseconds: dur is num ? dur.toInt() : 0,
        updatedAt: DateTime.now(),
        title: item.title,
        posterUrl: ApiEndpoints.proxyImage(item.posterUrl, category: rawKind, source: item.detailUrl),
        bannerUrl: ApiEndpoints.proxyImage(effectiveBanner, highQuality: true, category: rawKind, source: item.detailUrl),
      );
    } catch (_) {}
  }

  return MediaItem(
    id: item.id,
    title: item.title,
    posterUrl: ApiEndpoints.proxyImage(item.posterUrl, category: rawKind, source: effectiveSource),
    bannerUrl: ApiEndpoints.proxyImage(effectiveBanner, highQuality: true, category: rawKind, source: effectiveSource),
    logoUrl: item.logoUrl,
    type: mediaType,
    rating: item.rating ?? item.score,
    subtitle: resolvedSubtitle,
    year: item.year,
    detailUrl: item.detailUrl,
    animeId: item.animeId,
    score: item.score,
    reasonKeys: item.reasonKeys,
    playbackHistory: progressHistory,
    sectionId: sectionId,
    source: effectiveSource,
    card: card.copyWith(sectionId: sectionId),
  );
}

final editorialRowsProvider = FutureProvider.family<List<EditorialRow>, String>((ref, category) async {
  final sections = await ref.watch(editorialSectionsProvider(category).future);
  
  final List<EditorialRow> rows = sections.map((section) {
    final badge = editorialBadgeFromString(section.badge);
    final isMovie = section.badge.toLowerCase().contains('movie');
    
    // Usamos el resolver para determinar la presentación editorial
    final presentation = SectionPresentationResolver.resolve(
      section.badge, 
      id: section.title,
      serverFormat: section.format,
    );

    return EditorialRow(
      badge: badge ?? EditorialBadge.essential,
      title: section.title,
      subtitle: section.subtitle,
      isMovie: isMovie,
      format: presentation,
      items: section.items.map((e) => _mapEditorialItemToMediaItem(e, sectionId: section.id)).toList(),
      verMas: section.verMas,
    );
  }).toList();

  // Senior Logic: Ordenar secciones por jerarquía de prestigio editorial
  int getPriority(EditorialBadge badge) {
    switch (badge) {
      case EditorialBadge.mythical: return 0;
      case EditorialBadge.masterpiece: return 1;
      case EditorialBadge.movieEssential: return 2;
      case EditorialBadge.essential: return 3;
      case EditorialBadge.starter: return 4;
      case EditorialBadge.favorite: return 5;
      case EditorialBadge.awardWinner: return 6;
      case EditorialBadge.classic: return 7;
      case EditorialBadge.hiddenGem: return 8;
    }
  }

  rows.sort((a, b) => getPriority(a.badge).compareTo(getPriority(b.badge)));
  return rows;
});

MediaItem _mapEditorialItemToMediaItem(EditorialItem result, {String? sectionId}) {
  MediaType type = MediaType.series;
  final s = result.source.toLowerCase();
  final t = result.title.toLowerCase();
  final sub = result.subtitle?.toLowerCase() ?? '';
  
  final isAnime = result.badge.toLowerCase().contains('anime') || 
                  sub.contains('anime') || 
                  s.contains('jkanime') || s.contains('animejara') || s.contains('animed23');
                  
  final isKdrama = s.contains('tudorama') || s.contains('dorama') || s.contains('pandrama') || s.contains('doramaslatinox') || sub.contains('drama');
  
  final isMovie = result.badge.toLowerCase().contains('movie') || 
                  sub.contains('película') ||
                  t.contains('película');

  if (isAnime) type = MediaType.anime;
  else if (isKdrama) type = MediaType.kdrama;
  else if (isMovie) type = MediaType.movie;

  String? displaySubtitle = result.subtitle;
  if (type != MediaType.anime) {
    displaySubtitle = null; // Senior Fix: Eliminamos el año como subtítulo por petición UX
  } else if (displaySubtitle != null &&
      (displaySubtitle.toLowerCase().contains('1 ep') || displaySubtitle.toLowerCase().contains('película'))) {
    displaySubtitle = null; // Senior Fix: Ocultar año incluso en animes/ovas
  }

  // Senior Fix: Asegurar que el source sea un nombre de servidor válido para UrlUtils
  String effectiveSource = result.source;
  if (effectiveSource.isEmpty) {
    if (result.id.contains('jkanime.net')) effectiveSource = 'JKAnime';
    else if (result.id.contains('animejara.com')) effectiveSource = 'AnimeJara';
    else if (result.id.contains('tudorama.net')) effectiveSource = 'TuDorama';
    else if (result.id.contains('doramaslatinox')) effectiveSource = 'DoramasLatinox';
    else if (result.id.contains('repelishd')) effectiveSource = 'RepelisHD';
  }

  // Senior Fix: Fallback de imagen horizontal para secciones WIDE editoriales
  final String effectiveBanner = (result.bannerUrl != null && result.bannerUrl!.isNotEmpty)
      ? result.bannerUrl!
      : result.posterUrl;

  return MediaItem(
    id: result.id,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.posterUrl, source: effectiveSource, category: result.kind),
    bannerUrl: ApiEndpoints.proxyImage(effectiveBanner, source: effectiveSource, category: result.kind),
    logoUrl: result.logoUrl,
    type: type,
    rating: result.rating,
    source: effectiveSource,
    year: int.tryParse(result.year ?? ''),
    episode: result.episode,
    airingAt: result.airingAt,
    synopsis: result.synopsis,
    subtitle: displaySubtitle,
    aired: type == MediaType.movie || (result.subtitle?.toLowerCase().contains('finalizado') ?? false) || (result.status?.toLowerCase().contains('finalizado') ?? false),
    genres: result.genres,
    certification: result.certification,
    available: sectionId == 'genreUpcoming' ? false : result.available,
    detailUrl: sectionId == 'genreUpcoming' ? '' : (result.detailUrl ?? result.url),
    tmdbId: result.tmdbId,
    sectionId: sectionId,
    card: SearchResult(
      title: result.title,
      url: sectionId == 'genreUpcoming' ? '' : (result.url ?? result.detailUrl ?? result.id),
      quality: result.type ?? 'TV',
      thumbnail: result.posterUrl,
      banner: result.bannerUrl,
      source: effectiveSource,
      romaji: result.romaji,
      english: result.english,
      year: int.tryParse(result.year ?? ''),
      score: result.rating,
      synopsis: result.synopsis,
      trailerKey: result.trailerKey,
      kind: result.kind,
      type: result.type,
      genres: result.genres,
      sources: result.sources,
      sectionId: sectionId,
    ),
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

  final isFinished = result.status?.toLowerCase() == 'finished';

  // Senior Fix: Asegurar que el source sea un nombre de servidor válido
  String effectiveSource = result.source;
  if (effectiveSource.isEmpty) {
    if (result.url.contains('jkanime.net')) effectiveSource = 'JKAnime';
    else if (result.url.contains('animejara.com')) effectiveSource = 'AnimeJara';
    else if (result.url.contains('tudorama.net')) effectiveSource = 'TuDorama';
    else if (result.url.contains('doramaslatinox')) effectiveSource = 'DoramasLatinox';
    else if (result.url.contains('repelishd')) effectiveSource = 'RepelisHD';
  }

  // Senior Fix: Eliminamos el año como subtítulo por petición UX
  const String? displaySubtitle = null;

  return MediaItem(
    id: result.url,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.thumbnail, policy: ImageSize.poster, fallbackUrl: result.tmdbThumbnail),
    bannerUrl: ApiEndpoints.proxyImage(result.banner, policy: ImageSize.banner, fallbackUrl: result.tmdbBanner),
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
    ref.watch(editorialRowsProvider('inicio').future).ignore();
    ref.watch(editorialRowsProvider('animes').future).ignore();
    ref.watch(editorialRowsProvider('películas').future).ignore();
    ref.watch(editorialRowsProvider('series').future).ignore();
    ref.watch(editorialRowsProvider('kdrama').future).ignore();
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
      subtitle: (isMovie || ep == 0) ? null : 'Episodio $ep',
      year: item.year, source: effectiveSource, episode: ep == 0 ? null : ep, airingAt: item.airingAt,
      aired: isMovie || item.aired || item.status?.toLowerCase() == 'finished', card: card,
    );
  }).toList();
});
