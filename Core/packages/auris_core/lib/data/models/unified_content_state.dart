import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../models/server/anime_detail.dart';
import '../models/server/movie_detail.dart';
import '../models/server/search_result.dart';
import '../models/server/episodes_response.dart';
import '../models/server/shared_models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/player_provider.dart';

typedef UnifiedRelationsMap = Map<String, List<RelatedInfo>>;

/// Representa el estado completo de la pantalla de detalle.
class UnifiedContentState {
  /// El detalle principal del servidor (AniList/TMDB).
  final AsyncValue<ContentDetailResponse?> detail;
  
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
  final AsyncValue<UnifiedRelationsMap> relations;

  /// Indica si es una película o similar (sin capítulos reales).
  final bool isMovieish;
  
  /// Título limpio de la temporada actual (ej: "Youjo Senki II").
  final String? seasonTitle;

  const UnifiedContentState({
    required this.detail,
    this.allSources = const [],
    this.selectedSource,
    this.currentSeason = 1,
    this.totalSeasons = 1,
    this.episodes = const AsyncValue.loading(),
    this.relations = const AsyncValue.loading(),
    this.isMovieish = false,
    this.seasonTitle,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedContentState &&
          detail == other.detail &&
          const ListEquality().equals(allSources, other.allSources) &&
          selectedSource == other.selectedSource &&
          currentSeason == other.currentSeason &&
          totalSeasons == other.totalSeasons &&
          episodes == other.episodes &&
          relations == other.relations &&
          isMovieish == other.isMovieish &&
          seasonTitle == other.seasonTitle;

  @override
  int get hashCode => Object.hash(
        detail,
        const ListEquality().hash(allSources),
        selectedSource,
        currentSeason,
        totalSeasons,
        episodes,
        relations,
        isMovieish,
        seasonTitle,
      );

  UnifiedContentState copyWith({
    AsyncValue<ContentDetailResponse?>? detail,
    List<SearchResult>? allSources,
    SearchResult? selectedSource,
    int? currentSeason,
    int? totalSeasons,
    AsyncValue<GroupedEpisodesResult?>? episodes,
    AsyncValue<UnifiedRelationsMap>? relations,
    bool? isMovieish,
    String? seasonTitle,
  }) {
    return UnifiedContentState(
      detail: detail ?? this.detail,
      allSources: allSources ?? this.allSources,
      selectedSource: selectedSource ?? this.selectedSource,
      currentSeason: currentSeason ?? this.currentSeason,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      episodes: episodes ?? this.episodes,
      relations: relations ?? (this.relations as AsyncValue<UnifiedRelationsMap>),
      isMovieish: isMovieish ?? this.isMovieish,
      seasonTitle: seasonTitle ?? this.seasonTitle,
    );
  }
}
