import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class WebUtils {
  /// Elimina el Splash Screen de la web una vez que la app está lista.
  static void removeSplashScreen() {
    try {
      // Senior Web Fix: Verificar si la función existe en el Window global antes de llamarla.
      // Esto evita el error NoSuchMethodError si index.html no tiene implementado el Splash.
      if (js.context.hasProperty('removeSplashScreen')) {
        js.context.callMethod('removeSplashScreen');
      }
    } catch (e) {
      // debugPrint('Error removing splash screen: $e');
    }
  }

  /// Aplica ganancia de audio (Boost) al elemento video de la web.
  static void applyAudioBoost(double gain) {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
        (function(gainValue) {
          const videos = document.getElementsByTagName('video');
          for (let video of videos) {
            try {
              // Senior Web Fix: No enganchar el AudioContext si el volumen es normal (1.0) 
              // y aún no se ha inicializado el contexto. Esto previene el silencio por CORS.
              if (gainValue === 1.0 && !video._audioCtx) continue;

              if (!video._audioCtx) {
                const AudioContext = window.AudioContext || window.webkitAudioContext;
                if (!AudioContext) return;
                
                video._audioCtx = new AudioContext();
                video._source = video._audioCtx.createMediaElementSource(video);
                video._gainNode = video._audioCtx.createGain();
                video._source.connect(video._gainNode);
                video._gainNode.connect(video._audioCtx.destination);
              }
              
              if (video._audioCtx.state === 'suspended') {
                video._audioCtx.resume();
              }
              
              if (video._gainNode) {
                // Aplicar ganancia con rampa suave para evitar ruidos
                video._gainNode.gain.setTargetAtTime(gainValue, video._audioCtx.currentTime, 0.01);
              }
            } catch(e) { 
              // console.warn('AurisBoost System Error:', e); 
            }
          }
        })($gain)
        """
      ]);
    } catch (e) {
      debugPrint('Error applying web audio boost: $e');
    }
  }
}
