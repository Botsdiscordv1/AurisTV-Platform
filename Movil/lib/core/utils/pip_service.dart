import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('auristv/pip');
  static final ValueNotifier<bool> isPipMode = ValueNotifier<bool>(false);

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final bool inPip = call.arguments as bool? ?? false;
        isPipMode.value = inPip;
      }
    });
  }

  /// Configura si el sistema operativo puede activar PiP al salir de la app (Home button)
  static Future<void> setPipAllowed(
    bool allowed, {
    double aspectRatioWidth = 16,
    double aspectRatioHeight = 9,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) async {
    try {
      await _channel.invokeMethod('setPipAllowed', {
        'allowed': allowed,
        'aspectRatioWidth': aspectRatioWidth,
        'aspectRatioHeight': aspectRatioHeight,
        if (left != null) 'rectLeft': left,
        if (top != null) 'rectTop': top,
        if (right != null) 'rectRight': right,
        if (bottom != null) 'rectBottom': bottom,
      });
    } catch (e) {
      debugPrint('Error setting PiP allowed: $e');
    }
  }

  /// Fuerza la entrada manual a modo Picture-in-Picture (PiP)
  static Future<bool> enterPip({
    double aspectRatioWidth = 16,
    double aspectRatioHeight = 9,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip', {
        'aspectRatioWidth': aspectRatioWidth,
        'aspectRatioHeight': aspectRatioHeight,
        if (left != null) 'rectLeft': left,
        if (top != null) 'rectTop': top,
        if (right != null) 'rectRight': right,
        if (bottom != null) 'rectBottom': bottom,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error entering PiP: $e');
      return false;
    }
  }
}
