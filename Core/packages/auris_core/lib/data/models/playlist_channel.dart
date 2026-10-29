/// Un canal dentro de una lista M3U (línea `#EXTINF` + URL de stream).
class PlaylistChannel {
  /// Nombre tras la coma del `#EXTINF` ("TV Azteca Deportes", ...).
  final String title;

  /// URL absoluta del stream (m3u8/mp4/...).
  final String url;

  /// `tvg-logo` si la lista lo incluye.
  final String? logo;

  /// `group-title` (o `#EXTGRP`) si la lista lo incluye.
  final String? group;

  /// `tvg-id` si la lista lo incluye.
  final String? tvgId;

  const PlaylistChannel({
    required this.title,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'logo': logo,
      'group': group,
      'tvgId': tvgId,
    };
  }

  factory PlaylistChannel.fromJson(Map<dynamic, dynamic> json) {
    final title = json['title'] as String? ?? '';
    return PlaylistChannel(
      title: title.isEmpty ? 'Canal' : title,
      url: json['url'] as String? ?? '',
      logo: json['logo'] as String?,
      group: json['group'] as String?,
      tvgId: json['tvgId'] as String?,
    );
  }
}
