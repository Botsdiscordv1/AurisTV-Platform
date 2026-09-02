enum RemoteDeviceType { web, android, windows, ios, other }

class RemoteDevice {
  final String id;
  final String userId;
  final String name;
  final RemoteDeviceType type;
  final bool isOnline;
  final DateTime lastSeen;

  // Estado de medios
  final String? mediaTitle;
  final String? mediaSource;
  final String? mediaUrl;
  final String? mediaEpisode;
  final String? metadataTitle;
  final String? posterUrl;
  final String? bannerUrl;
  final String? category;
  final String? year;

  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final double volume;
  
  /// Pistas de audio/idioma disponibles en el dispositivo remoto
  final List<Map<String, dynamic>> availableTracks;
  final int selectedTrackIndex;
  
  final Map<String, dynamic> lastCommand;

  RemoteDevice({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.isOnline = true,
    DateTime? lastSeen,
    this.mediaTitle,
    this.mediaSource,
    this.mediaUrl,
    this.mediaEpisode,
    this.metadataTitle,
    this.posterUrl,
    this.bannerUrl,
    this.category,
    this.year,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    this.volume = 1.0,
    this.availableTracks = const [],
    this.selectedTrackIndex = 0,
    this.lastCommand = const {},
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory RemoteDevice.fromJson(Map<String, dynamic> json) {
    return RemoteDevice(
      id: json['device_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['device_name'] ?? 'Dispositivo desconocido',
      type: _typeFromString(json['device_type']),
      isOnline: json['is_online'] ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      mediaTitle: json['media_title'],
      mediaSource: json['media_source'],
      mediaUrl: json['media_url'],
      mediaEpisode: json['media_episode'],
      metadataTitle: json['metadata_title'],
      posterUrl: json['poster_url'],
      bannerUrl: json['banner_url'],
      category: json['category'],
      year: json['year'],
      positionMs: json['position_ms'] ?? 0,
      durationMs: json['duration_ms'] ?? 0,
      isPlaying: json['is_playing'] ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      availableTracks: (json['available_tracks'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      selectedTrackIndex: json['selected_track_index'] ?? 0,
      lastCommand: json['last_command'] is Map ? Map<String, dynamic>.from(json['last_command']) : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': id,
      'user_id': userId,
      'device_name': name,
      'device_type': type.name,
      'is_online': isOnline,
      'last_seen': lastSeen.toIso8601String(),
      'media_title': mediaTitle,
      'media_source': mediaSource,
      'media_url': mediaUrl,
      'media_episode': mediaEpisode,
      'metadata_title': metadataTitle,
      'poster_url': posterUrl,
      'banner_url': bannerUrl,
      'category': category,
      'year': year,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'is_playing': isPlaying,
      'volume': volume,
      'available_tracks': availableTracks,
      'selected_track_index': selectedTrackIndex,
      'last_command': lastCommand,
    };
  }

  static RemoteDeviceType _typeFromString(String? type) {
    return RemoteDeviceType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => RemoteDeviceType.other,
    );
  }

  RemoteDevice copyWith({
    bool? isOnline,
    DateTime? lastSeen,
    String? mediaTitle,
    String? mediaSource,
    String? mediaUrl,
    String? mediaEpisode,
    String? metadataTitle,
    String? posterUrl,
    String? bannerUrl,
    String? category,
    String? year,
    int? positionMs,
    int? durationMs,
    bool? isPlaying,
    double? volume,
    List<Map<String, dynamic>>? availableTracks,
    int? selectedTrackIndex,
    Map<String, dynamic>? lastCommand,
  }) {
    return RemoteDevice(
      id: id,
      userId: userId,
      name: name,
      type: type,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      mediaSource: mediaSource ?? this.mediaSource,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaEpisode: mediaEpisode ?? this.mediaEpisode,
      metadataTitle: metadataTitle ?? this.metadataTitle,
      posterUrl: posterUrl ?? this.posterUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      category: category ?? this.category,
      year: year ?? this.year,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      availableTracks: availableTracks ?? this.availableTracks,
      selectedTrackIndex: selectedTrackIndex ?? this.selectedTrackIndex,
      lastCommand: lastCommand ?? this.lastCommand,
    );
  }
}

class RemoteAction {
  static const String play = 'play';
  static const String pause = 'pause';
  static const String seek = 'seek';
  static const String setVolume = 'set_volume';
  static const String openMedia = 'open_media';
  static const String stop = 'stop';
  static const String skipOpEd = 'skip_oped';
  static const String switchTrack = 'switch_track';
}
