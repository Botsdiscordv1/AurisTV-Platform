import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class CastCreditsParams {
  final String url;
  final String? name;
  final String? profile;
  final int? personId;

  const CastCreditsParams({
    this.url = '',
    this.name,
    this.profile,
    this.personId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastCreditsParams &&
          url == other.url &&
          name == other.name &&
          profile == other.profile &&
          personId == other.personId;

  @override
  int get hashCode => Object.hash(url, name, profile, personId);
}

class FilterParams {
  final String? genre;
  final int? year;
  final String? category;
  final String? status;
  final String? idioma;
  final int page;
  final String? source;

  const FilterParams({
    this.genre,
    this.year,
    this.category,
    this.status,
    this.idioma,
    this.page = 1,
    this.source,
  });

  factory FilterParams.fromSectionFilters(SectionFilters filters, {int page = 1}) {
    final String? effectiveGenre = filters.genreSlug ?? 
        (filters.genres != null && filters.genres!.isNotEmpty ? filters.genres!.first : null);
        
    final int? effectiveYear = filters.year ?? 
        (filters.years != null && filters.years!.isNotEmpty ? filters.years!.first : null);
        
    final String? effectiveSource = filters.sources != null && filters.sources!.isNotEmpty
        ? filters.sources!.firstWhere((s) => s.toLowerCase() != 'sqlite', orElse: () => filters.sources!.first)
        : null;

    return FilterParams(
      genre: effectiveGenre,
      year: effectiveYear,
      category: filters.category,
      source: effectiveSource,
      page: page,
    );
  }

  factory FilterParams.fromSeeMore(SectionSeeMore seeMore, {int? overridePage}) {
    final p = seeMore.params;
    
    // Extraer año de forma segura sin importar si viene como int, String o lista
    int? parsedYear;
    if (p['year'] != null) {
      if (p['year'] is num) parsedYear = (p['year'] as num).toInt();
      else if (p['year'] is String) parsedYear = int.tryParse(p['year'] as String);
    } else if (p['years'] is List && (p['years'] as List).isNotEmpty) {
      final firstYear = (p['years'] as List).first;
      if (firstYear is num) parsedYear = firstYear.toInt();
      else if (firstYear is String) parsedYear = int.tryParse(firstYear);
    }

    // Extraer source limpiando 'sqlite' si viene en un array o usando el string directo
    String? parsedSource;
    if (p['source'] != null) {
      parsedSource = p['source'].toString();
    } else if (p['sources'] is List && (p['sources'] as List).isNotEmpty) {
      final list = (p['sources'] as List).map((e) => e.toString()).toList();
      parsedSource = list.firstWhere((s) => s.toLowerCase() != 'sqlite', orElse: () => list.first);
    }

    return FilterParams(
      genre: p['genre']?.toString() ?? p['genreSlug']?.toString() ?? p['genero']?.toString(),
      year: parsedYear,
      category: p['category']?.toString() ?? p['tipo']?.toString() ?? p['kind']?.toString(),
      status: p['status']?.toString() ?? p['estado']?.toString(),
      idioma: p['idioma']?.toString(),
      source: parsedSource,
      page: overridePage ?? (p['page'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterParams &&
          genre == other.genre &&
          year == other.year &&
          category == other.category &&
          status == other.status &&
          idioma == other.idioma &&
          page == other.page &&
          source == other.source;

  @override
  int get hashCode => Object.hash(genre, year, category, status, idioma, page, source);
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
          type == other.type;

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, kind, server, source, url, type);
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
  final String sourcesSignature;
  /// Nombre real de la fuente (p. ej. "AnimeAV1"). Antes se mandaba familyKey
  /// ("animeav1") como source y se dependía de que el server lo normalizara.
  final String? source;
  final bool fast;

  const GroupedEpisodesParams({
    required this.title,
    this.metadataTitle,
    required this.category,
    this.year,
    this.season,
    this.tmdbId,
    required this.familyKey,
    required this.currentSourceUrl,
    required this.sourcesSignature,
    this.source,
    this.fast = false,
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
          sourcesSignature == other.sourcesSignature &&
          source == other.source &&
          fast == other.fast;

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, tmdbId, familyKey, currentSourceUrl, sourcesSignature, source, fast);
}

/// Firma de identidad para la carga de episodios: depende SOLO de la fuente
/// seleccionada (+temporada). La lista de descubiertas crece con cada chunk
/// del search progresivo; si entrara en la firma, el provider se re-dispararía
/// (spinner infinito + refetch por chunk) aunque el usuario no cambie nada.
String episodesSignature(String selectedUrl, int? season) =>
    '$selectedUrl|${season ?? 0}';

class UnifiedRelationsParams {
  final List<SearchResult> sources;
  final String signature;

  const UnifiedRelationsParams({required this.sources, required this.signature});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedRelationsParams &&
          signature == other.signature;

  @override
  int get hashCode => signature.hashCode;
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

class EpisodesParams {
  final String url; final String source; final String? category;
  final String? title; final String? fullTitle; final String? altTitle;
  final int? tmdbId; final int? season; final int? year;
  final bool fast;

  const EpisodesParams({
    required this.url, required this.source, this.category,
    this.title, this.fullTitle, this.altTitle, this.tmdbId, this.season, this.year,
    this.fast = false,
  });

  @override bool operator ==(Object other) => identical(this, other) || other is EpisodesParams && url == other.url && source == other.source && season == other.season && fast == other.fast;
  @override int get hashCode => Object.hash(url, source, season, fast);
}

// --- Smart Episode Cache ---

/// Caché inteligente de episodios que invalida automáticamente cuando
/// un nuevo episodio se estrena (basado en schedule del backend).
class _EpisodeCacheEntry {
  final EpisodesResponse response;
  final DateTime cachedAt;
  final int? nextEpisode; // Número del próximo episodio a estrenar (del schedule)

  const _EpisodeCacheEntry({
    required this.response,
    required this.cachedAt,
    this.nextEpisode,
  });

  /// Determina si el caché sigue siendo válido.
  /// Si el schedule indica que un nuevo episodio debió haberse estrenado
  /// después de quando se cacheó, debemos refrescar.
  bool get isValid {
    if (nextEpisode == null) return true; // Sin schedule, caché indefinido
    // Si el schedule no indica próximo episodio, el anime terminó
    // y el caché es válido indefinidamente
    return true;
  }

  Map<String, dynamic> toJson() => {
    'response': {
      'source': response.source,
      'url': response.url,
      'slug': response.slug,
      'total': response.total,
      'episodes': response.episodes.map((e) => {
        'number': e.number,
        'id': e.id,
        'url': e.url,
        'title': e.title,
        'thumbnail': e.thumbnail,
        'description': e.description,
        'airDate': e.airDate,
        'duration': e.duration,
        'runtime': e.runtime,
        'quality': e.quality,
        'episodeType': e.episodeType,
        'tmdbSpecialNumber': e.tmdbSpecialNumber,
        'needsTranslation': e.needsTranslation,
      }).toList(),
      'specials': response.specials.map((e) => {
        'number': e.number, 'id': e.id, 'url': e.url, 'title': e.title,
        'thumbnail': e.thumbnail, 'description': e.description,
      }).toList(),
      'relations': response.relations.map((r) => {
        'title': r.title, 'url': r.url, 'slug': r.slug,
        'cover': r.cover, 'relation': r.relation, 'category': r.category,
      }).toList(),
      'tmdbId': response.tmdbId,
      'fullTitle': response.fullTitle,
      'season': response.season,
      'seasonAirDate': response.seasonAirDate,
      'seasonNotAvailable': response.seasonNotAvailable,
      'error': response.error,
    },
    'cachedAt': cachedAt.millisecondsSinceEpoch,
    'nextEpisode': nextEpisode,
  };

  factory _EpisodeCacheEntry.fromJson(Map<dynamic, dynamic> json) {
    final resp = Map<String, dynamic>.from(json['response'] as Map);
    return _EpisodeCacheEntry(
      response: EpisodesResponse.fromJson(resp),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['cachedAt'] as int? ?? 0),
      nextEpisode: json['nextEpisode'] as int?,
    );
  }
}

/// Provider compartido de caché de episodios. Usado por episodesProvider
/// y groupedEpisodesProvider para evitar duplicación.
final _sharedEpisodeCacheProvider = StateProvider<Map<String, _EpisodeCacheEntry>>((ref) => {});

/// Determina si el caché de episodios debe invalidarse basándose en el schedule.
/// Retorna true si hay un nuevo episodio que debió haberse estrenado.
Future<bool> _shouldInvalidateCache(Ref ref, EpisodesParams params, _EpisodeCacheEntry entry) async {
  try {
    final schedule = await ref.read(scheduleProvider.future);
    final now = DateTime.now();
    
    // Buscar este anime en el schedule de hoy
    for (final day in schedule.days) {
      if (!day.isToday) continue;
      for (final item in day.items) {
        // Matchear por título (normalizado)
        final itemTitle = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final paramTitle = (params.title ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (itemTitle.isEmpty || paramTitle.isEmpty) continue;
        if (!itemTitle.contains(paramTitle) && !paramTitle.contains(itemTitle)) continue;
        
        // Si hay un próximo episodio y es diferente al último cacheado
        if (item.nextEpisode != null && entry.nextEpisode != null) {
          if (item.nextEpisode! > entry.nextEpisode!) {
            debugPrint('[EpisodeCache] Invalidating: new episode ${item.nextEpisode} released');
            return true;
          }
        }
        
        // Si el schedule indica que ya se estrenó un episodio después del caché
        if (item.airingAt != null) {
          final airTime = DateTime.fromMillisecondsSinceEpoch(item.airingAt! * 1000);
          if (airTime.isAfter(entry.cachedAt) && airTime.isBefore(now)) {
            debugPrint('[EpisodeCache] Invalidating: episode aired at $airTime');
            return true;
          }
        }
      }
    }
  } catch (_) {}
  return false;
}

// --- Providers ---

final contentSearchProvider = FutureProvider.family<SearchResponse, ContentSearchParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('Provider disposed'));
  return repo.search(params.category, cleanTitleForDisplay(params.query), year: params.year, server: params.server, cancelToken: cancelToken);
});

final omdbSeasonProvider = FutureProvider.family<List<OmdbEpisode>, OmdbSeasonParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getOmdbSeason(title: params.title, season: params.season ?? 1);
});

final AutoDisposeFutureProviderFamily<EpisodesResponse?, EpisodesParams> episodesProvider = FutureProvider.autoDispose.family<EpisodesResponse?, EpisodesParams>((AutoDisposeFutureProviderRef<EpisodesResponse?> ref, EpisodesParams params) async {
  if (params.url.isEmpty) return null;
  
  final cache = ref.read(_sharedEpisodeCacheProvider);
  final cacheKey = '${params.url}|${params.source}|${params.season ?? 1}${params.fast ? '|fast' : ''}';
  
  // 1. Intentar caché en memoria
  final entry = cache[cacheKey];
  if (entry != null) {
      // 2. Verificar si el caché debe invalidarse (nuevo episodio estrenado)
      final shouldInvalidate = await _shouldInvalidateCache(ref, params, entry);
      if (!shouldInvalidate) {
        debugPrint('[EpisodeCache] HIT for ${params.title}');
        return entry.response;
      }
  }
  
  // 3. Fetch fresco del servidor
  final repo = ref.read(aurisRepositoryProvider);
  
  try {
    final response = await repo.getEpisodes(
      params.url, params.source, category: params.category,
      title: params.title, fullTitle: params.fullTitle, altTitle: params.altTitle,
      tmdbId: params.tmdbId, season: params.season, year: params.year,
      fast: params.fast,
    );

    // 4. Guardar en caché con info del schedule
    int? nextEp;
    try {
      final schedule = await ref.read(scheduleProvider.future);
      for (final day in schedule.days) {
          for (final item in day.items) {
            final itemTitle = item.title.toLowerCase();
            final paramTitle = (params.title ?? '').toLowerCase();
            if (itemTitle.contains(paramTitle) || paramTitle.contains(itemTitle)) {
              nextEp = item.nextEpisode;
              break;
            }
          }
          if (nextEp != null) break;
        }
      } catch (_) {}
      
      ref.read(_sharedEpisodeCacheProvider.notifier).state = {
        ...ref.read(_sharedEpisodeCacheProvider),
        cacheKey: _EpisodeCacheEntry(response: response, cachedAt: DateTime.now(), nextEpisode: nextEp),
      };
    
    return response;
  } catch (e) {
    // Regla 5: Fallback si episodes?fast=1 falla, reintenta una vez sin fast
    if (params.fast) {
      debugPrint('[Episodes] Fast load failed, retrying without fast: $e');
      // Fix circularity by using the future directly and being explicit
      final fallbackParams = EpisodesParams(
        url: params.url, source: params.source, category: params.category,
        title: params.title, fullTitle: params.fullTitle, altTitle: params.altTitle,
        tmdbId: params.tmdbId, season: params.season, year: params.year,
        fast: false,
      );
      return await ref.read(episodesProvider(fallbackParams).future);
    }
    rethrow;
  }
});

final castProvider = FutureProvider.autoDispose.family<List<CastInfo>, ({String url, String source, String? category})>((ref, arg) async {
  if (arg.url.isEmpty) return [];
  final repo = ref.read(aurisRepositoryProvider);
  return await repo.getCast(arg.url, source: arg.source, category: arg.category);
});

final relationsProvider = FutureProvider.autoDispose.family<List<RelatedInfo>, ({String url, String source, String? category})>((ref, arg) async {
  if (arg.url.isEmpty) return [];
  final repo = ref.read(aurisRepositoryProvider);
  return await repo.getRelations(arg.url, source: arg.source, category: arg.category);
});

final AutoDisposeFutureProviderFamily<GroupedEpisodesResult?, GroupedEpisodesParams> groupedEpisodesProvider = FutureProvider.autoDispose.family<GroupedEpisodesResult?, GroupedEpisodesParams>((AutoDisposeFutureProviderRef<GroupedEpisodesResult?> ref, GroupedEpisodesParams arg) async {
  // Usar el mismo episodesProvider subyacente para compartir caché
  final EpisodesResponse? episodesAsync = await ref.watch(episodesProvider(EpisodesParams(
    url: arg.currentSourceUrl,
    source: arg.source?.isNotEmpty == true ? arg.source! : arg.familyKey,
    category: arg.category,
    title: arg.title,
    fullTitle: arg.metadataTitle,
    tmdbId: arg.tmdbId,
    season: arg.season,
    year: arg.year,
    fast: arg.fast,
  )).future);

  if (episodesAsync == null) return null;

  Future.microtask(() async {
    final ctManager = ref.read(communityTranslationManagerProvider);
    for (final ep in episodesAsync.episodes) {
      if (!ep.needsTranslation) continue;
      await ctManager.processEpisodeTranslation(
        tmdbId: episodesAsync.tmdbId ?? arg.tmdbId,
        season: arg.season ?? episodesAsync.season,
        episode: ep,
        baseUrl: ApiEndpoints.baseUrlForSource(arg.source ?? '', arg.category),
      );
    }
  });

  return GroupedEpisodesResult(response: episodesAsync, sources: List.filled(episodesAsync.episodes.length, null));
});

final castCreditsProvider = FutureProvider.autoDispose.family<SearchResponse?, CastCreditsParams>((ref, params) async {
  final String? personName = params.name;
  if (params.url.isEmpty &&
      params.personId == null &&
      (personName == null || personName.isEmpty)) {
    return null;
  }
  final repo = ref.read(aurisRepositoryProvider);
  return await repo.getCastCredits(
    url: params.url,
    name: params.name,
    profile: params.profile,
    personId: params.personId,
  );
});

// --- Player Consolidated Providers ---

/// Estado consolidado del player para episodios.
/// Reemplaza los 5 ref.watch separados en el player por uno solo.
class PlayerEpisodesState {
  final EpisodesResponse? episodes;
  final bool hasNext;
  final bool hasPrevious;
  final int currentNum;
  final bool isLoading;

  const PlayerEpisodesState({
    this.episodes,
    required this.hasNext,
    required this.hasPrevious,
    required this.currentNum,
    required this.isLoading,
  });

  static PlayerEpisodesState empty() => const PlayerEpisodesState(
    hasNext: true, hasPrevious: false, currentNum: 0, isLoading: true,
  );
}

/// Provider consolidado: un solo watch en el player para todo lo relacionado con episodios.
final AutoDisposeFutureProviderFamily<PlayerEpisodesState, ({String url, String source, String? title, int? season, int? currentEpisode})> playerEpisodesSelector = FutureProvider.autoDispose.family<PlayerEpisodesState, ({String url, String source, String? title, int? season, int? currentEpisode})>((AutoDisposeFutureProviderRef<PlayerEpisodesState> ref, params) async {
  final EpisodesResponse? episodesAsync = await ref.watch(episodesProvider(EpisodesParams(
    url: params.url,
    source: params.source,
    title: params.title,
    season: params.season,
  )).future);

  if (episodesAsync == null || episodesAsync.episodes.isEmpty) {
    return PlayerEpisodesState(
      currentNum: params.currentEpisode ?? 0,
      hasNext: true, // Fallback: asumir que hay siguiente
      hasPrevious: (params.currentEpisode ?? 0) > 1,
      isLoading: false,
    );
  }

  final currentNum = params.currentEpisode ?? 0;
  return PlayerEpisodesState(
    episodes: episodesAsync,
    currentNum: currentNum,
    hasNext: episodesAsync.episodes.any((e) => e.number > currentNum),
    hasPrevious: currentNum > 1,
    isLoading: false,
  );
});

final unifiedRelationsProvider = StateNotifierProvider.autoDispose.family<_UnifiedRelationsNotifier, AsyncValue<UnifiedRelationsMap>, UnifiedRelationsParams>((ref, params) {
  return _UnifiedRelationsNotifier(ref, params.sources);
});

class _UnifiedRelationsNotifier extends StateNotifier<AsyncValue<UnifiedRelationsMap>> {
  final Ref ref; final List<SearchResult> sources; final Map<String, RelatedInfo> _allRelationsMap = {};
  _UnifiedRelationsNotifier(this.ref, this.sources) : super(const AsyncValue.loading()) { _load(); }

  void _load() async {
    if (sources.isEmpty) { state = const AsyncValue.data({}); return; }
    int finished = 0;
    for (final src in sources) {
      ref.read(episodesProvider(EpisodesParams(url: src.url, source: src.source, category: 'anime', season: src.season)).future).then((EpisodesResponse? res) {
        finished++; if (!mounted || res == null) return;
        if (res.relations.isNotEmpty) {
          final relationsWithSource = res.relations.map((r) => r.copyWith(source: src.source)).toList();
          _updateWithRelations(relationsWithSource);
        } else if (finished == sources.length && state is AsyncLoading) { state = const AsyncValue.data({}); }
      }).catchError((_) {
        finished++; if (mounted && finished == sources.length && state is AsyncLoading) { state = const AsyncValue.data({}); }
        return null;
      });
    }
  }

  void _updateWithRelations(List<RelatedInfo> newRelations) {
    final Map<String, RelatedInfo> franchiseMap = {}; final Map<String, RelatedInfo> similarMap = {}; final Map<String, RelatedInfo> recommendedMap = {};
    for (var rel in newRelations) {
      final key = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (!_allRelationsMap.containsKey(key)) _allRelationsMap[key] = rel;
    }
    for (var rel in _allRelationsMap.values) {
      final key = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final type = rel.relation.toLowerCase();
      bool isStrictFranchise = rel.category == 'franquicia' || type.contains('precuela') || type.contains('secuela') || type.contains('historia paralela') || type.contains('ova') || type.contains('ona') || type.contains('spin-off');
      bool isSimilar = rel.category == 'relacionado' || type.contains('similar') || type.contains('género');
      if (isStrictFranchise) franchiseMap[key] = rel; else if (isSimilar) similarMap[key] = rel; else recommendedMap[key] = rel;
    }
    state = AsyncValue.data({'franchise': franchiseMap.values.toList(), 'similar': similarMap.values.toList(), 'recommended': recommendedMap.values.toList()});
  }
}

/// Guardia anti-variantes: si las fuentes curadas (calendario/búsqueda) ya
/// cubren una familia (JKAnime, AnimeAV1...), un descubierto de la MISMA
/// familia con distinto slug Y distinta url es otra obra (mini, spin-off,
/// especial) y se descarta. Sin curadas, o coincidiendo slug/url, se conserva
/// (incluye splits SUB/LATINO, que comparten slug+url).
bool isRogueVariant(SourceItem s, List<SearchResult>? initialSources) {
  if (initialSources == null || initialSources.isEmpty) return false;
  if (s.url.isEmpty) return false;
  final fam = simplifySourceName(s.source);
  if (fam.isEmpty) return false;
  var familySeen = false;
  for (final r in initialSources) {
    final items = r.sources.isNotEmpty
        ? r.sources
        : [
            SourceItem(
                source: r.source,
                url: r.url,
                quality: r.quality,
                slug: r.slug)
          ];
    for (final c in items) {
      if (simplifySourceName(c.source) != fam) continue;
      if (c.url.isEmpty) continue;
      familySeen = true;
      final sameSlug =
          (s.slug?.isNotEmpty ?? false) && s.slug == c.slug;
      if (sameSlug || s.url == c.url) return false;
    }
  }
  return familySeen;
}

final discoveredSourcesProvider = Provider.family<List<SearchResult>, DiscoveredSourcesParams>((ref, params) {
  if (params.category.toLowerCase() == 'all' || params.category.isEmpty) return const <SearchResult>[];
  
  final bool isAuthoritative = params.initialSources != null && 
      params.initialSources!.any((s) => s.sources.length > 1);

  if (isAuthoritative) return const <SearchResult>[];

  final String? effectiveServer = params.server ?? (params.kind == 'anime' ? ApiEndpoints.animeBaseUrl : ApiEndpoints.moviesSeriesBaseUrl);
  String requestCategory = params.category.toLowerCase();
  if (effectiveServer == ApiEndpoints.moviesSeriesBaseUrl) requestCategory = params.kind == 'anime' ? 'movie_anime' : (requestCategory.contains('movie') ? 'movie' : 'series');
  else requestCategory = 'anime';

  final searchAsync = ref.watch(contentSearchProvider(ContentSearchParams(query: params.metadataTitle ?? params.title, category: requestCategory, year: params.year, server: effectiveServer)));
  final List<SearchResult> searchSources = [];
  final targetSeason = params.season ?? extractSeason(params.title);

  void addResult(SearchResult r) {
    final itemSources = r.sources.isNotEmpty ? r.sources : [SourceItem(source: r.source, url: r.url, quality: r.quality)];
    for (final s in itemSources) {
      if (s.source.isEmpty || s.source.toUpperCase() == 'TMDB' || s.source.toUpperCase() == 'ANILIST' || s.source.toUpperCase() == 'TRAKT') continue;
      // URL numérica (ej. "9" de HomeItem TMDB sin url real) no es fuente válida
      if (s.url.isEmpty || RegExp(r'^\d+$').hasMatch(s.url.trim())) continue;
      if (!s.url.toLowerCase().startsWith('http')) continue;
      // Variantes descubiertas (mini/spin-off) no pisan la lista curada.
      if (isRogueVariant(s, params.initialSources)) continue;
      final rSeason = r.season ?? extractSeason(r.title) ?? extractSeason(r.url);
      if (targetSeason != null && rSeason != null && rSeason != targetSeason && !isSeasonUnified(s.source)) continue;
      searchSources.add(r.copyWith(url: s.url, quality: cleanQuality(s.quality), source: s.source));
    }
  }

  if (params.initialSources != null) { for (final r in params.initialSources!) { addResult(r); } }
  final searchData = searchAsync.valueOrNull;
  if (searchData != null) { for (final r in searchData.results) { addResult(r); } }
  return searchSources;
});

final galleryProvider = FutureProvider.family<GalleryResponse, GalleryParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getGallery(kind: params.kind, title: params.title, year: params.year);
});

