import 'dart:convert';
import 'package:flutter/material.dart';
import '../../features/player/presentation/player_screen.dart';

/// Utilidades senior para URLs ultra-limpias, auto-contenidas y compatibles entre plataformas.
class UrlUtils {
  /// Señal global: cada apertura del player la incrementa.
  static final ValueNotifier<int> playerOpenedTick = ValueNotifier<int>(0);

  /// Abre el reproductor como un diálogo a pantalla completa
  static Future<T?> openPlayer<T>(BuildContext context, PlayerScreen player) {
    playerOpenedTick.value++;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => player,
    );
  }

  /// Cache en memoria de acceso ultrarrápido (0 ms)
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Mapeo de fuentes con sus dominios base para comprimir URLs originales
  static const Map<String, String> _sourceConfig = {
    'JKAnime': 'ja|https://jkanime.net/',
    'AnimeAV1': 'av|https://animeav1.com/media/',
    'AnimeJara': 'aj|https://animejara.com/anime/',
    'Aniyae': 'an|https://aniyae.com/anime/',
    'AnimeLatino': 'al|https://animelatinohd.com/anime/',
    'FiuziDragon': 'fd|https://fiuzidragon.com/anime/',
    'AnimeD23': 'ad|https://animed23.com/anime/',
    'KatAnime': 'ka|https://katanime.com/anime/',
    'AnimeGratis': 'ag|https://animegratis.net/anime/',
    'GnulaHD': 'gh|https://ww3.gnulahd.nu/',
    'TuDorama': 'td|https://tudorama.net/dorama/',
    'DoramasYT': 'dy|https://doramasyt.com/dorama/',
    'DoramasMP4': 'dm|https://doramasmp4.com/dorama/',
    'Pandrama': 'pd|https://pandrama.com/dorama/',
    'OnlyPelis': 'op|https://onlypelis.net/',
    'PelisPedia': 'pp|https://www.pelispedia.li/',
    'RePelisHD': 'rh|https://repelishd.pics/',
    'TMDB': 'tm|tmdb://',
    'AniList': 'ai|anilist://',
  };

  /// Mapeo inverso: código corto -> 'NombreFuente|BaseUrl'
  static final Map<String, ({String name, String base})> _codeToSource = () {
    final map = <String, ({String name, String base})>{};
    for (final entry in _sourceConfig.entries) {
      final parts = entry.value.split('|');
      if (parts.length >= 2) {
        map[parts[0]] = (name: entry.key, base: parts[1]);
      }
    }
    return map;
  }();

  /// Clave de cifrado compartida simétrica interna (32 bytes)
  static const List<int> _cipherKey = [
    0x41, 0x75, 0x72, 0x69, 0x73, 0x54, 0x56, 0x5F,
    0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74, 0x65,
    0x64, 0x5F, 0x53, 0x6F, 0x75, 0x72, 0x63, 0x65,
    0x5F, 0x32, 0x30, 0x32, 0x36, 0x21, 0x24, 0x2A
  ];

  /// Delimitador interno para empaquetado ultra-compacto (ASCII Unit Separator 0x1F)
  static const String _delimiter = '\x1F';

  /// Slugify estándar mejorado para preservar caracteres unicode (acentos, etc)
  static String slugify(String text) {
    return text.toLowerCase().trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Normaliza el prefijo de ruta según el [kind]:
  /// - 'anime' -> 'anime'
  /// - 'movie', 'movie_anime', 'movie_kdrama' -> 'movie'
  /// - 'kdrama', 'series' y demás -> 'serie'
  static String determineRoutePrefix({String? kind, String? category, String? type}) {
    final k = (kind ?? category ?? type ?? '').toLowerCase().trim();
    if (k == 'anime') {
      return 'anime';
    }
    if (k == 'movie' ||
        k == 'movie_anime' ||
        k == 'movie_kdrama' ||
        k.startsWith('movie')) {
      return 'movie';
    }
    return 'serie';
  }

  /// Encripta y comprime los metadatos y la fuente en un token opaco y URL-safe auto-contenido (estilo Prime Video).
  static String encodeShareableToken({
    required String title,
    required String source,
    required String url,
    String? category,
    int? year,
    String? quality,
    String? type,
    String? kind,
    String? metadataTitle,
    int? season,
    String? sectionId,
    String? from,
  }) {
    // 1. Comprimir fuente y URL usando el diccionario si existe
    String compressedSource = source;
    String compressedUrl = url;

    final config = _sourceConfig[source];
    if (config != null) {
      final parts = config.split('|');
      if (parts.length >= 2) {
        final code = parts[0];
        final base = parts[1];
        compressedSource = code;
        if (url.startsWith(base)) {
          compressedUrl = url.substring(base.length);
        }
      }
    }

    // 2. Empaquetar campos esenciales de forma ultra-compacta:
    // [source, url, kind, year, season, title, category]
    final effectiveKind = kind ?? category ?? type ?? '';
    final effectiveYear = (year != null && year > 0) ? year.toString() : '';
    final effectiveSeason = (season != null && season > 0) ? season.toString() : '';
    final effectiveCat = category ?? '';

    final packed = [
      compressedSource,
      compressedUrl,
      effectiveKind,
      effectiveYear,
      effectiveSeason,
      title,
      effectiveCat,
    ].join(_delimiter);

    final rawBytes = utf8.encode(packed);

    // 3. Encriptación XOR determinística contra la clave interna
    final encrypted = List<int>.filled(rawBytes.length, 0);
    for (var i = 0; i < rawBytes.length; i++) {
      final keyByte = _cipherKey[i % _cipherKey.length];
      encrypted[i] = rawBytes[i] ^ keyByte;
    }

    return base64Url.encode(encrypted).replaceAll('=', '');
  }

  /// Desencripta un token de URL auto-contenido o lo recupera por su Short ID / Slug desde la caché.
  static Map<String, dynamic>? decodeShareableToken(String token, {String? slug}) {
    try {
      if (token.isEmpty && (slug == null || slug.isEmpty)) return null;

      // 1. Intento rápido: buscar en cache por Token / ID
      if (token.isNotEmpty && _memoryCache.containsKey(token)) {
        return _memoryCache[token];
      }

      // 2. Intento rápido por slug
      if (slug != null && slug.isNotEmpty && _memoryCache.containsKey(slug)) {
        return _memoryCache[slug];
      }

      // 3. Desencriptar token auto-contenido si vino en la URL
      if (token.isNotEmpty) {
        try {
          var normalized = token;
          final pad = normalized.length % 4;
          if (pad == 2) {
            normalized += '==';
          } else if (pad == 3) {
            normalized += '=';
          }

          final bytes = base64Url.decode(normalized);
          if (bytes.isNotEmpty) {
            final decrypted = List<int>.filled(bytes.length, 0);
            for (var i = 0; i < decrypted.length; i++) {
              final keyByte = _cipherKey[i % _cipherKey.length];
              decrypted[i] = bytes[i] ^ keyByte;
            }

            final decodedStr = utf8.decode(decrypted, allowMalformed: true);

            // Caso A: Formato compacto delimitado por Unit Separator (\x1F)
            if (decodedStr.contains(_delimiter)) {
              final parts = decodedStr.split(_delimiter);
              if (parts.length >= 2) {
                var rawSource = parts[0];
                var rawUrl = parts[1];
                final kind = parts.length > 2 ? parts[2] : '';
                final year = parts.length > 3 ? int.tryParse(parts[3]) : null;
                final season = parts.length > 4 ? int.tryParse(parts[4]) : null;
                final title = parts.length > 5 && parts[5].isNotEmpty
                    ? parts[5]
                    : _titleFromSlug(slug);
                final category = parts.length > 6 && parts[6].isNotEmpty
                    ? parts[6]
                    : (kind.isNotEmpty ? kind : 'all');

                final mapped = _codeToSource[rawSource];
                if (mapped != null) {
                  rawSource = mapped.name;
                  if (!rawUrl.startsWith('http://') &&
                      !rawUrl.startsWith('https://') &&
                      !rawUrl.startsWith('tmdb://') &&
                      !rawUrl.startsWith('anilist://')) {
                    rawUrl = '${mapped.base}$rawUrl';
                  }
                }

                final result = <String, dynamic>{
                  'title': title,
                  'source': rawSource,
                  'url': rawUrl,
                  'category': category,
                  'year': year,
                  'season': season,
                  'kind': kind.isNotEmpty ? kind : null,
                  'type': kind.isNotEmpty ? kind : null,
                  'metadataTitle': title,
                };

                _memoryCache[token] = result;
                if (slug != null && slug.isNotEmpty) _memoryCache[slug] = result;
                return result;
              }
            }

            // Caso B: Formato JSON de retrocompatibilidad
            if (decodedStr.startsWith('{') && decodedStr.endsWith('}')) {
              final dynamic parsed = jsonDecode(decodedStr);
              if (parsed is Map<String, dynamic>) {
                var rawSource = (parsed['s'] as String?) ?? '';
                var rawUrl = (parsed['u'] as String?) ?? '';

                final mapped = _codeToSource[rawSource];
                if (mapped != null) {
                  rawSource = mapped.name;
                  if (!rawUrl.startsWith('http://') &&
                      !rawUrl.startsWith('https://') &&
                      !rawUrl.startsWith('tmdb://') &&
                      !rawUrl.startsWith('anilist://')) {
                    rawUrl = '${mapped.base}$rawUrl';
                  }
                }

                final result = <String, dynamic>{
                  'title': (parsed['t'] as String?) ?? _titleFromSlug(slug),
                  'source': rawSource,
                  'url': rawUrl,
                  'category': (parsed['c'] as String?) ?? 'all',
                  'year': parsed['y'] is int ? parsed['y'] as int : int.tryParse(parsed['y']?.toString() ?? ''),
                  'quality': parsed['q'] as String?,
                  'type': parsed['ty'] as String?,
                  'kind': parsed['k'] as String?,
                  'metadataTitle': parsed['mt'] as String?,
                  'season': parsed['se'] is int ? parsed['se'] as int : int.tryParse(parsed['se']?.toString() ?? ''),
                  'sectionId': parsed['sec'] as String?,
                  'from': parsed['f'] as String?,
                };

                _memoryCache[token] = result;
                if (slug != null && slug.isNotEmpty) _memoryCache[slug] = result;
                return result;
              }
            }
          }
        } catch (e) {
          debugPrint('[UrlUtils] Falló desencriptado directo en Movil: $e');
        }
      }

      // 4. Salvavidas final: Reconstruir a partir del slug para que la app no quede en blanco
      if (slug != null && slug.isNotEmpty) {
        final fallbackTitle = _titleFromSlug(slug);
        return {
          'title': fallbackTitle,
          'metadataTitle': fallbackTitle,
          'source': '',
          'url': '',
          'category': 'all',
        };
      }

      return null;
    } catch (e) {
      debugPrint('[UrlUtils] Error decodificando token shareable: $e');
      return null;
    }
  }

  /// Convierte un slug de URL a título capitalizado legible
  static String _titleFromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 'Contenido';
    final unencoded = Uri.decodeComponent(slug).replaceAll('-', ' ').trim();
    return unencoded.split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  /// Crea un link de detalles que contiene los parámetros necesarios
  static String buildShareableUri({
    required String title,
    required String source,
    required String url,
    String? category,
    int? year,
    String? quality,
    String? type,
    String? kind,
    String? metadataTitle,
    int? season,
    String? sectionId,
    String? from,
  }) {
    final prefix = determineRoutePrefix(kind: kind, category: category, type: type);
    final slug = slugify(title.isNotEmpty ? title : 'media');
    final token = encodeShareableToken(
      title: title,
      source: source,
      url: url,
      category: category,
      year: year,
      quality: quality,
      type: type,
      kind: kind,
      metadataTitle: metadataTitle,
      season: season,
      sectionId: sectionId,
      from: from,
    );

    return '/$prefix/$token/$slug';
  }

  /// Genera una URL de reproductor simple
  static String buildPlayerUri({
    required String title,
    required String contentId,
    required String episode,
    required String source,
    required String url,
    int? season,
    String? serverName,
    String? language,
    String? category,
    int? totalEpisodes,
    String? posterUrl,
    String? bannerUrl,
  }) {
    final queryParams = {
      'title': title,
      'contentId': contentId,
      'episode': episode,
      'source': source,
      'url': url,
      if (season != null) 'season': season.toString(),
      if (serverName != null) 'serverName': serverName,
      if (language != null) 'language': language,
      if (category != null) 'category': category,
      if (totalEpisodes != null) 'totalEpisodes': totalEpisodes.toString(),
      if (posterUrl != null) 'posterUrl': posterUrl,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
    };

    return Uri(path: '/reproductor', queryParameters: queryParams).toString();
  }
}
