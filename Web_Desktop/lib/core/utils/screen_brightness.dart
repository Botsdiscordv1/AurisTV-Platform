import 'package:flutter/services.dart';

/// Controla el brillo de la pantalla a través del canal nativo Android.
/// En plataformas sin canal (web/escritorio) es un no-op silencioso.
///
/// Solo afecta a la ventana activa de la app (WindowManager.screenBrightness),
/// así que no altera permanentemente el brillo del sistema ni pide permisos.
class ScreenBrightnessController {
  static const MethodChannel _channel = MethodChannel('auristv/brightness');

  /// Aplica el brillo actual de la ventana (0.0 - 1.0).
  static Future<void> setBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>(
        'setBrightness',
        {'value': value.clamp(0.0, 1.0)},
      );
    } catch (_) {
      // Canal no disponible (web/desktop).
    }
  }

  /// Devuelve el brillo actual de la ventana; si no hay override, el del sistema.
  static Future<double> getBrightness() async {
    try {
      final value = await _channel.invokeMethod<double>('getBrightness');
      return value ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }
}