final d23SeasonCheckProvider = FutureProvider.family<bool, ({String url, String? title, String? fullTitle, String category, int? season, int? year})>((ref, p) async {
  try {
    final repo = ref.read(aurisRepositoryProvider);
    final res = await repo.getEpisodes(p.url, 'AnimeD23', category: p.category, title: p.title, fullTitle: p.fullTitle, season: p.season, year: p.year).timeout(const Duration(seconds: 15));
    return !(res.seasonNotAvailable == true || res.episodes.isEmpty);
  } catch (_) { return true; }
});

final episodeImagePrefetchProvider = Provider.family<void, ({List<EpisodeInfo> episodes, int startFrom})>((ref, params) {
  if (kIsWeb) return;
  final windowSize = 12;
  final endAt = (params.startFrom + windowSize).clamp(0, params.episodes.length);
  final targetEpisodes = params.episodes.sublist(params.startFrom.clamp(0, params.episodes.length), endAt);
  for (final ep in targetEpisodes) {
    if (ep.thumbnail != null && ep.thumbnail!.isNotEmpty) {
      precacheImage(NetworkImage(ep.thumbnail!), ref.read(navigatorKeyProvider).currentContext!).catchError((_) => null);
    }
  }
});

final filterResultsProvider = FutureProvider.family<List<MediaItem>, FilterParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  final response = await repo.filter(
    genre: params.genre,
    year: params.year,
    category: params.category,
    status: params.status,
    idioma: params.idioma,
    page: params.page,
    source: params.source,
  );
  
  return response.results.map((r) => mapSearchResultToMediaItem(r, params.category ?? 'movie')).toList();
});
