import 'package:flutter/material.dart';

String buildEpisodeUrl(String baseUrl, String source, int episode) {
  final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final qIndex = trimmed.indexOf('?');
  final path = qIndex >= 0 ? trimmed.substring(0, qIndex) : trimmed;
  final query = qIndex >= 0 ? trimmed.substring(qIndex) : '';

  String pathUrl;
  if (source.toLowerCase().contains('animejara')) {
    final seasonMatch = RegExp(r'#season-(\d+)').firstMatch(baseUrl);
    final season = seasonMatch != null ? int.parse(seasonMatch.group(1)!) : 1;
    final cleanBase = baseUrl.split('#')[0].split('?')[0];
    final parts = cleanBase.replaceAll(RegExp(r'/+$'), '').split('/');
    final slug = parts.isNotEmpty ? parts.last : 'anime';
    return 'https://animejara.com/episode/' + slug + '-' + season.toString() + 'x' + episode.toString() + '/';
  } else if (source.toLowerCase().contains('katanime')) {
    final parts = path.split('/');
    final slug = parts.last;
    final domain = parts.take(3).join('/');
    pathUrl = '$domain/capitulo/$slug-$episode/';
  } else if (source.toLowerCase().contains('animegratis')) {
    final parts = path.split('/');
    var slug = parts.last;
    if (slug.endsWith('-anime')) {
      slug = slug.substring(0, slug.length - 6);
    }
    final domain = parts.take(3).join('/');
    pathUrl = '$domain/anime/$slug/episodio-$episode';
  } else if (source.toLowerCase().contains('jkanime')) {
    pathUrl = '$path/$episode/';
  } else if (source.toLowerCase().contains('animeflv') || source.toLowerCase().contains('tioanime')) {
    final parts = path.split('/');
    final slug = parts.last;
    final domain = parts.take(3).join('/');
    pathUrl = '$domain/ver/$slug-$episode';
  } else if (source.toLowerCase().contains('animed23')) {
    final parts = path.split('/');
    final slug = parts.last;
    final domain = parts.take(3).join('/');
    pathUrl = '$domain/capitulo/$slug-ep-$episode/';
  } else if (source.toLowerCase().contains('aniyae')) {
    return baseUrl;
  } else {
    pathUrl = '$path/$episode';
  }
  return '$pathUrl$query';
}

String simplifySourceName(String name) {
  final l = name.toLowerCase();
  if (l.contains('latinoyt')) return 'LYT';
  if (l.contains('av1')) return 'AV1';
  if (l.contains('jkanime')) return 'JKA';
  if (l.contains('flv')) return 'FLV';
  if (l.contains('aniyae')) return 'ANY';
  if (l.contains('animed23')) return 'A23';
  if (l.contains('tioanime')) return 'TIO';
  if (l.contains('animejara')) return 'AJR';
  if (l.contains('gnula')) return 'GNU';
  if (l.contains('katanime')) return 'KAT';
  if (l.contains('onlypelis')) return 'OPS';
  if (l.contains('pelispedia')) return 'PPA';
  if (l.contains('cuevana3')) return 'CV3';
  if (l.contains('gnulahd')) return 'GHD';
  if (l.contains('lamovie')) return 'LMV';
  if (l.contains('pelis24blog')) return 'P24';
  return name.toUpperCase();
}

const Map<String, int> _sourceDisplayOrder = {
  'AV1': 2,
  'AJR': 3,
  'A23': 4,
  'JKA': 5,
  'KAT': 6,
  'GNU': 7,
  'TIO': 8,
  'FLV': 9,
  'ANY': 10,
  'OPS': 11,
  'PPA': 12,
  'CV3': 13,
  'GHD': 14,
  'LMV': 15,
  'P24': 16,
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
  return title
      .replaceAll(
        RegExp(
          r'\s*\((En emisión|En emision|Finalizado|Finalizada)\)\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
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
    final isLatin = (r >= 0x61 && r <= 0x7A) || (r >= 0x30 && r <= 0x39);
    final isKana = (r >= 0x3040 && r <= 0x30FF);
    final isKanji = (r >= 0x3400 && r <= 0x9FFF);
    if (isLatin || isKana || isKanji) buffer.writeCharCode(r);
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
