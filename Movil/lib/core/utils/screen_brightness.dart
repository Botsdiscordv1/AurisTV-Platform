import 'package:flutter/services.dart';

/// Controla el brillo de la pantalla a través del canal nativo Android.
/// En plataformas sin canal (web/escritorio) es un no-op silencioso.
///
/// Solo afecta a la ventana activa de la app (WindowManager.screenBrightness),
/// así que no altera permanentemente el brillo del sistema ni pide permisos.
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

  /// Devuelve el brillo actual de la ventana; si no hay override, el del sistema (retorna 0.5 como base).
  static Future<double> getBrightness() async {
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      // Si el valor es < 0, significa que usa el brillo del sistema.
      if (value == null || value < 0) return 0.5;
      return value.clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }
}