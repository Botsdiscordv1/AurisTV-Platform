import 'media_item.dart';

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
