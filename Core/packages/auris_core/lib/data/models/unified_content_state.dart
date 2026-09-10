import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server/anime_detail.dart';
import '../models/server/movie_detail.dart';
import '../models/server/search_result.dart';
import '../models/server/episodes_response.dart';
import '../models/server/shared_models.dart';
import '../../data/providers/content_providers.dart';

/// Representa el estado completo de la pantalla de detalle.
class UnifiedContentState {
  /// El detalle principal del servidor (AniList/TMDB).
  final AsyncValue<dynamic> detail;
  
  /// El detalle específico de la temporada seleccionada (si difiere del principal).
  final AsyncValue<AnimeDetail?> seasonDetail;

  /// Todas las fuentes/servidores encontrados para este contenido.
  final List<SearchResult> allSources;
  
  /// La fuente seleccionada actualmente.
  final SearchResult? selectedSource;
  
  /// El número de temporada seleccionado actualmente.
  final int currentSeason;
  
  /// El total de temporadas conocidas.
  final int totalSeasons;

  /// La lista de episodios para la temporada y fuente actual.
  final AsyncValue<GroupedEpisodesResult?> episodes;

  /// Relacionados y recomendaciones.
  final AsyncValue<Map<String, List<RelationInfo>>> relations;

  /// Indica si es una película o similar (sin capítulos reales).
  final bool isMovieish;

  const UnifiedContentState({
    required this.detail,
    this.seasonDetail = const AsyncValue.data(null),
    this.allSources = const [],
    this.selectedSource,
    this.currentSeason = 1,
    this.totalSeasons = 1,
    this.episodes = const AsyncValue.loading(),
    this.relations = const AsyncValue.loading(),
    this.isMovieish = false,
  });

  UnifiedContentState copyWith({
    AsyncValue<dynamic>? detail,
    AsyncValue<AnimeDetail?>? seasonDetail,
    List<SearchResult>? allSources,
    SearchResult? selectedSource,
    int? currentSeason,
    int? totalSeasons,
    AsyncValue<GroupedEpisodesResult?>? episodes,
    AsyncValue<Map<String, List<RelationInfo>>>? relations,
    bool? isMovieish,
  }) {
    return UnifiedContentState(
      detail: detail ?? this.detail,
      seasonDetail: seasonDetail ?? this.seasonDetail,
      allSources: allSources ?? this.allSources,
      selectedSource: selectedSource ?? this.selectedSource,
      currentSeason: currentSeason ?? this.currentSeason,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      episodes: episodes ?? this.episodes,
      relations: relations ?? this.relations,
      isMovieish: isMovieish ?? this.isMovieish,
    );
  }
}
