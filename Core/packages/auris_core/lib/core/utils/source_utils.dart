

String buildEpisodeUrl(String baseUrl, String source, int episode) {
  final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final qIndex = trimmed.indexOf('?');
  final path = qIndex >= 0 ? trimmed.substring(0, qIndex) : trimmed;
  final query = qIndex >= 0 ? trimmed.substring(qIndex) : '';

  String pathUrl;
  final s = source.toLowerCase();
  
  if (s.contains('animejara')) {
    final seasonMatch = RegExp(r'#season-(\d+)').firstMatch(baseUrl);
    final season = seasonMatch != null ? int.parse(seasonMatch.group(1)!) : 1;
    final cleanBase = baseUrl.split('#')[0].split('?')[0];
    final parts = cleanBase.replaceAll(RegExp(r'/+$'), '').split('/');
    final slug = parts.isNotEmpty ? parts.last : 'anime';
    return 'https://animejara.com/episode/$slug-${season}x$episode/';
  } else if (s.contains('jkanime')) {
    // Senior Fix: Si la URL ya termina en un número (es un episodio), reemplazamos el segmento
    final parts = trimmed.split('/');
    if (parts.isNotEmpty && int.tryParse(parts.last) != null) {
      parts.removeLast();
      pathUrl = '${parts.join('/')}/$episode/';
    } else {
      pathUrl = '$trimmed/$episode/';
    }
  } else if (s.contains('animed23')) {
    final parts = path.split('/');
    final slug = parts.last;
    final domain = parts.take(3).join('/');
    pathUrl = '$domain/capitulo/$slug-ep-$episode/';
  } else {
    pathUrl = '$path/$episode';
  }
  return '$pathUrl$query';
}

String simplifySourceName(String name) {
  final l = name.toLowerCase();
  if (l.contains('av1')) return 'AV1';
  if (l.contains('jkanime')) return 'JKA';
  if (l.contains('animed23')) return 'A23';
  if (l.contains('animejara')) return 'AJR';
  if (l.contains('onlypelis')) return 'OPS';
  if (l.contains('pelispedia')) return 'PPA';
  if (l.contains('gnulahd')) return 'GHD';
  if (l.contains('lamovie')) return 'LMV';
  if (l.contains('repelishd')) return 'RHD';
  if (l.contains('doramaslatinox')) return 'DLX';
  return name.toUpperCase();
}

const Map<String, int> _sourceDisplayOrder = {
  'AV1': 2,
  'AJR': 3,
  'A23': 4,
  'JKA': 5,
  'DLX': 6,
  'RHD': 7,
  'LMV': 8,
  'OPS': 9,
  'PPA': 10,
  'GHD': 12,
};

int sourceDisplayRank(String source) {
  final key = simplifySourceName(source);
  return _sourceDisplayOrder[key] ?? 99;
}

String cleanQuality(String quality) {
  final l = quality.toLowerCase();
  if (l.contains('cast')) {
    return 'CAST';
  }
  if (l.contains('latino') || l.contains('dub') || l.contains('doblado') || l.contains('lat')) {
    return 'LATINO';
  }
  if (l.contains('sub') || l.contains('vose') || l.contains('jap')) {
    return 'SUB';
  }
  return quality.toUpperCase()
      .replaceAll('FULLHD', '1080P')
      .replaceAll('HD', '720P')
      .trim();
}

/// Mapa de códigos de idioma → bandera (emoji). El servidor envía calidad en
/// formato `TIPO-IDIOMA` (p.ej. `SUB-EN`, `DUB-MX`, `CAST-ES`, `SUB-ES`).
const Map<String, String> _langFlags = {
  'MX': '🇲🇽', // Latino (español latinoamericano)
  'ES': '🇪🇸', // Castellano (español de España)
  'EN': '🇬🇧', // Inglés (audio original con subtítulos)
  'US': '🇺🇸',
  'JP': '🇯🇵',
  'KO': '🇰🇷',
  'PT': '🇵🇹',
  'BR': '🇧🇷',
  'FR': '🇫🇷',
  'IT': '🇮🇹',
  'DE': '🇩🇪',
  'CN': '🇨🇳',
  'RU': '🇷🇺',
};

/// Tipo de pista según la calidad: 'DUB' (doblaje), 'CAST' (castellano),
/// 'SUB' (subtitulado) o '' si es resolución/desconocido.
String trackQualityType(String quality) {
  final up = quality.toUpperCase();
  if (up.contains('CAST')) return 'CAST';
  if (up.contains('SUB')) return 'SUB';
  if (up.contains('DUB') || up.contains('LAT')) return 'DUB';
  return '';
}

/// Idioma (código ISO-ish) inferido de la calidad, p.ej. `SUB-EN` → 'EN'.
String trackQualityLang(String quality) {
  final up = quality.toUpperCase();
  final parts = up.split('-');
  if (parts.length == 2 && parts[1].length >= 2 && parts[1].length <= 3) {
    final candidate = parts[1];
    if (_langFlags.containsKey(candidate)) return candidate;
  }
  final type = trackQualityType(quality);
  if (type == 'DUB' || type == 'CAST') return 'ES';
  if (type == 'SUB') return 'EN';
  return '';
}

/// Etiqueta corta de tipo para UI: 'DUB', 'CAST' o 'SUB'.
String trackQualityShortLabel(String quality) {
  final type = trackQualityType(quality);
  return type.isNotEmpty ? type : cleanQuality(quality);
}

