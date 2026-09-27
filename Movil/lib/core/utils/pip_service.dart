import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('auristv/pip');

  /// Configura si el sistema operativo puede activar PiP al salir de la app (Home button)
  static Future<void> setPipAllowed(bool allowed) async {
    try {
      await _channel.invokeMethod('setPipAllowed', {'allowed': allowed});
    } catch (e) {
      debugPrint('Error setting PiP allowed: $e');
    }
  }

  /// Fuerza la entrada manual a modo Picture-in-Picture (PiP)
  static Future<bool> enterPip() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (e) {
      debugPrint('Error entering PiP: $e');
      return false;
    }
  }
}
