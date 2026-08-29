import '../../../core/api/api_endpoints.dart';

class GalleryImage {
  final String url;
  final String type; // poster | backdrop | logo | banner
  final String source; // tmdb | fanart
  final String? lang;

  const GalleryImage({
    required this.url,
    required this.type,
    required this.source,
    this.lang,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> j) => GalleryImage(
        url: ApiEndpoints.proxyImage(j['url']?.toString()),
        type: j['type']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        lang: j['lang']?.toString(),
      );
}

class GalleryResponse {
  final int? tmdbId;
  final List<GalleryImage> gallery;

  const GalleryResponse({this.tmdbId, this.gallery = const []});

  factory GalleryResponse.fromJson(Map<String, dynamic> j) => GalleryResponse(
        tmdbId: (j['tmdbId'] as num?)?.toInt(),
        gallery: (j['gallery'] as List? ?? [])
            .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
