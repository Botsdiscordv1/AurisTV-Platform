/// Configuración de render de video nativo por plataforma.
///
/// El entrypoint de Móvil decide si usa `SurfaceView` + `vo=mediacodec_embed`.
/// TV/Web dejan el valor en `false` para conservar la textura de media_kit.
///
/// No se usa `bool.fromEnvironment` directamente en Core porque una build de
/// TV/Web podría heredar el define por accidente y quedarse sin
/// `VideoController` (mini player, PiP, cast, etc.).
class VideoSurfaceConfig {
  VideoSurfaceConfig._();

  /// `true` solo en Móvil Android cuando su entrypoint habilita el modo nativo.
  static bool nativeAndroidSurface = false;

  /// `true` si el dispositivo soporta Hybrid Composition++ (Android 14+ con
  /// Vulkan/Impeller). HCPP compone la PlatformView a nivel del sistema y evita
  /// que un snapshot de la UI quede congelado encima del `SurfaceView`.
  static bool useHybridAndroidView = false;
}
