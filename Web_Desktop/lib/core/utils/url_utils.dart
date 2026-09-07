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
    'GnulaHD': 'gh|https://ww3.gnulahd.nu/',
    'TuDorama': 'td|https://tudorama.net/dorama/',
    'DoramasYT': 'dy|https://doramasyt.com/dorama/',
    'DoramasMP4': 'dm|https://doramasmp4.com/dorama/',
    'Pandrama': 'pd|https://pandrama.com/dorama/',
    'OnlyPelis': 'op|https://onlypelis.net/',
    'PelisPedia': 'pp|https://www.pelispedia.li/',
    'TMDB': 'tm|tmdb://',
    'AniList': 'ai|anilist://',
  };

  /// Slugify estándar mejorado para preservar caracteres unicode (acentos, etc)
  static String slugify(String text) {
    return text.toLowerCase().trim()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '') // Mantiene letras unicode, números y espacios
        .replaceAll(RegExp(r'\s+'), '-'); // Convierte espacios a guiones
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
    String? from,
  }) {
    final queryParams = {
      'title': title,
      'source': source,
      'url': url,
      if (category != null) 'category': category,
      if (year != null) 'year': year.toString(),
      if (quality != null) 'quality': quality,
      if (type != null) 'type': type,
      if (from != null) 'from': from,
    };

    return Uri(path: '/detalles', queryParameters: queryParams).toString();
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
