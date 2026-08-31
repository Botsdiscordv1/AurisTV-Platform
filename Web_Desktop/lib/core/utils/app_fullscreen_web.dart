import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> setAppFullscreenImpl(bool fullscreen) async {
  try {
    final doc = web.document;
    if (fullscreen) {
      if (doc.fullscreenElement == null) {
        await doc.documentElement!.requestFullscreen().toDart;
        // Senior Web Fix: Intentar bloquear orientación a horizontal en móviles al entrar en pantalla completa
        try {
          final screen = web.window.screen;
          await screen.orientation.lock('landscape').toDart;
        } catch (_) {}
      }
    } else {
      if (doc.fullscreenElement != null) {
        // Senior Web Fix: Desbloquear orientación al salir de pantalla completa
        try {
          web.window.screen.orientation.unlock();
        } catch (_) {}
        await doc.exitFullscreen().toDart;
      }
    }
  } catch (_) {}
}

bool isAppFullscreenImpl() {
  try {
    return web.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

Future<void> lockAppOrientationImpl() async {
  try {
    final screen = web.window.screen;
    await screen.orientation.lock('landscape').toDart;
  } catch (_) {}
}

Future<void> unlockAppOrientationImpl() async {
  try {
    web.window.screen.orientation.unlock();
  } catch (_) {}
}

Stream<void> onFullscreenChangedImpl() {
  final controller = StreamController<void>.broadcast();
  
  // Guardamos la referencia para poder removerla luego
  JSFunction? jsHandler;
  
  controller.onListen = () {
    jsHandler = ((web.Event _) {
      if (!controller.isClosed) controller.add(null);
    }).toJS;
    web.document.addEventListener('fullscreenchange', jsHandler!);
  };
  
  controller.onCancel = () {
    if (jsHandler != null) {
      web.document.removeEventListener('fullscreenchange', jsHandler!);
    }
  };
  
  return controller.stream;
}
