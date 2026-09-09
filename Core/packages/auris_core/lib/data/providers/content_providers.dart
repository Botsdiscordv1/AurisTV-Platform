import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../auris_core.dart';
import '../../core/utils/content_logic.dart';
import '../../core/utils/source_utils.dart';

// --- Params Classes ---

class OmdbSeasonParams {
  final String title;
  final int? season;
  const OmdbSeasonParams({required this.title, this.season});
  @override bool operator ==(Object other) => identical(this, other) || other is OmdbSeasonParams && title == other.title && season == other.season;
  @override int get hashCode => Object.hash(title, season);
}

class ContentSearchParams {
  final String query; final String category; final int? year; final String? server;
  const ContentSearchParams({required this.query, required this.category, this.year, this.server});
  @override bool operator ==(Object other) => identical(this, other) || other is ContentSearchParams && query == other.query && category == other.category && year == other.year && server == other.server;
  @override int get hashCode => Object.hash(query, category, year, server);
}

class GalleryParams {
  final String kind;
  final String? title;
  final int? year;
  const GalleryParams({required this.kind, this.title, this.year});
  @override bool operator ==(Object other) => identical(this, other) || other is GalleryParams && kind == other.kind && title == other.title && year == other.year;
  @override int get hashCode => Object.hash(kind, title, year);
}

class DiscoveredSourcesParams {
  final String title;
  final String? metadataTitle;
  final String category;
  final int? year;
  final int? season;
  final String? kind;
  final String? server;
  final String source;
  final String? url;
  final String? type;
  final List<SearchResult>? initialSources;

  const DiscoveredSourcesParams({
    required this.title,
    this.metadataTitle,
    this.category = 'all',
    this.year,
    this.season,
    this.kind,
    this.server,
    this.source = '',
    this.url,
    this.type,
    this.initialSources,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredSourcesParams &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          category == other.category &&
          year == other.year &&
          season == other.season &&
          kind == other.kind &&
          server == other.server &&
          source == other.source &&
          url == other.url &&
          type == other.type &&
          const ListEquality<SearchResult>().equals(initialSources, other.initialSources);

  @override
  int get hashCode => Object.hash(
      title,
      metadataTitle,
      category,
      year,
      season,
      kind,
      server,
      source,
      url,
      type,
      const ListEquality<SearchResult>().hash(initialSources));
}

class GroupedEpisodesParams {
  final String title;
  final String? metadataTitle;
  final String category;
  final int? year;
  final int? season;
  final int? tmdbId;
  final String familyKey;
  final String currentSourceUrl;
  final List<SearchResult> sources;

  const GroupedEpisodesParams({
    required this.title,
    this.metadataTitle,
    required this.category,
    this.year,
    this.season,
    this.tmdbId,
    required this.familyKey,
    required this.currentSourceUrl,
    required this.sources,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupedEpisodesParams &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          category == other.category &&
          year == other.year &&
          season == other.season &&
          tmdbId == other.tmdbId &&
          familyKey == other.familyKey &&
          currentSourceUrl == other.currentSourceUrl &&
          _signature == other._signature;

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, tmdbId, familyKey, currentSourceUrl, _signature);

  String get _signature => sources.map(sourceSignature).join('||');
}

class GroupedEpisodesResult {
  final EpisodesResponse response;
  final List<SearchResult?> sources;
  const GroupedEpisodesResult({required this.response, required this.sources});
  SearchResult? sourceForNumber(int number) {
    for (var i = 0; i < response.episodes.length; i++) {
      if (response.episodes[i].number == number) return sources[i];
    }
    return null;
  }
  SearchResult? sourceForIndex(int index) {
    if (index >= 0 && index < sources.length) return sources[index];
    return null;
  }
}

// --- Providers ---

final omdbSeasonProvider = FutureProvider.family<List<OmdbEpisode>, OmdbSeasonParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  final title = params.title;
  final season = params.season;
  if (season != null && season > 0) {
    return repo.getOmdbSeason(title: title, season: season);
  }
  final romanMap = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10};
  int detectedSeason = 1;
  final t = title.toLowerCase();
  final patterns = [
    RegExp(r'\s(\d+)(?:st|nd|rd|th)?\s+season'),
    RegExp(r'season\s+(\d+)'),
    RegExp(r'\bs(\d{1,2})\b'),
    RegExp(r'\s+(ii|iii|iv|v|vi|vii|viii|ix|x)(?:\s*[:\u2013\-]|\s*$)', caseSensitive: false),
    RegExp(r'\s+(\d+)(?:st|nd|rd|th)?$'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m != null) {
      final raw = m.group(1)!.toLowerCase();
      final parsed = romanMap[raw] ?? int.tryParse(raw);
      if (parsed != null && parsed > 0 && parsed < 30) { detectedSeason = parsed; break; }
    }
  }
  return repo.getOmdbSeason(title: title, season: detectedSeason);
});

