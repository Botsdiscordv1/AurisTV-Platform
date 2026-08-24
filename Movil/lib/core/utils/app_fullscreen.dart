import 'app_fullscreen_io.dart'
    if (dart.library.js_interop) 'app_fullscreen_web.dart' as impl;

/// Activa/desactiva el modo pantalla completa real del dispositivo/browser.
/// En nativo (Windows/Linux/macOS/móvil) usa el plugin `fullscreen_window`;
/// en Web usa la Fullscreen API del navegador.
Future<void> setAppFullscreen(bool fullscreen) => impl.setAppFullscreenImpl(fullscreen);

/// Devuelve true si la aplicación está actualmente en pantalla completa.
bool isAppFullscreen() => impl.isAppFullscreenImpl();

/// Bloquea la orientación a horizontal (Web y Nativo).
Future<void> lockAppOrientation() => impl.lockAppOrientationImpl();

/// Libera la orientación (permite vertical/horizontal).
Future<void> unlockAppOrientation() => impl.unlockAppOrientationImpl();
