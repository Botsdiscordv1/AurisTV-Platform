import 'package:flutter/foundation.dart';

class WebUtils {
  /// No hace nada en plataformas nativas.
  static void removeSplashScreen() {
    debugPrint('[WebUtils] Splash removal ignored on non-web platform.');
  }

  /// No hace nada en plataformas nativas.
  static void applyAudioBoost(double gain) {
    // El boost nativo ya se maneja en el reproductor
  }
}
