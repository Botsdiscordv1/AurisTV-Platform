/// Catálogo de errores de reproducción con código y mensaje amigable
/// (estilo Netflix "(12013)"): el usuario ve una frase accionable + código,
/// el código queda en telemetría para diagnóstico.
class PlaybackErrorInfo {
  const PlaybackErrorInfo(this.code, this.message);

  /// Código estable tipo factura, p.ej. 'AURI1001'.
  final String code;

  /// Mensaje amigable en español.
  final String message;

  /// Mensaje listo para mostrar: 'texto… (AURI1001)'.
  String get display => '$message ($code)';
}

/// Traduce el mensaje crudo del reproductor a un [PlaybackErrorInfo].
/// Orden importa: los patrones más específicos primero.
PlaybackErrorInfo describePlaybackError(String raw) {
  final m = raw.toLowerCase();

  // Autoplay bloqueado por falta de interacción (web).
  if (m.contains('interact') || m.contains('autoplay')) {
    return const PlaybackErrorInfo(
      'AURI1006',
      'El navegador bloqueó el inicio automático: pulsa el botón de reproducción.',
    );
  }

  // Red / DNS / timeouts.
  if (m.contains('socket') ||
      m.contains('connection') ||
      m.contains('network') ||
      m.contains('timed out') ||
      m.contains('timeout') ||
      m.contains('host name') ||
      m.contains('dns') ||
      m.contains('unreachable')) {
    return const PlaybackErrorInfo(
      'AURI1001',
      'Revisa tu conexión a internet e inténtalo de nuevo.',
    );
  }

  // URL de reproducción expirada o rechazada por el servidor (403/401).
  if (m.contains('demuxer_error') ||
      m.contains('could_not_parse') ||
      m.contains('403') ||
      m.contains('401') ||
      m.contains('forbidden') ||
      m.contains('unauthorized') ||
      m.contains('expired')) {
    return const PlaybackErrorInfo(
      'AURI1002',
      'El enlace de reproducción expiró. Pulsa Reintentar para cargarlo de nuevo.',
    );
  }

  // Recurso inexistente (404 / archivo no encontrado).
  if (m.contains('404') ||
      m.contains('not found') ||
      m.contains('no such file') ||
      m.contains('does not exist')) {
    return const PlaybackErrorInfo(
      'AURI1003',
      'El video no está disponible en este momento. Prueba con otro servidor o episodio.',
    );
  }

  // Códec / contenedor no soportado o datos corruptos.
  if (m.contains('codec') ||
      m.contains('unsupported') ||
      m.contains('corrupt') ||
      m.contains('moov atom') ||
      m.contains('invalid data') ||
      m.contains('failed to parse')) {
    return const PlaybackErrorInfo(
      'AURI1004',
      'Este video no se puede decodificar en tu dispositivo.',
    );
  }

  // Licencias / DRM.
  if (m.contains('drm') || m.contains('license') || m.contains('widevine')) {
    return const PlaybackErrorInfo(
      'AURI1005',
      'No se pudo obtener la licencia de reproducción.',
    );
  }

  return const PlaybackErrorInfo(
    'AURI1000',
    'Ocurrió un error inesperado al reproducir.',
  );
}
