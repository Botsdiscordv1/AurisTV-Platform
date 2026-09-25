import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import 'home_provider.dart';

/// Tanda 2 — Ping reactivo de estrenos.
///
/// Consulta `GET /api/schedule/premiere-ping?since=` para saber si el server
/// actualizó `premiereUpdatedAt` (estrenos que entraron en su ventana de
/// emisión). Si hubo cambio, invalida el [scheduleProvider] global para que
/// la siguiente lectura refetchee el DTO fresco.
///
/// `since` crece monótonamente en memoria (una instancia por sesión de app).
/// El primer exito solo fija la línea base: en ese instante el schedule que
/// la pantalla acaba de cargar ya incluía esos patches, así que no hay cambio
/// que reportar. Nunca lanza — un ping fallido se ignora.
class SchedulePing {
  SchedulePing._();

  static int _lastUpdateAt = 0;
  static bool _baselineSet = false;

  /// Devuelve `true` si el server reportó estrenos actualizados desde la
  /// última consulta (después de fijar la línea base). Falla → `false`.
  static Future<bool> check(WidgetRef ref) async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final result = await repo.pingSchedulePremieres(_lastUpdateAt);
      if (result == null) return false;

      final lastUpdateAt = (result['lastUpdateAt'] as num?)?.toInt() ?? 0;
      // Primer exito: solo fija la línea base (el schedule ya cargado ya
      // incluye esos patches) — no reporta cambio.
      final changed = _baselineSet && result['changed'] == true;

      if (lastUpdateAt > _lastUpdateAt) _lastUpdateAt = lastUpdateAt;
      _baselineSet = true;

      if (changed) {
        ref.invalidate(scheduleProvider);
      }
      return changed;
    } catch (_) {
      return false;
    }
  }

  /// Solo para tests: restablece la línea base de la sesión.
  static void reset() {
    _lastUpdateAt = 0;
    _baselineSet = false;
  }
}
