import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../models/server/anime_detail.dart';
import '../models/server/movie_detail.dart';
import '../models/server/search_result.dart';
import '../models/server/detail_params.dart';
import '../models/unified_content_state.dart';
import '../providers/content_providers.dart';
import '../providers/player_provider.dart';
import '../../core/utils/content_logic.dart';
import '../../core/utils/source_utils.dart';

/// Proveedor de estado unificado para la pantalla de detalle.
/// Centraliza la orquestación de datos entre plataformas.
final unifiedContentProvider = StateNotifierProvider.autoDispose
    .family<UnifiedContentNotifier, UnifiedContentState, UnifiedDetailParams>((ref, params) {
  return UnifiedContentNotifier(ref, params);
});

class UnifiedContentNotifier extends StateNotifier<UnifiedContentState> {
  final Ref ref;
  final UnifiedDetailParams params;

  UnifiedContentNotifier(this.ref, this.params)
      : super(const UnifiedContentState(detail: AsyncValue.loading())) {
    _init();
  }

  void _init() {
    // 1. Detectar si es Película pre-carga
    final isMovieish = (params.category == 'movie' ||
            params.category == 'movie_anime' ||
            isMovieLikeTitle(params.title) ||
            params.kind?.toLowerCase() == 'movie' ||
            params.kind?.toLowerCase() == 'series') &&
        params.kind?.toLowerCase() != 'anime';

    state = state.copyWith(isMovieish: isMovieish);

    // 2. Cargar Detalle Principal
    _loadDetail();

    // 3. Cargar Fuentes (Descubrimiento)
    _listenSources();
  }

  void _loadDetail() {
    ref.listen<AsyncValue<ContentDetailResponse?>>(
      unifiedContentDetailProvider(params),
      (prev, next) {
        if (!mounted) return;
        state = state.copyWith(detail: next);
        
        // Actualizar total de temporadas si el detalle las trae
        next.whenData((detail) {
          if (detail == null) return;
          int total = 1;
          if (detail.anime != null) total = detail.anime!.totalSeasons ?? 1;
          if (detail.movie != null) total = detail.movie!.totalSeasons ?? detail.movie!.seasons.length;
          if (total < 1) total = 1;
          
          state = state.copyWith(totalSeasons: total);
          _loadEpisodes();
        });
      },
      fireImmediately: true,
    );
  }

  void _listenSources() {
    final sourcesParams = DiscoveredSourcesParams(
      title: params.title,
      metadataTitle: params.metadataTitle,
      category: params.category,
      kind: params.kind,
      year: params.year,
      season: state.currentSeason,
      source: params.source,
      url: params.url ?? '',
      type: params.type,
      server: params.source == 'AniList' ? 'https://anime.auristv.dpdns.org' : null,
    );

    ref.listen<List<SearchResult>>(
      discoveredSourcesProvider(sourcesParams),
      (prev, next) {
        if (!mounted) return;
        state = state.copyWith(allSources: next);
        
        // Si no hay fuente seleccionada, elegimos la mejor disponible por rank
        if (state.selectedSource == null && next.isNotEmpty) {
          final ranked = [...next]..sort((a, b) => sourceDisplayRank(a.source).compareTo(sourceDisplayRank(b.source)));
          state = state.copyWith(selectedSource: ranked.first);
          _loadEpisodes();
          _loadRelations();
        }
      },
      fireImmediately: true,
    );
  }

  void _loadEpisodes() {
    final currentSource = state.selectedSource;
    if (currentSource == null) return;

    final epParams = GroupedEpisodesParams(
      title: params.title,
      metadataTitle: params.metadataTitle ?? params.title,
      category: params.category,
      year: params.year,
      season: state.currentSeason,
      currentSourceUrl: currentSource.url,
      sources: state.allSources,
    );

    // No podemos usar ref.listen aquí directamente de forma reactiva si queremos 
    // que el estado de episodes se actualice en nuestro state.
    // Usamos ref.watch en el build o escuchamos manualmente.
    
    // NOTA: Para simplificar la migración, los episodios pueden seguir siendo
    // un provider independiente que la UI observa, pero lo ideal es integrarlo.
    // Por ahora, solo guardaremos la referencia para que la UI sepa qué pedir.
  }

  void _loadRelations() {
    if (state.allSources.isEmpty) return;
    // ... lógica de relacionados
  }

  /// Cambia la temporada seleccionada.
  void setSeason(int season) {
    if (season == state.currentSeason) return;
    state = state.copyWith(currentSeason: season, episodes: const AsyncValue.loading());
    _listenSources(); // Re-descubrir fuentes para la nueva temporada
  }

  /// Cambia el servidor/fuente seleccionada.
  void setSource(SearchResult source) {
    state = state.copyWith(selectedSource: source);
    _loadEpisodes();
  }
}