final contentSearchProvider = FutureProvider.family<SearchResponse, ContentSearchParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('Provider disposed'));

  // Senior Fix: Asegurar que el query de búsqueda no lleve el año si ya se pasa como parámetro
  final cleanQuery = cleanTitleForDisplay(params.query);
  return repo.search(
    params.category, 
    cleanQuery, 
    year: params.year, 
    server: params.server,
    cancelToken: cancelToken,
  );
});

final galleryProvider = FutureProvider.family<GalleryResponse, GalleryParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getGallery(kind: params.kind, title: params.title, year: params.year);
});

class EpisodesParams {
  final String url; 
  final String source; 
  final String? category;
  final String? title; 
  final String? fullTitle; 
  final String? altTitle; 
  final int? tmdbId; 
  final int? season; 
  final int? year;

  const EpisodesParams({
    required this.url, 
    required this.source, 
    this.category,
    this.title, 
    this.fullTitle, 
    this.altTitle, 
    this.tmdbId, 
    this.season, 
    this.year,
  });

  @override 
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is EpisodesParams && 
    url == other.url && 
    source == other.source;

  @override 
  int get hashCode => Object.hash(url, source);
}

final episodesProvider = FutureProvider.family<EpisodesResponse?, EpisodesParams>((ref, params) async {
  if (params.url.isEmpty) return null;
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getEpisodes(
    params.url, 
    params.source, 
    category: params.category,
    title: params.title, 
    fullTitle: params.fullTitle, 
    altTitle: params.altTitle, 
    tmdbId: params.tmdbId, 
    season: params.season, 
    year: params.year,
  );
});

final unifiedRelationsProvider =
    StateNotifierProvider.autoDispose.family<_UnifiedRelationsNotifier, AsyncValue<Map<String, List<RelatedInfo>>>, List<SearchResult>>((ref, sources) {
  return _UnifiedRelationsNotifier(ref, sources);
});

class _UnifiedRelationsNotifier extends StateNotifier<AsyncValue<Map<String, List<RelatedInfo>>>> {
  final Ref ref;
  final List<SearchResult> sources;
  final Map<String, RelatedInfo> _allRelationsMap = {};

  _UnifiedRelationsNotifier(this.ref, this.sources) : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() async {
    if (sources.isEmpty) {
      state = const AsyncValue.data({});
      return;
    }

    int finished = 0;

    for (final src in sources) {
      ref.read(episodesProvider(EpisodesParams(
        url: src.url, 
        source: src.source,
        category: 'anime',
      )).future).then((res) {
        finished++;
        if (!mounted || res == null) return;
        if (res.relations.isNotEmpty) {
          final relationsWithSource = res.relations.map((r) => r.copyWith(source: src.source)).toList();
          _updateWithRelations(relationsWithSource);
        } else if (finished == sources.length && state is AsyncLoading) {
          state = const AsyncValue.data({});
        }
      }).catchError((_) {
        finished++;
        if (mounted && finished == sources.length && state is AsyncLoading) {
          state = const AsyncValue.data({});
        }
        return null;
      });
    }
  }

