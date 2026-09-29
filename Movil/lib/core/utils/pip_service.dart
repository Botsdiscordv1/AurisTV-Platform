import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('auristv/pip');
  static final ValueNotifier<bool> isPipMode = ValueNotifier<bool>(false);

  /// Orientación real justo antes de entrar a PiP (el mini es vertical, pero
  /// se puede entrar desde el player horizontal). Al volver se restaura ESTA,
  /// no lo que diga el sensor en ese momento.
  static bool prePipWasLandscape = false;

  /// Si el sistema nunca confirma la entrada (onPipChanged true), se revierte
  /// el modo video-solo: si no, un Home sin PiP dejaría la UI atorada.
  static Timer? _entryWatchdog;
  static bool _entryConfirmed = false;
  /// Retorno del árbol completo tras salir de PiP (ver onPipChanged).
  static Timer? _exitRevertTimer;

  static void _recordPrePipOrientation() {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      prePipWasLandscape = size.width > size.height;
    } catch (_) {}
  }

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'prepareForPip') {
        _recordPrePipOrientation();
        _entryConfirmed = false;
        _exitRevertTimer?.cancel();
        isPipMode.value = true;
        _entryWatchdog?.cancel();
        _entryWatchdog = Timer(const Duration(seconds: 2), () {
          if (!_entryConfirmed && isPipMode.value) {
            debugPrint('[PiP] entrada no confirmada por el sistema: revirtiendo');
            isPipMode.value = false;
          }
        });
      } else if (call.method == 'onPipChanged') {
        final bool inPip = call.arguments as bool? ?? false;
        if (inPip) {
          _entryConfirmed = true;
          _exitRevertTimer?.cancel();
          isPipMode.value = true;
        } else {
          // Salida: el árbol completo (rebuild pesado) vuelve ~250ms DESPUÉS,
          // para que la animación de expansión del SO corra sobre el video
          // pelado (fluido) en vez de competir con el rebuild. La orientación
          // sí se restaura ya (barato, y deja las métricas listas).
          _exitRevertTimer?.cancel();
          _exitRevertTimer = Timer(const Duration(milliseconds: 250), () {
            isPipMode.value = false;
          });
        }

        if (!inPip) {
          // Volver a la orientación previa al PiP (flujo mini: vertical).
          // Determinista: el nativo ya no resetea a UNSPECIFIED al salir.
          if (prePipWasLandscape) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
        }
      }
    });
  }

  /// Notifica al nativo si el usuario está dentro de la pantalla del reproductor (PlayerScreen)
  static Future<void> setPlayerActive(bool active) async {
    try {
      await _channel.invokeMethod('setPlayerActive', {'active': active});
    } catch (e) {
      debugPrint('Error setting player active: $e');
    }
  }

  /// Configura si el sistema operativo puede activar PiP al salir de la app (Home button)
  static Future<void> setPipAllowed(bool allowed, {double aspectRatioWidth = 16, double aspectRatioHeight = 9}) async {
    try {
      await _channel.invokeMethod('setPipAllowed', {
        'allowed': allowed,
        'aspectRatioWidth': aspectRatioWidth,
        'aspectRatioHeight': aspectRatioHeight,
      });
    } catch (e) {
      debugPrint('Error setting PiP allowed: $e');
    }
  }

  /// Fuerza la entrada manual a modo Picture-in-Picture (PiP)
  static Future<bool> enterPip({double aspectRatioWidth = 16, double aspectRatioHeight = 9}) async {
    _recordPrePipOrientation();
    try {
      final args = {
        'aspectRatioWidth': aspectRatioWidth,
        'aspectRatioHeight': aspectRatioHeight,
      };
      bool ok = await _channel.invokeMethod<bool>('enterPip', args) ?? false;
      if (!ok) {
        // La entrada puede fallar en transitorio (rotación/cambio de config
        // en curso al pulsar Home): un reintento corto la recupera.
        await Future.delayed(const Duration(milliseconds: 400));
        ok = await _channel.invokeMethod<bool>('enterPip', args) ?? false;
      }
      if (!ok) {
        debugPrint('[PiP] el sistema declinó la entrada (permiso revocado o estado transitorio)');
      }
      return ok;
    } catch (e) {
      debugPrint('Error entering PiP: $e');
      return false;
    }
  }

  /// Permiso real del SO (feature + AppOps). Si el usuario lo revocó en
  /// Ajustes, enterPictureInPictureMode falla en silencio: verificar antes.
  static Future<bool> isPipPermitted() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isPipPermitted');
      debugPrint('[PiP] permiso del sistema: $ok');
      return ok ?? false;
    } catch (e) {
      debugPrint('Error checking PiP permission: $e');
      return false;
    }
  }

  /// Abre los ajustes del sistema de Picture-in-picture para reactivarlo.
  static Future<void> openPipSettings() async {
    try {
      await _channel.invokeMethod('openPipSettings');
    } catch (e) {
      debugPrint('Error opening PiP settings: $e');
    }
  }
}
