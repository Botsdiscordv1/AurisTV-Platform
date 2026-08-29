import 'package:auris_core/data/models/server/search_result.dart';

/// Infiere la categoría con la que se debe abrir un resultado de búsqueda
/// (`movie`, `series` o `anime`) a partir de los metadatos que envía el server
/// (`quality`, `type`, `kind`).
///
/// Regla de prioridad:
///   1. Película  — `quality`/`type` menciona película/movie/film, o `kind == 'movie'`.
///   2. Serie     — `quality`/`type` menciona serie/series/dorama/tv, o `kind == 'series'`.
///   3. Anime     — `quality`/`type`/`kind` menciona anime.
///   4. fallback  — la categoría seleccionada en la pestaña de búsqueda.
///
/// NOTA: No se usa `source` para forzar la categoría. El server ya envía
/// `kind` correcto (p.ej. GnulaHD marca sus animes con `kind: 'anime'`), así
/// que basar la decisión en el origen rompía el enrutamiento de animes que
/// vienen de fuentes de películas (GnulaHD) hacia el server de anime (3000).
String inferOpenCategory(SearchResult result, [String fallback = 'all']) {
  final q = result.quality.toLowerCase();
  final type = (result.type ?? '').toLowerCase();
  final kind = (result.kind ?? '').toLowerCase();

  if (q.contains('pelicula') ||
      q.contains('película') ||
      q.contains('movie') ||
      q.contains('film') ||
      type.contains('movie') ||
      kind == 'movie') {
    return 'movie';
  }
  if (q.contains('dorama') ||
      q.contains('drama') ||
      q.contains('serie') ||
      q.contains('series') ||
      q.contains('tv') ||
      type.contains('tv') ||
      kind == 'series') {
    return 'series';
  }
  if (q.contains('anime') || type.contains('anime') || kind == 'anime') {
    return 'anime';
  }
  // Algunos servidores (movies-series) no envían kind/type/category, pero la
  // URL revela la categoría (p.ej. onlypelis.com/serie/... vs /pelicula/...).
  final url = (result.url ?? '').toLowerCase();
  if (url.contains('serie') || url.contains('series') || url.contains('dorama')) {
    return 'series';
  }
  if (url.contains('pelicula') || url.contains('película') || url.contains('movie') || url.contains('film')) {
    return 'movie';
  }
  return fallback;
}
