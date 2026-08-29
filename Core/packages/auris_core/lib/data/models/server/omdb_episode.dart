import '../../../core/api/api_endpoints.dart';

class OmdbEpisode {
  final String title;
  final String description;
  final String thumbnail;
  final String? rating;
  final String? released;
  final String? duration;
  final int? runtime;
  final bool fromCache;

  const OmdbEpisode({
    required this.title,
    required this.description,
    required this.thumbnail,
    this.rating,
    this.released,
    this.duration,
    this.runtime,
    this.fromCache = false,
  });

  factory OmdbEpisode.fromJson(Map<String, dynamic> json) {
    return OmdbEpisode(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? 'Sin descripción disponible.',
      thumbnail: ApiEndpoints.proxyImage(json['thumbnail'] as String?),
      rating: json['rating']?.toString(),
      released: json['released'] as String?,
      duration: json['duration'] as String?,
      runtime: json['runtime'] as int?,
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }
}
