
import './server/search_result.dart';

class PlaybackHistory {
  final String contentId;
  final int? season;
  final String? episode;
  final int positionInMilliseconds;
  final int durationInMilliseconds;
  final DateTime updatedAt;
  
  final String? title;
  final String? posterUrl;
  final String? bannerUrl;
  final String? category;
  final String? source;
  final String? url;
  final String? language;
  final List<SearchResult>? alternativeSources;
  
  final double progress;
  final bool isCompleted;
  final String? profileId;

  PlaybackHistory({
    required this.contentId,
    this.season,
    this.episode,
    required this.positionInMilliseconds,
    this.durationInMilliseconds = 0,
    required this.updatedAt,
    this.title,
    this.posterUrl,
    this.bannerUrl,
    this.category,
    this.source,
    this.url,
    this.language,
    this.alternativeSources,
    double? progress,
    bool? isCompleted,
    this.profileId,
  })  : progress = progress ?? (durationInMilliseconds > 0 
          ? (positionInMilliseconds / durationInMilliseconds).clamp(0.0, 1.0) 
          : 0.0),
        isCompleted = isCompleted ?? (durationInMilliseconds > 0 && (positionInMilliseconds / durationInMilliseconds) > 0.95);

  Map<String, dynamic> toJson() {
    return {
      'contentId': contentId,
      'season': season,
      'episode': episode,
      'positionInMilliseconds': positionInMilliseconds,
      'durationInMilliseconds': durationInMilliseconds,
      'updatedAt': updatedAt.toIso8601String(),
      'title': title,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'category': category,
      'source': source,
      'url': url,
      'language': language,
      'alternativeSources': alternativeSources?.map((e) => e.toJson()).toList(),
      'progress': progress,
      'isCompleted': isCompleted,
      'profileId': profileId,
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
      posterUrl: json['posterUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      category: json['category'] as String?,
      source: json['source'] as String?,
      url: json['url'] as String?,
      language: json['language'] as String?,
      alternativeSources: json['alternativeSources'] != null 
          ? (json['alternativeSources'] as List<dynamic>)
              .map((e) => SearchResult.fromJson(e as Map))
              .toList() 
          : null,
      progress: json['progress'] != null ? double.tryParse(json['progress'].toString()) : calcProgress,
      isCompleted: json['isCompleted'] as bool? ?? (calcProgress > 0.95),
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
    String? posterUrl,
    String? bannerUrl,
    String? category,
    String? source,
    String? url,
    String? language,
    List<SearchResult>? alternativeSources,
    double? progress,
    bool? isCompleted,
    String? profileId,
  }) {
    return PlaybackHistory(
      contentId: contentId,
      season: season,
      episode: episode,
      positionInMilliseconds: positionInMilliseconds ?? this.positionInMilliseconds,
      durationInMilliseconds: durationInMilliseconds ?? this.durationInMilliseconds,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      category: category ?? this.category,
      source: source ?? this.source,
      url: url ?? this.url,
      language: language ?? this.language,
      alternativeSources: alternativeSources ?? this.alternativeSources,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      profileId: profileId ?? this.profileId,
    );
  }
}
