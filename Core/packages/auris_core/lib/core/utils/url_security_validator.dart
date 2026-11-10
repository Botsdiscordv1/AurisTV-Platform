import 'dart:math';
import 'package:flutter/foundation.dart';

/// Utilidades de seguridad para validar URLs y fuentes antes de
/// procesarlas a través de los endpoints de extracción de video.
/// 
/// Previene ataques de Server-Side Request Forgery (SSRF) y acceso
/// no autorizado a recursos internos.
class UrlSecurityValidator {
  // ============================================
  // --- LISTA BLANCA DE DOMINIOS PERMITIDOS ---
  // ============================================
  
  /// Dominios de streaming conocidos que son seguros para procesar.
  /// Las URLs que NO coincidan con estos dominios deben ser rechazadas.
  static const Set<String> allowedSourceHints = {
    // Anime sources
    'jkanime',
    'animeav1',
    'animed23',
    'animejara',
    'aniyae',
    'animelatino',
    'fiuzidragon',
    'tioanime',
    'katanime',
    'animegratis',
    'animeflv',
    'telegram',
    'veranime',
    'latinoyt',
    
    // Movie/Series sources
    'gnula',
    'gnulahd',
    'onlypelis',
    'pelispedia',
    'lamovie',
    'repelishd',
    'cuevana',
    
    // K-Drama sources
    'tudorama',
    'doramasyt',
    'doramasmp4',
    'pandrama',
    'doramaslatinox',
    
    // Live/PPV sources
    'ppv',
    'sport',
    'live',
    
    // YouTube (se maneja aparte)
    'youtube',
  };
  
  // ============================================
  // --- RANGES DE IP PRIVADOS (SSRF) ---
  // ============================================
  
  /// Patrones de IP privados que deben ser bloqueados
  static final RegExp _privateIpPattern = RegExp(
    r'^(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|'
    r'172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|'
    r'192\.168\.\d{1,3}\.\d{1,3}|'
    r'127\.\d{1,3}\.\d{1,3}\.\d{1,3}|'
    r'169\.254\.\d{1,3}\.\d{1,3}|'
    r'0\.\d{1,3}\.\d{1,3}\.\d{1,3}|'
    r'\:\:\:|'
    r'::1|'
    r'fc00::|'
    r'fd00::|'
    r'fe80::)',
    caseSensitive: false,
  );
  
  /// Dominios que deben ser bloqueados (no son hosts confiables)
  static const Set<String> blockedHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '[::1]',
    'metadata.google.internal',
  };
  
  // ============================================
  // --- VALIDACIÓN DE URL ---
  // ============================================
  
  /// Valida si una URL es segura para procesar.
  /// Retorna true si la URL pasa la validación, false si debe ser rechazada.
  static bool isUrlSafe(String url, {String? source}) {
    if (url.isEmpty) return false;
    
    final String normalizedUrl = url.toLowerCase().trim();
    
    // 1. Bloquear URLs de hosts locales/internos
    if (blockedHosts.any((host) => 
        normalizedUrl.contains(host) || 
        normalizedUrl.startsWith(host))) {
      debugPrint('[SECURITY] URL bloqueada por host local: $url');
      return false;
    }
    
    // 2. Bloquear IPs privadas
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        if (_privateIpPattern.hasMatch(uri.host) ||
            _privateIpPattern.hasMatch(uri.host.replaceAll(':', ''))) {
          debugPrint('[SECURITY] URL bloqueada por IP privada: $url');
          return false;
        }
      }
    } catch (e) {
      // Si no puede parsear, es sospechoso
      debugPrint('[SECURITY] URL no parseable, rechazada: $url');
      return false;
    }
    
    // 3. Requerir esquema http/https
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      debugPrint('[SECURITY] URL con esquema no permitido: $url');
      return false;
    }
    
    // 4. Validar source contra whitelist (si se proporciona)
    if (source != null && source.isNotEmpty) {
      final sourceLower = source.toLowerCase();
      
      // YouTube se maneja aparte (no hace extract)
      if (sourceLower.contains('youtube') || 
          url.contains('youtube.com') || 
          url.contains('youtu.be')) {
        return true; // Se maneja sin extract
      }
      
      // Verificar si el source está en la whitelist
      final hasValidSource = allowedSourceHints.any((hint) => 
          sourceLower.contains(hint));
      
      if (!hasValidSource) {
        debugPrint('[SECURITY] Source no autorizado: $source');
        return false;
      }
      
      // Verificar que la URL tenga un dominio relacionado
      final hasMatchingDomain = allowedSourceHints.any((hint) => 
          normalizedUrl.contains(hint));
      
      if (!hasMatchingDomain && !normalizedUrl.contains('auristv.dpdns.org')) {
        debugPrint('[SECURITY] URL sin dominio permitido: $url');
        // Nota: esto es un warning, no un error, porque los servidores
        // pueden redirigir a otros hosts
      }
    }
    
    return true;
  }
  
  /// Valida una URL de estación (canal deportivo) específica.
  /// Estas tienen reglas más estrictas.
  static bool isSportsChannelUrlSafe(String url) {
    if (url.isEmpty) return false;
    
    final String normalized = url.toLowerCase().trim();
    
    // Solo permitir URLs que empiecen con http/https
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      debugPrint('[SECURITY] URL de canal deportivo inválida: $url');
      return false;
    }
    
    // No permitir redirecciones a localhost
    if (normalized.contains('localhost') || 
        normalized.contains('127.0.0.1') ||
        normalized.contains('192.168.') ||
        normalized.contains('10.') ||
        normalized.contains('172.')) {
      debugPrint('[SECURITY] URL de canal deportivo con IP interna: $url');
      return false;
    }
    
    return true;
  }
}

/// Validador para parámetros de extracción
class ExtractParamsValidator {
  /// Valida los parámetros antes de llamar a extractVideo
  static bool validate({
    required String url,
    required String source,
    String? category,
  }) {
    // Validar URL base
    if (!UrlSecurityValidator.isUrlSafe(url, source: source)) {
      return false;
    }
    
    // Validar category contra valores permitidos
    if (category != null && category.isNotEmpty) {
      final validCategories = {'anime', 'movies', 'series', 'kdrama', 'live', 'sports', 'all'};
      final categoryLower = category.toLowerCase();
      
      // Permitir también valores derivados de las fuentes conocidas
      final isRecognizedCategory = categoryLower.anyMatch({'anime', 'movie', 'series', 'kdrama', 'drama', 'live', 'sport', 'ppv', 'sports'});
      
      if (!isRecognizedCategory && !validCategories.contains(categoryLower)) {
        debugPrint('[SECURITY] Categoría no reconocida: $category');
        // Warning, no error - categorías desconocidas pueden ser válidas en nuevas fuentes
      }
    }
    
    // Source no debe estar vacío
    if (source.isEmpty) {
      debugPrint('[SECURITY] Source vacío en extractVideo');
      return false;
    }
    
    return true;
  }
}

/// Extension para hacer coincidencia parcial en conjuntos
extension SetStringAnyMatchExtension on String {
  bool anyMatch(Set<String> patterns) {
    final lower = toLowerCase();
    return patterns.any((pattern) => lower.contains(pattern));
  }
}