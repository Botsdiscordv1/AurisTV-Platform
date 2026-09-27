import 'media_item.dart';
import 'server/search_result.dart';

class FavoriteItem {
  final String id;
  final String title;
  final String posterUrl;
  final String bannerUrl;
  final String category;
  final String source;
  final String url;
  final DateTime addedAt;
  final String profileId;
  /// Extras para abrir el detalle con fuentes (si no, el discovery pierde
  /// kind/año y el detalle abre sin fuentes). Opcionales por legacy.
  final String? kind;
  final int? year;
  final String? type;
  final int? season;
  /// Todas las fuentes conocidas (para abrir con las mismas que search/home).
  /// Legacy/directas: vacío y el discovery las reconstruye.
  final List<SourceItem> sources;

  FavoriteItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.bannerUrl,
    required this.category,
    required this.source,
    required this.url,
    required this.addedAt,
    required this.profileId,
    this.kind,
    this.year,
    this.type,
    this.season,
    this.sources = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'bannerUrl': bannerUrl,
      'category': category,
      'source': source,
      'url': url,
      'addedAt': addedAt.toIso8601String(),
      'profileId': profileId,
      'kind': kind,
      'year': year,
      'type': type,
      'season': season,
      'sources': sources.map((e) => e.toJson()).toList(),
    };
  }

  factory FavoriteItem.fromJson(Map<dynamic, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      title: json['title'] as String,
      posterUrl: json['posterUrl'] as String,
      bannerUrl: json['bannerUrl'] as String,
      category: json['category'] as String,
      source: json['source'] as String,
      url: json['url'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      profileId: json['profileId'] as String,
      kind: json['kind'] as String?,
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      type: json['type'] as String?,
      season: json['season'] != null ? int.tryParse(json['season'].toString()) : null,
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceItem.fromJson(e as Map))
              .toList() ??
          const [],
    );
  }

  factory FavoriteItem.fromMediaItem(MediaItem item, String profileId, {required String source, required String category, required String url}) {
    return FavoriteItem(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      bannerUrl: item.bannerUrl ?? '',
      category: category,
      source: source,
      url: url,
      addedAt: DateTime.now(),
      profileId: profileId,
    );
  }
}
