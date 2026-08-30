import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Senior Optimization: Reloj global para efectos editoriales (Pulse, Shimmer, Mythic).
/// 
/// En lugar de tener cientos de AnimationControllers (uno por cada tarjeta),
/// usamos este Singleton para sincronizar todas las animaciones del home.
/// Esto reduce drásticamente el uso de CPU y el número de Tickers activos.
class EditorialAnimationController extends ChangeNotifier {
  static final EditorialAnimationController instance = EditorialAnimationController._();
  EditorialAnimationController._();

  Ticker? _ticker;
  Duration _elapsed = Duration.zero;
  int _activeCount = 0;

  double get pulseValue {
    // Onda de 1.5s (0.0 a 1.0 y vuelta)
    final ms = _elapsed.inMilliseconds % 1500;
    final t = ms / 1500.0;
    return (t < 0.5 ? t * 2 : (1.0 - t) * 2).clamp(0.0, 1.0);
  }

  double get shimmerValue {
    // Barrido de 7s
    final ms = _elapsed.inMilliseconds % 7000;
    return ms / 7000.0;
  }

  double get mythicValue {
    // Ciclo de 4s
    final ms = _elapsed.inMilliseconds % 4000;
    return ms / 4000.0;
  }

  void acquire() {
    _activeCount++;
    if (_ticker == null) {
      _ticker = Ticker((elapsed) {
        _elapsed = elapsed;
        notifyListeners();
      });
      _ticker!.start();
    } else if (!_ticker!.isActive) {
      _ticker!.start();
    }
  }

  void release() {
    if (_activeCount > 0) _activeCount--;
    if (_activeCount == 0 && _ticker != null) {
      _ticker!.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
