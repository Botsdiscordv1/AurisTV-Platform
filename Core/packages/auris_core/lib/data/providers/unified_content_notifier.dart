import 'dart:async';
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

  // 6. Carga Atómica de Episodios
  AsyncValue<GroupedEpisodesResult?> episodesAsync = const AsyncValue.loading();
  if (selected != null) {
    // Firma estable: solo fuente seleccionada + temporada. La lista de
    // descubiertas crece por chunks y NO debe re-disparar la carga.
    final signature = episodesSignature(selected.url, input.season);

    final epParams = GroupedEpisodesParams(
      title: input.season > 1 ? seasonTitleFor(stripSeasonSuffix(params.title), input.season) : params.title,
      metadataTitle: params.metadataTitle ?? params.title,
      category: params.category,
      year: params.year,
      season: input.season,
      familyKey: simplifySourceName(selected.source),
      currentSourceUrl: selected.url,
      sourcesSignature: signature,
      source: selected.source,
    );
    
    final rawEpisodesAsync = ref.watch(groupedEpisodesProvider(epParams));

    episodesAsync = rawEpisodesAsync.whenData((bundle) {
      if (bundle == null) return null;
      return GroupedEpisodesResult(
        response: bundle.response,
        sources: List.filled(bundle.response.episodes.length, selected),
      );
    });
  }

  // 7. Relacionados
  final relSignature = allSources.map((s) => s.url).join(',');
  final relationsAsync = ref.watch(unifiedRelationsProvider(UnifiedRelationsParams(
    sources: allSources,
    signature: relSignature,
  )));

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
