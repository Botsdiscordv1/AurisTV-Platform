import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../models/server/anime_detail.dart';
import '../models/server/movie_detail.dart';
import '../models/server/search_result.dart';
import '../models/server/detail_params.dart';
import '../models/server/episodes_response.dart';
import '../models/server/shared_models.dart';
import '../models/unified_content_state.dart';
import '../providers/content_providers.dart';
import '../providers/community_translation_provider.dart';
import '../providers/player_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/api/providers.dart';
import '../../core/utils/content_logic.dart';
import '../../core/utils/source_utils.dart';

/// Gestiona la entrada del usuario de forma ultra-estable.
class _UnifiedContentInput {
  final int season;
  final String? manualKey;
  final String? frozenKey;

  _UnifiedContentInput({required this.season, this.manualKey, this.frozenKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedContentInput &&
          season == other.season &&
          manualKey == other.manualKey &&
          frozenKey == other.frozenKey;

  @override
  int get hashCode => Object.hash(season, manualKey, frozenKey);

  _UnifiedContentInput copyWith({int? season, String? manualKey, String? frozenKey}) {
    return _UnifiedContentInput(
      season: season ?? this.season,
      manualKey: manualKey ?? this.manualKey,
      frozenKey: frozenKey ?? this.frozenKey,
    );
  }
}

class _UnifiedContentInputNotifier extends StateNotifier<_UnifiedContentInput> {
  _UnifiedContentInputNotifier(int initialSeason, String? initialKey)
      : super(_UnifiedContentInput(season: initialSeason, frozenKey: initialKey));

  void setSeason(int season, String? resetFrozen) {
    if (state.season == season) return;
    state = _UnifiedContentInput(season: season, frozenKey: resetFrozen);
  }

  void setSource(SearchResult source) {
    state = state.copyWith(manualKey: '${source.source}|${source.url}');
  }

  void freeze(SearchResult source) {
    if (state.frozenKey != null) return;
    state = state.copyWith(frozenKey: '${source.source}|${source.url}');
  }
}

final _inputProvider = StateNotifierProvider.autoDispose
    .family<_UnifiedContentInputNotifier, _UnifiedContentInput, UnifiedDetailParams>((ref, params) {
  final initialSeason = params.season ?? extractSeason(params.url) ?? extractSeason(params.title) ?? 1;
  String? seedKey;
  if (params.initialSources?.isNotEmpty ?? false) {
    seedKey = '${params.initialSources!.first.source}|${params.initialSources!.first.url}';
  }
  return _UnifiedContentInputNotifier(initialSeason, seedKey);
});

/// --- PROVEEDOR MAESTRO UNIFICADO (V14 - SELECTION LOCK) ---
final unifiedContentProvider = Provider.autoDispose
    .family<UnifiedContentState, UnifiedDetailParams>((ref, params) {
  
  final input = ref.watch(_inputProvider(params));
  final inputNotifier = ref.read(_inputProvider(params).notifier);

  // 1. Metadatos
  final detailAsync = ref.watch(unifiedContentDetailProvider(params.copyWith(season: input.season)));

  // 2. Fuentes suplementarias
  final sourcesParams = DiscoveredSourcesParams(
    title: stripSeasonSuffix(params.title),
    metadataTitle: params.metadataTitle != null ? stripSeasonSuffix(params.metadataTitle!) : null,
    category: params.category,
    kind: params.kind,
    year: params.year,
    season: input.season,
    source: params.source,
    url: params.url ?? '',
    type: params.type,
    initialSources: params.initialSources,
  );
  final discovered = ref.watch(discoveredSourcesProvider(sourcesParams));

  // 3. Mezcla Determinística
  final List<SearchResult> allSources = [];
  final Set<String> seen = {};

  void add(SearchResult s) {
    final key = '${s.source}|${s.url}';
    if (seen.add(key)) {
      if (isSeasonUnified(s.source)) {
        final base = s.url.split('#')[0];
        allSources.add(s.copyWith(url: '$base#season-${input.season}'));
      } else {
        allSources.add(s);
      }
    }
  }

  // Expandir fuentes curadas: cada SearchResult trae sus `sources` anidadas
  // (calendario). Hay que desplegarlas en chips individuales; si no, solo
  // queda 1 chip (la fuente primaria).
  if (params.initialSources != null) {
    for (final r in params.initialSources!) {
      final items = r.sources.isNotEmpty
          ? r.sources
          : [SourceItem(source: r.source, url: r.url, quality: r.quality, slug: r.slug, type: r.type)];
      for (final s in items) {
        if (s.source.isEmpty || s.source.toUpperCase() == 'TMDB' || s.source.toUpperCase() == 'ANILIST' || s.source.toUpperCase() == 'TRAKT') continue;
        if (s.url.isEmpty || RegExp(r'^\d+$').hasMatch(s.url.trim()) || !s.url.toLowerCase().startsWith('http')) continue;
        add(r.copyWith(source: s.source, url: s.url, quality: s.quality, slug: s.slug, type: s.type));
      }
    }
  }
  for (final s in discovered) {
    if (s.source.isEmpty || s.url.isEmpty || RegExp(r'^\d+$').hasMatch(s.url.trim()) || !s.url.toLowerCase().startsWith('http')) continue;
    add(s);
  }
  allSources.sort((a, b) => sourceDisplayRank(a.source).compareTo(sourceDisplayRank(b.source)));

  // 4. Bloqueo de Selección (Freeze)
  if (input.frozenKey == null && allSources.isNotEmpty) {
    Future.microtask(() => inputNotifier.freeze(allSources.first));
  }

  // 5. Selección Inmutable (Manual > Congelada > Primera)
  final effectiveKey = input.manualKey ?? input.frozenKey;
  final selected = (effectiveKey != null) 
      ? (allSources.firstWhereOrNull((s) => '${s.source}|${s.url}' == effectiveKey) ?? (allSources.isNotEmpty ? allSources.first : null))
      : (allSources.isNotEmpty ? allSources.first : null);

  // 6. Carga Progresiva (Paso 1: Fast -> Paso 2: Full + Cast + Relations -> Paso 3: Merge)
  AsyncValue<GroupedEpisodesResult?> episodesAsync = const AsyncValue.loading();
  AsyncValue<List<CastInfo>> castAsync = const AsyncValue.loading();
  AsyncValue<UnifiedRelationsMap> relationsAsync = const AsyncValue.loading();

  if (selected != null) {
    final detailData = detailAsync.valueOrNull;
    final isMovieish = detailData?.isMovieish ?? (params.category.contains('movie') || 
                       params.kind?.toLowerCase().contains('movie') == true || 
                       params.kind?.toLowerCase().contains('pelicula') == true ||
                       params.type?.toLowerCase().contains('movie') == true);

    final progParams = ProgressiveParams(
      url: selected.url,
      source: selected.source,
      category: params.category,
      title: input.season > 1 ? seasonTitleFor(stripSeasonSuffix(params.title), input.season) : params.title,
      metadataTitle: params.metadataTitle ?? params.title,
      season: input.season,
      year: params.year,
      tmdbId: detailData?.anime?.tmdbId ?? int.tryParse(detailData?.movie?.tmdbId ?? ''),
      isMovieish: isMovieish,
    );

    final progState = ref.watch(progressiveContentProvider(progParams));

    episodesAsync = progState.episodes;
    castAsync = progState.cast;
    relationsAsync = progState.relations;
  }

  final detailData = detailAsync.valueOrNull;
  return UnifiedContentState(
    detail: detailAsync,
    allSources: allSources,
    selectedSource: selected,
    currentSeason: input.season,
    totalSeasons: detailData != null 
        ? (detailData.anime?.totalSeasons ?? detailData.movie?.totalSeasons ?? detailData.movie?.seasons.length ?? 1)
        : 1,
    episodes: episodesAsync,
    cast: castAsync,
    relations: relationsAsync,
    isMovieish: detailData?.isMovieish ?? (params.category.contains('movie') || 
                 params.kind?.toLowerCase().contains('movie') == true || 
                 params.kind?.toLowerCase().contains('pelicula') == true ||
                 params.type?.toLowerCase().contains('movie') == true),
    seasonTitle: input.season > 1 ? seasonTitleFor(stripSeasonSuffix(params.title), input.season) : null,
  );
});

/// Tracker de personalización para la vista de detalle.
/// Se dispara una única vez cuando el detalle de un anime es cargado y visualizado.
final detailViewTrackerProvider = Provider.autoDispose.family<void, UnifiedDetailParams>((ref, params) {
  ref.listen<UnifiedContentState>(unifiedContentProvider(params), (prev, next) {
    final animeId = next.detail.valueOrNull?.anime?.id;
    if (animeId != null) {
      final auth = ref.read(authProvider);
      ref.read(userEventTrackerProvider).record(
        userId: auth?.activeProfileId ?? auth?.id,
        animeId: animeId,
        event: 'detail_view',
        sectionId: params.sectionId,
      );
    }
  }, fireImmediately: true);
});

extension UnifiedContentActions on WidgetRef {
  void setSeason(UnifiedDetailParams params, int season) {
    final seedKey = params.initialSources?.isNotEmpty == true ? '${params.initialSources!.first.source}|${params.initialSources!.first.url}' : null;
    read(_inputProvider(params).notifier).setSeason(season, seedKey);
  }
  void setSource(UnifiedDetailParams params, SearchResult source) {
    read(_inputProvider(params).notifier).setSource(source);
  }
}

extension UnifiedDetailParamsExt on UnifiedDetailParams {
  UnifiedDetailParams copyWith({int? season}) {
    return UnifiedDetailParams(
      title: title, metadataTitle: metadataTitle, category: category,
      kind: kind, year: year, season: season ?? this.season,
      source: source, url: url, type: type, sectionId: sectionId,
      initialSources: initialSources,
    );
  }
}

class ProgressiveParams {
  final String url;
  final String source;
  final String category;
  final String title;
  final String? metadataTitle;
  final int season;
  final int? year;
  final int? tmdbId;
  final bool isMovieish;

  const ProgressiveParams({
    required this.url,
    required this.source,
    required this.category,
    required this.title,
    this.metadataTitle,
    required this.season,
    this.year,
    this.tmdbId,
    this.isMovieish = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressiveParams &&
          url == other.url &&
          source == other.source &&
          category == other.category &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          season == other.season &&
          year == other.year &&
          tmdbId == other.tmdbId &&
          isMovieish == other.isMovieish;

  @override
  int get hashCode => Object.hash(
        url,
        source,
        category,
        title,
        metadataTitle,
        season,
        year,
        tmdbId,
        isMovieish,
      );
}

class ProgressiveContentState {
  final AsyncValue<GroupedEpisodesResult?> episodes;
  final AsyncValue<List<CastInfo>> cast;
  final AsyncValue<UnifiedRelationsMap> relations;

  const ProgressiveContentState({
    this.episodes = const AsyncValue.loading(),
    this.cast = const AsyncValue.loading(),
    this.relations = const AsyncValue.loading(),
  });

  ProgressiveContentState copyWith({
    AsyncValue<GroupedEpisodesResult?>? episodes,
    AsyncValue<List<CastInfo>>? cast,
    AsyncValue<UnifiedRelationsMap>? relations,
  }) {
    return ProgressiveContentState(
      episodes: episodes ?? this.episodes,
      cast: cast ?? this.cast,
      relations: relations ?? this.relations,
    );
  }
}

class ProgressiveContentNotifier extends StateNotifier<ProgressiveContentState> {
  final Ref _ref;
  final ProgressiveParams _params;

  ProgressiveContentNotifier(this._ref, this._params)
      : super(const ProgressiveContentState()) {
    _startFlow();
  }

  Future<void> _startFlow() async {
    final repo = _ref.read(aurisRepositoryProvider);

    // Paso 1 — Carga instantánea (bloqueante, solo esto)
    // GET /api/episodes?url={fichaUrl}&source={S}&season={N}&fast=1
    EpisodesResponse? fastRes;
    try {
      fastRes = await repo.getEpisodes(
        _params.url,
        _params.source,
        category: _params.category,
        season: _params.season,
        fast: true,
      );
    } catch (e) {
      debugPrint('[ProgressiveContent] Fast load failed, retrying full: $e');
      try {
        fastRes = await repo.getEpisodes(
          _params.url,
          _params.source,
          category: _params.category,
          title: _params.title,
          fullTitle: _params.metadataTitle,
          season: _params.season,
          year: _params.year,
          tmdbId: _params.tmdbId,
          fast: false,
        );
      } catch (err, st) {
        if (!mounted) return;
        state = state.copyWith(
          episodes: AsyncValue.error(err, st),
          cast: const AsyncValue.data([]),
          relations: const AsyncValue.data({}),
        );
        return;
      }
    }

    if (!mounted) return;

    final initialEpisodes = fastRes.episodes.map((ep) {
      final displayTitle = (ep.title != null && ep.title!.isNotEmpty)
          ? ep.title
          : 'Episodio ${ep.number}';
      return EpisodeInfo(
        number: ep.number,
        id: ep.id,
        url: ep.url,
        title: displayTitle,
        thumbnail: ep.thumbnail,
        description: ep.description,
        airDate: ep.airDate,
        duration: ep.duration,
        runtime: ep.runtime,
        quality: ep.quality,
        episodeType: ep.episodeType,
        tmdbSpecialNumber: ep.tmdbSpecialNumber,
        needsTranslation: ep.needsTranslation,
      );
    }).toList();

    final selected = SearchResult(
      title: _params.title,
      url: _params.url,
      source: _params.source,
      quality: 'HD',
      thumbnail: '',
    );

    final initialResponse = EpisodesResponse(
      source: fastRes.source.isNotEmpty ? fastRes.source : _params.source,
      url: fastRes.url.isNotEmpty ? fastRes.url : _params.url,
      slug: fastRes.slug,
      total: fastRes.total > 0 ? fastRes.total : initialEpisodes.length,
      episodes: initialEpisodes,
      specials: fastRes.specials,
      tmdbId: fastRes.tmdbId ?? _params.tmdbId,
      season: fastRes.season ?? _params.season,
      seasonAirDate: fastRes.seasonAirDate,
    );

    final initialBundle = GroupedEpisodesResult(
      response: initialResponse,
      sources: List.filled(initialEpisodes.length, selected),
    );

    // EMITIR PASO 1 AL INSTANTE
    state = state.copyWith(
      episodes: AsyncValue.data(initialBundle),
    );

    Future.microtask(() {
      final ctManager = _ref.read(communityTranslationManagerProvider);
      for (final ep in initialEpisodes) {
        if (!ep.needsTranslation) continue;
        unawaited(ctManager.processEpisodeTranslation(
          tmdbId: initialResponse.tmdbId ?? _params.tmdbId,
          season: _params.season,
          episode: ep,
        ));
      }
    });

    // Paso 2 — Solo DESPUÉS de pintar el paso 1, dispara en background (paralelo entre sí)
    final effectiveTmdbId = fastRes.tmdbId ?? _params.tmdbId;
    final isAnimeCategory = _params.category.toLowerCase().contains('anime') || _params.category.toLowerCase().contains('movie_anime');

    // A) GET /api/episodes?url={U}&source={S}&title={T}&fullTitle={FT}&season={N}&year={Y}[&tmdbId={id}]
    final fullEpisodesTask = () async {
      try {
        final fullRes = await repo.getEpisodes(
          _params.url,
          _params.source,
          category: _params.category,
          title: _params.title,
          fullTitle: _params.metadataTitle,
          season: _params.season,
          year: _params.year,
          tmdbId: effectiveTmdbId,
          fast: false,
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;
        final currentBundle = state.episodes.valueOrNull;
        if (currentBundle != null && fullRes.episodes.isNotEmpty) {
          final Map<int, EpisodeInfo> fullMap = {
            for (final ep in fullRes.episodes) ep.number: ep
          };

          // Paso 3 — Merge (por episodes[].number, misma key, sin remontar)
          final mergedEpisodes = currentBundle.response.episodes.map((fastEp) {
            final fullEp = fullMap[fastEp.number];
            if (fullEp != null) {
              final mergedTitle = (fullEp.title != null && fullEp.title!.isNotEmpty)
                  ? fullEp.title
                  : fastEp.title;
              final mergedThumb = (fullEp.thumbnail != null && fullEp.thumbnail!.isNotEmpty)
                  ? fullEp.thumbnail
                  : fastEp.thumbnail;

              return EpisodeInfo(
                number: fastEp.number,
                id: fastEp.id != 0 ? fastEp.id : fullEp.id,
                url: fastEp.url.isNotEmpty ? fastEp.url : fullEp.url,
                title: mergedTitle,
                thumbnail: mergedThumb,
                description: fullEp.description ?? fastEp.description,
                airDate: fullEp.airDate ?? fastEp.airDate,
                duration: fullEp.duration ?? fastEp.duration,
                runtime: fullEp.runtime ?? fastEp.runtime,
                quality: fullEp.quality ?? fastEp.quality,
                episodeType: fullEp.episodeType ?? fastEp.episodeType,
                tmdbSpecialNumber: fullEp.tmdbSpecialNumber ?? fastEp.tmdbSpecialNumber,
                needsTranslation: fullEp.needsTranslation,
              );
            }
            return fastEp;
          }).toList();

          final mergedResponse = EpisodesResponse(
            source: currentBundle.response.source,
            url: currentBundle.response.url,
            slug: currentBundle.response.slug,
            total: currentBundle.response.total,
            episodes: mergedEpisodes,
            specials: fullRes.specials.isNotEmpty ? fullRes.specials : currentBundle.response.specials,
            relations: currentBundle.response.relations,
            cast: currentBundle.response.cast,
            tmdbId: fullRes.tmdbId ?? currentBundle.response.tmdbId,
            season: currentBundle.response.season,
            seasonAirDate: fullRes.seasonAirDate ?? currentBundle.response.seasonAirDate,
          );

          state = state.copyWith(
            episodes: AsyncValue.data(GroupedEpisodesResult(
              response: mergedResponse,
              sources: List.filled(mergedEpisodes.length, selected),
            )),
          );
        }
      } catch (e) {
        debugPrint('[ProgressiveContent] Task A (Full Episodes) failed or timed out: $e');
      }
    }();

    // B) Cast → movies: GET /api/cast?url={U} | anime: GET /api/cast?tmdbId={id}&mediaType={tv|movie}
    final castTask = () async {
      try {
        List<CastInfo> castList;
        if (isAnimeCategory && effectiveTmdbId != null) {
          final mediaType = _params.isMovieish ? 'movie' : 'tv';
          castList = await repo.getCast(
            _params.url,
            source: _params.source,
            category: _params.category,
            tmdbId: effectiveTmdbId,
            mediaType: mediaType,
          ).timeout(const Duration(seconds: 10));
        } else {
          castList = await repo.getCast(
            _params.url,
            source: _params.source,
            category: _params.category,
            title: _params.title,
            year: _params.year,
          ).timeout(const Duration(seconds: 10));
        }

        if (!mounted) return;
        state = state.copyWith(cast: AsyncValue.data(castList));
      } catch (e) {
        debugPrint('[ProgressiveContent] Task B (Cast) failed or timed out: $e');
        if (!mounted) return;
        state = state.copyWith(cast: const AsyncValue.data([]));
      }
    }();

    // C) Relations → movies: GET /api/relations?url={U} | anime: GET /api/relations?url={U}&source={S}
    final relationsTask = () async {
      try {
        final relList = await repo.getRelations(
          _params.url,
          source: isAnimeCategory ? _params.source : null,
          category: _params.category,
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (relList.isEmpty) {
          state = state.copyWith(relations: const AsyncValue.data({}));
          return;
        }

        final Map<String, RelatedInfo> franchiseMap = {};
        final Map<String, RelatedInfo> similarMap = {};
        final Map<String, RelatedInfo> recommendedMap = {};

        for (var rel in relList) {
          final key = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final type = rel.relation.toLowerCase();

          bool isStrictFranchise = rel.category == 'franquicia' ||
                                   type.contains('precuela') ||
                                   type.contains('secuela') ||
                                   type.contains('historia paralela') ||
                                   type.contains('ova') ||
                                   type.contains('ona') ||
                                   type.contains('spin-off');

          bool isSimilar = rel.category == 'relacionado' ||
                           type.contains('similar') ||
                           type.contains('género');

          if (isStrictFranchise) franchiseMap[key] = rel;
          else if (isSimilar) similarMap[key] = rel;
          else recommendedMap[key] = rel;
        }

        final relMap = {
          'franchise': franchiseMap.values.toList(),
          'similar': similarMap.values.toList(),
          'recommended': recommendedMap.values.toList(),
        };

        state = state.copyWith(relations: AsyncValue.data(relMap));
      } catch (e) {
        debugPrint('[ProgressiveContent] Task C (Relations) failed or timed out: $e');
        if (!mounted) return;
        state = state.copyWith(relations: const AsyncValue.data({}));
      }
    }();

    await Future.wait([fullEpisodesTask, castTask, relationsTask]);
  }
}

final progressiveContentProvider = StateNotifierProvider.autoDispose
    .family<ProgressiveContentNotifier, ProgressiveContentState, ProgressiveParams>((ref, params) {
  return ProgressiveContentNotifier(ref, params);
});
