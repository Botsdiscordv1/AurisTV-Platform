import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Gestor centralizado de caché en disco para AurisTV.
/// Diseñado para equilibrar velocidad, persistencia y espacio de almacenamiento
/// en dispositivos limitados (como TV Boxes chinas de 1GB RAM / 8GB eMMC).
class AurisImageCacheManager {
  AurisImageCacheManager._();

  static const String key = 'auris_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 800,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Configuración global de memoria y comportamiento de renderizado de imágenes.
/// Previene la expulsión prematura de memoria RAM (LRU thrashing) sin exceder
/// los estrictos límites de Dalvik/Heap en TV Boxes de gama baja.
class AurisImageConfig {
  AurisImageConfig._();

  /// Animación ultra rápida de fade-in para evitar sensación de recarga / parpadeo
  /// y reducir el consumo de shaders en GPUs modestas (ej. Mali-450 / Mali-G31).
  static const Duration defaultFadeInDuration = Duration(milliseconds: 100);
  static const Duration defaultFadeOutDuration = Duration.zero;

  /// Configuración optimizada para Android TV / Google TV.
  /// En TV Boxes chinas de 1GB de RAM, el sistema operativo deja apenas ~250MB
  /// libres para apps. Un límite de 72-85MB para imágenes es el punto dulce:
  /// evita que el OOM-Killer cierre la app y, gracias a [memCacheWidth] estricto,
  /// permite mantener más de 300 pósters y carátulas en memoria viva simultáneamente.
  static void configureForTV({bool isLowRam = true}) {
    if (kIsWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = isLowRam ? (72 << 20) : (96 << 20); // 72MB - 96MB
    cache.maximumSize = isLowRam ? 350 : 500;
  }

  /// Configuración para Móviles Android / iOS (típicamente 3GB - 8GB RAM).
  static void configureForMobile() {
    if (kIsWeb) return;
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = 160 << 20; // 160 MB
    cache.maximumSize = 800;
  }

  /// Configuración para Web y Desktop (Windows / macOS / Linux).
  static void configureForDesktopWeb() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = 384 << 20; // 384 MB
    cache.maximumSize = 1200;
  }
}
