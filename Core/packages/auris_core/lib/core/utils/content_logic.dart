import '../../data/models/media_item.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/image_policy.dart';
import '../../data/models/server/search_result.dart';
import 'source_utils.dart';

MediaItem mapSearchResultToMediaItem(SearchResult result, String category) {
  MediaType type = MediaType.series;
  final c = category.toLowerCase();
  
  if (c.contains('anime')) type = MediaType.anime;
  else if (c.contains('movie') || c.contains('pelicula')) type = MediaType.movie;
  else if (c.contains('drama')) type = MediaType.kdrama;
  else if (c.contains('series')) type = MediaType.series;

  // Inferencia por Kind si el category es genérico
  final k = result.kind?.toLowerCase() ?? '';
  if (k == 'movie') type = MediaType.movie;
  else if (k == 'series') type = MediaType.series;
  else if (k == 'anime') type = MediaType.anime;
  else if (k == 'kdrama') type = MediaType.kdrama;

  // Senior Fix: Asegurar que el source sea un nombre de servidor válido
  String effectiveSource = result.source;
  if (effectiveSource.isEmpty) {
    if (result.url.contains('jkanime.net')) effectiveSource = 'JKAnime';
    else if (result.url.contains('animejara.com')) effectiveSource = 'AnimeJara';
    else if (result.url.contains('tudorama.net')) effectiveSource = 'TuDorama';
    else if (result.url.contains('doramaslatinox')) effectiveSource = 'DoramasLatinox';
  }

  return MediaItem(
    id: result.url,
    title: result.title,
    romaji: result.romaji,
    english: result.english,
    posterUrl: ApiEndpoints.proxyImage(result.thumbnail, policy: ImageSize.poster, fallbackUrl: result.tmdbThumbnail),
    bannerUrl: ApiEndpoints.proxyImage(result.banner, policy: ImageSize.banner, fallbackUrl: result.tmdbBanner),
    logoUrl: ApiEndpoints.proxyImage(result.logo),
    type: type,
    synopsis: result.synopsis,
    rating: result.score,
    year: result.year,
    source: effectiveSource,
    available: true,
    detailUrl: result.url,
    trailerKey: result.trailerKey,
    genres: result.genres ?? const [],
    card: result,
  );
}

