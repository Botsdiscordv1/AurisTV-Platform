import '../../data/models/server/search_result.dart';
import 'category_utils.dart';
import 'content_logic.dart';

/// Palabras de formato que los scrapers añaden a la MISMA obra
/// (`"Foo película"` == `"Foo"`) y que por tanto se ignoran al agrupar.
///
/// ⚠️ `ova|special|oav` NO se ignoran: son obras distintas dentro de una misma
/// franquicia. Agruparlas por "franchise" las fusionaba y se perdían resultados
/// (bug real: `"Ranma ½ OVA"` se comía a `"Ranma ½"` (1989) y la búsqueda de
/// "Ranma" devolvía 12 resultados en vez de 13).
final RegExp _formatWordsRe =
    RegExp(r'\b(movie|pel[íi]cula|film)\b', caseSensitive: false);

/// Etiquetas de formato que solo se usan para elegir la categoría de fallback
/// cuando el servidor no envía `kind`/`quality`/`type`. Se mantiene el
/// comportamiento histórico (`"Foo OVA"` sin metadatos seguía agrupándose como
/// película) pero ya no forman parte de la clave de fusión.
final RegExp _typeWordsRe = RegExp(
    r'\b(movie|pel[íi]cula|film|ova|special|oav)\b',
    caseSensitive: false);

/// Clave de identidad de un resultado de búsqueda.
///
/// Normaliza el título (minúsculas, sin acentos ni puntuación, sin palabras de
/// formato) y le añade la categoría en la que se abriría, para poder fusionar
/// la misma obra venga como la traiga cada fuente sin mezclar obras homónimas
/// de otro formato.
String searchFuseKey(SearchResult r) {
  final t = r.title.toLowerCase();
  final isMovieish = _typeWordsRe.hasMatch(t);
  final franchise = normalizeTitleForMatch(t)
      .replaceAll(_formatWordsRe, '')
      .replaceAll(RegExp(r'\s+'), '');
  final cat = inferOpenCategory(r, isMovieish ? 'movie' : 'tv');
  return '$franchise#$cat';
}

/// Dos resultados con la misma [searchFuseKey] solo son la misma obra si no se
/// contradicen: si ambas fuentes traen el año y difiere, son obras distintas
/// (p.ej. el remake de una serie clásica con título idéntico).
bool searchResultsCanBeFused(SearchResult a, SearchResult b) {
  final ya = a.year;
  final yb = b.year;
  return ya == null || yb == null || ya == yb;
}

/// Fusiona dos resultados que representan la misma obra: une sus fuentes y
/// conserva los metadatos del que aporte póster (y en su defecto banner),
/// rellenando sus huecos con los del otro.
SearchResult fuseSearchResults(SearchResult existing, SearchResult incoming) {
  final mergedSources = List<SourceItem>.from(existing.sources);
  for (final src in incoming.sources) {
    if (!mergedSources.any((s) => s.source == src.source && s.url == src.url)) {
      mergedSources.add(src);
    }
  }

  final bool incomingHasPoster =
      incoming.thumbnail.isNotEmpty && existing.thumbnail.isEmpty;
  final bool incomingHasBanner = !incomingHasPoster &&
      (incoming.banner ?? '').isNotEmpty &&
      (existing.banner ?? '').isEmpty;
  final bool takeIncoming = incomingHasPoster || incomingHasBanner;

  final SearchResult winner = takeIncoming ? incoming : existing;
  final SearchResult loser = takeIncoming ? existing : incoming;

  return winner.copyWith(
    sources: mergedSources,
    quality: winner.quality.isNotEmpty ? winner.quality : loser.quality,
    thumbnail: winner.thumbnail.isNotEmpty ? winner.thumbnail : loser.thumbnail,
    banner: (winner.banner ?? '').isNotEmpty ? winner.banner : loser.banner,
    year: winner.year ?? loser.year,
    slug: winner.slug ?? loser.slug,
    kind: winner.kind ?? loser.kind,
    type: winner.type ?? loser.type,
    season: winner.season ?? loser.season,
    totalSeasons: winner.totalSeasons ?? loser.totalSeasons,
    status: winner.status ?? loser.status,
    genres: winner.genres ?? loser.genres,
    synopsis: winner.synopsis ?? loser.synopsis,
    progress: winner.progress ?? loser.progress,
  );
}

/// Inserta `r` en `acc` fusionándolo con el resultado que ya ocupaba su clave.
/// Devuelve `true` si ha creado una fila nueva y `false` si se ha fusionado.
bool upsertSearchResult(Map<String, SearchResult> acc, SearchResult r) {
  final key = searchFuseKey(r);
  final existing = acc[key];

  if (existing == null) {
    acc[key] = r;
    return true;
  }

  if (!searchResultsCanBeFused(existing, r)) {
    // Mismo título pero año distinto: son obras distintas que conviven
    // (p.ej. "Ranma ½" 1989 y su remake). Cada una en su propio hueco.
    final altKey = r.url.isNotEmpty ? 'url:${r.url}' : '$key@${r.year ?? 0}';
    final altExisting = acc[altKey];
    acc[altKey] = altExisting == null ? r : fuseSearchResults(altExisting, r);
    return altExisting == null;
  }

  acc[key] = fuseSearchResults(existing, r);
  return false;
}

/// Deduplica una lista de resultados de búsqueda agrupando los que son la
/// misma obra (misma [searchFuseKey] y años compatibles).
List<SearchResult> deduplicateSearchResults(Iterable<SearchResult> results) {
  final acc = <String, SearchResult>{};
  for (final r in results) {
    upsertSearchResult(acc, r);
  }
  return acc.values.toList();
}
