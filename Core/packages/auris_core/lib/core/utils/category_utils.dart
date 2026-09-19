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
  final type = (result.type ?? '').toLowerCase().trim();
  final kind = (result.kind ?? '').toLowerCase().trim();
  final url = (result.url ?? '').toLowerCase();

  // 1. Prioridad: Metadatos explícitos del servidor (kind)
  if (kind == 'movie_anime' || kind == 'anime-movies' || kind == 'anime_movie') return 'movie_anime';
  if (kind == 'movie' || kind == 'pelicula') return 'movie';
  if (kind == 'series' || kind == 'serie' || kind == 'tv') return 'series';
  if (kind == 'anime') return 'anime';

  // 2. Prioridad: Calidad/Etiqueta visual (quality)
  if (q.contains('pelicula') || q.contains('película') || q.contains('movie')) return 'movie';
  if (q.contains('serie') || q.contains('series') || q.contains('tv') || q.contains('dorama') || q.contains('drama')) return 'series';
  if (q.contains('anime')) return 'anime';

  // 3. Prioridad: Estructura de la URL
  if (url.contains('/pelicula/') || url.contains('/movie/')) return 'movie';
  if (url.contains('/serie/') || url.contains('/series/') || url.contains('/dorama/') || url.contains('/tv/')) return 'series';
  if (url.contains('/anime/')) return 'anime';

  // 4. Prioridad: Metadato 'type'
  if (type.contains('movie')) return 'movie';
  if (type.contains('tv') || type.contains('series')) return 'series';
  if (type.contains('anime')) return 'anime';

  return fallback;
}

/// Determina de forma robusta si un contenido es una película o formato largo
/// para ajustar la UI (ocultar "Ep 1", formatear tiempo en horas, etc.)
bool isMovieLike(String? category, [String? title, int? durationMs]) {
  final String c = (category ?? '').toLowerCase();
  final String t = (title ?? '').toLowerCase();

  // 1. Check por categoría (Incluye variantes de servidores)
  if (c == 'movie' || c == 'movie_anime' || c == 'anime-movies' || 
      c == 'anime_movie' || c.contains('pelicula') || c.contains('película')) {
    return true;
  }
  
  // 2. Check por título (Palabras clave de largometraje)
  final bool hasMovieKeywords = t.contains('pelicula') || t.contains('película') || 
      t.contains('movie') || t.contains('especial') || t.contains('ova');
      
  if (hasMovieKeywords || t.contains('película:') || t.contains('pelicula:')) {
    return true;
  }

  // 3. Check por duración (Senior Logic: > 30 min = Película/Especial largo)
  if (durationMs != null && durationMs > 30 * 60 * 1000) {
    return true;
  }
  
  return false;
}

