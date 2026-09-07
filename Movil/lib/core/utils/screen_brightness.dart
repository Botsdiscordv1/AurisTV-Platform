import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Controla el brillo de la pantalla a través del canal nativo Android.
/// En plataformas sin canal (web/escritorio) es un no-op silencioso.
class ScreenBrightnessController {
  static const MethodChannel _channel = MethodChannel('auristv/brightness');

  /// Aplica el brillo actual de la ventana (0.0 - 1.0).
  /// Si se pasa -1.0, se restaura el brillo del sistema.
  static Future<void> setBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>(
        'setBrightness',
        {'value': value == -1.0 ? -1.0 : value.clamp(0.0, 1.0)},
      );
    } catch (_) {
      // Canal no disponible (web/desktop).
    }
  }

  /// Restaura el brillo al valor del sistema.
  static Future<void> resetBrightness() async {
    await setBrightness(-1.0);
  }

  /// Devuelve el brillo actual; si no hay override de ventana, el del sistema.
  static Future<double> getBrightness() async {
    try {
      // 1. Intentamos obtener el override de la ventana actual desde el canal nativo
      final windowBrightness = await _channel.invokeMethod<double>('getBrightness');
      
      // 2. Si hay un override activo en la ventana (0.0 a 1.0), lo respetamos.
      // Android devuelve -1.0 si usa el del sistema.
      if (windowBrightness != null && windowBrightness >= 0.0) {
        return windowBrightness.clamp(0.0, 1.0);
      }

      // 3. Senior Fix: Si no hay override, obtenemos el brillo ACTUAL (que es el del sistema).
      // Usamos .current para capturar el valor real que ve el ojo del usuario.
      double current = await ScreenBrightness().current;
      
      // Senior Safety: Si el valor es 0, podría ser que el plugin aún no esté listo.
      // Intentamos con .system como segunda opción.
      if (current <= 0.0) {
        current = await ScreenBrightness().system;
      }

      // Senior Final Fallback: Si sigue siendo casi 0, usamos 0.5 por seguridad.
      return current > 0.01 ? current.clamp(0.0, 1.0) : 0.5;
    } catch (_) {
      return 0.5;
    }
  }
}