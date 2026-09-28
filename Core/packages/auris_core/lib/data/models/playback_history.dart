import './server/search_result.dart';
import './server/detail_params.dart';

class PlaybackHistory {
  final String contentId;
  final int? season;
  final String? episode;
  final int positionInMilliseconds;
  final int durationInMilliseconds;
  final DateTime updatedAt;
  
  final String? title;
  final String? metadataTitle;
  final String? posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final String? category;
  final String? source;
  final String? url;
  final List<SearchResult>? alternativeSources;
  
  final String? kind;
  final String? type;
  final int? year;
  /// Título del episodio en curso (ej. "Es como un temblor de tierra").
  /// Se guarda al reproducir (con la lista de episodios) para mostrar
  /// "T1:E7 . Título" sin depender de red al pintar la tarjeta.
  final String? episodeTitle;

  final double progress;
  final bool isCompleted;
  final String? profileId;
  /// Oculto de Continuar Viendo (el usuario limpió la fila) pero CONSERVADO
  /// en el Historial. Solo un borrado explícito en Historial lo elimina.
  /// Ver de nuevo (updatePosition) lo revive (false).
  final bool dismissed;

  PlaybackHistory({
    required this.contentId,
    this.season,
    this.episode,
    required this.positionInMilliseconds,
    this.durationInMilliseconds = 0,
    required this.updatedAt,
    this.title,
    this.metadataTitle,
    this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
    this.category,
    this.source,
    this.url,
    this.alternativeSources,
    this.kind,
    this.type,
    this.year,
    this.episodeTitle,
    double? progress,
    bool? isCompleted,
    this.profileId,
    bool? dismissed,
  })  : progress = progress ?? (durationInMilliseconds > 0 
          ? (positionInMilliseconds / durationInMilliseconds).clamp(0.0, 1.0) 
          : 0.0),
        isCompleted = isCompleted ?? (durationInMilliseconds > 0 && (positionInMilliseconds / durationInMilliseconds) > 0.95),
        dismissed = dismissed ?? false;

  Map<String, dynamic> toJson() {
    return {
      'contentId': contentId,
      'season': season,
      'episode': episode,
      'positionInMilliseconds': positionInMilliseconds,
      'durationInMilliseconds': durationInMilliseconds,
      'updatedAt': updatedAt.toIso8601String(),
      'title': title,
      'metadataTitle': metadataTitle,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'logoUrl': logoUrl,
      'category': category,
      'source': source,
      'url': url,
      'alternativeSources': alternativeSources?.map((e) => e.toJson()).toList(),
      'kind': kind,
      'type': type,
      'year': year,
      'episodeTitle': episodeTitle,
      'progress': progress,
      'isCompleted': isCompleted,
      'profileId': profileId,
      'dismissed': dismissed,
    };
  }

