import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utilidad global para prevenir el spam de clics en la navegación (Safe Tap).
/// 
/// Bloquea ejecuciones sucesivas de una función si se invocan dentro de un 
/// umbral de tiempo determinado (por defecto 600ms).
class SafeTap {
  static DateTime? _lastTap;
  
  /// Ejecuta la [action] solo si ha pasado suficiente tiempo desde el último clic.
  /// 
  /// [threshold] es el tiempo mínimo de espera entre clics (default: 600ms).
  static void run(VoidCallback action, {int threshold = 600}) {
    final now = DateTime.now();
    
    if (_lastTap == null || now.difference(_lastTap!).inMilliseconds > threshold) {
      _lastTap = now;
      action();
    } else {
      debugPrint('[SafeTap] Spam detectado. Bloqueando acción para evitar duplicados.');
    }
  }

  /// Limpia el bloqueo manualmente (útil para tests o reset de estados).
  static void reset() {
    _lastTap = null;
  }
}
