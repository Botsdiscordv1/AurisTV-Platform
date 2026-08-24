import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiEndpoints {
  // --- CONFIGURACIÓN DE SERVIDORES ---
  // Usamos el DNS de DuckDNS con HTTPS automático vía Caddy.
  static String _serverIp = 'auristvanime.duckdns.org';

  /// Senior: Permite cambiar la dirección del servidor en tiempo de ejecución para pruebas.
  static void setServerAddress(String address) {
    _serverIp = address;
  }

  static String get serverAddress => _serverIp;

  // Puerto por servidor de backend:
  //   3000 → Anime
  //   3001 → Películas y Series
  //   3002 → Kdramas
  static const String _animePort = '3000';
  static const String _moviesPort = '3001';
  static const String _kdramasPort = '3002';

  // --- CONFIGURACIÓN SUPABASE ---
  static const String supabaseUrl = 'https://vrxuzquddfegpxjcffvf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZyeHV6cXVkZGZlZ3B4amNmZnZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MjkwNTcsImV4cCI6MjEwMTEwNTA1N30.YiJVKqtNM1D4aZbgBaVSGkMczNIHGpxj0tzDVj95MY8';
  // ----------------------------------

  static String baseUrlForPort(String port) {
    // Senior: Si estamos en Web, intentamos detectar si el servidor está en la misma IP que el host.
    if (kIsWeb) {
      if (_serverIp == 'localhost' || _serverIp == '127.0.0.1') {
        return 'http://localhost:$port';
      }
      
      // Senior Dynamic Protocol: Si la IP es local (192.168...), usamos HTTP y el puerto.
      // Si es un dominio (duckdns...), usamos HTTPS sin puerto (manejado por Caddy).
      final bool isLocalIp = _serverIp.startsWith('192.168.') || _serverIp.startsWith('10.');
      final protocol = isLocalIp ? 'http' : 'https';
      final portSuffix = isLocalIp ? ":$port" : "";
      
      return '$protocol://$_serverIp$portSuffix';
    }

    // Para plataformas nativas (Android/Windows):
    final bool isLocalIp = _serverIp.startsWith('192.168.') || _serverIp.startsWith('10.');
    final protocol = isLocalIp ? 'http' : 'https';
    final portSuffix = isLocalIp ? ":$port" : "";
    
    return '$protocol://$_serverIp$portSuffix';
  }

  /// URL base por defecto (servidor de Anime, puerto 3000).
  static String get baseUrl => baseUrlForPort(_animePort);

  static String get animeBaseUrl => baseUrlForPort(_animePort);
  static String get moviesBaseUrl => baseUrlForPort(_moviesPort);
  static String get kdramasBaseUrl => baseUrlForPort(_kdramasPort);

  /// URL base según la categoría de contenido (sin fan-out para 'all').
  static String baseUrlForCategory(String category) {
    final c = category.toLowerCase();
    if (c == 'kdrama' || c == 'kdramas' || c == 'dorama' || c == 'doramas') {
      return kdramasBaseUrl;
    }
    if (c == 'anime' || c == 'animes' || c == 'animé' ||
        c == 'anime-seasonal' || c == 'anime-movies' ||
        c == 'movie_anime') {
      return animeBaseUrl;
    }
    return moviesBaseUrl;
  }

  /// URL base según la fuente de scraping (p. ej. JKAnime, Cuevana3, Tudorama).
  /// Soporta fuentes duales (como GnulaHD) usando la categoría como desempate.
  static String baseUrlForSource(String source, [String? category]) {
    final s = source.toLowerCase();
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'animeflv', 'aniyae', 'animelatino', 'fiuzidragon', 'tioanime', 'animed23', 'animejara', 'katanime', 'animegratis', 'veranime'];
    const movieHints = ['gnula', 'gnulahd'];

    if (kdramaHints.any(s.contains)) return kdramasBaseUrl;

    // Caso Especial: GnulaHD existe en Anime (3000) y Películas (3001)
    if (movieHints.any(s.contains)) {
      final c = category?.toLowerCase() ?? '';
      // 'all' no trae 'anime', pero la búsqueda Todo ya fusiona resultados del
      // servidor de anime; GNU anime (el caso común) debe ir a 3000. En el VPS
      // todos los puertos colapsan al mismo dominio, así que no cambia nada.
      if (c.contains('anime') || c == 'all') return animeBaseUrl;
      return moviesBaseUrl;
    }

    if (animeHints.any(s.contains)) return animeBaseUrl;
    return moviesBaseUrl;
  }

  static String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Senior Web Fix: Si es una ruta relativa, le anteponemos la baseUrl del servidor actual.
    // Esto es crítico para que las imágenes de búsqueda carguen en dispositivos móviles.
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    
    if (kIsWeb) {
      // Si la URL contiene localhost pero hemos configurado una IP manual, la corregimos.
      if ((url.contains('localhost') || url.contains('127.0.0.1')) && 
          _serverIp != 'localhost' && _serverIp != '127.0.0.1') {
        return url.replaceAll('localhost', _serverIp).replaceAll('127.0.0.1', _serverIp);
      }
      return url;
    }
    
    if (Platform.isAndroid && (url.contains('127.0.0.1') || url.contains('localhost'))) {
      return url.replaceAll('127.0.0.1', _serverIp).replaceAll('localhost', _serverIp);
    }
    return url;
  }

  /// Pasa una imagen por el proxy del servidor si es necesario.
  static String proxyImage(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Si la URL ya es local o del proxy, no tocar.
    if (url.contains('/api/proxy/image') || url.contains(_serverIp)) {
      return fixUrl(url);
    }

    // Senior Web Fix: Solo forzamos proxy en Web por el tema de CORS.
    // En App Nativa (Android/iOS) cargamos directo para máxima velocidad.
    if (kIsWeb) {
      if (url.startsWith('http') && !url.contains('localhost') && !url.contains(_serverIp)) {
        return fixUrl('$baseUrl/api/proxy/image?url=${Uri.encodeComponent(url)}');
      }
      return url;
    }
    
    // SENIOR OPTIMIZATION (Mobile/Desktop Nativo): 
    // Solo proxeamos dominios que bloquean activamente el acceso móvil.
    // Esto reduce la carga del servidor y evita bloqueos de rate-limit.
    final bool needsProxy = url.contains('animeav1.com') || 
                            url.contains('zilla-networks.com') ||
                            url.contains('jkanime') ||
                            url.contains('gnula');

    if (needsProxy && url.startsWith('http')) {
       return fixUrl('$baseUrl/api/proxy/image?url=${Uri.encodeComponent(url)}');
    }
    
    return url;
  }

  // Search
  static const String search = '/api/search';
  static String searchByCategory(String category) => '/api/search/$category';
  static const String searchAnimeVariants = '/api/search/anime/variants';

  // Detail
  static const String detailAnime = '/api/detail/anime';
  static const String detailMovie = '/api/detail/movie';

  // Home Editorial
  static const String homeEditorial = '/api/home/editorial';

  // Home Recent / Top (scraped from real sources)
  static String homeRecent(int limit) => '/api/home/recent?limit=$limit';
  static String homeTop(int limit) => '/api/home/top?limit=$limit';

  // Schedule
  static const String schedule = '/api/schedule';

  // Sources
  static const String sources = '/api/sources';

  // Subscriptions
  static String subscriptions(String userId) => '/api/subscriptions/$userId';

  // Titles
  static const String titlesAnime = '/api/titles/anime';
  static const String titlesMovie = '/api/titles/movie';

  // Extract / Episodes
  static const String extract = '/api/extract';
  static const String episodes = '/api/episodes';
  static const String resolveEpisode = '/api/resolve-episode';

  // OMDB Enriched Data
  static const String omdbSeason = '/api/omdb/season';
  static const String omdbEpisode = '/api/omdb/episode';

  // Health
  static const String health = '/api/health';

  // Gallery (TMDB + fanart.tv images)
  static const String gallery = '/api/gallery';
  static String galleryUrl({int? tmdbId, String kind = 'tv', String? title, int? year}) {
    final q = <String, String>{};
    if (tmdbId != null) q['tmdbId'] = tmdbId.toString();
    q['kind'] = kind;
    if (title != null && title.isNotEmpty) q['title'] = title;
    if (year != null) q['year'] = year.toString();
    return '$gallery?${Uri(queryParameters: q).query}';
  }
}