/// Código de idioma en TEXTO para la UI (estilo Netflix, sin banderas).
/// p.ej. `SUB-ES` -> 'ES', `DUB-MX` -> 'MX', `SUB-EN` -> 'EN', `SUB-JP` -> 'JP'.
/// Si no hay código de idioma, cae al tipo: 'SUB'/'CAST'/'LAT'.
String languageCodeText(String quality) {
  final lang = trackQualityLang(quality);
  if (lang.isNotEmpty) return lang;
  final type = trackQualityType(quality);
  if (type == 'SUB') return 'SUB';
  if (type == 'CAST') return 'CAST';
  if (type == 'DUB') return 'LAT';
  return '';
}

String cleanTitleForDisplay(String title) {
  if (title.isEmpty) return title;
  
  // 1. Limpieza de estados al final: (En emisión), (Finalizado), etc.
  final statusPattern = RegExp(r'\s*\((?:En emisi[oó]n|Finalizado|Finalizada)\)\s*$', caseSensitive: false);
  
  // 2. Limpieza de año al final: buscamos un año de 4 dígitos (19xx o 20xx)
  // precedido por espacio y opcionalmente entre paréntesis/corchetes.
  // Evitamos \b para prevenir problemas con caracteres unicode adyacentes.
  final yearPattern = RegExp(r'[\s\(\[]+(?:19|20)\d{2}[\)\]]?\s*$', caseSensitive: false);

  // 3. Limpieza de etiquetas de idioma/audio al final (ej. "Latino", "Castellano", "Sub Español", "Audio Latino", etc.)
  final languagePattern = RegExp(r'\s*[\-–—:\(\[]+\s*(?:audio\s+latino|latino|espa[nñ]ol|castellano|sub\s+espa[nñ]ol|subbed|vose|doblado)\s*[\)\]]?\s*$|\s+(?:audio\s+latino|latino|espa[nñ]ol|castellano|sub\s+espa[nñ]ol|subbed|vose|doblado)\s*$', caseSensitive: false);

  String cleaned = title.replaceAll(statusPattern, '');
  cleaned = cleaned.replaceAll(yearPattern, '');
  cleaned = cleaned.replaceAll(languagePattern, '');
  
  cleaned = cleaned.trim();

  // Si después de limpiar el año quedó vacío (era solo el año), devolvemos el original.
  return cleaned.isEmpty ? title : cleaned;
}

String cleanTitleForMatching(String title) {
  final base = title.toLowerCase()
      .replaceAll('×', 'x')
      .replaceAll('½', '1/2')
      .replaceAll(RegExp(r'\b1st season|first season|season 1\b', caseSensitive: false), '1')
      .replaceAll(RegExp(r'\b2nd season|second season|season 2\b', caseSensitive: false), '2')
      .replaceAll(RegExp(r'\b3rd season|third season|season 3\b', caseSensitive: false), '3')
      .replaceAll(RegExp(r'\b4th season|fourth season|season 4\b', caseSensitive: false), '4')
      .replaceAll(RegExp(r'\b5th season|fifth season|season 5\b', caseSensitive: false), '5')
      .replaceAll(RegExp(r'\bii\b', caseSensitive: false), '2')
      .replaceAll(RegExp(r'\biii\b', caseSensitive: false), '3')
      .replaceAll(RegExp(r'\biv\b', caseSensitive: false), '4')
      .replaceAll(RegExp(r'\bv\b', caseSensitive: false), '5')
      .replaceAll(RegExp(r'\bmovie|pelicula|film\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
      .replaceAll(RegExp(r'audio latino|latino|sub español|subbed|vose|doblado', caseSensitive: false), '')
      .replaceAll(RegExp(r'season \d+|temporada \d+|part \d+|parte \d+|cour \d+', caseSensitive: false), '');
  
  final buffer = StringBuffer();
  for (final r in base.runes) {
    // Permitir letras latinas (incluyendo bloques de acentos), números y CJK.
    final isAlphanumeric = (r >= 0x30 && r <= 0x39) || // 0-9
                           (r >= 0x61 && r <= 0x7A) || // a-z
                           (r >= 0xC0 && r <= 0x24F);  // Latin-1 Supp + Latin Extended A/B (áéíóúüñ...)
    
    final isCJK = (r >= 0x3040 && r <= 0x30FF) || // Kana
                  (r >= 0x3400 && r <= 0x9FFF);   // Kanji
                  
    // Para matching estricto removemos espacios, pero preservamos el carácter semántico.
    if (isAlphanumeric || isCJK) {
      buffer.writeCharCode(r);
    }
  }
  return buffer.toString();
}

String? formatRating(double? r) {
  if (r == null || r <= 0) return null;
  final double normalized = r > 10 ? r / 10.0 : r;
  return normalized.toStringAsFixed(1);
}

/// Builds language options from tracks only, without adding phantom/synthetic tracks.
/// Each entry represents a real available stream from the server.
typedef LanguageOption = ({String server, String url, String quality, bool isTrack, int trackIndex});

List<LanguageOption> buildLanguageOptions({
  required List<({String label, String quality, String url, bool isDownload})> tracks,
  required String currentServer,
}) {
  final sourceOptions = <LanguageOption>[];
  for (int i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    if (t.isDownload) continue;
    final quality = t.quality.isNotEmpty ? t.quality.toUpperCase() : 'SUB';
    sourceOptions.add((
      server: currentServer,
      url: t.url,
      quality: quality,
      isTrack: true,
      trackIndex: i,
    ));
  }
  return sourceOptions;
}
