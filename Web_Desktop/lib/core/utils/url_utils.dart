import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../features/player/presentation/player_screen.dart';

/// Utilidades senior para URLs ultra-limpias, encriptadas, comprimidas y estilo Crunchyroll.
class UrlUtils {
  /// Señal global: cada apertura del player la incrementa. Las pantallas con
  /// tráiler inline (content) la escuchan para pausar aunque el player no
  /// abra por su propio _openPlayer (mini, control remoto, notificaciones).
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

  /// Cache en memoria de acceso ultrarrápido (0 ms) para IDs cortos y slugs
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Guarda en memoria y en Hive ('media_slug_cache') para persistir tras F5
  static void _saveToCache(String shortId, String slug, Map<String, dynamic> data) {
    _memoryCache[shortId] = data;
    if (slug.isNotEmpty) _memoryCache[slug] = data;
    try {
      if (Hive.isBoxOpen('media_slug_cache')) {
        final box = Hive.box('media_slug_cache');
        box.put(shortId, data);
        if (slug.isNotEmpty) box.put(slug, data);
      }
    } catch (e) {
      debugPrint('[UrlUtils] Error guardando en media_slug_cache: $e');
    }
  }

  /// Recupera parámetros guardados por shortId o por slug
  static Map<String, dynamic>? _getFromCache(String key) {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      if (Hive.isBoxOpen('media_slug_cache')) {
        final box = Hive.box('media_slug_cache');
        final dynamic val = box.get(key);
        if (val is Map) {
          final mapped = Map<String, dynamic>.from(val);
          _memoryCache[key] = mapped;
          return mapped;
        }
      }
    } catch (e) {
      debugPrint('[UrlUtils] Error leyendo de media_slug_cache: $e');
    }
    return null;
  }

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

  /// Semilla de cifrado interna para generar tokens opacos seguros (estilo Crunchyroll)
  static const List<int> _cipherKey = [
    0x41, 0x75, 0x72, 0x69, 0x73, 0x54, 0x56, 0x5F,
    0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74, 0x65,
    0x64, 0x5F, 0x53, 0x6F, 0x75, 0x72, 0x63, 0x65,
    0x5F, 0x32, 0x30, 0x32, 0x36, 0x21, 0x24, 0x2A
  ];

  /// Genera un ID corto y elegante de 9 caracteres alfanuméricos (idéntico a Crunchyroll: G4PH0WXVJ)
  /// utilizando el charset Crockford Base32.
  static String generateShortId(String source, String url, String title) {
    final raw = '$source|$url|$title';
    var hash1 = 0x811c9dc5;
    for (var i = 0; i < raw.length; i++) {
      hash1 ^= raw.codeUnitAt(i);
      hash1 = (hash1 * 0x01000193) & 0xFFFFFFFF;
    }

    var hash2 = 0x27d4eb2f;
    for (var i = raw.length - 1; i >= 0; i--) {
      hash2 ^= raw.codeUnitAt(i);
      hash2 = (hash2 * 0x1000193) & 0xFFFFFFFF;
    }

    const chars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    var v1 = hash1;
    var v2 = hash2;
    final sb = StringBuffer();
    for (var i = 0; i < 5; i++) {
      sb.write(chars[v1 % chars.length]);
      v1 = v1 ~/ chars.length;
    }
    for (var i = 0; i < 4; i++) {
      sb.write(chars[v2 % chars.length]);
      v2 = v2 ~/ chars.length;
    }
    return sb.toString();
  }

  /// Slugify estándar mejorado para preservar caracteres unicode (acentos, etc)
  static String slugify(String text) {
    return text.toLowerCase().trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '') // Mantiene letras unicode, números y espacios
        .replaceAll(RegExp(r'\s+'), '-'); // Convierte espacios a guiones
  }

  /// Normaliza el prefijo de ruta según el [kind]:
  /// - 'movie', 'movie_anime', 'movie_kdrama' -> '/movie'
  /// - 'anime', 'kdrama', 'series' y demás -> '/series'
  static String determineRoutePrefix({String? kind, String? category, String? type}) {
    final k = (kind ?? category ?? type ?? '').toLowerCase().trim();
    if (k == 'movie' ||
        k == 'movie_anime' ||
        k == 'movie_kdrama' ||
        k.startsWith('movie')) {
      return 'movie';
    }
    return 'series';
  }

  /// Encripta y comprime los metadatos y la fuente en un token opaco y URL-safe (fallback auto-contenido).
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

    // 2. Construir mapa compacto
    final payload = <String, dynamic>{
      't': title,
      's': compressedSource,
      'u': compressedUrl,
      if (category != null && category.isNotEmpty) 'c': category,
      if (year != null && year > 0) 'y': year,
      if (quality != null && quality.isNotEmpty) 'q': quality,
      if (type != null && type.isNotEmpty) 'ty': type,
      if (kind != null && kind.isNotEmpty) 'k': kind,
      if (metadataTitle != null && metadataTitle.isNotEmpty) 'mt': metadataTitle,
      if (season != null && season > 0) 'se': season,
      if (sectionId != null && sectionId.isNotEmpty) 'sec': sectionId,
      if (from != null && from.isNotEmpty) 'f': from,
    };

    final jsonStr = jsonEncode(payload);
    final rawBytes = utf8.encode(jsonStr);

    final rand = Random();
    final salt0 = rand.nextInt(256);
    final salt1 = rand.nextInt(256);

    final encrypted = List<int>.filled(rawBytes.length + 2, 0);
    encrypted[0] = salt0;
    encrypted[1] = salt1;

    for (var i = 0; i < rawBytes.length; i++) {
      final keyByte = _cipherKey[(i + salt0) % _cipherKey.length];
      final shift = (salt1 * (i + 13)) & 0xFF;
      encrypted[i + 2] = rawBytes[i] ^ keyByte ^ shift;
    }

    return base64Url.encode(encrypted).replaceAll('=', '');
  }

  /// Desencripta un token de URL o lo recupera por su Short ID / Slug desde la caché.
  static Map<String, dynamic>? decodeShareableToken(String token, {String? slug}) {
    try {
      if (token.isEmpty) return null;

      // 1. Intento rápido: buscar en cache por Short ID (ej: G4PH0WXVJ)
      final cachedById = _getFromCache(token);
      if (cachedById != null) return cachedById;

      // 2. Intento por slug
      if (slug != null && slug.isNotEmpty) {
        final cachedBySlug = _getFromCache(slug);
        if (cachedBySlug != null) return cachedBySlug;
      }

      // 3. Fallback: Desencriptar token largo si vino cifrado completo
      if (token.length > 16) {
        var normalized = token;
        final pad = normalized.length % 4;
        if (pad == 2) {
          normalized += '==';
        } else if (pad == 3) {
          normalized += '=';
        } else if (pad == 1) {
          return null;
        }

        final bytes = base64Url.decode(normalized);
        if (bytes.length <= 2) return null;

        final salt0 = bytes[0];
        final salt1 = bytes[1];

        final decrypted = List<int>.filled(bytes.length - 2, 0);
        for (var i = 0; i < decrypted.length; i++) {
          final keyByte = _cipherKey[(i + salt0) % _cipherKey.length];
          final shift = (salt1 * (i + 13)) & 0xFF;
          decrypted[i] = bytes[i + 2] ^ keyByte ^ shift;
        }

        final jsonStr = utf8.decode(decrypted);
        final dynamic parsed = jsonDecode(jsonStr);
        if (parsed is! Map<String, dynamic>) return null;

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

        return {
          'title': (parsed['t'] as String?) ?? 'Contenido',
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
      }

      return null;
    } catch (e) {
      debugPrint('[UrlUtils] Error decodificando token shareable: $e');
      return null;
    }
  }

  /// Crea un link de detalles limpio, corto y con ID de 9 caracteres estilo Crunchyroll:
  /// Ej: /series/G4PH0WXVJ/la-chispa-del-amor
  /// Ej: /movie/M89AK109Z/spider-man-un-nuevo-dia
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
    final shortId = generateShortId(source, url, title);

    final payload = <String, dynamic>{
      'title': title,
      'source': source,
      'url': url,
      if (category != null && category.isNotEmpty) 'category': category,
      if (year != null && year > 0) 'year': year,
      if (quality != null && quality.isNotEmpty) 'quality': quality,
      if (type != null && type.isNotEmpty) 'type': type,
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (metadataTitle != null && metadataTitle.isNotEmpty) 'metadataTitle': metadataTitle,
      if (season != null && season > 0) 'season': season,
      if (sectionId != null && sectionId.isNotEmpty) 'sectionId': sectionId,
      if (from != null && from.isNotEmpty) 'from': from,
    };

    // Guardar en Hive y RAM para resolución instantánea (0 ms)
    _saveToCache(shortId, slug, payload);

    return '/$prefix/$shortId/$slug';
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
