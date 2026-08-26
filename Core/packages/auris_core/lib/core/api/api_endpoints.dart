import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiEndpoints {
  static const Map<String, String> _servers = {
    'anime':   'anime.auristv.dpdns.org',
    'movies_series':  'movies-series.auristv.dpdns.org',
    'kdramas': 'kdramas.auristv.dpdns.org',
  };

  static final Map<String, String> _serverOverride = {};

  static void setServerAddress(String address, [String category = 'anime']) {
    _serverOverride[category.toLowerCase()] = address;
  }

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
    final all = <String>{..._servers.values, ..._serverOverride.values};
    return all.any((d) => url.contains(d));
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
      return moviesSeriesBaseUrl;
    }

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
  static String proxyImage(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Si la URL ya es local o del proxy, no tocar.
    if (url.contains('/api/proxy/image') || _isOurServer(url)) {
      return fixUrl(url);
    }

    // Senior Web Fix: Solo forzamos proxy en Web por el tema de CORS.
    // En App Nativa (Android/iOS) cargamos directo para máxima velocidad.
    if (kIsWeb) {
      if (url.startsWith('http') && !url.contains('localhost') && !_isOurServer(url)) {
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
