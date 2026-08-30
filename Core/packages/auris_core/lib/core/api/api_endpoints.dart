import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiEndpoints {
  static const Map<String, String> _servers = {
    'anime':   'anime.auristv.dpdns.org',
    'movies_series':  'movies-series.auristv.dpdns.org',
    'kdramas': 'kdramas.auristv.dpdns.org',
  };

  static final Map<String, String> _serverOverride = {};

  static void useLocalServer(String ip) {
    _serverOverride['anime'] = ip;
    _serverOverride['movies_series'] = ip;
    _serverOverride['kdramas'] = ip;
  }

  static String _domainFor(String category) {
    final key = category.toLowerCase();
    return _serverOverride[key] ?? _servers[key] ?? _servers['anime']!;
  }

  static String get serverAddress => _domainFor('anime');

  static String get _defaultDomain => _domainFor('anime');

  static bool _isOurServer(String url) {
    final lower = url.toLowerCase();
    final all = <String>{..._servers.values, ..._serverOverride.values};
    return all.any((d) => lower.contains(d.toLowerCase())) || 
           lower.contains('auristv.dpdns.org');
  }

  static const String _animePort = '3000';
  static const String _moviesSeriesPort = '3001';
  static const String _kdramasPort = '3002';

  static String _categoryForPort(String port) {
    if (port == _moviesSeriesPort) return 'movies_series';
    if (port == _kdramasPort) return 'kdramas';
    return 'anime';
  }

  static String _baseUrlForDomain(String domain, String port) {
    final bool isLocal = domain == 'localhost' ||
        domain == '127.0.0.1' ||
        domain.startsWith('192.168.') ||
        domain.startsWith('10.');
    if (isLocal) return 'http://$domain:$port';
    return 'https://$domain';
  }

  static String _baseUrlForCategory(String category, String port) {
    return _baseUrlForDomain(_domainFor(category), port);
  }

  // --- CONFIGURACIÓN SUPABASE ---
  static const String supabaseUrl = 'https://vrxuzquddfegpxjcffvf.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZyeHV6cXVkZGZlZ3B4amNmZnZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MjkwNTcsImV4cCI6MjEwMTEwNTA1N30.YiJVKqtNM1D4aZbgBaVSGkMczNIHGpxj0tzDVj95MY8';
  // ----------------------------------

  // --- TIMEOUTS DE UX (Sincronizados entre plataformas) ---
  /// Tiempo para esperar metadata enriquecida (logos, sinopsis larga) antes de mostrar fallbacks.
  static const Duration detailRevealTimeout = Duration(seconds: 30);
  /// Tiempo máximo para mostrar el esqueleto global de una página.
  static const Duration pageLoadTimeout = Duration(seconds: 20);
  // -------------------------------------------------------

  static String baseUrlForPort(String port) {
    return _baseUrlForCategory(_categoryForPort(port), port);
  }

  /// URL base por defecto (servidor de Anime, puerto 3000).
  static String get baseUrl => baseUrlForPort(_animePort);

  static String get animeBaseUrl => baseUrlForPort(_animePort);
  static String get moviesSeriesBaseUrl => baseUrlForPort(_moviesSeriesPort);
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
    return moviesSeriesBaseUrl;
  }

  /// URL base según la fuente de scraping (p. ej. JKAnime, Cuevana3, Tudorama).
  /// Las fuentes de películas/series (p. ej. GnulaHD) viven en el server de
  /// Películas/Series (3001) y no se enrutan al server de anime (3000).
  static String baseUrlForSource(String source, [String? category]) {
    final s = source.toLowerCase();
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'aniyae', 'animelatino', 'fiuzidragon', 'animed23', 'animejara', 'katanime'];
    const movieHints = ['gnula', 'gnulahd'];

    if (kdramaHints.any(s.contains)) return kdramasBaseUrl;

    // GnulaHD solo existe en el server de Películas/Series (3001).
    if (movieHints.any(s.contains)) return moviesSeriesBaseUrl;

    if (animeHints.any(s.contains)) return animeBaseUrl;
    return moviesSeriesBaseUrl;
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
          _defaultDomain != 'localhost' && _defaultDomain != '127.0.0.1') {
        return url.replaceAll('localhost', _defaultDomain).replaceAll('127.0.0.1', _defaultDomain);
      }
      return url;
    }
    
    if (Platform.isAndroid && (url.contains('127.0.0.1') || url.contains('localhost'))) {
      return url.replaceAll('127.0.0.1', _defaultDomain).replaceAll('localhost', _defaultDomain);
    }
    return url;
  }

  /// Pasa una imagen por el proxy del servidor si es necesario.
  /// Implementación Senior: Auto-limpieza de recursión infinita (Unwrapping).
  static String proxyImage(String? url) {
    if (url == null || url.isEmpty) return '';

    String workingUrl = url;

    // 1. DESENVOLVER (Unwrap): Eliminar capas de proxy previas si existen.
    // Esto previene el error 414 Request-URI Too Large.
    while (workingUrl.contains('/api/proxy/image?url=')) {
      try {
        final uri = Uri.parse(workingUrl);
        final nestedUrl = uri.queryParameters['url'];
        if (nestedUrl != null && nestedUrl != workingUrl) {
          workingUrl = nestedUrl;
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }

    final String lowerUrl = workingUrl.toLowerCase();

    // 2. Si es una ruta relativa o ya apunta a nuestro servidor, corregir (fixUrl) y retornar.
    if (workingUrl.startsWith('/') || _isOurServer(workingUrl) || 
        lowerUrl.contains('localhost') || lowerUrl.contains('127.0.0.1')) {
      return fixUrl(workingUrl);
    }

    // 3. Evaluar necesidad de proxy para URLs externas.
    if (workingUrl.startsWith('http')) {
      // SENIOR OPTIMIZATION: Dominios que permiten carga directa o que bloquean proxies (502).
      // Incluimos cdns de anime que suelen dar problemas en el proxy.
      const bypassDomains = [
        'tmdb.org', 
        'themoviedb.org', 
        'googleusercontent.com',
        'cloudinary.com',
        'fbcdn.net',
        'jkdesa.com',
        'jkanime.net'
      ];
      
      if (bypassDomains.any((d) => lowerUrl.contains(d))) {
        return workingUrl;
      }

      // En Web intentamos proxy para el resto (por CORS).
      bool shouldProxy = kIsWeb;
      
      // En Mobile/Nativo/TV solo para dominios conflictivos conocidos.
      if (!shouldProxy) {
        const proxyDomains = [
          'animeav1.com', 'zilla-networks.com', 'jkanime', 
          'gnula', 'animeflv', 'jk-anime', 'idmwp.com',
          'discordapp.com'
        ];
        shouldProxy = proxyDomains.any((d) => lowerUrl.contains(d));
      }

      if (shouldProxy) {
        return '$baseUrl/api/proxy/image?url=${Uri.encodeComponent(workingUrl)}';
      }
    }

    return workingUrl;
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