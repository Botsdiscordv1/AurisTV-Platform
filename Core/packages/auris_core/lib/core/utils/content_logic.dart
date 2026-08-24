import 'package:collection/collection.dart';
import '../../data/models/server/search_result.dart';
import 'source_utils.dart';

int? extractSeason(String? s) {
  if (s == null) return null;
  final t = s.toLowerCase();
  final m = RegExp(r'(\d+)(?:st|nd|rd|th)?\s+(?:season|temporada|part|parte|cour)').firstMatch(t);
  if (m != null) return int.tryParse(m.group(1)!);
  final m2 = RegExp(r'(?:season|temporada|part|parte|cour)\s*(\d+)').firstMatch(t);
  if (m2 != null) return int.tryParse(m2.group(1)!);
  final romanMap = {'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10};
  for (final entry in romanMap.entries) {
    if (entry.key == 'x') {
      if (RegExp(r'[\s\-]X(?:$|[\s\-:,.)\]])').hasMatch(s)) return 10;
      continue;
    }
    if (RegExp(r'[\s\-]' + entry.key + r'(?:$|[\s\-:,.)\]])', caseSensitive: false).hasMatch(s)) return entry.value;
  }
  final hasNonLatin = RegExp(r'[^\x00-\x7F]').hasMatch(t);
  if (!hasNonLatin) {
    if (t.endsWith('1/2') || t.endsWith('1-2') || t.endsWith('\u00BD')) return null;
    final parts = t.split(RegExp(r'[\s\-/]')).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      final last = parts.last;
      if (RegExp(r'^\d+$').hasMatch(last)) {
        final n = int.tryParse(last);
        if (n != null && n >= 2 && n < 30) return n;
      }
      if (romanMap[last] != null) return romanMap[last];
    }
  }
  return null;
}

String stripSeasonSuffix(String title) {
  return title
      .replaceAll(
        RegExp(
          r'\s*(?:\d+(?:st|nd|rd|th)?\s*(?:season|temporada|part|parte|cour)|(?:season|temporada|part|parte|cour)\s*\d+|ii{1,3}|iv|v|vi{1,3}|final\s*season)\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
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
  final movieUrlRe = RegExp(r'\b(movie|película|film)\b', caseSensitive: false);
  return r.kind?.toLowerCase() == 'movie' ||
      movieUrlRe.hasMatch(r.url) ||
      (r.slug != null && movieUrlRe.hasMatch(r.slug!));
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