  void _updateWithRelations(List<RelatedInfo> newRelations) {
    final Map<String, RelatedInfo> franchiseMap = {};
    final Map<String, RelatedInfo> similarMap = {};
    final Map<String, RelatedInfo> recommendedMap = {};

    for (var rel in newRelations) {
      final cleanTitle = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim();
      final key = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (!_allRelationsMap.containsKey(key)) {
        _allRelationsMap[key] = rel;
      }
    }

    for (var rel in _allRelationsMap.values) {
      final cleanTitle = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim();
      final key = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final type = rel.relation.toLowerCase().trim();

      bool isStrictFranchise = false;
      bool isSimilar = false;

      if (rel.category != null) {
        isStrictFranchise = rel.category == 'franquicia';
        isSimilar = rel.category == 'relacionado';
      } else {
        isStrictFranchise = type.contains('precuela') || 
                            type.contains('secuela') || 
                            type.contains('historia paralela') || 
                            type.contains('historia alternativa') || 
                            type.contains('ova') || 
                            type.contains('ona') ||
                            type.contains('spin-off') ||
                            type.contains('alternativa') ||
                            type.contains('adicional') ||
                            type.contains('personaje incluido') ||
                            type == 'relacionado';

        isSimilar = type.contains('similar') || 
                    type.contains('relacionado') || 
                    type.contains('género');
      }

      if (isStrictFranchise) {
        if (!franchiseMap.containsKey(key)) franchiseMap[key] = rel;
      } else if (isSimilar) {
        if (!similarMap.containsKey(key)) similarMap[key] = rel;
      } else {
        if (!recommendedMap.containsKey(key)) recommendedMap[key] = rel;
      }
    }

    for (final key in franchiseMap.keys) {
      recommendedMap.remove(key);
      similarMap.remove(key);
    }
    for (final key in similarMap.keys) {
      recommendedMap.remove(key);
    }

    state = AsyncValue.data({
      'franchise': franchiseMap.values.toList(),
      'similar': similarMap.values.toList(),
      'recommended': recommendedMap.values.toList(),
    });
  }
}

