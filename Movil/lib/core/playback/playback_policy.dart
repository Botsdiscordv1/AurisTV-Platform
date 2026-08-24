class PlaybackPolicy {
  /// Umbral de progreso para mostrar el botón "Siguiente" (0.0 a 1.0)
  final double? nextContentThreshold;

  /// Umbral de progreso para marcar el contenido como completado (0.0 a 1.0)
  final double completedThreshold;

  /// Tiempo restante para mostrar navegación o botón "Siguiente"
  final Duration? remainingTimeThreshold;

  /// Reproducción automática del siguiente contenido
  final bool autoPlayNext;

  /// Precargar siguiente contenido al alcanzar el 90%
  final bool preloadNext;

  const PlaybackPolicy({
    this.nextContentThreshold,
    required this.completedThreshold,
    this.remainingTimeThreshold,
    required this.autoPlayNext,
    required this.preloadNext,
  });
}
