import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

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
import '../providers/playback_history_provider.dart';
import '../../core/api/providers.dart';
import '../../core/api/api_endpoints.dart';
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
      title: input.season > 1 
          ? seasonTitleFor(stripSeasonSuffix(params.title), input.season) 
          : stripSeasonSuffix(params.title),
      metadataTitle: params.metadataTitle != null 
          ? (input.season > 1 ? seasonTitleFor(stripSeasonSuffix(params.metadataTitle!), input.season) : stripSeasonSuffix(params.metadataTitle!))
          : stripSeasonSuffix(params.title),
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

    // Sincronizar el póster vertical real del detalle con el historial local
    final detailData = next.detail.valueOrNull;
    if (detailData != null) {
      final poster = detailData.anime?.poster ?? detailData.movie?.poster;
      final banner = detailData.anime?.backdrop ?? detailData.movie?.backdrop;
      final logo = detailData.anime?.logo ?? detailData.movie?.logo;
      final title = detailData.anime?.title ?? detailData.movie?.title ?? params.title;
      if (poster != null && poster.isNotEmpty) {
        ref.read(playbackHistoryStateProvider.notifier).updatePosterForContent(
          contentId: params.url ?? params.title,
          title: title,
          posterUrl: poster,
          bannerUrl: banner,
          logoUrl: logo,
        );
      }
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
    // GET /api/episodes?url={fichaUrl}&source={S}&title={T}&fullTitle={FT}&season={N}&fast=1
    // title/fullTitle van también en el fast: sin ellos el server no puede
    // resolver la URL de la temporada pedida cuando la ficha quedó en otra
    // (p. ej. cambiar a S1 con la URL de S2 en el selector de temporadas).
    EpisodesResponse? fastRes;
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

    // EMITIR PASO 1 AL INSTANTE (overlay ES desde cache local si ya existe)
    final initialForEmit = await _overlayCachedEs(
      initialEpisodes,
      initialResponse.tmdbId ?? _params.tmdbId,
      _params.season,
    );
    final initialBundle = GroupedEpisodesResult(
      response: EpisodesResponse(
        source: initialResponse.source,
        url: initialResponse.url,
        slug: initialResponse.slug,
        total: initialResponse.total > 0 ? initialResponse.total : initialForEmit.length,
        episodes: initialForEmit,
        specials: initialResponse.specials,
        tmdbId: initialResponse.tmdbId,
        season: initialResponse.season,
        seasonAirDate: initialResponse.seasonAirDate,
      ),
      sources: List.filled(initialForEmit.length, selected),
    );

    if (!mounted) return;
    state = state.copyWith(
      episodes: AsyncValue.data(initialBundle),
    );

    Future.microtask(() => _queueCommunityTranslations(
      episodes: initialForEmit,
      tmdbId: initialResponse.tmdbId ?? _params.tmdbId,
      season: _params.season,
    ));

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

          // Paso 3 — Merge por número. Regla por campo:
          // - Si fast ya tiene ese campo en ES → no se pisa (evita parpadeo).
          // - Si fast no tiene título/sinopsis → tomar del full (gap-fill).
          // - Si fast aún needsTranslation → preferir full cuando traiga texto.
          // thumbnail/fechas: full manda si existe.
          final mergedEpisodes = currentBundle.response.episodes.map((fastEp) {
            final fullEp = fullMap[fastEp.number];
            if (fullEp == null) return fastEp;

            final fastTitle = fastEp.title;
            final fastDesc = fastEp.description;
            final fullTitle = fullEp.title;
            final fullDesc = fullEp.description;
            final fastHasTitle = fastTitle?.trim().isNotEmpty ?? false;
            final fastHasDesc = fastDesc?.trim().isNotEmpty ?? false;
            final fullHasTitle = fullTitle?.trim().isNotEmpty ?? false;
            final fullHasDesc = fullDesc?.trim().isNotEmpty ?? false;
            final fastHasText = fastHasTitle || fastHasDesc;
            // ES en fast solo cuenta si YA hay texto (no un campo vacío).
            final fastIsEs = !fastEp.needsTranslation && fastHasText;

            // Título / sinopsis (por campo):
            // - fast en ES y con texto → no pisar
            // - fast sin ese campo → gap-fill desde full
            // - fast needsTranslation → full manda si trae texto
            String? mergedTitle;
            if (fastHasTitle && fastIsEs) {
              mergedTitle = fastTitle;
            } else if (fullHasTitle) {
              mergedTitle = (!fastHasTitle || !fastIsEs) ? fullTitle : fastTitle;
            } else {
              mergedTitle = fastTitle;
            }

            String? mergedDesc;
            if (fastHasDesc && fastIsEs) {
              mergedDesc = fastDesc;
            } else if (fullHasDesc) {
              mergedDesc = (!fastHasDesc || !fastIsEs) ? fullDesc : fastDesc;
            } else {
              mergedDesc = fastDesc;
            }

            final mergedThumb = (fullEp.thumbnail != null && fullEp.thumbnail!.isNotEmpty)
                ? fullEp.thumbnail
                : fastEp.thumbnail;

            return EpisodeInfo(
              number: fastEp.number,
              id: fastEp.id != 0 ? fastEp.id : fullEp.id,
              url: fastEp.url.isNotEmpty ? fastEp.url : fullEp.url,
              title: mergedTitle,
              thumbnail: mergedThumb,
              description: mergedDesc,
              airDate: fullEp.airDate ?? fastEp.airDate,
              duration: fullEp.duration ?? fastEp.duration,
              runtime: fullEp.runtime ?? fastEp.runtime,
              quality: fullEp.quality ?? fastEp.quality,
              episodeType: fullEp.episodeType ?? fastEp.episodeType,
              tmdbSpecialNumber: fullEp.tmdbSpecialNumber ?? fastEp.tmdbSpecialNumber,
              needsTranslation: fastIsEs
                  ? false
                  : fullEp.needsTranslation,
            );
          }).toList();

          final mergeTmdbId = fullRes.tmdbId ?? currentBundle.response.tmdbId;
          final mergedForEmit = await _overlayCachedEs(
            mergedEpisodes,
            mergeTmdbId,
            _params.season,
          );

          final mergedResponse = EpisodesResponse(
            source: currentBundle.response.source,
            url: currentBundle.response.url,
            slug: currentBundle.response.slug,
            total: currentBundle.response.total,
            episodes: mergedForEmit,
            specials: fullRes.specials.isNotEmpty ? fullRes.specials : currentBundle.response.specials,
            relations: currentBundle.response.relations,
            cast: currentBundle.response.cast,
            tmdbId: mergeTmdbId,
            season: currentBundle.response.season,
            seasonAirDate: fullRes.seasonAirDate ?? currentBundle.response.seasonAirDate,
          );

          state = state.copyWith(
            episodes: AsyncValue.data(GroupedEpisodesResult(
              response: mergedResponse,
              sources: List.filled(mergedForEmit.length, selected),
            )),
          );

          // Crowdsource: traducir en vivo lo que siga en EN/JA y pintar solo
          // título/sinopsis en el estado local.
          Future.microtask(() => _queueCommunityTranslations(
            episodes: mergedForEmit,
            tmdbId: mergeTmdbId,
            season: _params.season,
          ));
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

  /// Overlay solo de título/sinopsis desde el cache Hive local.
  /// thumbnail, airDate, duration, quality, etc. no se tocan.
  Future<List<EpisodeInfo>> _overlayCachedEs(
    List<EpisodeInfo> episodes,
    int? tmdbId,
    int? season,
  ) async {
    if (tmdbId == null || season == null || episodes.isEmpty) return episodes;
    try {
      final box = await Hive.openBox('community_translations_cache');
      final out = <EpisodeInfo>[];
      var changed = false;
      for (final e in episodes) {
        // Solo rellenar lo que aún necesita ES. Si el episodio ya viene
        // traducido del server/full, no pisar con el cache local del cliente
        // (podría ser peor: "solá" vs "Solá").
        if (!e.needsTranslation) {
          out.add(e);
          continue;
        }
        final c = box.get('sent_${tmdbId}_${season}_${e.number}');
        if (c is! Map) {
          out.add(e);
          continue;
        }
        final t = c['title'] as String?;
        final o = c['overview'] as String?;
        if (t == null && o == null) {
          out.add(e);
          continue;
        }
        // Título siempre con mayúscula inicial (cache viejo puede traer "solá").
        final nt = (t != null && t.trim().isNotEmpty)
            ? CommunityTranslationManager.capitalizeTitle(t)
            : e.title;
        final no = (o != null && o.trim().isNotEmpty) ? o : e.description;
        if (nt == e.title && no == e.description) {
          out.add(e);
          continue;
        }
        changed = true;
        out.add(EpisodeInfo(
          number: e.number,
          id: e.id,
          url: e.url,
          title: nt,
          thumbnail: e.thumbnail,
          description: no,
          airDate: e.airDate,
          duration: e.duration,
          runtime: e.runtime,
          quality: e.quality,
          episodeType: e.episodeType,
          tmdbSpecialNumber: e.tmdbSpecialNumber,
          needsTranslation: false,
        ));
      }
      return changed ? out : episodes;
    } catch (_) {
      return episodes;
    }
  }

  /// Encola traducciones comunitarias en background y, si el server las guarda
  /// (o ya las tiene), pinta solo título/sinopsis en ES. El resto de campos de
  /// la tarjeta (thumbnail, fecha, duración, certificación…) quedan intactos:
  /// la certificación ni siquiera vive en EpisodeInfo (viene del detail).
  void _queueCommunityTranslations({
    required List<EpisodeInfo> episodes,
    required int? tmdbId,
    required int? season,
  }) {
    if (tmdbId == null || season == null) return;
    final targets = episodes.where((e) => e.needsTranslation).toList();
    if (targets.isEmpty) return;

    final ctManager = _ref.read(communityTranslationManagerProvider);
    final baseUrl = ApiEndpoints.baseUrlForSource(_params.source, _params.category);
    for (final ep in targets) {
      unawaited(() async {
        final result = await ctManager.processEpisodeTranslation(
          tmdbId: tmdbId,
          season: season,
          episode: ep,
          baseUrl: baseUrl,
        );
        if (result == null || !mounted) return;
        final rawTitle = (result.title != null && result.title!.trim().isNotEmpty)
            ? result.title!
            : ep.title;
        final newTitle = (rawTitle != null && rawTitle.trim().isNotEmpty)
            ? CommunityTranslationManager.capitalizeTitle(rawTitle)
            : ep.title;
        final newDesc = (result.overview != null && result.overview!.trim().isNotEmpty)
            ? result.overview
            : ep.description;
        if (newTitle == ep.title && newDesc == ep.description) return;

        final current = state.episodes.valueOrNull;
        if (current == null) return;
        final updated = current.response.episodes.map((e) {
          if (e.number != ep.number) return e;
          // Solo texto + flag. thumbnail/airDate/duration/quality se copian de e.
          return EpisodeInfo(
            number: e.number,
            id: e.id,
            url: e.url,
            title: newTitle ?? e.title,
            thumbnail: e.thumbnail,
            description: newDesc ?? e.description,
            airDate: e.airDate,
            duration: e.duration,
            runtime: e.runtime,
            quality: e.quality,
            episodeType: e.episodeType,
            tmdbSpecialNumber: e.tmdbSpecialNumber,
            needsTranslation: false,
          );
        }).toList();
        state = state.copyWith(
          episodes: AsyncValue.data(GroupedEpisodesResult(
            response: EpisodesResponse(
              source: current.response.source,
              url: current.response.url,
              slug: current.response.slug,
              total: current.response.total,
              episodes: updated,
              specials: current.response.specials,
              relations: current.response.relations,
              cast: current.response.cast,
              tmdbId: current.response.tmdbId,
              season: current.response.season,
              seasonAirDate: current.response.seasonAirDate,
            ),
            sources: current.sources,
          )),
        );
      }());
    }
  }
}

final progressiveContentProvider = StateNotifierProvider.autoDispose
    .family<ProgressiveContentNotifier, ProgressiveContentState, ProgressiveParams>((ref, params) {
  return ProgressiveContentNotifier(ref, params);
});
