import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Puente al canal NATIVO de Google Cast de Android (`CastChannel.kt`).
///
/// - MethodChannel "auristv/cast": comandos (init, chooser, load, play...).
/// - EventChannel "auristv/castEvents": eventos del receptor (posición, sesión...).
///
/// En iOS/Web/Windows los métodos son no-op seguros (el cast nativo
/// solo existe en Android con Google Play Services).
class NativeCastService {
  static const MethodChannel _channel = MethodChannel('auristv/cast');
  static const EventChannel _eventChannel = EventChannel('auristv/castEvents');

  final bool isSupported =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Inicializa el CastContext nativo. Devuelve true si Cast está disponible.
  Future<bool> init() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('init') ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[AurisCast] init error: $e');
      return false;
    }
  }

  /// Abre el diálogo NATIVO de Google Cast para elegir dispositivo.
  Future<bool> showDeviceChooser() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('showDeviceChooser') ?? false;
    } catch (e) {
      debugPrint('[AurisCast] showDeviceChooser error: $e');
      return false;
    }
  }

  /// Carga el media en el receptor y arranca el autoplay.
  Future<void> loadMedia({
    required String url,
    required int startMs,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('loadMedia', {
        'url': url,
        'startMs': startMs,
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
    } catch (e) {
      debugPrint('[AurisCast] loadMedia error: $e');
    }
  }

  Future<void> play() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('[AurisCast] play error: $e');
    }
  }

  Future<void> pause() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('[AurisCast] pause error: $e');
    }
  }

  Future<void> seekTo(int ms) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('seek', {'ms': ms});
    } catch (e) {
      debugPrint('[AurisCast] seek error: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
    } catch (e) {
      debugPrint('[AurisCast] setVolume error: $e');
    }
  }

  /// Detiene la reproducción y desconecta la sesión (reten en handback).
  Future<bool> stopCasting() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('stopCasting') ?? false;
    } catch (e) {
      debugPrint('[AurisCast] stopCasting error: $e');
      return false;
    }
  }

  /// Último estado de media conocido (para restaurar UI al reabrir el player).
  Future<Map<String, dynamic>?> getMediaStatus() async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMethod('getMediaStatus');
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  /// Stream de eventos nativos (availability, sessionStarted, mediaStatus...).
  Stream<Map<String, dynamic>> events() {
    return _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }
}
