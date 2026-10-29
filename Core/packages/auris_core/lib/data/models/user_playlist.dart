/// Lista de reproducción M3U/M3U8.
///
/// Puede ser una lista **integrada** en la app ([isBuiltIn] = true, no se
/// puede eliminar) o una **añadida por el usuario** desde Ajustes.
class UserPlaylist {
  /// Identificador estable y URI-safe ('deportes', 'usr_ab12cd34ef', ...).
  final String id;

  /// Nombre visible ("Deportes", "Mi liga", ...).
  final String name;

  /// URL absoluta http(s) del archivo .m3u/.m3u8.
  final String url;

  /// true = precargada por la app; no se puede borrar.
  final bool isBuiltIn;

  /// Procedencia: 'iptv-org', 'Free-TV' o 'custom' (usuario).
  final String source;

  final DateTime addedAt;

  const UserPlaylist({
    required this.id,
    required this.name,
    required this.url,
    required this.isBuiltIn,
    required this.source,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'isBuiltIn': isBuiltIn,
      'source': source,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory UserPlaylist.fromJson(Map<dynamic, dynamic> json) {
    return UserPlaylist(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Lista',
      url: json['url'] as String? ?? '',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      source: json['source'] as String? ?? 'custom',
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
