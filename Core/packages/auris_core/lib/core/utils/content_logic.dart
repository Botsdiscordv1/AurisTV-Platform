import '../../data/models/media_item.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/image_policy.dart';
import '../../data/models/server/search_result.dart';
import 'source_utils.dart';

/// Verifica si una URL corresponde a un episodio individual en lugar de la serie/ficha principal
bool isEpisodeUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final l = url.toLowerCase();
  return RegExp(r'/episodios?/|/ver/|-\d+x\d+|\b-s\d+e\d+\b|/capitulo/|/episode/').hasMatch(l);
}

/// Convierte una URL de episodio a la URL canónica de la serie principal si es posible
String cleanSeriesUrl(String url) {
  if (url.isEmpty) return url;

  // 1. OnlyPelis / GnulaHD / PelisPedia / RePelisHD:
  // /episodios/title-1x1/ o /episodio/title-1x1/ -> /serie/title/
  final movieSeriesEp = RegExp(r'/episodios?/([^/]+)-\d+x\d+/?', caseSensitive: false);
  if (movieSeriesEp.hasMatch(url)) {
    return url.replaceAllMapped(movieSeriesEp, (m) => '/serie/${m.group(1)}/');
  }

  // 2. JKAnime: /anime-name/1/ -> /anime-name/
  final jkEp = RegExp(r'(https?://jkanime\.net/([^/]+))/\d+/?', caseSensitive: false);
  if (jkEp.hasMatch(url)) {
    return url.replaceAllMapped(jkEp, (m) => '${m.group(1)}/');
  }

  return url;
}

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
    else if (result.url.contains('repelishd')) effectiveSource = 'RepelisHD';
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
  //    La "X" solo cuenta como temporada si viene marcada explícitamente
  //    ("Season X", "Temporada X"): hay títulos legítimos que terminan en X
  //    (Doctora X, Project X) y confundirlos con la temporada 10 rompía los
  //    episodios.
  final romanKeyword = RegExp(
    r'(?:season|temporada|part|parte|cour)\s*[xX]\b',
  ).firstMatch(s);
  if (romanKeyword != null) return 10;
  final romanMap = {'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9};
  for (final entry in romanMap.entries) {
    if (RegExp(r'[\s\-]' + entry.key + r'(?:$|[\s\-:,.)\]])', caseSensitive: false).hasMatch(s)) return entry.value;
  }

  // Senior Identity Fix: Evitamos extraer números árabes solos al final (ej: "Thunder 3")
  // porque suelen ser parte del nombre oficial y no una temporada.
  // Solo los aceptamos si vienen con prefijos claros (punto 1).
  return null;
}

/// true si la URL apunta a un cour/parcial ("-part-2", "-parte-1"): esa página
/// YA es específica, así que su slug no codifica una temporada completa.
bool urlIsCourPage(String? url) {
  final u = (url ?? '').split('?').first.split('#').first.trimRight();
  return u.isNotEmpty && RegExp(r'[-_](?:part|parte)[-_]?\d+/*$', caseSensitive: false).hasMatch(u);
}

/// Temporada que codifica la URL de la fuente (espejo de seasonFromUrl del
/// servidor: "-3rd-season" → 3, "-season-2" → 2, "-ii" → 2). Única diferencia
/// con el server: en un cour devuelve null, porque ahí la URL ya es la página
/// pedida y re-resolver la temporada sustituye el cour por la temporada entera.
int? seasonFromUrl(String? url) {
  final u = (url ?? '').split('?').first.split('#').first.trimRight();
  if (u.isEmpty || urlIsCourPage(u)) return null;
  final m = RegExp(r'[-/#](\d{1,2})(?:st|nd|rd|th)?-?(?:season|temporada)', caseSensitive: false).firstMatch(u) ??
      RegExp(r'[-/#](?:season|temporada)-(\d{1,2})', caseSensitive: false).firstMatch(u);
  if (m != null) return int.tryParse(m.group(1)!);
  // Romanos: solo si van marcados ("-season-ii") o son un segmento aislado
  // ("/ii/"). Antes se aceptaba cualquier sufijo ("-x"), y títulos como
  // "doctora-x" se interpretaban como temporada 10.
  final rm = RegExp(r'[-/_](?:season|temporada|part|parte|cour)[-_]([ivx]{1,4})(?=$|[/?#_-])', caseSensitive: false).firstMatch(u) ??
      RegExp(r'(?:^|/)([ivx]{1,4})(?=/|$)', caseSensitive: false).firstMatch(u);
  if (rm == null) return null;
  const roman = <String, int>{
    'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10,
  };
  return roman[rm.group(1)!.toLowerCase()];
}

