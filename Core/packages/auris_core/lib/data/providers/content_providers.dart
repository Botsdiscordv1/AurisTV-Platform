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
    required this.category,
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
  final String sourcesSignature; // Senior Fix: Firma de texto para estabilidad absoluta

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
          sourcesSignature == other.sourcesSignature;

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, tmdbId, familyKey, currentSourceUrl, sourcesSignature);
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

  const EpisodesParams({
    required this.url, required this.source, this.category,
    this.title, this.fullTitle, this.altTitle, this.tmdbId, this.season, this.year,
  });

  @override bool operator ==(Object other) => identical(this, other) || other is EpisodesParams && url == other.url && source == other.source && season == other.season;
  @override int get hashCode => Object.hash(url, source, season);
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

final episodesProvider = FutureProvider.autoDispose.family<EpisodesResponse?, EpisodesParams>((ref, params) async {
  if (params.url.isEmpty) return null;
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getEpisodes(
    params.url, params.source, category: params.category,
    title: params.title, fullTitle: params.fullTitle, altTitle: params.altTitle,
    tmdbId: params.tmdbId, season: params.season, year: params.year,
  );
});

final groupedEpisodesProvider = FutureProvider.autoDispose.family<GroupedEpisodesResult?, GroupedEpisodesParams>((ref, arg) async {
  final repo = ref.watch(aurisRepositoryProvider);
  
  // Senior Fix: Carga del primario con prioridad.
  // No usamos ref.read(...).future para no perder la reactividad si el repo cambia.
  final primaryRes = await repo.getEpisodes(
    arg.currentSourceUrl, arg.familyKey, category: arg.category,
    title: arg.title, fullTitle: arg.metadataTitle, tmdbId: arg.tmdbId,
    season: arg.season, year: arg.year,
  );

  // Traducciones en background real
  Future.microtask(() {
    final ctManager = ref.read(communityTranslationManagerProvider);
    for (final ep in primaryRes.episodes) {
      if (ep.description == null || ep.description!.isEmpty) {
        unawaited(ctManager.processEpisodeTranslation(tmdbId: primaryRes.tmdbId ?? arg.tmdbId, season: arg.season ?? primaryRes.season, episode: ep));
      }
    }
  });

  return GroupedEpisodesResult(response: primaryRes, sources: List.filled(primaryRes.episodes.length, null));
});

final unifiedRelationsProvider = StateNotifierProvider.autoDispose.family<_UnifiedRelationsNotifier, AsyncValue<UnifiedRelationsMap>, List<SearchResult>>((ref, sources) {
  return _UnifiedRelationsNotifier(ref, sources);
});

class _UnifiedRelationsNotifier extends StateNotifier<AsyncValue<UnifiedRelationsMap>> {
  final Ref ref; final List<SearchResult> sources; final Map<String, RelatedInfo> _allRelationsMap = {};
  _UnifiedRelationsNotifier(this.ref, this.sources) : super(const AsyncValue.loading()) { _load(); }

  void _load() async {
    if (sources.isEmpty) { state = const AsyncValue.data({}); return; }
    int finished = 0;
    for (final src in sources) {
      ref.read(episodesProvider(EpisodesParams(url: src.url, source: src.source, category: 'anime', season: src.season)).future).then((res) {
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

final discoveredSourcesProvider = Provider.family<List<SearchResult>, DiscoveredSourcesParams>((ref, params) {
  if (params.category.toLowerCase() == 'all' || params.category.isEmpty) return const <SearchResult>[];
  
  // Senior Fix: Solo modo autoritativo si tiene sub-fuentes verificadas.
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
      if (s.source.toUpperCase() == 'TMDB' || s.source.toUpperCase() == 'ANILIST') continue;
      
      // Senior Fix: Relajamos filtro de temporada para no perder fuentes en S2+
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
