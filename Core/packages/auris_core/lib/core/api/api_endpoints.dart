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
           lower.contains('auristv.dpdns.org') ||
           lower.contains('129.151.126.4');
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
    
    final bool isIP = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(domain);
    if (isIP) return 'https://$domain:$port';

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
  static const Duration detailRevealTimeout = Duration(seconds: 30);
  static const Duration pageLoadTimeout = Duration(seconds: 20);
  // -------------------------------------------------------

  static String baseUrlForPort(String port) {
    return _baseUrlForCategory(_categoryForPort(port), port);
  }

  static String get baseUrl => baseUrlForPort(_animePort);
  static String get animeBaseUrl => baseUrlForPort(_animePort);
  static String get moviesSeriesBaseUrl => baseUrlForPort(_moviesSeriesPort);
  static String get kdramasBaseUrl => baseUrlForPort(_kdramasPort);

  static String baseUrlForCategory(String category) {
    final c = category.toLowerCase();
    if (c == 'kdrama' || c == 'kdramas' || c == 'dorama' || c == 'doramas') return kdramasBaseUrl;
    if (c == 'anime' || c == 'animes' || c == 'animé' ||
        c == 'anime-seasonal' || c == 'anime-movies' ||
        c == 'movie_anime') return animeBaseUrl;
    return moviesSeriesBaseUrl;
  }

  static String baseUrlForSource(String source, [String? category]) {
    final s = source.toLowerCase();
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'aniyae', 'animelatino', 'fiuzidragon', 'animed23', 'animejara', 'katanime'];
    const movieHints = ['gnula', 'gnulahd'];
    if (kdramaHints.any(s.contains)) return kdramasBaseUrl;
    if (movieHints.any(s.contains)) return moviesSeriesBaseUrl;
    if (animeHints.any(s.contains)) return animeBaseUrl;
    return moviesSeriesBaseUrl;
  }

  static String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('/')) return '$baseUrl$url';
    
    final lower = url.toLowerCase();
    
    if (kIsWeb) {
      String fixed = url;
      // En Web, si la URL tiene la IP de nuestro servidor, la cambiamos por el dominio
      // para evitar errores de certificado SSL (Mixed Content / Cert Mismatch).
      if (lower.contains('129.151.126.4')) {
        fixed = fixed.replaceAll('129.151.126.4', _defaultDomain);
        fixed = fixed.replaceAll(':3000', '');
        fixed = fixed.replaceAll(':3001', '');
        fixed = fixed.replaceAll(':3002', '');
      }
      
      if ((lower.contains('localhost') || lower.contains('127.0.0.1')) &&
          _defaultDomain != 'localhost' && _defaultDomain != '127.0.0.1') {
        fixed = fixed.replaceAll('localhost', _defaultDomain).replaceAll('127.0.0.1', _defaultDomain);
        fixed = fixed.replaceAll(':3000', '');
        fixed = fixed.replaceAll(':3001', '');
        fixed = fixed.replaceAll(':3002', '');
      }
      return fixed;
    }

    // Guard para evitar crash en Web al acceder a Platform
    if (Platform.isAndroid && (lower.contains('127.0.0.1') || lower.contains('localhost'))) {
      return url.replaceAll('127.0.0.1', _defaultDomain).replaceAll('localhost', _defaultDomain);
    }
    
    return url;
  }

  /// Pasa una imagen por el proxy del servidor si es necesario.
  /// Implementación Senior: Idempotente y Anti-Recursiva.
  static String proxyImage(String? url) {
    if (url == null || url.isEmpty) return '';

    String workingUrl = url;

    // 1. DESENVOLVER (Unwrap) TOTAL:
    // Siempre limpiamos la URL primero para saber qué hay realmente dentro,
    // incluso si ya viene con nuestro proxy desde el servidor.
    while (workingUrl.contains('url=http') || workingUrl.contains('/api/proxy/image')) {
       final int index = workingUrl.lastIndexOf('url=http');
       if (index != -1) {
         workingUrl = workingUrl.substring(index + 4);
         try {
           workingUrl = Uri.decodeFull(workingUrl);
         } catch (_) {}
       } else {
         break; 
       }
    }

    final String lowerUrl = workingUrl.toLowerCase();

    // 2. BYPASS DE SEGURIDAD (Prioridad Absoluta):
    // Dominios que NUNCA deben pasar por el proxy porque fallan (502/403).
    const bypassKeywords = [
      'tmdb.org', 'themoviedb.org', 
      'googleusercontent.com', 'fbcdn.net'
    ];
    
    if (bypassKeywords.any((k) => lowerUrl.contains(k))) {
      return workingUrl; // Devolvemos la URL limpia y directa
    }

    // 3. Si la URL limpia es de nuestro servidor o local, fixUrl.
    if (_isOurServer(workingUrl) || workingUrl.startsWith('/') || 
        lowerUrl.contains('localhost') || lowerUrl.contains('127.0.0.1')) {
      return fixUrl(workingUrl);
    }

    // 4. APLICAR PROXY:
    if (workingUrl.startsWith('http')) {
      // --- FALLBACK PARA DOMINIOS CIEGOS (Weserv) ---
      // Si el VPS no puede ver el dominio (como jkdesa), usamos un proxy público global.
      if (lowerUrl.contains('jkdesa.com') || lowerUrl.contains('jkanime.net')) {
        return 'https://images.weserv.nl/?url=${Uri.encodeComponent(workingUrl)}';
      }

      // --- PROXY PRIVADO (Nuestro VPS) ---
      // Para el resto de dominios que el VPS SÍ ve (como animeav1).
      if (kIsWeb) {
        return '$baseUrl/api/proxy/image?url=${Uri.encodeComponent(workingUrl)}';
      }
      
      const forceProxyDomains = [
        'zilla-networks.com', 'idmwp.com', 'animeflv', 
        'animeav1.com'
      ];
      if (forceProxyDomains.any((d) => lowerUrl.contains(d))) {
        return '$baseUrl/api/proxy/image?url=${Uri.encodeComponent(workingUrl)}';
      }
    }

    return workingUrl;
  }

  static const String search = '/api/search';
  static String searchByCategory(String category) => '/api/search/$category';
  static const String searchAnimeVariants = '/api/search/anime/variants';
  static const String detailAnime = '/api/detail/anime';
  static const String detailMovie = '/api/detail/movie';
  static const String homeEditorial = '/api/home/editorial';
  static String homeRecent(int limit) => '/api/home/recent?limit=$limit';
  static String homeTop(int limit) => '/api/home/top?limit=$limit';
  static const String schedule = '/api/schedule';
  static const String sources = '/api/sources';
  static String subscriptions(String userId) => '/api/subscriptions/$userId';
  static const String titlesAnime = '/api/titles/anime';
  static const String titlesMovie = '/api/titles/movie';
  static const String extract = '/api/extract';
  static const String episodes = '/api/episodes';
  static const String resolveEpisode = '/api/resolve-episode';
  static const String omdbSeason = '/api/omdb/season';
  static const String omdbEpisode = '/api/omdb/episode';
  static const String health = '/api/health';
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
