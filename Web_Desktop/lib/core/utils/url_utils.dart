import 'dart:convert';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:flutter/material.dart';
import '../../features/player/presentation/player_screen.dart';

/// Utilidades senior para URLs ultra-limpias, comprimidas y compartibles.
class UrlUtils {
  /// Abre el reproductor como un diálogo a pantalla completa
  static void openPlayer(BuildContext context, PlayerScreen player) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => player,
    );
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
    'Gnula': 'gn|https://gnula.nu/',
    'GnulaHD': 'gh|https://gnulahd.com/',
    'TuDorama': 'td|https://tudorama.net/dorama/',
    'DoramasYT': 'dy|https://doramasyt.com/dorama/',
    'DoramasMP4': 'dm|https://doramasmp4.com/dorama/',
    'Pandrama': 'pd|https://pandrama.com/dorama/',
  };

  /// Slugify estándar
  static String slugify(String text) {
    return text.toLowerCase().trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Crea un link shareable que contiene la info mínima necesaria
  static String buildShareableUri({
    required String title,
    required String source,
    required String url,
    String? category,
    int? year,
  }) {
    // 1. Identificar fuente y comprimir URL
    String sourceCode = '??';
    String compressedUrl = url;
    
    for (var entry in _sourceConfig.entries) {
      final parts = entry.value.split('|');
      if (entry.key == source || url.startsWith(parts[1])) {
        sourceCode = parts[0];
        compressedUrl = url.replaceFirst(parts[1], ''); 
        if (compressedUrl.endsWith('/')) {
          compressedUrl = compressedUrl.substring(0, compressedUrl.length - 1);
        }
        break;
      }
    }

    // 2. Crear paquete ULTRA-compacto (Sin título, lo sacaremos del slug)
    // Formato: s|u|c|y (fuente|id_url|categoria|año)
    final catCode = category?.toLowerCase().startsWith('movie') == true ? 'm' : (category?.toLowerCase().startsWith('kdrama') == true ? 'k' : 'a');
    final rawData = '$sourceCode|$compressedUrl|$catCode|${year ?? ''}';
    
    // 3. Ofuscar a Base64 URL-Safe y QUITAR el padding '=='
    String token = base64Url.encode(utf8.encode(rawData));
    token = token.replaceAll('=', ''); 

    final slug = slugify(title);
    return '/media/$slug/$token';
  }

  /// Decodifica el token y usa el slug como fallback para el título
  static Map<String, dynamic>? decodeShareableToken(String token, String slug) {
    try {
      String normalizedToken = token;
      while (normalizedToken.length % 4 != 0) normalizedToken += '=';

      final decoded = utf8.decode(base64Url.decode(normalizedToken));
      final p = decoded.split('|');
      if (p.length < 3) return null;

      final sourceCode = p[0];
      final urlId = p[1];
      
      String sourceName = sourceCode;
      String fullUrl = urlId;
      for (var entry in _sourceConfig.entries) {
        if (entry.value.startsWith('$sourceCode|')) {
          sourceName = entry.key;
          fullUrl = entry.value.split('|')[1] + urlId;
          if (sourceName == 'JKAnime' && !fullUrl.endsWith('/')) fullUrl += '/';
          break;
        }
      }

      // Reconstruimos un título legible a partir del slug (ej: dandadan-2nd -> Dandadan 2nd)
      final prettyTitle = slug.split('-').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');

      return {
        'source': sourceName,
        'url': fullUrl,
        'category': p[2] == 'm' ? 'movie' : (p[2] == 'k' ? 'kdrama' : 'anime'),
        'year': p.length > 3 ? int.tryParse(p[3]) : null,
        'title': prettyTitle,
      };
    } catch (_) {
      return null;
    }
  }

  /// Genera una URL de reproductor ultra-comprimida y profesional
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
    // 1. Identificar fuente y comprimir URL
    String sourceCode = '??';
    String compressedUrl = url;
    for (var entry in _sourceConfig.entries) {
      final parts = entry.value.split('|');
      if (entry.key == source || url.startsWith(parts[1])) {
        sourceCode = parts[0];
        compressedUrl = url.replaceFirst(parts[1], '');
        if (compressedUrl.endsWith('/')) {
          compressedUrl = compressedUrl.substring(0, compressedUrl.length - 1);
        }
        break;
      }
    }

    // 2. Comprimir imágenes (Solo guardamos el ID de TMDB si es posible)
    String compressImg(String? u) {
      if (u == null || u.isEmpty) return '';
      final match = RegExp(r'/t/p/[^/]+/(.+\.jpg)').firstMatch(u);
      return match != null ? match.group(1)! : u;
    }

    // 3. Crear paquete ADN (Pipe separated para ahorrar espacio)
    // Formato: s|u|sn|sv|l|c|te|p|b
    final sn = season?.toString() ?? '';
    final sv = serverName ?? '';
    final l = (language?.toLowerCase().contains('latino') ?? false) ? 'L' : 'S';
    final c = category?.toLowerCase().startsWith('movie') == true ? 'm' : 'a';
    final te = totalEpisodes?.toString() ?? '';
    final p = compressImg(posterUrl);
    final b = compressImg(bannerUrl);

    final rawData = '$sourceCode|$compressedUrl|$sn|$sv|$l|$c|$te|$p|$b|$title';
    String token = base64Url.encode(utf8.encode(rawData)).replaceAll('=', '');

    final slug = slugify(contentId);
    return '/ver/$slug/$episode/$token';
  }

  /// Decodifica el ADN del reproductor
  static Map<String, dynamic>? decodePlayerToken(String token) {
    try {
      String normalizedToken = token;
      while (normalizedToken.length % 4 != 0) normalizedToken += '=';
      final decoded = utf8.decode(base64Url.decode(normalizedToken));
      final p = decoded.split('|');
      if (p.length < 9) return null;

      String expandImg(String path, String size) {
        if (path.isEmpty) return '';
        if (path.startsWith('http')) return path;
        return 'https://image.tmdb.org/t/p/$size/$path';
      }

      final sourceCode = p[0];
      final urlId = p[1];
      String sourceName = sourceCode;
      String fullUrl = urlId;
      for (var entry in _sourceConfig.entries) {
        if (entry.value.startsWith('$sourceCode|')) {
          sourceName = entry.key;
          fullUrl = entry.value.split('|')[1] + urlId;
          break;
        }
      }

      return {
        'source': sourceName,
        'url': fullUrl,
        'season': int.tryParse(p[2]),
        'serverName': p[3],
        'language': p[4] == 'L' ? 'LAT' : 'SUB',
        'category': p[5] == 'm' ? 'movie' : 'anime',
        'totalEpisodes': int.tryParse(p[6]),
        'posterUrl': expandImg(p[7], 'w500'),
        'bannerUrl': expandImg(p[8], 'original'),
        'title': p.length > 9 ? p[9] : '',
      };
    } catch (_) {
      return null;
    }
  }
}
