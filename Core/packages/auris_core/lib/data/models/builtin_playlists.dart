import 'user_playlist.dart';

/// Listas integradas en AurisTV por defecto.
///
/// Reproducen el set preinstalado de la app de referencia (lacancha 1.0.2):
/// 16 listas de iptv-org (países, categorías e idioma) + Free-TV + el
/// agregado global "Todos los canales". Son de solo lectura: el usuario puede
/// abrirlas pero no eliminarlas.
class BuiltinPlaylists {
  BuiltinPlaylists._();

  /// Base de iptv-org verificada (responde 206 + `#EXTM3U`).
  static const String iptvOrgBase = 'https://iptv-org.github.io/iptv/';

  /// Fecha de referencia para el orden de las listas integradas.
  static final DateTime _addedAt = DateTime.utc(2026, 1, 1);

  /// (id, nombre, ruta relativa sin extensión dentro de iptv-org).
  static const List<(String, String, String)> _iptvOrgEntries = [
    ('deportes', 'Deportes', 'categories/sports'),
    ('espanol', 'En español', 'languages/spa'),
    ('mexico', 'México', 'countries/mx'),
    ('argentina', 'Argentina', 'countries/ar'),
    ('colombia', 'Colombia', 'countries/co'),
    ('peru', 'Perú', 'countries/pe'),
    ('chile', 'Chile', 'countries/cl'),
    ('venezuela', 'Venezuela', 'countries/ve'),
    ('ecuador', 'Ecuador', 'countries/ec'),
    ('guatemala', 'Guatemala', 'countries/gt'),
    ('espana', 'España', 'countries/es'),
    ('usa', 'Estados Unidos', 'countries/us'),
    ('noticias', 'Noticias', 'categories/news'),
    ('infantil', 'Infantil', 'categories/kids'),
    ('peliculas', 'Películas', 'categories/movies'),
    ('musica', 'Música', 'categories/music'),
  ];

  /// Las 18 listas integradas, en el mismo orden que la app de referencia.
  static final List<UserPlaylist> all = [
    for (final e in _iptvOrgEntries)
      UserPlaylist(
        id: e.$1,
        name: e.$2,
        url: '$iptvOrgBase${e.$3}.m3u',
        isBuiltIn: true,
        source: 'iptv-org',
        addedAt: _addedAt,
      ),
    UserPlaylist(
      id: 'freetv',
      name: 'Free-TV · Mundo',
      url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
      isBuiltIn: true,
      source: 'Free-TV',
      addedAt: _addedAt,
    ),
    UserPlaylist(
      id: 'todos',
      name: 'Todos los canales',
      url: '${iptvOrgBase}index.m3u',
      isBuiltIn: true,
      source: 'iptv-org',
      addedAt: _addedAt,
    ),
  ];
}
