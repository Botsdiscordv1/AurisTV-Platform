import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Utilidades para generar y verificar tokens firmados con HMAC.
/// 
/// Este sistema protege los deep links de `/watch/:token/:slug` y similares 
/// contra:
/// - URL falsas (tokens inventados)
/// - Reutilización de tokens antiguos
/// - Acceso a contenido protegido mediante URL compartidas
/// 
/// Uso:
/// ```dart
/// // Al generar URL
/// final signedToken = SignedTokenManager.createToken(payload: {'title': 'My Show'});
/// final url = '/watch/$signedToken/$slug';
/// 
/// // Al leer URL
/// final payload = SignedTokenManager.verifyToken(token);
/// if (payload != null) { /* token válido */ }
/// ```
class SignedTokenManager {
  // ============================================
  // --- CONFIGURACIÓN ---
  // ============================================
  
  /// Duración máxima de validez del token (24 horas por defecto)
  static const Duration tokenValidity = Duration(hours: 24);
  
  /// Número de segundos de tolerancia para diferencias de reloj
  static const int _maxClockSkewSeconds = 60; // 1 minuto
  
  /// Prefijo para identificar tokens firmados en la caché
  static const String _cachePrefix = 'signed_token_';
  
  // ============================================
  // --- FIRMADO HMAC-SHA256 ---
  // ============================================
  
  /// Genera la clave secreta para HMAC.
  /// En producción, DEBE provenir de variables de entorno o un secrets manager.
  static Uint8List _getSigningKey() {
    // En producción, reemplazar con:
    // final key = Platform.environment['TOKEN_SIGNING_KEY'];
    // if (key == null || key.isEmpty) {
    //   // Fallar en producción, permitir en desarrollo
    //   assert(false, 'TOKEN_SIGNING_KEY no configurado');
    //   return Uint8List.fromList(utf8.encode('dev-only-key-change-me'));
    // }
    // return Uint8List.fromList(utf8.encode(key));
    
    // Versión desarrollo: clave fija pero documentada como temporal
    // TODO: Migrar a variables de entorno en producción
    const devKey = 'auris_tv_token_signing_key_v1_change_in_production';
    return Uint8List.fromList(utf8.encode(devKey));
  }
  
  /// Crea un token firmado con HMAC-SHA256.
  /// 
  /// El token tiene formato: `base64(payload).base64(signature).timestamp`
  static String createToken({required Map<String, dynamic> payload}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final fullPayload = {
      ...payload,
      'ts': timestamp,
      'ver': 1,
    };
    
    final payloadBytes = utf8.encode(jsonEncode(fullPayload));
    final payloadB64 = base64Url.encode(payloadBytes);
    
    final key = _getSigningKey();
    final signature = Hmac(sha256, key).convert(payloadBytes);
    final signatureB64 = base64Url.encode(signature.bytes);
    
    return '$payloadB64.$signatureB64.$timestamp';
  }
  
  /// Verifica un token firmado y devuelve el payload si es válido.
  static Map<String, dynamic>? verifyToken(String token) {
    if (token.isEmpty) return null;
    
    final parts = token.split('.');
    if (parts.length != 3) {
      // Formato antiguo (sinfirmar) - aún se permite pero sin garantías
      return _decodeLegacyToken(token);
    }
    
    try {
      final payloadB64 = parts[0];
      final signatureB64 = parts[1];
      final timestampStr = parts[2];
      
      final timestamp = int.tryParse(timestampStr);
      if (timestamp == null) return null;
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp > tokenValidity.inSeconds + _maxClockSkewSeconds) {
        debugPrint('[SignedToken] Token expirado (edad: ${now - timestamp}s)');
        return null;
      }
      
      final payloadBytes = base64Url.decode(payloadB64);
      final fullPayload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      
      final key = _getSigningKey();
      final expectedSignature = Hmac(sha256, key).convert(payloadBytes);
      final expectedB64 = base64Url.encode(expectedSignature.bytes);
      
      if (!timingSafeEqual(signatureB64, expectedB64)) {
        debugPrint('[SignedToken] Firma inválida');
        return null;
      }
      
      fullPayload.remove('ts');
      fullPayload.remove('ver');
      
      return fullPayload;
    } catch (e) {
      debugPrint('[SignedToken] Error verificando token: $e');
      return null;
    }
  }
  
  static Map<String, dynamic>? _decodeLegacyToken(String token) {
    // Implementación simplificada - los tokens legacy se validan por caché
    return null;
  }
  
  static bool timingSafeEqual(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
  
  // ============================================
  // --- INTEGRACIÓN CON CACHE ---
  // ============================================
  
  static void cacheVerifiedToken(String signedToken, Map<String, dynamic> payload) {
    try {
      if (Hive.isBoxOpen('media_slug_cache')) {
        final box = Hive.box('media_slug_cache');
        box.put('$_cachePrefix$signedToken', payload);
      }
    } catch (e) {
      debugPrint('[SignedToken] Error guardando en cache: $e');
    }
  }
  
  static Map<String, dynamic>? getCachedOrVerify(String token) {
    if (Hive.isBoxOpen('media_slug_cache')) {
      final box = Hive.box('media_slug_cache');
      final cached = box.get('$_cachePrefix$token');
      if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }
    }
    return verifyToken(token);
  }
}