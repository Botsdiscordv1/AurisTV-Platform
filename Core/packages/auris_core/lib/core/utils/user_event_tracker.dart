import 'package:flutter/foundation.dart';
import '../../data/repositories/auris_repository.dart';

/// Servicio singleton de Tracking E2E de Eventos de Usuario para personalización.
/// Gestiona deduplicación de eventos por sesión de reproducción, debouncing y aislamiento de red.
class UserEventTracker {
  final AurisRepository _repository;
  
  // Set en memoria para deduplicar eventos de interacción directa rápidos (debounce de clicks o toggle)
  final Map<String, DateTime> _debounceCache = {};
  
  // Cache de sesiones activas para impedir duplicación redundante de play/completed en la misma instancia
  final Set<String> _playbackSessionCache = {};

  UserEventTracker(this._repository);

  /// Registra un evento de personalización del usuario y lo envía asíncronamente al backend sin bloquear la UX.
  void record({
    required String? userId,
    required String? animeId,
    required String event,
    String? sectionId,
    String? playbackSessionId,
  }) {
    // Restricciones de guard obligatorias del negocio
    if (userId == null || userId.isEmpty || userId == 'guest_profile') return;
    if (animeId == null || animeId.isEmpty) return;

    final String eventKey = event.trim().toLowerCase();
    
    // Deduplicación específica para reproducción (play, completed_view) combinando sesión
    if (playbackSessionId != null && (eventKey == 'play' || eventKey == 'completed_view')) {
      final String sessionKey = '${userId}_${animeId}_${playbackSessionId}_$eventKey';
      if (_playbackSessionCache.contains(sessionKey)) {
        return; // Evento ya enviado para esta sesión de reproducción, ignorar
      }
      _playbackSessionCache.add(sessionKey);
    } else {
      // Debounce general de 1.5 segundos para eventos rápidos/rebuilds de UI (detail_view, favorite, dislike, skip)
      final String actionKey = '${userId}_${animeId}_$eventKey';
      final DateTime now = DateTime.now();
      if (_debounceCache.containsKey(actionKey)) {
        final DateTime lastSent = _debounceCache[actionKey]!;
        if (now.difference(lastSent).inMilliseconds < 1500) {
          return; // Ignorar ráfaga por rebuild o clics simultáneos
        }
      }
      _debounceCache[actionKey] = now;
    }

    if (kDebugMode) {
      print('[UserEventTracker] Fire Event real -> userId: $userId, animeId: $animeId, event: $eventKey');
    }

    // Ejecución asíncrona aislada para no bloquear la reproducción o navegación (UX fluida)
    _repository.sendUserEvent(
      userId: userId,
      animeId: animeId,
      event: eventKey,
      sectionId: sectionId,
    ).ignore();
  }

  /// Limpia los cachés de sesión (Útil para cambios de usuario o reseteo de estados)
  void clearCache() {
    _debounceCache.clear();
    _playbackSessionCache.clear();
  }
}