/// Temporada que debe viajar en la query del servidor. La S1 solo se envía si
/// la URL codifica otra temporada (para que el server la resuelva a la base);
/// si la URL no declara ninguna, la página ya es la S1 y no se envía nada, así
/// el server sirve la URL tal cual en vez de re-resolverla.
int? seasonForRequest(int? season, String? url) {
  if (season == null) return null;
  if (season > 1) return season;
  return seasonFromUrl(url) == null ? null : season;
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

/// Igual que [stripSeasonSuffix] pero preserva el marcador de parte/cour
/// ("Part 2", "Parte 1", "Cour 2"). El detail del servidor de anime resuelve
/// el nodo de identidad correcto con ese marcador (ej. Diamond no Ace act II
/// Second Season Part 2 vs la S2 base); el strip aquí dejaba la petición sin
/// "Part 2" y el server devolvía la entrada del cour anterior. Los numerales
/// romanos solo se quitan si cierran el título ("Youjo Senki II") para no
/// romper títulos como "Act II".
String stripSeasonSuffixKeepPart(String title) {
  if (title.isEmpty) return title;
  final tLower = title.toLowerCase();

  final keywordPatterns = [
    RegExp(r'\s*\d+(?:st|nd|rd|th)?\s*(?:season|temporada).*', caseSensitive: false),
    RegExp(r'\s*(?:season|temporada)\s*\d+.*', caseSensitive: false),
    RegExp(r'\s+final\s*season.*', caseSensitive: false),
    RegExp(r'\s+s\d+\b', caseSensitive: false),
  ];

  for (var p in keywordPatterns) {
    if (p.hasMatch(tLower)) return title.replaceAll(p, '').trim();
  }

  final romanEnd = RegExp(r'\s+(?:ii|iii|iv|v)$', caseSensitive: false);
  if (romanEnd.hasMatch(title)) return title.replaceAll(romanEnd, '').trim();

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

/// Detecta URLs de catálogo, listado o filtros que no representan fichas individuales.
bool isListingUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return true;
  final u = Uri.tryParse(rawUrl.trim());
  if (u == null) return true;
  if (u.queryParameters.containsKey('orden') ||
      u.queryParameters.containsKey('genre') ||
      u.queryParameters.containsKey('genero') ||
      u.queryParameters.containsKey('page') ||
      u.queryParameters.containsKey('tipo') ||
      u.queryParameters.containsKey('categoria') ||
      u.queryParameters.containsKey('ano') ||
      u.queryParameters.containsKey('year')) {
    return true;
  }
  final path = u.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
  if (RegExp(r'^/(?:pelicula|serie|peliculas|series|genero|categoria)$', caseSensitive: false).hasMatch(path) ||
      RegExp(r'^/(?:genero|categoria|tag|animes|filter)/', caseSensitive: false).hasMatch(path) ||
      path.contains('/page/')) {
    return true;
  }
  return false;
}

const Set<String> _kNavTitles = {
  'mas vistas', 'más vistas', 'mas vistos', 'más vistos',
  'mas valoradas', 'más valoradas', 'lo mas visto', 'lo más visto',
  'peliculas', 'películas', 'series', 'estrenos', 'populares',
  'inicio', 'home', 'ver mas', 'ver más', 'tendencias',
  'nuevas peliculas', 'nuevas películas',
};

/// Detecta títulos que corresponden a enlaces de navegación o categorías web.
bool isNavTitle(String? title) {
  if (title == null) return true;
  final t = title.toLowerCase().trim();
  if (t.length < 3) return true;
  return _kNavTitles.contains(t);
}

/// Normaliza un título para comparaciones libres de acentos y caracteres especiales.
String normalizeTitleForMatch(String s) {
  return s
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
      .replaceAll('à', 'a').replaceAll('è', 'e').replaceAll('ì', 'i').replaceAll('ò', 'o').replaceAll('ù', 'u')
      .replaceAll('ä', 'a').replaceAll('ë', 'e').replaceAll('ï', 'i').replaceAll('ö', 'o').replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Determina si el título de un resultado descubierto es compatible con la obra consultada.
bool isTitleCompatible(String mainTitle, String candidateTitle, {String? metadataTitle}) {
  final cNorm = normalizeTitleForMatch(candidateTitle);
  if (cNorm.isEmpty || isNavTitle(candidateTitle)) return false;

  final targets = [
    mainTitle,
    if (metadataTitle != null && metadataTitle.isNotEmpty) metadataTitle,
  ];

  for (final target in targets) {
    final tNorm = normalizeTitleForMatch(stripSeasonSuffix(target));
    if (tNorm.isEmpty) continue;
    if (tNorm == cNorm || tNorm.contains(cNorm) || cNorm.contains(tNorm)) return true;

    const stopWords = {'the', 'and', 'los', 'las', 'del', 'con', 'para', 'por', 'una', 'uno', 'unos', 'unas', 'season', 'temporada'};
    final tWords = tNorm.split(' ').where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();
    final cWords = cNorm.split(' ').where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();
    if (tWords.isEmpty || cWords.isEmpty) continue;

    final intersection = tWords.intersection(cWords);
    if (intersection.length >= 2 || (intersection.length / tWords.length) >= 0.5) {
      return true;
    }
  }
  return false;
}
