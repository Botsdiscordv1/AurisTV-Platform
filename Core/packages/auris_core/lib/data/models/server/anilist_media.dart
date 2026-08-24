class AnilistMedia {
  final int id;
  final String englishTitle;
  final String romajiTitle;
  final String? bannerImage;
  final String coverImage;
  final int? episodes;

  const AnilistMedia({
    required this.id,
    required this.englishTitle,
    required this.romajiTitle,
    this.bannerImage,
    required this.coverImage,
    this.episodes,
  });

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? {};
    final cover = json['coverImage'] as Map<String, dynamic>? ?? {};
    return AnilistMedia(
      id: json['id'] as int? ?? 0,
      englishTitle: title['english'] as String? ?? '',
      romajiTitle: title['romaji'] as String? ?? '',
      bannerImage: json['bannerImage'] as String?,
      coverImage: cover['extraLarge'] as String? ?? '',
      episodes: json['episodes'] as int?,
    );
  }
}