final groupedEpisodesProvider = FutureProvider.family<GroupedEpisodesResult?, GroupedEpisodesParams>((ref, params) async {
  if (params.sources.isEmpty) return null;
  
  // Evitar mezclar temporadas distintas de la misma familia
  int? _seasonInUrl(String u) {
    final m = RegExp(r'[-/#](\d{1,2})(?:st|nd|rd|th)?-?(?:season|temporada)', caseSensitive: false).firstMatch(u) ??
        RegExp(r'[-/#](?:season|temporada)-(\d{1,2})', caseSensitive: false).firstMatch(u);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  final familySourcesRaw = params.sources.where((s) => simplifySourceName(s.source) == params.familyKey).toList();
  if (familySourcesRaw.isEmpty) return null;

  final familySources = (params.season == null || params.season! <= 1)
      ? familySourcesRaw
      : familySourcesRaw.where((s) {
          final su = _seasonInUrl(s.url);
          return su == null || su == params.season;
        }).toList();

  final hasDubVariant = familySources.any((s) => isDubQuality(s.quality));
  final hasSubVariant = familySources.any((s) => s.quality.isNotEmpty && !isDubQuality(s.quality));
  final hasVariants = hasDubVariant && hasSubVariant;

  // Senior Optimization: Await primary active source first for instant episode list display
  final currentSrc = params.sources.firstWhere(
    (s) => s.url == params.currentSourceUrl,
    orElse: () => familySources.first,
  );

  final primaryFuture = ref.watch(episodesProvider(EpisodesParams(
    url: currentSrc.url,
    source: currentSrc.source,
    category: params.category,
    title: params.title,
    fullTitle: params.metadataTitle,
    tmdbId: params.tmdbId,
    season: params.season,
    year: params.year,
  )).future).catchError((_) => null);

  final secondaryFutures = params.sources
      .where((s) => s.url != currentSrc.url)
      .map((src) => ref.watch(episodesProvider(EpisodesParams(
            url: src.url,
            source: src.source,
            category: params.category,
            title: params.title,
            fullTitle: params.metadataTitle,
            tmdbId: params.tmdbId,
            season: params.season,
            year: params.year,
          )).future).catchError((_) => null))
      .toList();

  final primaryRes = await primaryFuture;
  final secondaryResults = await Future.wait(secondaryFutures).timeout(
    const Duration(seconds: 3),
    onTimeout: () => List<EpisodesResponse?>.filled(secondaryFutures.length, null),
  );

  final results = <EpisodesResponse?>[];
  for (final src in params.sources) {
    if (src.url == currentSrc.url) {
      results.add(primaryRes);
    } else {
      final secIdx = params.sources.where((s) => s.url != currentSrc.url).toList().indexWhere((s) => s.url == src.url);
      results.add(secIdx >= 0 && secIdx < secondaryResults.length ? secondaryResults[secIdx] : null);
    }
  }

  final resBySource = <String, EpisodesResponse?>{};
  for (var i = 0; i < params.sources.length; i++) {
    resBySource[params.sources[i].url] = results[i];
  }

  EpisodesResponse? primary;
  final mergedByNumber = <int, (EpisodeInfo, SearchResult?)>{};
  final mergedRelations = <RelatedInfo>[];
  
  for (final src in familySources) {
    final res = resBySource[src.url];
    if (res == null) continue;
    primary ??= res;
    if (mergedRelations.isEmpty && res.relations.isNotEmpty) {
      mergedRelations.addAll(res.relations);
    }
    for (final ep in res.episodes) {
      final epQuality = ep.quality ?? src.quality;
      final isDub = isDubQuality(epQuality);
      final existing = mergedByNumber[ep.number];
      if (existing == null) {
        mergedByNumber[ep.number] = (ep, src);
      } else if (hasVariants && isDub) {
        final existingEp = existing.$1;
        final existingQuality = existingEp.quality ?? existing.$2?.quality ?? '';
        if (!isDubQuality(existingQuality)) {
          mergedByNumber[ep.number] = (ep, src);
        }
      }
    }
  }

  if (primary == null) return null;

  final mergedSpecials = <EpisodeInfo>[];
  String specialKey(EpisodeInfo e) {
    final t = e.tmdbSpecialNumber;
    if (t != null && t > 0) return 'tmdb$t';
    return '${e.number}:${(e.title ?? '').trim().toLowerCase()}';
  }

  for (final src in params.sources) {
    final res = resBySource[src.url];
    if (res == null) continue;
    for (final sp in res.specials) {
      final key = specialKey(sp);
      final idx = mergedSpecials.indexWhere((e) => specialKey(e) == key);
      if (idx < 0) {
        mergedSpecials.add(sp);
      } else {
        final cur = mergedSpecials[idx];
        final curComplete = cur.url.isNotEmpty && (cur.description?.isNotEmpty ?? false);
        final spComplete = sp.url.isNotEmpty && (sp.description?.isNotEmpty ?? false);
        if (!curComplete && spComplete) mergedSpecials[idx] = sp;
      }
    }
  }
  
  mergedSpecials.sort((a, b) => (a.number).compareTo(b.number));
  final entries = mergedByNumber.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final mergedList = [for (final e in entries) e.value.$1];
  final mergedSources = [for (final e in entries) e.value.$2];

  return GroupedEpisodesResult(
    response: EpisodesResponse(
      source: primary.source,
      url: primary.url,
      slug: primary.slug,
      total: mergedList.length,
      fullTitle: primary.fullTitle,
      episodes: mergedList,
      specials: mergedSpecials,
      relations: mergedRelations.isNotEmpty ? mergedRelations : primary.relations,
      tmdbId: primary.tmdbId,
      season: primary.season,
      seasonAirDate: primary.seasonAirDate,
    ),
    sources: mergedSources,
  );
});

/// Senior Optimization: Lógica de precarga de imágenes para evitar "cuadros grises".
/// Se encarga de descargar silenciosamente las miniaturas de los episodios
/// que el usuario probablemente verá a continuación.
final episodeImagePrefetchProvider = Provider.family<void, ({List<EpisodeInfo> episodes, int startFrom})>((ref, params) {
  // Senior Strategy: Limitamos la precarga a una ventana de 12 episodios
  // para no saturar la RAM ni la red en series largas (One Piece, Black Clover, etc.)
  final windowSize = 12;
  final endAt = (params.startFrom + windowSize).clamp(0, params.episodes.length);
  final targetEpisodes = params.episodes.sublist(
    params.startFrom.clamp(0, params.episodes.length), 
    endAt
  );

  for (final ep in targetEpisodes) {
    if (ep.thumbnail != null && ep.thumbnail!.isNotEmpty) {
      // Usamos el API de Flutter para bajar la imagen al cache de disco/RAM
      // sin pintarla todavía en la UI.
      precacheImage(
        NetworkImage(ep.thumbnail!), 
        ref.read(navigatorKeyProvider).currentContext!,
      ).catchError((_) => null); // Senior Resilience: Fallos de red individuales no bloquean el resto
    }
  }
});

final discoveredSourcesProvider = Provider.family<List<SearchResult>, DiscoveredSourcesParams>((ref, params) {
  // Senior Fix: Si la categoría es 'all', esperamos a que el orquestador resuelva.
  if (params.category.toLowerCase() == 'all' || params.category.isEmpty) {
    return const <SearchResult>[];
  }

  final searchQuery = params.metadataTitle ?? params.title;
  final cat = params.category.toLowerCase();
  final kind = params.kind?.toLowerCase();
  final isFromAnimeServer = params.server == ApiEndpoints.animeBaseUrl;
  
  // 1. Identificar naturaleza del contenido.
  final isAnimeKind = kind == 'anime';
  final isAnimeCat = cat == 'anime';
  final isMovie = cat == 'movie' || kind == 'movie';
  
  // 2. ¿Es una serie de imagen real pura?
  final isStrictLiveActionSeries = (kind == 'series' || cat == 'series') && !isAnimeKind;
  
  // 3. Selección de Servidor y Categoría de Petición.
  final String? effectiveServer = params.server ?? 
      (isStrictLiveActionSeries || (isMovie && !isFromAnimeServer) 
          ? ApiEndpoints.moviesSeriesBaseUrl 
          : (isAnimeKind || isFromAnimeServer ? ApiEndpoints.animeBaseUrl : null));

  String requestCategory = cat;
  if (effectiveServer == ApiEndpoints.moviesSeriesBaseUrl) {
    // Si buscamos en el servidor movie pero es anime, pedimos movie_anime para redirección
    requestCategory = isAnimeKind ? 'movie_anime' : (isMovie ? 'movie' : 'series');
  } else if (effectiveServer == ApiEndpoints.animeBaseUrl) {
    requestCategory = 'anime';
  }

  // --- CATALOG SYNC SIDE EFFECT ---
  // Senior Fix: Reportar fuentes al catálogo global conforme se descubren.
  // Contrato con el server: título BASE de la franquicia + season N (igual que
  // el detail). El server acumula en una sola fila por obra.
  final isAnime = isAnimeKind || isAnimeCat || isFromAnimeServer;
  if (isAnime) {
    final repo = ref.read(aurisRepositoryProvider);
    final catalogTitle = stripSeasonSuffix(params.title);
    void syncResults(AsyncValue<SearchResponse> asyncValue) {
      if (asyncValue.hasValue) {
        final List<SourceItem> toSync = [];
        for (final r in asyncValue.value!.results) {
          if (r.sources.isNotEmpty) {
            toSync.addAll(r.sources);
          } else if (r.source.isNotEmpty && r.url.isNotEmpty) {
            toSync.add(SourceItem(source: r.source, url: r.url, quality: r.quality, slug: r.slug, type: r.type));
          }
        }
        if (toSync.isNotEmpty) {
          repo.updateCatalogSources(
            title: catalogTitle.isNotEmpty ? catalogTitle : params.title,
            season: params.season,
            sources: toSync,
          );
        }
      }
    }

    final searchParams = ContentSearchParams(query: searchQuery, category: requestCategory, year: params.year, server: effectiveServer);
    ref.listen<AsyncValue<SearchResponse>>(contentSearchProvider(searchParams), (prev, next) => syncResults(next));

    final bq = stripSeasonSuffix(searchQuery);
    if (bq.isNotEmpty && bq != searchQuery) {
      ref.listen<AsyncValue<SearchResponse>>(
        contentSearchProvider(ContentSearchParams(query: bq, category: requestCategory, year: params.year, server: effectiveServer)),
        (prev, next) => syncResults(next),
      );
    }

    final rq = (params.season != null && params.season! > 1) ? seasonTitleFor(stripSeasonSuffix(searchQuery), params.season!) : null;
    if (rq != null && rq.toLowerCase() != searchQuery.toLowerCase()) {
      ref.listen<AsyncValue<SearchResponse>>(
        contentSearchProvider(ContentSearchParams(query: rq, category: requestCategory, year: params.year, server: effectiveServer)),
        (prev, next) => syncResults(next),
      );
    }

    if (params.initialSources != null && params.initialSources!.isNotEmpty) {
      Future.microtask(() {
        final List<SourceItem> initial = [];
        for (var r in params.initialSources!) {
          if (r.sources.isNotEmpty) initial.addAll(r.sources);
          else initial.add(SourceItem(source: r.source, url: r.url, quality: r.quality, slug: r.slug, type: r.type));
        }
        if (initial.isNotEmpty) repo.updateCatalogSources(
          title: catalogTitle.isNotEmpty ? catalogTitle : params.title,
          season: params.season,
          sources: initial,
        );
      });
    }
  }

  // Senior Optimization: Solo bloqueamos la búsqueda si ya recibimos una lista 
  // "autoritativa" de fuentes (más de una fuente o una fuente que ya trae sub-fuentes).
  // Esto permite que el Calendario sea instantáneo pero que la Búsqueda Normal 
  // Search all alternative servers to discover all sources (including Calendar)
  final searchAsync = ref.watch(contentSearchProvider(ContentSearchParams(
    query: searchQuery, 
    category: requestCategory, 
    year: params.year, 
    server: effectiveServer
  )));

  final baseSearchQuery = stripSeasonSuffix(searchQuery);
  final baseSearchAsync = (baseSearchQuery.isNotEmpty && baseSearchQuery != searchQuery)
      ? ref.watch(contentSearchProvider(ContentSearchParams(query: baseSearchQuery, category: requestCategory, year: params.year, server: effectiveServer)))
      : null;

  // Query de temporada con ordinal ("X 2nd Season"): coincide con los slugs de
  // las fuentes (JKAnime/AV1/Jara/D23 usan "-2nd-season"). El sufijo roman
  // ("X ii") no existe en ningún catálogo y devolvía basura o mezclaba S1+S2.
  final seasonQuery = (params.season != null && params.season! > 1) ? seasonTitleFor(stripSeasonSuffix(searchQuery), params.season!) : null;
  final seasonSearchAsync = (seasonQuery != null && seasonQuery.toLowerCase() != searchQuery.toLowerCase())
      ? ref.watch(contentSearchProvider(ContentSearchParams(query: seasonQuery, category: requestCategory, year: params.year, server: effectiveServer)))
      : null;

  // 4. Detalle de Anime (Enriquecimiento)
  // Solo enriquecemos si es anime o viene del servidor de anime.
  final allowAnimeDetail = isAnimeKind || isAnimeCat || isFromAnimeServer;
  
  final detailAsync = !allowAnimeDetail 
      ? const AsyncValue<ContentDetailResponse?>.data(null) 
      : ref.watch(unifiedContentDetailProvider(UnifiedDetailParams(
          title: params.title,
          metadataTitle: params.metadataTitle,
          category: params.category,
          kind: params.kind,
          year: params.year,
          season: params.season,
          source: params.source, 
          url: params.url,
          type: params.type,
        )));

  final searchData = searchAsync.valueOrNull;
  final detail = detailAsync.valueOrNull?.anime;
  final isMovieCategory = cat == 'movie' || cat == 'movie_anime' || kind == 'movie';
  final qBase = cleanTitleForMatching(params.title);
  final metaBase = params.metadataTitle != null ? cleanTitleForMatching(params.metadataTitle!) : null;
  final targetSeason = params.season ?? extractSeason(params.title) ?? extractSeason(params.metadataTitle);
  String coreTitle(String cleaned) => cleaned.replaceAll(RegExp(r'\d+$'), '');
  final familyBases = <String>{
    if (qBase.isNotEmpty) coreTitle(qBase),
    if (metaBase != null && metaBase.isNotEmpty) coreTitle(metaBase),
    if (detail != null) ...{
      if (detail.title.isNotEmpty) coreTitle(cleanTitleForMatching(detail.title)),
      if ((detail.titleEnglish?.isNotEmpty ?? false)) coreTitle(cleanTitleForMatching(detail.titleEnglish!)),
      if ((detail.titleJapanese?.isNotEmpty ?? false)) cleanTitleForMatching(detail.titleJapanese!),
    },
  }..removeWhere((e) => e.isEmpty);
  final List<SearchResult> searchSources = [];
  bool seasonMatches(SearchResult r) {
    if (isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source))) return true;
    final rSeason = extractSeason(r.title) ?? extractSeason(r.romaji) ?? extractSeason(r.english);
    if (targetSeason != null) {
      if ((rSeason ?? 1) == targetSeason) return true;
      if (rSeason == null && r.totalSeasons != null && r.totalSeasons! >= targetSeason) return true;
      return false;
    }
    if (rSeason == null || rSeason <= 1) return true;
    if (r.year == null) return false;
    if (params.year == null) return true;
    return params.year == r.year;
  }
  bool yearMatches(SearchResult r) {
    if (params.season != null) return true;
    if (params.year == null || r.year == null) return true;
    return (params.year! - r.year!).abs() <= 1;
  }
  bool strictMatch(SearchResult r) {
    if (isSeasonUnified(r.source)) {
      final baseTitleClean = cleanTitleForMatching(stripSeasonSuffix(params.title));
      final metaTitleClean = params.metadataTitle != null ? cleanTitleForMatching(stripSeasonSuffix(params.metadataTitle!)) : null;
      final rClean = cleanTitleForMatching(r.title);
      final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
      return rClean == baseTitleClean || rRomajiClean == baseTitleClean || (metaTitleClean != null && (rClean == metaTitleClean || rRomajiClean == metaTitleClean));
    }
    final rClean = cleanTitleForMatching(r.title);
    final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
    return (rClean == qBase || rClean == metaBase) || (rRomajiClean == qBase || rRomajiClean == metaBase);
  }
  bool isValidFamilyMatch(String candidate, String base) {
    if (base.contains(candidate) || candidate.contains(base)) {
      final shorter = candidate.length < base.length ? candidate.length : base.length;
      final longer  = candidate.length < base.length ? base.length   : candidate.length;
      return shorter / longer >= 0.5;
    }
    final minLen = candidate.length < base.length ? candidate.length : base.length;
    if (minLen < 8) return false;
    int commonLen = 0;
    for (int i = 0; i < minLen; i++) {
      if (candidate[i] == base[i]) commonLen++;
      else break;
    }
    return commonLen / minLen >= 0.6;
  }
  bool familyMatch(SearchResult r) {
    final rClean = cleanTitleForMatching(r.title);
    final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
    for (final b in familyBases) {
      if (b.length >= 4) {
        if (rClean.isNotEmpty && isValidFamilyMatch(rClean, b)) return true;
        if (rRomajiClean.isNotEmpty && isValidFamilyMatch(rRomajiClean, b)) return true;
      }
    }
    return false;
  }
  final seenSources = <String>{};
  bool isCastellano(SearchResult r, String quality) {
    final t = '${r.title} ${r.romaji ?? ''} ${r.english ?? ''}'.toLowerCase();
    final qLower = quality.toLowerCase();
    final mentionsCastellano = t.contains('castellano') || qLower.contains('castellano');
    if (!mentionsCastellano) return false;
    final hasSubOrLat = qLower.contains('sub') || qLower.contains('latino') || qLower.contains('dub');
    return !hasSubOrLat;
  }
  void addResult(SearchResult r, {bool ignoreSeason = false}) {
    final itemSources = r.sources.isNotEmpty ? r.sources : [SourceItem(source: r.source, url: r.url, quality: r.quality)];
    for (final s in itemSources) {
      final sName = s.source.toUpperCase();
      if (sName == 'TMDB' || sName == 'ANILIST' || sName == 'TRAKT') continue;
      if (isCastellano(r, s.quality)) continue;
      if (isMovieCategory != isMovieResult(r)) continue;
      final rSeason = r.season ?? extractSeason(r.title) ?? extractSeason(r.romaji) ?? extractSeason(r.english) ?? extractSeason(r.url) ?? extractSeason(r.slug) ?? 1;
      if (targetSeason != null && rSeason != targetSeason && !isSeasonUnified(s.source) && !ignoreSeason) continue;
      final qLower = s.quality.toLowerCase();
      final hasSub = qLower.contains('sub');
      final hasLat = qLower.contains('latino') || qLower.contains('dub');
      if (hasSub && hasLat) {
        for (final lang in ['SUB', 'LATINO']) {
          final uniqueKey = '${simplifySourceName(s.source)}_${lang}_${r.slug ?? s.url}'.toLowerCase();
          if (seenSources.add(uniqueKey)) {
            searchSources.add(SearchResult(title: r.title, url: s.url, quality: lang, thumbnail: r.thumbnail, banner: r.banner, source: s.source, slug: r.slug, romaji: r.romaji, english: r.english, year: r.year, score: r.score, status: r.status, type: r.type, kind: r.kind));
          }
        }
      } else {
        final displayQuality = cleanQuality(s.quality);
        final uniqueKey = '${simplifySourceName(s.source)}_${displayQuality}_${r.slug ?? s.url}'.toLowerCase();
        if (seenSources.add(uniqueKey)) {
          searchSources.add(SearchResult(title: r.title, url: s.url, quality: displayQuality, thumbnail: r.thumbnail, banner: r.banner, source: s.source, slug: r.slug, romaji: r.romaji, english: r.english, year: r.year, score: r.score, status: r.status, type: r.type, kind: r.kind));
        }
      }
    }
  }
  for (final r in (params.initialSources ?? const <SearchResult>[])) { addResult(r, ignoreSeason: true); }
  final isMovieCard = params.category == 'movie' || params.category == 'movie_anime' || RegExp(r'\b(movie|película|film)\b', caseSensitive: false).hasMatch(searchQuery);

  final movieMarker = RegExp(r'\b(movie|película|film)\b', caseSensitive: false);
  List<SearchResult> mergedResults = searchData?.results ?? const <SearchResult>[];
  final baseSearchData = baseSearchAsync?.valueOrNull;
  if (baseSearchData != null && baseSearchData.results.isNotEmpty) {
    final seenUrls = <String>{ for (final r in mergedResults) (r.url.isNotEmpty ? r.url : r.title).toLowerCase(), };
    final extras = <SearchResult>[];
    for (final r in baseSearchData.results) {
      final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
      final hasUnified = isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source));
      if (seenUrls.add(key) && hasUnified && familyMatch(r) && (isMovieCard || !movieMarker.hasMatch(r.title))) {
        final unified = r.sources.where((s) => isSeasonUnified(s.source)).toList();
        if (unified.isNotEmpty) { extras.add(r.copyWith(source: unified.first.source, url: unified.first.url, quality: unified.first.quality, sources: unified, status: r.status, type: r.type, kind: r.kind)); }
      }
    }
    if (extras.isNotEmpty) mergedResults = [...mergedResults, ...extras];
  }
  final seasonData = seasonSearchAsync?.valueOrNull;
  if (seasonData != null && seasonData.results.isNotEmpty) {
    final seenUrls = <String>{ for (final r in mergedResults) (r.url.isNotEmpty ? r.url : r.title).toLowerCase(), };
    final seasonExtras = <SearchResult>[];
    for (final r in seasonData.results) {
      final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
      if (seenUrls.add(key)) seasonExtras.add(r);
    }
    if (seasonExtras.isNotEmpty) mergedResults = [...mergedResults, ...seasonExtras];
  }
  if (mergedResults.isEmpty && searchSources.isEmpty) return [];
  final eligible = mergedResults.where((r) => seasonMatches(r) && yearMatches(r)).toList();
  if (params.category == 'movie_anime') {
    for (final r in eligible) { addResult(r); }
    return searchSources;
  }
  for (final r in eligible) {
    final isAjr = isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source));
    if ((isAjr && familyMatch(r)) || strictMatch(r) || (r.kind?.toLowerCase() == 'movie' && familyMatch(r))) addResult(r);
  }
  if (searchSources.isEmpty) { for (final r in eligible) { if (familyMatch(r)) addResult(r); } }

  return searchSources;
});

/// Verifica de forma aislada si AnimeD23 tiene episodios para la temporada
/// pedida. Se usa para ocultar el chip de D23 en la UI cuando el server
/// responde `seasonNotAvailable` (o sin episodios), sin bloquear la lista
/// completa de servidores (la probe de D23 puede tardar varios segundos).
final d23SeasonCheckProvider = FutureProvider.family<bool, ({
  String url,
  String? title,
  String? fullTitle,
  String category,
  int? season,
  int? year,
})>((ref, p) async {
  try {
    final repo = ref.watch(aurisRepositoryProvider);
    final res = await repo
        .getEpisodes(
          p.url,
          'AnimeD23',
          category: p.category,
          title: p.title,
          fullTitle: p.fullTitle,
          season: p.season,
          year: p.year,
        )
        .timeout(const Duration(seconds: 15));
    // El server devuelve `seasonNotAvailable` (o sin episodios) cuando la
    // temporada pedida no existe en D23; en ese caso la ocultamos.
    return !(res.seasonNotAvailable == true || res.episodes.isEmpty);
  } catch (_) {
    return true;
  }
});
