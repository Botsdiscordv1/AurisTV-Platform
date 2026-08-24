class QualityOption {
  final String key;
  final String label;
  final String url;
  final Map<String, String> headers;
  final int? height;
  final int? bandwidth;

  const QualityOption({
    required this.key,
    required this.label,
    required this.url,
    this.headers = const {},
    this.height,
    this.bandwidth,
  });

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      height: json['height'] as int?,
      bandwidth: json['bandwidth'] as int?,
    );
  }
}

class VideoTrackOption {
  final String label;
  final String url;
  final bool isEmbed;
  final bool isDownload;
  final Map<String, String> headers;
  final List<QualityOption> qualities;
  final String quality;

  const VideoTrackOption({
    required this.label,
    required this.url,
    this.isEmbed = false,
    this.isDownload = false,
    this.headers = const {},
    this.qualities = const [],
    this.quality = '',
  });

  factory VideoTrackOption.fromJson(Map<String, dynamic> json) {
    return VideoTrackOption(
      label: json['label'] as String? ?? '',
      url: json['url'] as String? ?? '',
      isEmbed: json['isEmbed'] as bool? ?? false,
      isDownload: json['isDownload'] as bool? ?? false,
      headers: (json['headers'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      qualities: (json['qualities'] as List<dynamic>?)
              ?.map((q) => QualityOption.fromJson(q as Map<String, dynamic>))
              .toList() ??
          const [],
      quality: json['quality'] as String? ?? '',
    );
  }
}

class ExtractResult {
  final String url;
  final Map<String, String> headers;
  final List<VideoTrackOption> tracks;
  final List<QualityOption> qualities;

  const ExtractResult({
    required this.url,
    required this.headers,
    this.tracks = const [],
    this.qualities = const [],
  });

  factory ExtractResult.fromJson(Map<String, dynamic> json) {
    return ExtractResult(
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => VideoTrackOption.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      qualities: (json['qualities'] as List<dynamic>?)
              ?.map((q) => QualityOption.fromJson(q as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