int? extractSeason(String? s) {
  if (s == null || s.isEmpty) return null;
  final t = s.toLowerCase();

  // 1. Detección por palabras clave (Muy alta certidumbre)
  final m = RegExp(r'(\d+)(?:st|nd|rd|th)?\s+(?:season|temporada|part|parte|cour)').firstMatch(t);
  if (m != null) return int.tryParse(m.group(1)!);
  final m2 = RegExp(r'(?:season|temporada|part|parte|cour)\s*(\d+)').firstMatch(t);
  if (m2 != null) return int.tryParse(m2.group(1)!);

  // 2. Detección por números romanos (Estándar en Anime)
  final romanMap = {'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10};
  for (final entry in romanMap.entries) {
    if (entry.key == 'x') {
      if (RegExp(r'[\s\-]X(?:$|[\s\-:,.)\]])').hasMatch(s)) return 10;
      continue;
    }
    if (RegExp(r'[\s\-]' + entry.key + r'(?:$|[\s\-:,.)\]])', caseSensitive: false).hasMatch(s)) return entry.value;
  }

  // Senior Identity Fix: Evitamos extraer números árabes solos al final (ej: "Thunder 3")
  // porque suelen ser parte del nombre oficial y no una temporada.
  // Solo los aceptamos si vienen con prefijos claros (punto 1).
  return null;
}

String stripSeasonSuffix(String title) {
  if (title.isEmpty) return title;
  final tLower = title.toLowerCase();

  // 1. Limpiar si contiene palabras clave explícitas (Seguro)
  final keywordPatterns = [
    RegExp(r'\s*\d+(?:st|nd|rd|th)?\s*(?:season|temporada|part|parte|cour).*', caseSensitive: false),
    RegExp(r'\s*(?:season|temporada|part|parte|cour)\s*\d+.*', caseSensitive: false),
    RegExp(r'\s+final\s*season.*', caseSensitive: false),
    RegExp(r'\s+s\d+\b', caseSensitive: false),
  ];

  for (var p in keywordPatterns) {
    if (p.hasMatch(tLower)) return title.replaceAll(p, '').trim();
  }

  // 2. Limpiar números romanos al final (Estándar en Anime)
  final romanPatterns = [
    RegExp(r'\s+ii\b', caseSensitive: false),
    RegExp(r'\s+iii\b', caseSensitive: false),
    RegExp(r'\s+iv\b', caseSensitive: false),
    RegExp(r'\s+v\b', caseSensitive: false),
  ];

  for (var p in romanPatterns) {
    if (p.hasMatch(tLower)) return title.replaceAll(p, '').trim();
  }

  // Senior Identity Fix: YA NO eliminamos números árabes sueltos (ej: " 3")
  // para evitar romper títulos como "Thunder 3".
  return title.trim();
}

String seasonTitleFor(String baseTitle, int season) {
  if (season <= 1) return baseTitle.trim();
  const ordinals = {2: '2nd', 3: '3rd', 4: '4th', 5: '5th', 6: '6th', 7: '7th', 8: '8th', 9: '9th', 10: '10th'};
  final suffix = ordinals[season] ?? '${season}th';
  return '${baseTitle.trim()} $suffix Season';
}

String seasonTitleRoman(String baseTitle, int season) {
  if (season <= 1) return baseTitle.trim();
  const romans = {2: 'ii', 3: 'iii', 4: 'iv', 5: 'v', 6: 'vi', 7: 'vii', 8: 'viii', 9: 'ix', 10: 'x'};
  final r = romans[season] ?? season.toString();
  return '${baseTitle.trim()} $r';
}

bool isSeasonUnified(String source) {
  final k = simplifySourceName(source);
  return k == 'AJR' || k == 'GNU' || k == 'VAN';
}

String sourceSignature(SearchResult source) {
  return '${source.source}|${source.quality}|${source.url}|${source.slug ?? ''}';
}

bool isMovieResult(SearchResult r) {
  final movieUrlRe = RegExp(r'\b(movie|pel[ií]cula|film)\b', caseSensitive: false);
  return r.kind?.toLowerCase() == 'movie' ||
      movieUrlRe.hasMatch(r.url) ||
      (r.slug != null && movieUrlRe.hasMatch(r.slug!));
}

bool isMovieLikeTitle(String title) {
  return RegExp(r'\b(movie|film)\b|pel[ií]culas?', caseSensitive: false).hasMatch(title);
}

SearchResult? withSeasonUnified(SearchResult? source, int? season) {
  if (source == null) return null;
  if (season == null) return source;
  if (!isSeasonUnified(source.source)) return source;
  final base = source.url.split('#')[0];
  return source.copyWith(url: '$base#season-$season');
}

List<SearchResult> familySourcesFor(SearchResult currentSource, List<SearchResult> sources) {
  final familyKey = simplifySourceName(currentSource.source);
  final grouped = sources.where((s) => simplifySourceName(s.source) == familyKey).toList();
  grouped.sort((a, b) {
    if (a.url == currentSource.url) return -1;
    if (b.url == currentSource.url) return 1;
    return sourceSignature(a).compareTo(sourceSignature(b));
  });
  return grouped;
}

bool isDubQuality(String q) {
  final ql = q.toLowerCase();
  return ql.contains('latino') ||
      ql.contains('dub') ||
      ql.contains('doblado') ||
      ql.contains('castellano') ||
      ql.contains('dubbed');
}

String getWarningText(String? certification) {
  if (certification == null || certification.isEmpty || certification == 'NR') return 'Contenido no calificado. Se recomienda discreción del espectador.';
  final cert = certification.toUpperCase();
  if (cert.contains('18') || cert == 'TV-MA' || cert == 'R' || cert.contains('NC-17')) return 'Violencia explícita, lenguaje fuerte, contenido sexual, consumo de sustancias.';
  if (cert.contains('16') || cert == 'TV-14') return 'Violencia moderada, lenguaje malsonante, temas sugerentes.';
  if (cert.contains('12') || cert == 'PG-13' || cert == 'TV-PG') return 'Acción intensa, lenguaje moderado, algunas escenas de riesgo.';
  if (cert.contains('7') || cert == 'PG') return 'Fantasía suave, algunas escenas de miedo o acción ligera.';
  if (cert == 'G' || cert == 'ALL' || cert.contains('U')) return 'Apto para todos los públicos. Sin advertencias específicas.';
  return 'Se recomienda discreción del espectador.';
}