  factory PlaybackHistory.fromJson(Map<dynamic, dynamic> json) {
    int pos = 0;
    if (json.containsKey('positionInMilliseconds')) {
      pos = int.tryParse(json['positionInMilliseconds'].toString()) ?? 0;
    } else if (json.containsKey('positionInSeconds')) {
      pos = (int.tryParse(json['positionInSeconds'].toString()) ?? 0) * 1000;
    }

    final int dur = int.tryParse(json['durationInMilliseconds']?.toString() ?? '0') ?? 0;
    final double calcProgress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    return PlaybackHistory(
      contentId: json['contentId'] as String? ?? 'unknown',
      season: json['season'] != null ? int.tryParse(json['season'].toString()) : null,
      episode: json['episode']?.toString(),
      positionInMilliseconds: pos,
      durationInMilliseconds: dur,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      title: json['title'] as String?,
      metadataTitle: json['metadataTitle'] as String?,
      posterUrl: json['posterUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
      category: json['category'] as String?,
      source: json['source'] as String?,
      url: json['url'] as String?,
      alternativeSources: json['alternativeSources'] != null 
          ? (json['alternativeSources'] as List<dynamic>)
              .map((e) => SearchResult.fromJson(e as Map))
              .toList() 
          : null,
      kind: json['kind'] as String?,
      type: json['type'] as String?,
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      episodeTitle: json['episodeTitle'] as String?,
      progress: json['progress'] != null ? double.tryParse(json['progress'].toString()) : calcProgress,
      isCompleted: json['isCompleted'] as bool? ?? (calcProgress > 0.95),
      dismissed: json['dismissed'] as bool? ?? false,
      profileId: json['profileId'] as String? ?? 'guest_profile',
    );
  }

  Duration get position => Duration(milliseconds: positionInMilliseconds);
  Duration get duration => Duration(milliseconds: durationInMilliseconds);

  int get positionInSeconds => (positionInMilliseconds / 1000).floor();
  int get durationInSeconds => (durationInMilliseconds / 1000).floor();
  
  double get progressPercentage => progress;
  bool get isFinished => isCompleted;
  
  String get key => generateKey(contentId, season, episode, profileId: profileId);

  static String generateKey(String contentId, int? season, String? episode, {String? profileId}) {
    final String base = episode == null ? contentId : '$contentId|S${season ?? 1}|E$episode';
    if (profileId == null) return base;
    return '$profileId|$base';
  }

  PlaybackHistory copyWith({
    int? positionInMilliseconds,
    int? durationInMilliseconds,
    DateTime? updatedAt,
    String? title,
    String? metadataTitle,
    String? posterUrl,
    String? bannerUrl,
    String? logoUrl,
    String? category,
    String? source,
    String? url,
    List<SearchResult>? alternativeSources,
    String? kind,
    String? type,
    int? year,
    String? episodeTitle,
    double? progress,
    bool? isCompleted,
    String? profileId,
    bool? dismissed,
  }) {
    return PlaybackHistory(
      contentId: contentId,
      season: season,
      episode: episode,
      positionInMilliseconds: positionInMilliseconds ?? this.positionInMilliseconds,
      durationInMilliseconds: durationInMilliseconds ?? this.durationInMilliseconds,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      metadataTitle: metadataTitle ?? this.metadataTitle,
      posterUrl: posterUrl ?? this.posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      category: category ?? this.category,
      source: source ?? this.source,
      url: url ?? this.url,
      alternativeSources: alternativeSources ?? this.alternativeSources,
      kind: kind ?? this.kind,
      type: type ?? this.type,
      year: year ?? this.year,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      profileId: profileId ?? this.profileId,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Extension para convertir fácilmente un elemento del historial de reproducción
/// en parámetros de navegación hacia la pantalla de detalles (UnifiedDetailParams).
extension PlaybackHistoryToDetailParams on PlaybackHistory {
  UnifiedDetailParams toUnifiedDetailParams({String? sectionId}) {
    String normalizedCategory = (category ?? 'anime').toLowerCase().trim();
    if (normalizedCategory.contains('pelic') || normalizedCategory == 'movie') {
      normalizedCategory = 'movie';
    } else if (normalizedCategory.contains('serie') || normalizedCategory == 'series') {
      normalizedCategory = 'series';
    } else if (normalizedCategory.contains('kdrama') || normalizedCategory == 'kdrama' || normalizedCategory.contains('dorama')) {
      normalizedCategory = 'kdrama';
    } else if (normalizedCategory.contains('anim') || normalizedCategory == 'anime' || normalizedCategory == 'movie_anime') {
      normalizedCategory = (kind?.toLowerCase() == 'movie' || type?.toLowerCase() == 'movie') ? 'movie' : 'anime';
    } else {
      normalizedCategory = 'anime';
    }

    // Título nunca vacío: sin él la ruta /content/:title no matchea
    // (Page Not Found). Fallback a metadataTitle y luego contentId.
    final resolvedTitle = (title != null && title!.isNotEmpty)
        ? title!
        : ((metadataTitle != null && metadataTitle!.isNotEmpty)
            ? metadataTitle!
            : contentId);

    return UnifiedDetailParams(
      title: resolvedTitle,
      metadataTitle: metadataTitle,
      category: normalizedCategory,
      kind: kind ?? (normalizedCategory == 'movie' ? 'movie' : 'anime'),
      type: type ?? normalizedCategory,
      year: year,
      url: url,
      source: source ?? '',
      season: season,
      initialSources: alternativeSources,
      sectionId: sectionId,
    );
  }
}
